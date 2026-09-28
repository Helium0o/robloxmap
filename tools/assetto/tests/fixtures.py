"""Synthetic Assetto Corsa files for the tests (writes the same binary layout kn5.py reads)."""

from __future__ import annotations

import io
import math
import os
import struct

from aclib.ailine import AIPoint, write_ai

IDENTITY = (1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)


def _s(text: str) -> bytes:
    b = text.encode("utf-8")
    return struct.pack("<i", len(b)) + b


def png_bytes(color=(90, 90, 96)) -> bytes:
    try:
        from PIL import Image
    except ImportError:
        return b"not-an-image" + bytes(color)
    buf = io.BytesIO()
    Image.new("RGB", (4, 4), color).save(buf, format="PNG")
    return buf.getvalue()


def write_kn5(path: str, textures, materials, root, version: int = 6) -> None:
    out = bytearray(b"sc6969")
    out += struct.pack("<i", version)
    if version > 5:
        out += struct.pack("<i", 0)
    out += struct.pack("<i", len(textures))
    for name, data in textures:
        out += struct.pack("<i", 1) + _s(name) + struct.pack("<i", len(data)) + data
    out += struct.pack("<i", len(materials))
    for m in materials:
        out += _s(m["name"]) + _s(m.get("shader", "ksPerPixel"))
        out += struct.pack("<BB", m.get("blend", 0), 1 if m.get("alpha") else 0)
        if version > 4:
            out += struct.pack("<i", 0)
        props = m.get("props", {"ksDiffuse": 0.4})
        out += struct.pack("<i", len(props))
        for pname, value in props.items():
            out += _s(pname) + struct.pack("<10f", value, *([0.0] * 9))
        maps = m.get("maps", {})
        out += struct.pack("<i", len(maps))
        for sampler, tex in maps.items():
            out += _s(sampler) + struct.pack("<i", 0) + _s(tex)

    def node(n):
        nonlocal out
        children = n.get("children", [])
        out += struct.pack("<i", n["kind"]) + _s(n["name"]) + struct.pack("<i", len(children)) + b"\x01"
        if n["kind"] == 1:
            out += struct.pack("<16f", *n.get("matrix", IDENTITY))
        else:
            mesh = n["mesh"]
            pos, nrm, uv, idx = mesh["positions"], mesh["normals"], mesh["uvs"], mesh["indices"]
            vcount = len(pos) // 3
            skinned = n["kind"] == 3
            out += struct.pack("<BBB", 1, 1 if mesh.get("visible", True) else 0, 0)
            if skinned:
                out += struct.pack("<i", 1) + _s("bone0") + struct.pack("<16f", *IDENTITY)
            out += struct.pack("<i", vcount)
            for i in range(vcount):
                out += struct.pack("<8f", *pos[3 * i : 3 * i + 3], *nrm[3 * i : 3 * i + 3], *uv[2 * i : 2 * i + 2])
                out += struct.pack("<3f", 1, 0, 0)
                if skinned:
                    out += struct.pack("<8f", 1, 0, 0, 0, 0, 0, 0, 0)
            out += struct.pack("<i", len(idx)) + struct.pack(f"<{len(idx)}H", *idx)
            out += struct.pack("<ii", mesh.get("material", 0), 0)
            if skinned:
                out += b"\x00" * 8
            else:
                out += struct.pack("<ff", mesh.get("lod_in", 0.0), mesh.get("lod_out", 0.0))
                out += struct.pack("<4f", 0, 0, 0, 1)
                out += struct.pack("<B", 1 if mesh.get("renderable", True) else 0)
        for c in children:
            node(c)

    node(root)
    with open(path, "wb") as f:
        f.write(bytes(out))


def box(cx, cy, cz, sx, sy, sz, inverted=False):
    """Axis-aligned box mesh with outward normals (or inverted winding)."""
    positions, normals, uvs, indices = [], [], [], []
    faces = [
        ((1, 0, 0), (0, 0, -1), (0, 1, 0)),
        ((-1, 0, 0), (0, 0, 1), (0, 1, 0)),
        ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
        ((0, -1, 0), (1, 0, 0), (0, 0, 1)),
        ((0, 0, 1), (1, 0, 0), (0, 1, 0)),
        ((0, 0, -1), (-1, 0, 0), (0, 1, 0)),
    ]
    for n, u, v in faces:
        base = len(positions) // 3
        for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            x = cx + (n[0] + a * u[0] + b * v[0]) * sx / 2
            y = cy + (n[1] + a * u[1] + b * v[1]) * sy / 2
            z = cz + (n[2] + a * u[2] + b * v[2]) * sz / 2
            positions += [x, y, z]
            normals += list(n)
            uvs += [(a + 1) / 2, (b + 1) / 2]
        # u x v = n, so (0,1,2) is counter-clockwise seen from outside
        tri = [base, base + 1, base + 2, base, base + 2, base + 3]
        if inverted:
            tri = [base, base + 2, base + 1, base, base + 3, base + 2]
        indices += tri
    return {"positions": positions, "normals": normals, "uvs": uvs, "indices": indices}


def ribbon(points, width):
    """Flat road strip along a closed loop of (x, z) points at y = 0, normals up."""
    positions, normals, uvs, indices = [], [], [], []
    n = len(points)
    for i, (x, z) in enumerate(points):
        nx_, nz_ = points[(i + 1) % n]
        px, pz = points[i - 1]
        dx, dz = nx_ - px, nz_ - pz
        length = math.hypot(dx, dz)
        rx, rz = -dz / length, dx / length
        for side in (-1, 1):
            positions += [x + rx * side * width / 2, 0.0, z + rz * side * width / 2]
            normals += [0, 1, 0]
            uvs += [(side + 1) / 2, i / 4]
    for i in range(n):
        a, b = 2 * i, 2 * i + 1
        c, d = 2 * ((i + 1) % n), 2 * ((i + 1) % n) + 1
        # choose winding so the geometric normal points up (+Y)
        for tri in ((a, c, b), (b, c, d)):
            p = [positions[3 * k : 3 * k + 3] for k in tri]
            ux, uz = p[1][0] - p[0][0], p[1][2] - p[0][2]
            vx, vz = p[2][0] - p[0][0], p[2][2] - p[0][2]
            gy = uz * vx - ux * vz
            indices += list(tri) if gy > 0 else [tri[0], tri[2], tri[1]]
    return {"positions": positions, "normals": normals, "uvs": uvs, "indices": indices}


def oval(n=120, rx=180.0, rz=110.0):
    return [(rx * math.cos(2 * math.pi * i / n), rz * math.sin(2 * math.pi * i / n)) for i in range(n)]


GROUP_MATRIX = (0, 0, -1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 100, 0, 50, 1)  # 90 deg about Y, then move


def make_track(root_dir: str, name: str = "testring", with_models_ini: bool = False) -> str:
    track = os.path.join(root_dir, name)
    os.makedirs(os.path.join(track, "ai"), exist_ok=True)
    os.makedirs(os.path.join(track, "data"), exist_ok=True)
    os.makedirs(os.path.join(track, "ui"), exist_ok=True)
    textures = [
        ("asphalt.png", png_bytes((50, 50, 56))),
        ("bricks.png", png_bytes((180, 60, 40))),
        ("big.dds", b"\x00" * 200_000),
    ]
    materials = [
        {"name": "road", "shader": "ksMultilayer", "maps": {"txDiffuse": "asphalt.png"}},
        {"name": "grass", "shader": "ksPerPixel"},
        {"name": "bricks", "shader": "ksPerPixel", "maps": {"txDiffuse": "bricks.png"}},
        {"name": "leaves", "shader": "ksPerPixelAT", "alpha": True},
        {"name": "concrete", "shader": "ksPerPixel"},
    ]
    plane = {
        "positions": [-300, -1, -200, 300, -1, -200, 300, -1, 200, -300, -1, 200],
        "normals": [0, 1, 0] * 4,
        "uvs": [0, 0, 1, 0, 1, 1, 0, 1],
        "indices": [0, 2, 1, 0, 3, 2],
        "material": 1,
    }
    road = ribbon(oval(), 12.0)
    road["material"] = 0
    building = box(0, 5, 0, 10, 10, 20)
    building["material"] = 2
    wall = box(-150, 1, 0, 2, 2, 60, inverted=True)
    wall["material"] = 4
    tree = box(20, 5, 20, 1, 10, 1)
    tree["material"] = 3
    far = box(0, 30, 400, 40, 60, 40)
    far["material"] = 2
    far["lod_in"] = 500.0
    flag = box(10, 10, 10, 1, 1, 1)
    flag["material"] = 4
    root = {
        "kind": 1,
        "name": name,
        "children": [
            {"kind": 2, "name": "1ROAD_main", "mesh": road},
            {"kind": 2, "name": "1GRASS_infield", "mesh": plane},
            {
                "kind": 1,
                "name": "GRP_buildings",
                "matrix": GROUP_MATRIX,
                "children": [{"kind": 2, "name": "pitbuilding", "mesh": building}],
            },
            {"kind": 2, "name": "armco_wall", "mesh": wall},
            {"kind": 2, "name": "tree_01", "mesh": tree},
            {"kind": 2, "name": "stand_far", "mesh": far},
            {"kind": 3, "name": "flag_anim", "mesh": flag},
            {"kind": 1, "name": "AC_START_0"},
        ],
    }
    write_kn5(os.path.join(track, name + ".kn5"), textures, materials, root)
    pts = []
    for x, z in oval(240):
        pts.append(AIPoint(x, 0.1, z, 0.0, side_left=6.0, side_right=6.0, speed=30))
    pts.append(AIPoint(pts[0].x, pts[0].y, pts[0].z, 0.0, 6.0, 6.0, 30))
    write_ai(os.path.join(track, "ai", "fast_lane.ai"), pts)
    with open(os.path.join(track, "data", "surfaces.ini"), "w") as f:
        f.write("[SURFACE_0]\nKEY=ROAD\nFRICTION=0.98\n\n[SURFACE_1]\nKEY=GRASS\nFRICTION=0.6\n")
    with open(os.path.join(track, "ui", "ui_track.json"), "w") as f:
        f.write('{"name": "Test Ring", "length": "1100"}')
    if with_models_ini:
        with open(os.path.join(track, "models_short.ini"), "w") as f:
            f.write(f"[MODEL_0]\nFILE={name}.kn5\nPOSITION=0,0,0\nROTATION=0,0,0\n")
    return track
