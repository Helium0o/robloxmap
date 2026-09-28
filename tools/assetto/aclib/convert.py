"""KN5 track geometry -> Roblox-ready OBJ tiles, manifest and racing line.

Roblox limits (2026): a MeshPart holds at most 20,000 triangles and a part may not be larger
than 2048 studs on any axis. Tracks therefore get cut into square tiles, every tile into
objects below `max_tris`, and each object becomes one MeshPart after import.

Coordinates: Assetto Corsa and Roblox are both right-handed with +Y up, so positions map
directly; they are only scaled from metres to studs (default 1 stud = 0.28 m) and moved so
the track is centred on the origin with its lowest road near y = 0.
"""

from __future__ import annotations

import json
import math
import os
import re
from array import array
from dataclasses import dataclass, field

from . import kn5 as kn5mod
from .ailine import read_ai

# default look of each category in Roblox (material name, RGB, collide)
CATEGORY_STYLE = {
    "road": ("Asphalt", (46, 46, 52), True),
    "kerb": ("SmoothPlastic", (186, 64, 60), True),
    "grass": ("Grass", (62, 98, 54), True),
    "sand": ("Sand", (190, 170, 120), True),
    "ground": ("Ground", (92, 86, 66), True),
    "wall": ("Concrete", (150, 150, 152), True),
    "building": ("SmoothPlastic", (158, 158, 164), True),
    "alpha": ("SmoothPlastic", (70, 110, 60), False),
    "foliage": ("Grass", (48, 86, 46), False),
    "crowd": ("SmoothPlastic", (120, 110, 100), False),
    "sky": ("SmoothPlastic", (120, 140, 170), False),
}

SKIPPED_BY_DEFAULT = {"helper", "sky", "crowd", "foliage", "alpha"}

PHYSICS_MAP = {
    "ROAD": "road",
    "PIT": "road",
    "ASPHALT": "road",
    "KERB": "kerb",
    "CURB": "kerb",
    "GRASS": "grass",
    "SAND": "sand",
    "GRAVEL": "sand",
    "DIRT": "sand",
    "WALL": "wall",
    "BARRIER": "wall",
    "GROUND": "ground",
    "TERRAIN": "ground",
}

KEYWORDS = [
    ("helper", r"^ac_|shadow|_collider$|^col_"),
    ("sky", r"sky|horizon|cloud|backdrop|panorama"),
    ("crowd", r"crowd|people|spectator|audience|marshal|fans\b|flagman"),
    ("foliage", r"tree|leaf|leaves|foliage|bush|hedge|plant|palm|pine|vegetation|forest|3dgrass|grass3d|shrub"),
    ("kerb", r"kerb|curb|rumble"),
    ("road", r"road|asphalt|tarmac|pitlane|pit_lane|runway"),
    ("grass", r"grass|lawn|turf"),
    ("sand", r"sand|gravel|dirt"),
    ("wall", r"wall|barrier|fence|guardrail|guard_rail|armco|rail|tyre|tire|tecpro|jersey"),
    ("ground", r"terrain|ground|land|mountain|hill|cliff|rock"),
]


@dataclass
class Settings:
    studs_per_meter: float = 1 / 0.28
    tile: float = 1024.0
    max_tris: int = 19000
    mirror: bool = False
    keep: set = field(default_factory=set)  # extra categories to keep (e.g. {"foliage"})
    drop: set = field(default_factory=set)  # categories to drop (e.g. {"building"})
    keep_lod: bool = False
    exclude: list = field(default_factory=list)  # regexes on node names
    include: list = field(default_factory=list)
    colors: bool = True  # average texture colour per object (needs Pillow)
    center: bool = True
    swap_sides: bool = False


@dataclass
class Geom:
    name: str
    category: str
    material: str
    positions: array
    normals: array
    uvs: array
    indices: array
    invisible: bool
    color: tuple | None = None


class Classifier:
    def __init__(self, surfaces):
        keys = sorted({s.upper() for s in surfaces}, key=len, reverse=True)
        self.physics = re.compile(r"^\d+(" + "|".join(map(re.escape, keys)) + r")", re.I) if keys else None
        self.keywords = [(cat, re.compile(rx, re.I)) for cat, rx in KEYWORDS]

    def classify(self, name: str, material) -> tuple:
        """Returns (category, is_physics_surface)."""
        if self.physics:
            m = self.physics.match(name)
            if m:
                return PHYSICS_MAP.get(m.group(1).upper(), "ground"), True
        text = name
        if material is not None:
            text = f"{name} {material.name} {material.shader}"
        for category, rx in self.keywords:
            if rx.search(name if category == "helper" else text):
                return category, False
        if material is not None:
            shader = material.shader.lower()
            if shader.startswith("kstree") or shader.startswith("ksgrass"):
                return "foliage", False
            if material.alpha_tested or material.blend_mode != 0:
                return "alpha", False
        return "building", False


def _texture_color(kn5, material, cache):
    """Average colour of a material's diffuse texture, or None (needs Pillow)."""
    if material is None:
        return None
    name = material.textures.get("txDiffuse") or next(iter(material.textures.values()), None)
    if not name:
        return None
    if name in cache:
        return cache[name]
    color = None
    tex = next((t for t in kn5.textures if t.name == name), None)
    if tex is not None:
        try:
            import io

            from PIL import Image

            with Image.open(io.BytesIO(tex.read(kn5))) as img:
                img = img.convert("RGB").resize((8, 8))
                pixels = list(img.getdata())
            color = tuple(int(sum(p[i] for p in pixels) / len(pixels)) for i in range(3))
        except Exception:
            color = None
    cache[name] = color
    return color


def _transform_node(node, settings):
    """Mesh vertices of a node -> Roblox studs (before centring), plus normals."""
    m = node.world
    s = settings.studs_per_meter
    mx = -1.0 if settings.mirror else 1.0
    pos = node.mesh.positions
    nrm = node.mesh.normals
    count = len(pos) // 3
    out_p = array("f", bytes(4 * 3 * count))
    out_n = array("f", bytes(4 * 3 * count))
    m00, m01, m02 = m[0], m[1], m[2]
    m10, m11, m12 = m[4], m[5], m[6]
    m20, m21, m22 = m[8], m[9], m[10]
    m30, m31, m32 = m[12], m[13], m[14]
    for i in range(count):
        x, y, z = pos[3 * i], pos[3 * i + 1], pos[3 * i + 2]
        out_p[3 * i] = (x * m00 + y * m10 + z * m20 + m30) * s * mx
        out_p[3 * i + 1] = (x * m01 + y * m11 + z * m21 + m31) * s
        out_p[3 * i + 2] = (x * m02 + y * m12 + z * m22 + m32) * s
        a, b, c = nrm[3 * i], nrm[3 * i + 1], nrm[3 * i + 2]
        out_n[3 * i] = (a * m00 + b * m10 + c * m20) * mx
        out_n[3 * i + 1] = a * m01 + b * m11 + c * m21
        out_n[3 * i + 2] = a * m02 + b * m12 + c * m22
    return out_p, out_n


def _fix_winding(positions, normals, indices):
    """Makes triangle winding agree with the authored normals (Roblox culls back faces).

    Votes over the whole mesh and flips it if most triangles disagree. Returns True if flipped."""
    agree = 0
    disagree = 0
    p, n = positions, normals
    for t in range(0, len(indices) - 2, 3):
        a, b, c = indices[t], indices[t + 1], indices[t + 2]
        ax, ay, az = p[3 * a], p[3 * a + 1], p[3 * a + 2]
        ux, uy, uz = p[3 * b] - ax, p[3 * b + 1] - ay, p[3 * b + 2] - az
        vx, vy, vz = p[3 * c] - ax, p[3 * c + 1] - ay, p[3 * c + 2] - az
        gx, gy, gz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        nx = n[3 * a] + n[3 * b] + n[3 * c]
        ny = n[3 * a + 1] + n[3 * b + 1] + n[3 * c + 1]
        nz = n[3 * a + 2] + n[3 * b + 2] + n[3 * c + 2]
        d = gx * nx + gy * ny + gz * nz
        if d > 0:
            agree += 1
        elif d < 0:
            disagree += 1
    if disagree > agree:
        for t in range(0, len(indices) - 2, 3):
            indices[t + 1], indices[t + 2] = indices[t + 2], indices[t + 1]
        return True
    return False


@dataclass
class Report:
    kept: dict = field(default_factory=dict)  # category -> triangles
    skipped: dict = field(default_factory=dict)  # reason -> triangles
    flipped: int = 0
    objects: int = 0
    offset: tuple = (0.0, 0.0, 0.0)
    bounds: tuple = (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    warnings: list = field(default_factory=list)


def load_geometry(track, settings: Settings, report: Report, log=print) -> list:
    classifier = Classifier(track.surfaces)
    excludes = [re.compile(x, re.I) for x in settings.exclude]
    includes = [re.compile(x, re.I) for x in settings.include]
    geoms = []
    for ref in track.models:
        if not os.path.isfile(ref.path):
            report.warnings.append(f"missing model file {ref.path}")
            continue
        if any(abs(r) > 1e-6 for r in ref.rotation):
            report.warnings.append(f"{os.path.basename(ref.path)}: ROTATION in models ini ignored")
        log(f"reading {os.path.basename(ref.path)} ...")
        model = kn5mod.read_kn5(ref.path, load_meshes=True)
        color_cache = {}
        try:
            for node in model.meshes():
                mesh = node.mesh
                tris = mesh.triangle_count
                if tris == 0:
                    continue
                material = model.materials[mesh.material_id] if 0 <= mesh.material_id < len(model.materials) else None
                category, physics = classifier.classify(node.name, material)
                forced = any(rx.search(node.name) for rx in includes)
                reason = None
                if any(rx.search(node.name) for rx in excludes) and not forced:
                    reason = "excluded by pattern"
                elif category in settings.drop and not forced:
                    reason = f"category {category} dropped"
                elif category in SKIPPED_BY_DEFAULT and category not in settings.keep and not forced:
                    reason = f"category {category}"
                elif node.lod_in > 0 and not settings.keep_lod and not forced:
                    reason = "distant LOD"
                elif not (mesh.visible and mesh.renderable) and not physics and not forced:
                    reason = "hidden"
                elif mesh.skinned and not forced:
                    reason = "animated mesh"
                if reason:
                    report.skipped[reason] = report.skipped.get(reason, 0) + tris
                    continue
                positions, normals = _transform_node(node, settings)
                if ref.position != (0.0, 0.0, 0.0):
                    px, py, pz = ref.position
                    s = settings.studs_per_meter
                    dx = px * s * (-1 if settings.mirror else 1)
                    for i in range(0, len(positions), 3):
                        positions[i] += dx
                        positions[i + 1] += py * s
                        positions[i + 2] += pz * s
                indices = array("I", mesh.indices)
                if _fix_winding(positions, normals, indices):
                    report.flipped += 1
                color = _texture_color(model, material, color_cache) if settings.colors else None
                geoms.append(
                    Geom(
                        name=node.name,
                        category=category,
                        material=material.name if material else "",
                        positions=positions,
                        normals=normals,
                        uvs=array("f", mesh.uvs),
                        indices=indices,
                        invisible=not (mesh.visible and mesh.renderable),
                        color=color,
                    )
                )
                report.kept[category] = report.kept.get(category, 0) + tris
        finally:
            model.close()
    return geoms


def center_geometry(geoms, settings: Settings, report: Report):
    inf = float("inf")
    x0 = y0 = z0 = inf
    x1 = y1 = z1 = -inf
    road_y = inf
    for g in geoms:
        p = g.positions
        xs, ys, zs = p[0::3], p[1::3], p[2::3]
        x0, x1 = min(x0, min(xs)), max(x1, max(xs))
        y0, y1 = min(y0, min(ys)), max(y1, max(ys))
        z0, z1 = min(z0, min(zs)), max(z1, max(zs))
        if g.category == "road":
            road_y = min(road_y, min(ys))
    if not geoms:
        return
    if settings.center:
        base_y = road_y if road_y < inf else y0
        offset = (-(x0 + x1) / 2, -base_y, -(z0 + z1) / 2)
    else:
        offset = (0.0, 0.0, 0.0)
    ox, oy, oz = offset
    for g in geoms:
        p = g.positions
        for i in range(0, len(p), 3):
            p[i] += ox
            p[i + 1] += oy
            p[i + 2] += oz
    report.offset = offset
    report.bounds = (x0 + ox, y0 + oy, z0 + oz, x1 + ox, y1 + oy, z1 + oz)


def _subdivide_large(g: Geom, limit: float):
    """Splits triangles longer than `limit` studs so no object outgrows Roblox's size cap."""
    p, n, uv, idx = g.positions, g.normals, g.uvs, g.indices
    out = array("I")
    stack = [(idx[t], idx[t + 1], idx[t + 2]) for t in range(0, len(idx) - 2, 3)]
    changed = False

    def extent(a, b, c):
        xs = (p[3 * a], p[3 * b], p[3 * c])
        ys = (p[3 * a + 1], p[3 * b + 1], p[3 * c + 1])
        zs = (p[3 * a + 2], p[3 * b + 2], p[3 * c + 2])
        return max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))

    def midpoint(a, b):
        k = len(p) // 3
        for arr, dim in ((p, 3), (n, 3)):
            for d in range(dim):
                arr.append((arr[dim * a + d] + arr[dim * b + d]) / 2)
        for d in range(2):
            uv.append((uv[2 * a + d] + uv[2 * b + d]) / 2)
        return k

    while stack:
        a, b, c = stack.pop()
        if extent(a, b, c) > limit:
            changed = True
            ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
            stack.extend([(a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)])
        else:
            out.extend((a, b, c))
    if changed:
        g.indices = out


def _safe(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]+", "_", name).strip("_") or "track"


def write_tiles(geoms, out_dir: str, track_name: str, settings: Settings, report: Report, log=print) -> list:
    tiles_dir = os.path.join(out_dir, "meshes")
    os.makedirs(tiles_dir, exist_ok=True)
    tile = settings.tile
    for g in geoms:
        _subdivide_large(g, tile * 0.9)

    # bucket -> (geometry indices, triangle offsets), kept as compact arrays
    buckets = {}
    for gi, g in enumerate(geoms):
        p, idx = g.positions, g.indices
        for t in range(0, len(idx) - 2, 3):
            a, b, c = idx[t], idx[t + 1], idx[t + 2]
            cx = (p[3 * a] + p[3 * b] + p[3 * c]) / 3
            cz = (p[3 * a + 2] + p[3 * b + 2] + p[3 * c + 2]) / 3
            key = (math.floor(cx / tile), math.floor(cz / tile), g.category, g.invisible)
            entry = buckets.get(key)
            if entry is None:
                entry = buckets[key] = (array("I"), array("I"))
            entry[0].append(gi)
            entry[1].append(t)

    if not buckets:
        return []
    min_tx = min(k[0] for k in buckets)
    min_tz = min(k[1] for k in buckets)
    base = _safe(track_name)
    objects = []
    for key in sorted(buckets, key=lambda k: (k[1], k[0], k[2], k[3])):
        tx, tz, category, invisible = key
        gis, ts = buckets[key]
        for chunk_index, start in enumerate(range(0, len(ts), settings.max_tris)):
            chunk = list(zip(gis[start : start + settings.max_tris], ts[start : start + settings.max_tris]))
            suffix = "_collider" if invisible else ""
            name = f"{base}_{tx - min_tx:02d}_{tz - min_tz:02d}_{category}{suffix}_{chunk_index + 1}"
            path = os.path.join(tiles_dir, name + ".obj")
            info = _write_obj(path, name, geoms, chunk, category)
            info.update(
                {
                    "name": name,
                    "file": os.path.relpath(path, out_dir).replace(os.sep, "/"),
                    "category": category,
                    "tile": [tx - min_tx, tz - min_tz],
                    "invisible": invisible,
                }
            )
            objects.append(info)
    report.objects = len(objects)
    log(f"wrote {len(objects)} mesh files to {tiles_dir}")
    return objects


def _write_obj(path, name, geoms, chunk, category):
    remap = {}
    verts = []
    faces = []
    color_weight = [0.0, 0.0, 0.0, 0.0]
    for gi, t in chunk:
        g = geoms[gi]
        idx = g.indices
        face = []
        for corner in (idx[t], idx[t + 1], idx[t + 2]):
            key = (gi, corner)
            k = remap.get(key)
            if k is None:
                k = len(verts) + 1
                remap[key] = k
                verts.append(key)
            face.append(k)
        faces.append(face)
        if g.color is not None:
            color_weight[0] += g.color[0]
            color_weight[1] += g.color[1]
            color_weight[2] += g.color[2]
            color_weight[3] += 1
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    lines = [f"# ac2roblox: {name} ({category}, {len(faces)} triangles)", f"o {name}"]
    for gi, v in verts:
        p = geoms[gi].positions
        x, y, z = p[3 * v], p[3 * v + 1], p[3 * v + 2]
        lo = [min(lo[0], x), min(lo[1], y), min(lo[2], z)]
        hi = [max(hi[0], x), max(hi[1], y), max(hi[2], z)]
        lines.append(f"v {x:.4f} {y:.4f} {z:.4f}")
    for gi, v in verts:
        uv = geoms[gi].uvs
        lines.append(f"vt {uv[2 * v]:.5f} {1 - uv[2 * v + 1]:.5f}")
    for gi, v in verts:
        n = geoms[gi].normals
        nx, ny, nz = n[3 * v], n[3 * v + 1], n[3 * v + 2]
        length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
        lines.append(f"vn {nx / length:.4f} {ny / length:.4f} {nz / length:.4f}")
    for a, b, c in faces:
        lines.append(f"f {a}/{a}/{a} {b}/{b}/{b} {c}/{c}/{c}")
    with open(path, "w", newline="\n") as f:
        f.write("\n".join(lines))
        f.write("\n")
    color = None
    if color_weight[3] > 0:
        color = [int(color_weight[i] / color_weight[3]) for i in range(3)]
    size = [max(0.05, hi[i] - lo[i]) for i in range(3)]
    center = [(hi[i] + lo[i]) / 2 for i in range(3)]
    return {
        "triangles": len(faces),
        "vertices": len(verts),
        "center": [round(c, 3) for c in center],
        "size": [round(s, 3) for s in size],
        "color": color,
    }


def racing_line(track, settings: Settings, report: Report, tolerance: float = 0.35, max_step: float = 48.0):
    """AI spline in the same space as the meshes, simplified for Roblox.

    Returns dict(points=[[x, y, z, left, right], ...], closed=bool) in studs, where left and
    right are the distances to the track edges relative to the direction of travel."""
    if not track.ai_path:
        return None
    ai = read_ai(track.ai_path)
    s = settings.studs_per_meter
    mx = -1.0 if settings.mirror else 1.0
    ox, oy, oz = report.offset
    pts = []
    for p in ai.points:
        left, right = p.side_left * s, p.side_right * s
        if settings.mirror != settings.swap_sides:
            left, right = right, left
        pts.append((p.x * s * mx + ox, p.y * s + oy, p.z * s + oz, left, right))
    if len(pts) < 2:
        return None
    spacing = sum(math.dist(pts[i][:3], pts[i + 1][:3]) for i in range(len(pts) - 1)) / (len(pts) - 1)
    closed = math.dist(pts[0][:3], pts[-1][:3]) < max(3 * spacing, 20.0)

    # Ramer-Douglas-Peucker on positions, then cap the segment length
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i0, i1 = stack.pop()
        a, b = pts[i0][:3], pts[i1][:3]
        ab = [b[k] - a[k] for k in range(3)]
        ab_len2 = sum(c * c for c in ab) or 1e-9
        worst, worst_d = None, tolerance
        for i in range(i0 + 1, i1):
            q = pts[i][:3]
            t = max(0.0, min(1.0, sum((q[k] - a[k]) * ab[k] for k in range(3)) / ab_len2))
            d = math.dist(q, [a[k] + ab[k] * t for k in range(3)])
            w = abs((pts[i][3] + pts[i][4]) - (pts[i0][3] + pts[i0][4]))
            if d > worst_d or w > 4.0:
                worst, worst_d = i, max(d, worst_d)
        if worst is not None:
            keep[worst] = True
            stack.append((i0, worst))
            stack.append((worst, i1))
    simplified = []
    last = None
    for i, p in enumerate(pts):
        if keep[i]:
            if last is not None:
                gap = math.dist(last[:3], p[:3])
                steps = int(gap // max_step)
                for k in range(1, steps + 1):
                    t = k / (steps + 1)
                    simplified.append(tuple(last[j] + (p[j] - last[j]) * t for j in range(5)))
            simplified.append(p)
            last = p
    if closed and math.dist(simplified[0][:3], simplified[-1][:3]) < 1.0:
        simplified.pop()
    return {
        "points": [[round(v, 2) for v in p] for p in simplified],
        "closed": closed,
        "length_m": round(ai.length, 1),
        "has_sides": ai.has_sides,
    }


def write_manifest(out_dir, track, settings, report, objects, line):
    manifest = {
        "track": _safe(track.name),
        "layout": track.layout,
        "studs_per_meter": settings.studs_per_meter,
        "mirror": settings.mirror,
        "offset": [round(v, 3) for v in report.offset],
        "bounds": [round(v, 2) for v in report.bounds],
        "objects": objects,
        "racing_line": line,
        "styles": {k: {"material": v[0], "color": list(v[1]), "collide": v[2]} for k, v in CATEGORY_STYLE.items()},
    }
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    return manifest
