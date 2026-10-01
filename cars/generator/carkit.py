"""
carkit - a small procedural toolkit for building semi-realistic car meshes
that import cleanly into Roblox Studio (File > Import 3D, .obj).

Coordinate convention while building (all units are metres):
    u : longitudinal, 0 = rear bumper, L = front bumper
    s : lateral, + = car's right side
    h : height above ground

On export the car is centred and converted to Roblox-friendly axes:
    X = right, Y = up, -Z = forward (matches Roblox LookVector), units = studs.
"""

import math
import numpy as np

METRES_PER_STUD = 0.28  # Roblox's official real-world conversion


# --------------------------------------------------------------------------
# small maths helpers
# --------------------------------------------------------------------------

def pchip(xk, yk, x):
    """Monotone cubic (Fritsch-Carlson) interpolation - no overshoot."""
    xk = np.asarray(xk, float)
    yk = np.asarray(yk, float)
    x = np.asarray(x, float)
    n = len(xk)
    if n == 1:
        return np.full_like(x, yk[0])
    h = np.diff(xk)
    d = np.diff(yk) / h
    m = np.zeros(n)
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0:
            m[i] = 0.0
        else:
            w1 = 2 * h[i] + h[i - 1]
            w2 = h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
    xc = np.clip(x, xk[0], xk[-1])
    i = np.clip(np.searchsorted(xk, xc) - 1, 0, n - 2)
    t = (xc - xk[i]) / h[i]
    t2, t3 = t * t, t * t * t
    return ((2 * t3 - 3 * t2 + 1) * yk[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
            + (-2 * t3 + 3 * t2) * yk[i + 1] + (t3 - t2) * h[i] * m[i + 1])


def curve(keys):
    """keys: list of (u, value) -> callable f(u)."""
    keys = sorted(keys)
    xs = [k[0] for k in keys]
    ys = [k[1] for k in keys]
    return lambda u: pchip(xs, ys, u)


def circle_poly(cx, cy, r, n=32, ry=None, rot=0.0):
    ry = r if ry is None else ry
    a = np.linspace(0, 2 * math.pi, n, endpoint=False)
    x, y = r * np.cos(a), ry * np.sin(a)
    c, s = math.cos(rot), math.sin(rot)
    return [(cx + c * xi - s * yi, cy + s * xi + c * yi) for xi, yi in zip(x, y)]


def rounded_poly(pts, radius, seg=4):
    """Round the corners of a polygon (list of (x,y))."""
    pts = [np.array(p, float) for p in pts]
    n = len(pts)
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        a, b = p0 - p1, p2 - p1
        la, lb = np.linalg.norm(a), np.linalg.norm(b)
        r = min(radius, la * 0.45, lb * 0.45)
        if r <= 1e-6:
            out.append(tuple(p1))
            continue
        qa, qb = p1 + a / la * r, p1 + b / lb * r
        for k in range(seg + 1):
            t = k / seg
            q = (1 - t) ** 2 * qa + 2 * (1 - t) * t * p1 + t * t * qb
            out.append(tuple(q))
    return out


def poly_area(pts):
    p = np.asarray(pts)
    return 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])


def triangulate(poly):
    """Ear-clipping triangulation of a simple polygon. Returns index triples."""
    pts = [np.array(p, float) for p in poly]
    idx = list(range(len(pts)))
    if poly_area(poly) < 0:
        idx.reverse()
    tris = []

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        n = len(idx)
        for k in range(n):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % n]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if cross(a, b, c) <= 1e-12:
                continue
            ok = True
            for j in idx:
                if j in (i0, i1, i2):
                    continue
                p = pts[j]
                if cross(a, b, p) >= 0 and cross(b, c, p) >= 0 and cross(c, a, p) >= 0:
                    ok = False
                    break
            if ok:
                tris.append((i0, i1, i2))
                idx.pop(k)
                break
        else:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    return tris


def delaunay_flip(verts2d, tris, iters=2000):
    """Lawson edge flips -> constrained Delaunay (outline edges never flip)."""
    P = np.asarray(verts2d, float)
    T = [list(t) for t in tris]

    def incircle(a, b, c, d):
        m = np.array([[P[a][0] - P[d][0], P[a][1] - P[d][1], (P[a] - P[d]) @ (P[a] - P[d])],
                      [P[b][0] - P[d][0], P[b][1] - P[d][1], (P[b] - P[d]) @ (P[b] - P[d])],
                      [P[c][0] - P[d][0], P[c][1] - P[d][1], (P[c] - P[d]) @ (P[c] - P[d])]])
        return np.linalg.det(m) > 1e-14

    def ccw(a, b, c):
        return (P[b][0] - P[a][0]) * (P[c][1] - P[a][1]) - (P[b][1] - P[a][1]) * (P[c][0] - P[a][0])

    for _ in range(iters):
        edges = {}
        for ti, t in enumerate(T):
            for k in range(3):
                a, b = t[k], t[(k + 1) % 3]
                edges.setdefault((min(a, b), max(a, b)), []).append(ti)
        flipped = False
        touched = set()
        for (a, b), ts in edges.items():
            if len(ts) != 2 or ts[0] in touched or ts[1] in touched:
                continue
            t1, t2 = T[ts[0]], T[ts[1]]
            c = [v for v in t1 if v not in (a, b)][0]
            d = [v for v in t2 if v not in (a, b)][0]
            # orient t1 as (a, b, c) ccw
            if ccw(a, b, c) < 0:
                a, b = b, a
            if incircle(a, b, c, d) and ccw(c, d, b) * ccw(c, d, a) < 0:
                T[ts[0]] = [a, d, c] if ccw(a, d, c) > 0 else [a, c, d]
                T[ts[1]] = [d, b, c] if ccw(d, b, c) > 0 else [d, c, b]
                touched.update(ts)
                flipped = True
        if not flipped:
            break
    return [tuple(t) for t in T]


def refine(verts2d, tris, maxlen):
    """Conforming red-green refinement until every edge is shorter than maxlen."""
    V = [np.array(v, float) for v in verts2d]
    T = [tuple(t) for t in tris]
    for _ in range(12):
        mids = {}

        def key(a, b):
            return (a, b) if a < b else (b, a)

        long_edges = set()
        for t in T:
            for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
                if np.linalg.norm(V[a] - V[b]) > maxlen:
                    long_edges.add(key(a, b))
        if not long_edges:
            break
        for e in long_edges:
            mids[e] = len(V)
            V.append((V[e[0]] + V[e[1]]) * 0.5)
        NT = []
        for t in T:
            a, b, c = t
            mab, mbc, mca = mids.get(key(a, b)), mids.get(key(b, c)), mids.get(key(c, a))
            ms = [mab is not None, mbc is not None, mca is not None]
            cnt = sum(ms)
            if cnt == 0:
                NT.append(t)
            elif cnt == 3:
                NT += [(a, mab, mca), (mab, b, mbc), (mca, mbc, c), (mab, mbc, mca)]
            elif cnt == 1:
                if mab is not None:
                    NT += [(a, mab, c), (mab, b, c)]
                elif mbc is not None:
                    NT += [(a, b, mbc), (a, mbc, c)]
                else:
                    NT += [(a, b, mca), (mca, b, c)]
            else:  # two split edges
                if mab is None:
                    NT += [(a, b, mbc), (a, mbc, mca), (mca, mbc, c)]
                elif mbc is None:
                    NT += [(a, mab, mca), (mab, b, c), (mab, c, mca)]
                else:
                    NT += [(a, mab, c), (mab, b, mbc), (mab, mbc, c)]
        T = NT
    return np.array(V), np.array(T, int)


def boundary_loop(tris):
    """Return ordered boundary vertex loop of a disc-like triangle soup."""
    from collections import defaultdict
    cnt = defaultdict(int)
    directed = {}
    for t in tris:
        for a, b in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            k = (min(a, b), max(a, b))
            cnt[k] += 1
            directed[k] = (a, b)
    nxt = {}
    for k, c in cnt.items():
        if c == 1:
            a, b = directed[k]
            nxt[a] = b
    if not nxt:
        return []
    start = next(iter(nxt))
    loop = [start]
    cur = nxt[start]
    while cur != start and len(loop) <= len(nxt):
        loop.append(cur)
        cur = nxt[cur]
    return loop


# --------------------------------------------------------------------------
# mesh containers
# --------------------------------------------------------------------------

class Mesh:
    def __init__(self):
        self.V = np.zeros((0, 3))
        self.F = np.zeros((0, 3), int)

    def add(self, V, F, orient=True):
        V = np.asarray(V, float)
        F = np.asarray(F, int)
        if len(F) == 0:
            return
        if orient:
            V, F = orient_closed(V, F)
        F = F + len(self.V)
        self.V = np.vstack([self.V, V])
        self.F = np.vstack([self.F, F])

    def merge(self, other):
        self.add(other.V, other.F, orient=False)

    def transformed(self, R=None, t=(0, 0, 0)):
        m = Mesh()
        V = self.V if R is None else self.V @ np.asarray(R).T
        m.V = V + np.asarray(t)
        m.F = self.F.copy()
        return m

    def mirrored_s(self):
        """Mirror across the car's centre plane (s -> -s)."""
        m = Mesh()
        m.V = self.V * np.array([1, -1, 1])
        m.F = self.F[:, ::-1].copy()
        return m


def to_out(V):
    """(u, s, h) -> right-handed output frame (X right, Y up, Z back)."""
    V = np.asarray(V)
    return np.stack([V[:, 1], V[:, 2], -V[:, 0]], axis=1)


def signed_volume(V, F):
    P = to_out(V)
    a, b, c = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
    return np.sum(np.einsum("ij,ij->i", a, np.cross(b, c))) / 6.0


def orient_closed(V, F):
    if signed_volume(V, F) < 0:
        F = F[:, ::-1]
    return V, F


class Car:
    """A named collection of meshes. Each mesh becomes one MeshPart in Roblox."""

    def __init__(self, name, length):
        self.name = name
        self.L = length
        self.parts = {}

    alias = {}

    def part(self, name):
        name = self.alias.get(name, name)
        if name not in self.parts:
            self.parts[name] = Mesh()
        return self.parts[name]

    def _split_parts(self, limit):
        """Roblox caps a MeshPart at 20k triangles: split big parts into chunks."""
        for pname, mesh in self.parts.items():
            n = len(mesh.F)
            if n <= limit:
                yield pname, mesh
                continue
            chunks = int(math.ceil(n / limit))
            # split along the length so each chunk stays compact
            cu = mesh.V[mesh.F].mean(axis=1)[:, 0]
            order = np.argsort(cu)
            for c in range(chunks):
                sel = order[c * n // chunks:(c + 1) * n // chunks]
                F = mesh.F[sel]
                used, inv = np.unique(F, return_inverse=True)
                m = Mesh()
                m.V = mesh.V[used]
                m.F = inv.reshape(F.shape)
                yield (pname if c == 0 else f"{pname}{c + 1}"), m

    def tri_counts(self):
        return {k: len(m.F) for k, m in self.parts.items()}

    # ------------------------------------------------------------------
    def export_obj(self, path, materials, scale_m_per_unit=METRES_PER_STUD, smooth_angle=50):
        """Write .obj + .mtl.  materials: part name -> (mtl name, (r,g,b))."""
        import os
        mtl_path = os.path.splitext(path)[0] + ".mtl"
        used = {}
        lines = [f"# {self.name} - generated by cars/generator (procedural)",
                 f"# units: studs (1 stud = {scale_m_per_unit} m), +X right, +Y up, -Z forward",
                 f"mtllib {os.path.basename(mtl_path)}"]
        vofs = 1
        nofs = 1
        for pname, mesh in self._split_parts(19000):
            if len(mesh.F) == 0:
                continue
            P = to_out(mesh.V)
            P[:, 2] += self.L / 2.0  # centre along length
            P /= scale_m_per_unit
            N, corner_n = corner_normals(P, mesh.F, smooth_angle)
            mname, rgb = materials.get(pname, ("Default", (0.6, 0.6, 0.6)))
            used[mname] = rgb
            lines.append(f"o {pname}")
            lines.append(f"g {pname}")
            lines.append(f"usemtl {mname}")
            lines += [f"v {x:.3f} {y:.3f} {z:.3f}" for x, y, z in P]
            lines += [f"vn {x:.3f} {y:.3f} {z:.3f}" for x, y, z in N]
            for fi, f in enumerate(mesh.F):
                a, b, c = f + vofs
                na, nb, nc = corner_n[fi] + nofs
                lines.append(f"f {a}//{na} {b}//{nb} {c}//{nc}")
            vofs += len(P)
            nofs += len(N)
        with open(path, "w") as fh:
            fh.write("\n".join(lines) + "\n")
        with open(mtl_path, "w") as fh:
            for mname, (r, g, b) in used.items():
                fh.write(f"newmtl {mname}\nKa 0 0 0\nKd {r:.3f} {g:.3f} {b:.3f}\n"
                         f"Ks 0.25 0.25 0.25\nNs 60\nd 1\nillum 2\n\n")


def corner_normals(P, F, angle_deg):
    """Per-corner normals with an auto-smooth angle (hard edges stay crisp)."""
    a, b, c = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
    fn = np.cross(b - a, c - a)
    area = np.linalg.norm(fn, axis=1, keepdims=True)
    fnu = fn / np.maximum(area, 1e-12)
    cos_t = math.cos(math.radians(angle_deg))
    nv = len(P)
    # incident faces per vertex
    order = np.argsort(F.ravel(), kind="stable")
    verts_sorted = F.ravel()[order]
    faces_sorted = order // 3
    starts = np.searchsorted(verts_sorted, np.arange(nv))
    ends = np.searchsorted(verts_sorted, np.arange(nv), side="right")
    normals = []
    lookup = {}
    corner = np.zeros(F.shape, int)
    for fi in range(len(F)):
        for k in range(3):
            v = F[fi, k]
            inc = faces_sorted[starts[v]:ends[v]]
            sel = inc[(fnu[inc] @ fnu[fi]) >= cos_t]
            n = fn[sel].sum(axis=0)
            ln = np.linalg.norm(n)
            n = fnu[fi] if ln < 1e-12 else n / ln
            key = (round(n[0], 3), round(n[1], 3), round(n[2], 3))
            if key not in lookup:
                lookup[key] = len(normals)
                normals.append(n)
            corner[fi, k] = lookup[key]
    return np.array(normals), corner


# --------------------------------------------------------------------------
# primitive builders  (all in u, s, h)
# --------------------------------------------------------------------------

def grid_closed(rings, cap_start=True, cap_end=True):
    """rings: (N, M, 3) array of closed loops -> closed tube mesh."""
    rings = np.asarray(rings, float)
    N, M, _ = rings.shape
    V = rings.reshape(-1, 3).tolist()
    F = []
    for i in range(N - 1):
        for j in range(M):
            a = i * M + j
            b = i * M + (j + 1) % M
            c = (i + 1) * M + (j + 1) % M
            d = (i + 1) * M + j
            F += [(a, b, c), (a, c, d)]
    if cap_start:
        ci = len(V)
        V.append(rings[0].mean(axis=0).tolist())
        F += [(ci, (j + 1) % M, j) for j in range(M)]
    if cap_end:
        ci = len(V)
        V.append(rings[-1].mean(axis=0).tolist())
        base = (N - 1) * M
        F += [(ci, base + j, base + (j + 1) % M) for j in range(M)]
    return np.array(V), np.array(F)


def thicken(V, F, t):
    """Turn an open, outward-facing surface patch into a closed slab of thickness t."""
    V = np.asarray(V, float)
    F = np.asarray(F, int)
    P = to_out(V)
    a, b, c = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
    fn = np.cross(b - a, c - a)
    vn = np.zeros_like(P)
    for k in range(3):
        np.add.at(vn, F[:, k], fn)
    vn /= np.maximum(np.linalg.norm(vn, axis=1, keepdims=True), 1e-12)
    # back to (u, s, h): out = (s, h, -u)
    vn_ush = np.stack([-vn[:, 2], vn[:, 0], vn[:, 1]], axis=1)
    n = len(V)
    inner = V - vn_ush * t
    NV = np.vstack([V, inner])
    NF = [tuple(f) for f in F] + [(f[0] + n, f[2] + n, f[1] + n) for f in F]
    from collections import Counter
    edges = Counter()
    for f in F:
        for i in range(3):
            edges[(f[i], f[(i + 1) % 3])] += 1
    for (p, q) in list(edges):
        if (q, p) not in edges:
            NF += [(q, p, p + n), (q, p + n, q + n)]
    return NV, np.array(NF)


def prism(poly, h0, h1):
    """Extrude a plan-view (u, s) polygon between heights h0 and h1."""
    poly = [tuple(p) for p in poly]
    if poly_area(poly) < 0:
        poly = poly[::-1]
    tris = triangulate(poly)
    n = len(poly)
    V = [(u, s, h0) for u, s in poly] + [(u, s, h1) for u, s in poly]
    F = [(t[0], t[2], t[1]) for t in tris] + [(t[0] + n, t[1] + n, t[2] + n) for t in tris]
    for i in range(n):
        j = (i + 1) % n
        F += [(i, j, j + n), (i, j + n, i + n)]
    return np.array(V, float), np.array(F)


def superellipsoid(center, radii, e=0.3, nu=12, nv=6):
    """Rounded box / pill. e -> 0 is boxy, e = 1 is an ellipsoid."""
    cu, cs, ch = center
    ru, rs, rh = radii

    def sp(x, p):
        return np.sign(x) * np.abs(x) ** p

    rings = []
    for i in range(1, nv):
        th = -math.pi / 2 + math.pi * i / nv
        ring = []
        for j in range(nu):
            ph = 2 * math.pi * j / nu
            x = sp(math.cos(th), e) * sp(math.cos(ph), e)
            y = sp(math.cos(th), e) * sp(math.sin(ph), e)
            z = sp(math.sin(th), e)
            ring.append((cu + ru * x, cs + rs * y, ch + rh * z))
        rings.append(ring)
    V, F = grid_closed(rings, cap_start=False, cap_end=False)
    V = V.tolist()
    bot, top = len(V), len(V) + 1
    V.append((cu, cs, ch - rh))
    V.append((cu, cs, ch + rh))
    F = F.tolist()
    M = nu
    last = (nv - 2) * M
    F += [(bot, (j + 1) % M, j) for j in range(M)]
    F += [(top, last + j, last + (j + 1) % M) for j in range(M)]
    return np.array(V), np.array(F)


def box(center, size):
    cu, cs, ch = center
    du, ds, dh = (x / 2 for x in size)
    V = np.array([(cu + a * du, cs + b * ds, ch + c * dh)
                  for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)])
    F = np.array([(0, 1, 3), (0, 3, 2), (4, 6, 7), (4, 7, 5), (0, 4, 5), (0, 5, 1),
                  (2, 3, 7), (2, 7, 6), (0, 2, 6), (0, 6, 4), (1, 5, 7), (1, 7, 3)])
    return V, F


def lathe(profile, center, axis="s", seg=48, phase=0.0):
    """Revolve a closed (r, a) profile around an axis through center.
    axis 's' = lateral (wheels), 'u' = longitudinal (exhaust tips)."""
    cu, cs, ch = center
    rings = []
    for (r, a) in profile:
        ring = []
        for j in range(seg):
            t = phase + 2 * math.pi * j / seg
            if axis == "s":
                ring.append((cu + r * math.cos(t), cs + a, ch + r * math.sin(t)))
            else:
                ring.append((cu + a, cs + r * math.cos(t), ch + r * math.sin(t)))
        rings.append(ring)
    rings.append(rings[0])
    V, F = grid_closed(rings, cap_start=False, cap_end=False)
    # weld the duplicated closing ring
    M = seg
    n = len(profile)
    F = np.where(F >= n * M, F - n * M, F)
    V = V[: n * M]
    return V, F


def sweep(profile2d, path, up_hint=(1, 0, 0)):
    """Sweep a closed 2D profile (a, b) along a 3D path.
    'a' is laid along up_hint (e.g. the chord direction), 'b' along the
    in-plane normal. Ends are capped."""
    path = np.asarray(path, float)
    hint = np.asarray(up_hint, float)
    rings = []
    for i in range(len(path)):
        if i == 0:
            t = path[1] - path[0]
        elif i == len(path) - 1:
            t = path[-1] - path[-2]
        else:
            t = path[i + 1] - path[i - 1]
        t /= np.linalg.norm(t)
        a = hint - t * (hint @ t)
        a /= np.linalg.norm(a)
        b = np.cross(t, a)
        rings.append([path[i] + a * p + b * q for p, q in profile2d])
    return grid_closed(rings)


def airfoil(chord, thick, n=14, camber=0.0):
    """Closed airfoil outline (a = along chord, b = thickness)."""
    xs = (1 - np.cos(np.linspace(0, math.pi, n))) / 2
    yt = 5 * thick * (0.2969 * np.sqrt(xs) - 0.126 * xs - 0.3516 * xs ** 2
                      + 0.2843 * xs ** 3 - 0.1036 * xs ** 4)
    yc = camber * 4 * xs * (1 - xs)
    upper = [(x * chord, (c + y) * chord) for x, y, c in zip(xs, yt, yc)]
    lower = [(x * chord, (c - y) * chord) for x, y, c in zip(xs[::-1], yt[::-1], yc[::-1])]
    pts = upper + lower[1:-1]
    return pts


def rot_u(angle):
    """Rotation about the u axis (roll)."""
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_s(angle):
    """Rotation about the s axis (pitch)."""
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, 0, -s], [0, 1, 0], [s, 0, c]])


def rot_h(angle):
    """Rotation about the h axis (yaw)."""
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def xform(VF, R=None, t=(0, 0, 0)):
    V, F = VF
    V = np.asarray(V, float)
    if R is not None:
        V = V @ np.asarray(R).T
    return V + np.asarray(t), F


# --------------------------------------------------------------------------
# the car body: a lofted surface driven by keyframed profile parameters
# --------------------------------------------------------------------------

class Body:
    """
    Cross-section parameters, each keyframed along u (see the car specs):
      zF  floor height              wF  inner floor half width (wheel wells)
      wB  body half width at the character line
      zMid character-line (crease) height
      zBelt shoulder / fender top   wGH greenhouse base half width
      wR  roof (top surface) half width
      zRE height of the roof/hood edge   zT  centreline top height
      under  how far the lower side / skirt tucks in under the crease
      over   tumble-home from the crease up to the shoulder
    Wheel arches are cut by raising the lower edge over each wheel; the
    crease rides over each arch and the side bulges out (flare) around it.
    Tight point pairs ("bevel") keep creases crisp after smoothing.
    """

    def __init__(self, L, keys, wheels, arch_r, end_r=(0.08, 0.08), end_p=4.0, glass=None,
                 flare=0.02, bevel=0.006, crease_gap=0.07, panels=None, ends=None):
        self.L = L
        # shaping of the nose / tail: {"front": dict(zone, plan, top, bot), "rear": ...}
        self.ends = ends or {}
        self.glass = glass or {}
        self.panels = panels or {}
        self.f = {k: curve(v) for k, v in keys.items()}
        self.wheels = wheels  # list of (u, zc)
        self.arch_r = arch_r
        self.end_r = end_r
        self.end_p = end_p
        self.flare = flare
        self.bevel = bevel
        self.crease_gap = crease_gap
        self.kinds = None

    def params(self, u):
        return {k: float(f(u)) for k, f in self.f.items()}

    def arch(self, u):
        z = -1.0
        for (wu, wz) in self.wheels:
            d = abs(u - wu)
            if d < self.arch_r:
                z = max(z, wz + math.sqrt(self.arch_r ** 2 - d * d))
        return z

    def arch_halo(self, u, gap):
        """Height of a curve following the arch, 'gap' above it (smooth tails)."""
        z = -1.0
        r = self.arch_r + gap
        for (wu, wz) in self.wheels:
            d = abs(u - wu)
            if d < r:
                z = max(z, wz + math.sqrt(r * r - d * d))
        return z

    def flare_at(self, u):
        f = 0.0
        for (wu, _) in self.wheels:
            d = abs(u - wu)
            a, b = self.arch_r - 0.02, self.arch_r + 0.32
            if d <= a:
                t = 1.0
            elif d >= b:
                t = 0.0
            else:
                x = (b - d) / (b - a)
                t = x * x * (3 - 2 * x)
            f = max(f, t)
        return self.flare * f

    def profile(self, u):
        p = self.params(u)
        zF, wF = p["zF"], p["wF"]
        wB0 = p["wB"]
        wB = wB0 + self.flare_at(u)
        under, over = p["under"], p["over"]
        bv = self.bevel
        aL = max(zF, self.arch(u))
        hC = max(p["zMid"], self.arch_halo(u, self.crease_gap))
        zBelt = max(p["zBelt"], hC + 0.07)
        pts, kinds = [], []

        def add(pt, kind):
            pts.append(pt)
            kinds.append(kind)

        wS = wB - under                     # skirt / lower side
        h_sk = min(aL + 0.07, hC - 0.05)    # top of the side skirt
        add((0.0, zF), "floor")
        add((wF * 0.5, zF), "floor")
        add((wF, zF), "well")
        add((wF, aL), "sill")
        add((wS - 0.04, aL), "skirt")
        add((wS - 0.003, aL + 0.004), "skirt")
        add((wS, h_sk), "skirt")
        add((wS - 0.010, h_sk + 0.006), "lower")      # step above the skirt
        for t in (0.55,):
            hh = h_sk + 0.006 + (hC - bv - h_sk - 0.006) * t
            add((wS - 0.010 + (wB - bv * 0.6 - wS + 0.010) * t ** 1.4, hh), "lower")
        add((wB - bv * 0.6, hC - bv), "crease")
        add((wB, hC), "crease")
        add((wB - bv * 0.6, hC + bv), "upper")
        sh = wB0 - over
        for t in (0.55,):
            hh = hC + bv + (zBelt - bv - hC - bv) * t
            add((wB - bv * 0.6 + (sh - wB + bv * 0.6) * t ** 1.2, hh), "upper")
        add((sh, zBelt - bv), "shoulder")
        add((sh - bv * 1.2, zBelt + bv * 0.3), "deck")
        zDeck = zBelt + 0.012
        wGH = min(p["wGH"], sh - 0.05)
        wR = min(p["wR"], wGH - 0.005)
        zRE = max(p["zRE"], zDeck + 0.004)
        zT = max(p["zT"], zRE)
        for k, t in enumerate(np.linspace(0, 1, 4)[:-1]):
            bow = 0.010 * math.sin(math.pi * t)
            add((wGH + (wR - wGH) * t + bow, zDeck + (zRE - zDeck) * t), "gh0" if k == 0 else "gh")
        for k, t in enumerate((0.0, 0.04, 0.16, 0.38, 0.66, 1.0)):
            add((wR * (1 - t), zRE + (zT - zRE) * (1 - (1 - t) ** 2)), "pillar" if k < 2 else "top")
        pts = np.array(pts)
        if self.kinds is None:
            self.kinds = kinds
        # square-ish nose and tail with a tight radius
        k = 1.0
        if u < self.end_r[0]:
            d = (self.end_r[0] - u) / self.end_r[0]
            k = (1 - d ** self.end_p) ** (1 / self.end_p)
        elif u > self.L - self.end_r[1]:
            d = (u - (self.L - self.end_r[1])) / self.end_r[1]
            k = (1 - min(d, 1.0) ** self.end_p) ** (1 / self.end_p)
        if k < 1.0:
            hc = 0.5 * (zF + zT)
            pts[:, 0] *= k
            pts[:, 1] = hc + (pts[:, 1] - hc) * k
        return pts

    def stations(self, base=0.062, fine=0.034):
        us = set(np.round(np.arange(0, self.L, base), 4))
        for wu, _ in self.wheels:
            for u in np.arange(wu - self.arch_r - 0.03, wu + self.arch_r + 0.03, fine):
                us.add(round(u, 4))
        for r, sign in ((self.end_r[0], 0), (self.end_r[1], 1)):
            for t in np.linspace(0, 1, 12):
                d = r * (1 - math.cos(t * math.pi / 2))
                us.add(round(d if sign == 0 else self.L - d, 4))
        g = self.glass
        for key in ("windshield", "rear"):
            if key in g:
                us.update(round(x, 4) for x in g[key])
        for a, b in g.get("side", []):
            us.update((round(a, 4), round(b, 4)))
        pn = self.panels
        for key in ("hood", "trunk"):
            if key in pn:
                us.update(round(x, 4) for x in pn[key])
        if "door" in pn:
            us.update(round(x, 4) for x in pn["door"]["u"] + pn["door"]["top"])
        us.add(0.0)
        us.add(round(self.L, 4))
        us = sorted(u for u in us if 0 <= u <= self.L)
        # drop near duplicates
        out = [us[0]]
        for u in us[1:]:
            if u - out[-1] > 0.004:
                out.append(u)
        if out[-1] != round(self.L, 4):
            out[-1] = round(self.L, 4)
        return out

    def classify(self, u, kind, side):
        """Which part a loft face belongs to (Body, Glass, Trim, Door_R, Hood...)."""
        g, pn = self.glass, self.panels
        sfx = "_R" if side > 0 else "_L"
        upper = kind in ("gh0", "gh", "pillar", "top")
        is_glass = False
        if kind == "top":
            for key in ("windshield", "rear"):
                if key in g and g[key][0] <= u <= g[key][1]:
                    is_glass = True
        if kind in ("gh", "gh0") and "side" in g:
            lo = min(a for a, b in g["side"])
            hi = max(b for a, b in g["side"])
            if lo <= u <= hi:
                if kind == "gh0" and g.get("belt_trim", True):
                    tag = "Trim"
                elif any(a <= u <= b for a, b in g["side"]):
                    tag = "Glass"
                else:
                    tag = "Trim"  # B-pillar between the windows
                door = pn.get("door")
                if door and door["top"][0] <= u <= door["top"][1]:
                    return {"Glass": "DoorGlass", "Trim": "DoorTrim"}[tag] + sfx
                return tag
        if "door" in pn and kind in ("lower", "crease", "upper", "shoulder", "deck"):
            d0, d1 = pn["door"]["u"]
            if d0 <= u <= d1:
                return "Door" + sfx
        if upper:
            for key, name in (("hood", "Hood"), ("trunk", "Trunk")):
                if key in pn and pn[key][0] <= u <= pn[key][1]:
                    return name + ("Glass" if is_glass else "")
        return "Glass" if is_glass else "Body"

    def mesh(self):
        """Returns {part: (V, F)} - the loft split into paint / glass / panels."""
        rings = []
        us = self.stations()
        n = None
        for u in us:
            pr = self.profile(u)
            n = len(pr)
            right = [(u, s, h) for s, h in pr]
            left = [(u, -s, h) for s, h in pr[-2:0:-1]]
            rings.append(right + left)
        V, F = grid_closed(rings, cap_start=True, cap_end=True)
        V = self.warp(V)
        V, F = orient_closed(V, F)
        M = 2 * n - 2
        nquads = (len(us) - 1) * M

        def prof_idx(m):
            m %= M
            return m if m < n else 2 * n - 2 - m

        tags = []
        for i in range(len(us) - 1):
            um = 0.5 * (us[i] + us[i + 1])
            for m in range(M):
                seg = min(prof_idx(m), prof_idx(m + 1))
                side = 1 if m < n - 1 else -1
                tags.append(self.classify(um, self.kinds[seg], side))
        tags = np.repeat(np.array(tags), 2)
        tags = np.concatenate([tags, np.array(["Body"] * (len(F) - 2 * nquads))])
        out = {}
        for name in np.unique(tags):
            sub = F[tags == name]
            used, inv = np.unique(sub, return_inverse=True)
            out[str(name)] = (V[used], inv.reshape(sub.shape))
        return out

    # ---- tables used to project decals onto the body ------------------
    def build_table(self, step=0.002):
        self.tu = np.arange(0, self.L + 1e-9, step)
        self.tp = np.array([self.profile(u) for u in self.tu])

    # ---- nose / tail shaping ------------------------------------------
    def _end_amount(self, which, s, h):
        """How far (m) each point of the end face is pulled back."""
        e = self.ends.get(which)
        if not e:
            return np.zeros_like(s)
        u_end = self.L if which == "front" else 0.0
        p = self.params(min(max(u_end, 0.02), self.L - 0.02))
        hb, ht = p["zF"], p["zT"]
        hc = hb + e.get("mid", 0.45) * (ht - hb)
        a = np.clip(np.abs(s) / e.get("width", 0.9), 0, 1)
        top = np.clip((h - hc) / max(ht - hc, 1e-3), 0, 1)
        bot = np.clip((hc - h) / max(hc - hb, 1e-3), 0, 1)
        S = e["plan"] * a ** 2.2 + e["top"] * top ** 2 + e["bot"] * bot ** 2
        return np.minimum(S, 0.45 * e["zone"])

    def warp(self, V):
        """Sweep the corners back, lean the top back and tuck the chin under."""
        V = np.array(V, float)
        u, s_, h = V[:, 0], V[:, 1], V[:, 2]
        if "front" in self.ends:
            z = self.ends["front"]["zone"]
            u0 = self.L - z
            t = np.clip((u - u0) / z, 0, None)
            V[:, 0] = np.where(u > u0, u - self._end_amount("front", s_, h) * t * t, V[:, 0])
        if "rear" in self.ends:
            z = self.ends["rear"]["zone"]
            t = np.clip((z - u) / z, 0, None)
            V[:, 0] = np.where(u < z, V[:, 0] + self._end_amount("rear", s_, h) * t * t, V[:, 0])
        return V

    def unwarp_u(self, up, s, h):
        """Inverse of warp() along u (vectorised). Points past the ends map outside."""
        u = up.copy()
        if "front" in self.ends:
            z = self.ends["front"]["zone"]
            u0 = self.L - z
            S = self._end_amount("front", s, h)
            m = up > u0
            c = up - u0
            disc = z * z - 4 * S * c
            with np.errstate(invalid="ignore", divide="ignore"):
                t = np.where(S > 1e-9, (z - np.sqrt(np.maximum(disc, 0))) / (2 * S), c / z)
            t = np.where((disc < 0) | (t > 1), 2.0, t)
            u = np.where(m, u0 + z * t, u)
        if "rear" in self.ends:
            z = self.ends["rear"]["zone"]
            S = self._end_amount("rear", s, h)
            m = up < z
            c = z - up
            disc = z * z - 4 * S * c
            with np.errstate(invalid="ignore", divide="ignore"):
                t = np.where(S > 1e-9, (z - np.sqrt(np.maximum(disc, 0))) / (2 * S), c / z)
            t = np.where((disc < 0) | (t > 1), 2.0, t)
            u = np.where(m, z - z * t, u)
        return u

    def inside(self, Q, warped=True):
        """Vectorised: are points (u, s, h) inside the body shell?
        warped=False tests against the loft before the nose/tail shaping."""
        u = self.unwarp_u(Q[:, 0], Q[:, 1], Q[:, 2]) if warped else Q[:, 0]
        step = self.tu[1] - self.tu[0]
        idx = np.clip(np.round(u / step).astype(int), 0, len(self.tu) - 1)
        polys = self.tp[idx]                       # (N, n, 2)
        px = np.abs(Q[:, 1])[:, None] + 1e-7
        py = Q[:, 2][:, None]
        x1, y1 = polys[:, :, 0], polys[:, :, 1]
        x2, y2 = np.roll(x1, -1, axis=1), np.roll(y1, -1, axis=1)
        cond = (y1 > py) != (y2 > py)
        with np.errstate(divide="ignore", invalid="ignore"):
            xi = x1 + (py - y1) * (x2 - x1) / (y2 - y1)
        hit = (cond & (px < xi)).sum(axis=1) % 2 == 1
        return hit & (u >= 0) & (u <= self.L)

    def raycast(self, origin, direction, tmax=5.0, step=0.008, miss_nan=False, warped=True):
        """March rays from outside until they enter the body, then bisect."""
        origin = np.asarray(origin, float)
        dvec = np.asarray(direction, float)
        n = len(origin)
        t_hit = np.full(n, np.nan)
        for t in np.arange(step, tmax, step):
            todo = np.isnan(t_hit)
            if not todo.any():
                break
            ins = self.inside(origin[todo] + dvec * t, warped)
            idx = np.where(todo)[0][ins]
            t_hit[idx] = t
        lo = np.where(np.isnan(t_hit), 0, t_hit - step)
        hi = np.where(np.isnan(t_hit), 0, t_hit)
        for _ in range(10):
            mid = 0.5 * (lo + hi)
            ins = self.inside(origin + dvec * mid[:, None], warped)
            hi = np.where(ins, mid, hi)
            lo = np.where(ins, lo, mid)
        if miss_nan:
            t = np.where(np.isnan(t_hit), np.nan, hi)
        else:
            t = np.where(np.isnan(t_hit), np.nanmedian(t_hit) if np.any(~np.isnan(t_hit)) else 0, hi)
        return origin + dvec * t[:, None]

    def surface_side(self, u, h):
        """Outermost body |s| at (u, h), or None."""
        p = self.raycast(np.array([[u, 2.0, h]]), np.array([0, -1.0, 0]), tmax=2.0,
                         step=0.004, miss_nan=True)[0]
        return None if np.isnan(p[1]) else float(p[1])

    def surface_top(self, u, s):
        """Top body height at (u, s), or None."""
        p = self.raycast(np.array([[u, s, 2.5]]), np.array([0, 0, -1.0]), tmax=2.5,
                         step=0.004, miss_nan=True)[0]
        return None if np.isnan(p[2]) else float(p[2])

    def surface_front(self, s, h, front=True):
        """u of the nose (front=True) or tail surface at (s, h), or None."""
        o = np.array([[self.L + 1.0 if front else -1.0, s, h]])
        p = self.raycast(o, np.array([-1.0 if front else 1.0, 0, 0]), tmax=2.0,
                         step=0.004, miss_nan=True)[0]
        return None if np.isnan(p[0]) else float(p[0])


# --------------------------------------------------------------------------
# projected "decals": thin slabs that hug the body (lights, glass, grilles..)
# --------------------------------------------------------------------------

def resample_poly(poly, spacing):
    """Insert points so no outline edge is longer than spacing."""
    out = []
    n = len(poly)
    for i in range(n):
        a = np.array(poly[i], float)
        b = np.array(poly[(i + 1) % n], float)
        k = max(1, int(math.ceil(np.linalg.norm(b - a) / spacing)))
        for j in range(k):
            out.append(tuple(a + (b - a) * j / k))
    return out


def project(body, view, a, b, side=1, yaw=0.0, pitch=0.0, pivot=None):
    """Cast parallel rays at the body. Returns hit points and the ray's
    outward direction. yaw / pitch (degrees) tilt front/rear rays toward the
    car's flank / top so wrap-around lights hit the paint squarely."""
    a = np.asarray(a, float)
    b = np.asarray(b, float)
    if view in ("front", "rear"):
        fwd = 1.0 if view == "front" else -1.0
        pa, pb = (np.mean(a), np.mean(b)) if pivot is None else pivot
        if pivot is not None and np.mean(a) < 0:
            pa = -abs(pa)
        sgn = np.sign(pa) or 1.0
        y, p = math.radians(yaw), math.radians(pitch)
        d = np.array([fwd * math.cos(y) * math.cos(p), sgn * math.sin(y) * math.cos(p), math.sin(p)])
        # pivot plane: where a straight ray through the outline centre lands
        c = body.raycast(np.array([[body.L + 1 if fwd > 0 else -1, pa, pb]]),
                         np.array([-fwd, 0, 0]), warped=False)[0]
        base = np.stack([np.full_like(a, c[0]), a, b], axis=1)
    elif view == "side":
        d = np.array([0, float(side), 0])
        base = np.stack([a, np.zeros_like(a), b], axis=1)
    elif view == "top":
        d = np.array([0, 0, 1.0])
        base = np.stack([a, b, np.zeros_like(a)], axis=1)
    else:
        raise ValueError(view)
    origin = base + d * 2.5
    # project onto the loft before the nose/tail shaping, then bend the hit
    # points with the same warp so details follow the curved ends exactly
    return body.warp(body.raycast(origin, -d, warped=False)), d


def decal(body, poly, view, out=0.004, depth=0.012, maxlen=0.045, side=1, bulge=0.0,
          yaw=0.0, pitch=0.0, pivot=None):
    """
    poly : 2D outline in the view plane
       view 'front'/'rear' : (s, h)
       view 'side'         : (u, h)   side = +1 right, -1 left
       view 'top'          : (u, s)
    out   : how far the visible face sits proud of the paint
    depth : slab thickness pushed into the body
    bulge : extra dome height in the centre (lenses)
    """
    poly = [tuple(p) for p in poly]
    if poly_area(poly) < 0:
        poly = poly[::-1]
    poly = resample_poly(poly, maxlen)
    tris = delaunay_flip(poly, triangulate(poly))
    V2, T = refine(poly, tris, max(maxlen * (2 if view in ("front", "rear") else 3), 0.06))
    loop = boundary_loop(T)
    # dome factor for bulge: 1 in the middle, 0 on the outline
    if bulge:
        bpts = V2[loop]
        dmin = np.array([np.min(np.linalg.norm(bpts - v, axis=1)) for v in V2])
        dome = np.sqrt(np.clip(dmin / max(dmin.max(), 1e-6), 0, 1))
    else:
        dome = np.zeros(len(V2))

    a, b = V2[:, 0], V2[:, 1]
    P, d = project(body, view, a, b, side=side, yaw=yaw, pitch=pitch, pivot=pivot)

    # offset along the local surface normal so decals never sink into
    # sloped or wrapping paint (fallback: the projection axis)
    nrm = np.zeros_like(P)
    fa, fb, fc = P[T[:, 0]], P[T[:, 1]], P[T[:, 2]]
    fn = np.cross(fb - fa, fc - fa)
    for k in range(3):
        np.add.at(nrm, T[:, k], fn)
    ln = np.linalg.norm(nrm, axis=1, keepdims=True)
    nrm = np.where(ln > 1e-12, nrm / np.maximum(ln, 1e-12), d)
    nrm *= np.sign(nrm @ d)[:, None] + (nrm @ d == 0)[:, None]
    nrm = nrm + d * 0.25
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    top = P + nrm * (out + bulge * dome)[:, None]
    bot = P - nrm * depth
    V = np.vstack([top, bot])
    # make the visible face point away from the paint (checked in the
    # right-handed export frame; (u, s, h) itself is left-handed)
    to = to_out(top)
    fa, fb, fc = to[T[:, 0]], to[T[:, 1]], to[T[:, 2]]
    if np.sum(np.cross(fb - fa, fc - fa) @ to_out(d[None, :])[0]) < 0:
        T = T[:, ::-1]
    # the underside sits inside the paint and is never seen, so it is left out
    F = [tuple(t) for t in T]
    # walls (duplicate verts so edges shade crisply)
    loop = boundary_loop(T)
    for i in range(len(loop)):
        p, q = loop[i], loop[(i + 1) % len(loop)]
        base = len(V)
        V = np.vstack([V, [top[p], top[q], bot[q], bot[p]]])
        F += [(base, base + 2, base + 1), (base, base + 3, base + 2)]
    return V, np.array(F)


def mirror_poly_s(poly):
    """Mirror a (s, h) / (u, s) polygon about s = 0 for front/rear/top views."""
    return [(-x, y) for x, y in poly]


def mirror_poly_top(poly):
    return [(x, -y) for x, y in poly]


# --------------------------------------------------------------------------
# wheels
# --------------------------------------------------------------------------

def tire(R, rim_r, width, seg=28):
    w = width / 2
    side_r = rim_r + 0.55 * (R - rim_r)
    prof = [
        (rim_r + 0.008, -w * 0.86), (side_r, -w), (R - 0.016, -w * 0.94), (R, -w * 0.70),
        (R, w * 0.70), (R - 0.016, w * 0.94), (side_r, w), (rim_r + 0.008, w * 0.86),
    ]
    return lathe(prof, (0, 0, 0), "s", seg)


def rim(rim_r, width, spokes=5, twin=False, spoke_w=0.04, dish=0.025, seg=28,
        hub_r=0.075, style="straight", e=0.25):
    """Wheel rim built around the origin, outer face towards +s."""
    parts = []
    w = width / 2
    # barrel + lip (closed lathe profile, hollow look via an inner wall)
    prof = [
        (rim_r + 0.014, w * 0.86 + 0.012), (rim_r + 0.014, w * 0.86 - 0.004),
        (rim_r - 0.012, w * 0.60), (rim_r - 0.012, -w * 0.94),
        (rim_r - 0.024, -w * 0.94), (rim_r - 0.024, w * 0.55),
        (rim_r - 0.002, w * 0.86 + 0.008),
    ]
    parts.append(lathe(prof, (0, 0, 0), "s", seg))
    # hub
    face = w * 0.86 - dish
    hub = [(0.001, face + 0.012), (hub_r * 0.55, face + 0.012), (hub_r, face),
           (hub_r, face - 0.05), (0.001, face - 0.05)]
    parts.append(lathe(hub, (0, 0, 0), "s", 14))
    # spokes
    n = spokes * (2 if twin else 1)
    for k in range(n):
        if twin:
            base_ang = 2 * math.pi * (k // 2) / spokes
            ang = base_ang + (0.11 if k % 2 else -0.11)
        else:
            ang = 2 * math.pi * k / n
        length = rim_r - hub_r * 0.8
        mid = hub_r * 0.8 + length / 2
        VF = superellipsoid((0, 0, 0), (length / 2, 0.016, spoke_w / 2), e=e, nu=6, nv=4)
        V, F = VF
        V = np.array(V)
        if style == "taper":
            # wider near the rim
            t = (V[:, 0] + length / 2) / length
            V[:, 2] *= 0.75 + 0.6 * t
        # concave: spokes move outward toward the rim lip
        t = (V[:, 0] + length / 2) / length
        V[:, 1] += dish * t
        V[:, 0] += mid
        R = rot_s(ang)
        V = V @ R.T
        V[:, 1] += face - 0.004
        parts.append((V, F))
    # lug nuts
    for k in range(5):
        ang = 2 * math.pi * k / 5 + math.pi / 5
        r = hub_r * 0.62
        parts.append(lathe([(0.001, face + 0.022), (0.009, face + 0.022), (0.009, face + 0.004),
                            (0.001, face + 0.004)],
                           (r * math.cos(ang), 0, r * math.sin(ang)), "s", 5))
    return parts


def brake(disc_r, caliper_rgb_unused=None, offset=-0.03, caliper_ang=math.radians(150)):
    parts = []
    disc = [(0.06, offset + 0.014), (disc_r, offset + 0.014), (disc_r, offset - 0.014),
            (0.06, offset - 0.014)]
    parts.append(("disc", lathe(disc, (0, 0, 0), "s", 20)))
    # caliper: an arc of a box hugging the disc edge
    rings = []
    span = math.radians(60)
    for i in range(9):
        a = caliper_ang - span / 2 + span * i / 8
        prof = []
        for (rr, ss) in ((disc_r - 0.05, offset - 0.035), (disc_r + 0.022, offset - 0.035),
                         (disc_r + 0.022, offset + 0.032), (disc_r - 0.05, offset + 0.032)):
            prof.append((rr * math.cos(a), ss, rr * math.sin(a)))
        rings.append(prof)
    parts.append(("caliper", grid_closed(rings)))
    return parts
