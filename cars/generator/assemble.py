"""Shared assembly: turns a car spec dict into a carkit.Car with named parts."""

import math
import numpy as np
import carkit as ck


def _add(car, part, VF, mirror=False):
    V, F = VF
    car.part(part).add(V, F)
    if mirror:
        m = ck.Mesh()
        m.V = np.asarray(V, float) * np.array([1, -1, 1])
        m.F = np.asarray(F)[:, ::-1]
        car.part(part).add(m.V, m.F)


PANEL_THICKNESS = {"Door": 0.035, "Hood": 0.025, "Trunk": 0.025, "DoorGlass": 0.006,
                   "TrunkGlass": 0.006, "DoorTrim": 0.01}


def _named(part, side):
    """'DoorTrim*' -> 'DoorTrim_R' / 'DoorTrim_L'."""
    if part.endswith("*"):
        return part[:-1] + ("_R" if side > 0 else "_L")
    return part


def marker(car, name, pos, size=0.05):
    """Tiny named cube the Roblox rig script reads (seat / hinge positions)."""
    V, F = ck.box(pos, (size, size, size))
    car.part("Marker_" + name).add(V, F)


def build(spec):
    L = spec["length"]
    car = ck.Car(spec["name"], L)
    wheels = spec["wheels"]  # list of dict(u, half_track, R, rim_r, width)
    body = ck.Body(L, spec["body"], [(w["u"], w["R"]) for w in wheels[::2]],
                   spec["arch_r"], end_r=spec.get("end_r", (0.08, 0.08)),
                   end_p=spec.get("end_p", 4.0), glass=spec.get("glass"),
                   flare=spec.get("flare", 0.02), bevel=spec.get("bevel", 0.006),
                   crease_gap=spec.get("crease_gap", 0.07), panels=spec.get("panels"),
                   ends=spec.get("ends"))
    for pname, (V, F) in body.mesh().items():
        base = pname[:-2] if pname[-2:] in ("_R", "_L") else pname
        if base in PANEL_THICKNESS:
            V, F = ck.thicken(V, F, PANEL_THICKNESS[base])
            car.part(pname).add(V, F)
        else:
            car.part(pname).add(V, F, orient=False)
    body.build_table()
    car.body = body

    # ---- projected details --------------------------------------------
    decals = []
    for d in spec["decals"]:
        decals.append(d)
        if d.get("frame"):
            # raised lip around an opening so it reads as recessed
            width, out = d["frame"]
            pts = ck.resample_poly(d["poly"], 0.03)
            path = pts + [pts[0]]
            a, b = np.array(path[-2]), np.array(path[-1])
            path[-1] = tuple(b - (b - a) / max(np.linalg.norm(b - a), 1e-9) * 0.012)
            fr = line(d["view"], path, width=width, part=d.get("frame_part", "Trim"), out=out,
                      sym=d.get("sym", True))
            for k in ("yaw", "pitch", "pivot"):
                if k in d:
                    fr[k] = d[k]
            fr["depth"] = 0.02
            decals.append(fr)
    for d in decals:
        part, view, poly = d["part"], d["view"], d["poly"]
        kw = {k: d[k] for k in ("out", "depth", "maxlen", "bulge", "yaw", "pitch", "pivot") if k in d}
        sym = d.get("sym", True)
        if view == "side":
            sides = (1, -1) if sym else (d.get("side", 1),)
            for sd in sides:
                _add(car, _named(part, sd), ck.decal(body, poly, "side", side=sd, **kw))
        else:
            sd = 1 if np.mean([p[1] if view == "top" else p[0] for p in poly]) >= 0 else -1
            _add(car, _named(part, sd), ck.decal(body, poly, view, **kw))
            if sym:
                mp = ck.mirror_poly_s(poly) if view in ("front", "rear") else ck.mirror_poly_top(poly)
                _add(car, _named(part, -sd), ck.decal(body, mp, view, **kw))

    # ---- wheels (each one its own set of parts so it can spin / steer) ------
    for w in wheels:
        side = 1 if w["half_track"] > 0 else -1
        tag = w["tag"]
        ht = abs(w["half_track"])
        if spec.get("flush"):
            p = body.params(w["u"])
            outer = p["wB"] + body.flare_at(w["u"]) - p["under"]
            ht = outer - w["width"] / 2 - spec.get("flush_inset", 0.012)
        center = np.array([w["u"], side * ht, w["R"]])
        tV, tF = ck.tire(w["R"], w["rim_r"], w["width"])
        parts = [("Tire_" + tag, (tV, tF))]
        for VF in ck.rim(w["rim_r"], w["width"], **spec["rim_style"]):
            parts.append(("Rim_" + tag, VF))
        for kind, VF in ck.brake(spec["disc_r"] if w["tag"][0] == "F" else spec["disc_r"] * 0.93,
                                 caliper_ang=math.radians(165 if w["tag"][0] == "F" else 15)):
            parts.append((("Brake_" if kind == "disc" else "Caliper_") + tag, VF))
        for pname, (V, F) in parts:
            V = np.asarray(V, float).copy()
            if side < 0:
                V[:, 1] *= -1
                F = np.asarray(F)[:, ::-1]
            car.part(pname).add(V + center, F)

    # ---- hinge / seat markers for the Roblox rig ----------------------------
    pn = spec.get("panels", {})
    if "door" in pn:
        d1 = pn["door"]["u"][1]
        hmid = 0.62
        s_out = body.surface_side(d1, hmid)
        for sd, sfx in ((1, "R"), (-1, "L")):
            marker(car, "Hinge_Door_" + sfx, (d1 - 0.02, sd * (s_out - 0.03), hmid))
    if "hood" in pn:
        u0 = pn["hood"][0]
        marker(car, "Hinge_Hood", (u0 + 0.02, 0.0, body.surface_top(u0 + 0.02, 0.0) - 0.02))
    if "trunk" in pn:
        u1 = pn["trunk"][1]
        marker(car, "Hinge_Trunk", (u1 - 0.02, 0.0, body.surface_top(u1 - 0.02, 0.0) - 0.02))

    # ---- custom extras (wing, mirrors, interior, exhaust...) ------------
    for fn in spec.get("extras", []):
        fn(car, body)
    return car


# --------------------------------------------------------------------------
# reusable extras
# --------------------------------------------------------------------------

def mirrors(u, h, reach, size=(0.075, 0.10, 0.058)):
    """Door mirrors, one part per side so they swing with the doors."""
    def fn(car, body):
        s_body = body.surface_side(u, h - 0.04)
        for sd, sfx in ((1, "_R"), (-1, "_L")):
            cs = s_body + reach
            parts = [
                ("Mirror", ck.superellipsoid((u, cs, h), size, e=0.3, nu=18, nv=10)),
                ("Mirror", ck.box((u + 0.01, s_body + (reach - size[1] * 0.6 + 0.02) / 2 - 0.01,
                                   h - 0.035), (0.07, reach - size[1] * 0.6 + 0.02, 0.022))),
                ("MirrorGlass", ck.superellipsoid((u - size[0] * 0.92, cs, h),
                                                  (0.012, size[1] * 0.82, size[2] * 0.75),
                                                  e=0.3, nu=18, nv=8)),
            ]
            for name, (V, F) in parts:
                V = np.asarray(V, float).copy()
                F = np.asarray(F)
                if sd < 0:
                    V[:, 1] *= -1
                    F = F[:, ::-1]
                car.part(name + sfx).add(V, F)
    return fn


def interior(seat_u, seat_s, dash_u, wheel_side, floor_h, belt_h, roof_h, half_w,
             rear_seat_u=None):
    def fn(car, body):
        P = "Interior"
        # tub to block see-through
        _add(car, P, ck.box(((dash_u + (rear_seat_u or seat_u) - 0.4) / 2, 0,
                              floor_h + 0.18), (dash_u - (rear_seat_u or seat_u) + 0.6,
                                                half_w * 2 - 0.12, 0.30)))
        for sgn in (1, -1):
            s = seat_s * sgn
            # cushion + backrest + headrest
            _add(car, P, ck.superellipsoid((seat_u + 0.05, s, floor_h + 0.36), (0.25, 0.25, 0.07), e=0.35))
            back = ck.superellipsoid((0, 0, 0), (0.07, 0.25, 0.30), e=0.35)
            _add(car, P, ck.xform(back, ck.rot_s(math.radians(-14)), (seat_u - 0.22, s, floor_h + 0.70)))
            _add(car, P, ck.superellipsoid((seat_u - 0.32, s, min(floor_h + 1.04, roof_h - 0.13)), (0.06, 0.13, 0.09), e=0.4))
        if rear_seat_u is not None:
            _add(car, P, ck.superellipsoid((rear_seat_u, 0, floor_h + 0.36), (0.22, half_w - 0.18, 0.07), e=0.35))
            back = ck.superellipsoid((0, 0, 0), (0.07, half_w - 0.2, 0.24), e=0.35)
            _add(car, P, ck.xform(back, ck.rot_s(math.radians(-24)), (rear_seat_u - 0.22, 0, floor_h + 0.62)))
        # dashboard
        _add(car, P, ck.superellipsoid((dash_u, 0, belt_h - 0.06), (0.20, half_w - 0.10, 0.12), e=0.3))
        # steering wheel
        sw_u, sw_s, sw_h = dash_u - 0.30, seat_s * wheel_side, belt_h - 0.02
        ring = [(0.19 + 0.018 * math.cos(a), 0.018 * math.sin(a))
                for a in np.linspace(0, 2 * math.pi, 8, endpoint=False)]
        V, F = ck.lathe(ring, (0, 0, 0), "u", 28)
        _add(car, "Steering", ck.xform((V, F), ck.rot_s(math.radians(-62)), (sw_u, sw_s, sw_h)))
        _add(car, "Steering", ck.xform(ck.superellipsoid((0, 0, 0), (0.03, 0.06, 0.06), e=0.5),
                                       ck.rot_s(math.radians(-62)), (sw_u + 0.005, sw_s, sw_h)))
        _add(car, "Steering", ck.xform(ck.box((0, 0, 0), (0.02, 0.36, 0.03)),
                                       ck.rot_s(math.radians(-62)), (sw_u, sw_s, sw_h)))
        col = ck.box((0, 0, 0), (0.30, 0.05, 0.05))
        _add(car, "Steering", ck.xform(col, ck.rot_s(math.radians(28)),
                                       (sw_u + 0.16, sw_s, sw_h - 0.06)))
    return fn


def exhaust(u, s, h, r, length=0.20, oval=1.0, part="Exhaust", poke=0.035):
    """Exhaust tip. u=None places it 'poke' metres behind the rear bumper surface."""
    def fn(car, body):
        if u is None:
            back = body.surface_front(s, h + r + 0.03, front=False)
            uu = (back if back is not None else 0.0) - poke
        else:
            uu = u
        prof = [(r * 0.80, 0.0), (r, 0.0), (r, length), (r * 0.8, length), (r * 0.8, 0.01)]
        V, F = ck.lathe(prof, (0, 0, 0), "u", 28)
        V = np.array(V)
        V[:, 2] *= 1.0 / oval
        _add(car, part, (V + np.array([uu, s, h]), F))
        # dark inner
        inner = [(0.001, 0.03), (r * 0.79, 0.03), (r * 0.79, 0.06), (0.001, 0.06)]
        V, F = ck.lathe(inner, (0, 0, 0), "u", 20)
        V = np.array(V)
        V[:, 2] *= 1.0 / oval
        _add(car, "Undertray", (V + np.array([uu, s, h]), F))
    return fn


def undertray(u0, u1, half_w, h):
    def fn(car, body):
        _add(car, "Undertray", ck.box(((u0 + u1) / 2, 0, h), (u1 - u0, half_w * 2, 0.02)))
    return fn


def plate(view, s0, s1, h0, h1, out=0.006):
    """Licence plate decal: white plate + dark frame."""
    return [
        dict(part="Plate", view=view, sym=False, out=out + 0.004,
             poly=ck.rounded_poly([(s0, h0), (s1, h0), (s1, h1), (s0, h1)], 0.01)),
        dict(part="Trim", view=view, sym=False, out=out,
             poly=ck.rounded_poly([(s0 - 0.015, h0 - 0.015), (s1 + 0.015, h0 - 0.015),
                                   (s1 + 0.015, h1 + 0.015), (s0 - 0.015, h1 + 0.015)], 0.015)),
    ]


def line(view, pts, width=0.006, part="PanelGaps", out=0.0015, sym=True):
    """A thin strip following a polyline (panel gaps, trim lines)."""
    pts = np.asarray(pts, float)
    left, right = [], []
    for i in range(len(pts)):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == len(pts) - 1:
            t = pts[-1] - pts[-2]
        else:
            t = pts[i + 1] - pts[i - 1]
        t /= np.linalg.norm(t)
        n = np.array([-t[1], t[0]]) * width / 2
        left.append(tuple(pts[i] + n))
        right.append(tuple(pts[i] - n))
    return dict(part=part, view=view, poly=left + right[::-1], out=out, depth=0.006,
                maxlen=0.04, sym=sym)


def interior_markers(seat_u, seat_s, floor_h, driver_side):
    def fn(car, body):
        marker(car, "DriverSeat", (seat_u + 0.05, seat_s * driver_side, floor_h + 0.36))
        marker(car, "PassengerSeat", (seat_u + 0.05, -seat_s * driver_side, floor_h + 0.36))
    return fn


def splitter(depth=0.05, inset=0.06, h=None, back=0.30, part="Splitter"):
    """Front lip / splitter plate that follows the curved nose outline."""
    def fn(car, body):
        L = body.L
        hh = h if h is not None else body.params(L - 0.1)["zF"] + 0.005
        probe = hh + 0.03
        right = []
        wmax = body.params(L - 0.3)["wB"] - inset
        for a in np.linspace(0, 1, 16):
            sv = wmax * a
            uf = body.surface_front(sv, probe)
            if uf is None:
                break
            right.append((uf + depth * (1 - 0.6 * a ** 3), sv))
        right.append((right[-1][0] - back * 0.5, right[-1][1]))
        right.append((L - back - 0.1, right[-1][1] * 0.9))
        poly = [(u, sv) for u, sv in right] + [(u, -sv) for u, sv in right[::-1] if sv > 1e-6]
        poly = ck.rounded_poly(poly, 0.02, seg=3)
        _add(car, part, ck.prism(poly, hh - 0.012, hh + 0.008))
    return fn


def diffuser(width, fins=4, length=0.32, h0=None, part="Diffuser"):
    """Rear diffuser: an angled plate with vertical strakes."""
    def fn(car, body):
        zf = h0 if h0 is not None else body.params(0.3)["zF"]
        tail = body.surface_front(0.0, zf + 0.06, front=False)
        u0 = (tail if tail is not None else 0.0) - 0.02
        u1 = u0 + length
        plate = [(u0, -width), (u1, -width), (u1, width), (u0, width)]
        V, F = ck.prism(plate, -0.006, 0.006)
        V = np.asarray(V, float)
        # tilt: rises toward the rear
        V[:, 2] += zf + 0.02 + (u1 - V[:, 0]) / (u1 - u0) * 0.07
        _add(car, part, (V, F))
        for k in range(fins):
            s = -width + 2 * width * (k + 1) / (fins + 1)
            fV, fF = ck.box((u0 + 0.14, s, 0), (0.24, 0.008, 0.08))
            fV = np.asarray(fV, float)
            fV[:, 2] += zf - 0.01 + (u1 - fV[:, 0]) / (u1 - u0) * 0.07
            _add(car, part, (fV, fF))
    return fn


def _tub(car, body, u0, u1, half_w, floor_h, top_h, closed_front=True):
    """Dark box under a lid whose walls stay below the paint."""
    _add(car, "EngineBay", ck.box(((u0 + u1) / 2, 0, floor_h + 0.01), (u1 - u0, half_w * 2, 0.02)))
    steps = max(2, int((u1 - u0) / 0.05))
    for k in range(steps):
        a = u0 + (u1 - u0) * k / steps
        b = u0 + (u1 - u0) * (k + 1) / steps
        top = min(top_h, body.surface_top((a + b) / 2, half_w + 0.01) - 0.035)
        for sd in (1, -1):
            _add(car, "EngineBay", ck.box(((a + b) / 2, sd * half_w, (floor_h + top) / 2),
                                          (b - a + 0.002, 0.02, top - floor_h)))
    ends = (u0, u1) if closed_front else (u0,)
    for uu in ends:
        top = min(top_h, body.surface_top(uu, half_w * 0.9) - 0.035)
        _add(car, "EngineBay", ck.box((uu, 0, (floor_h + top) / 2), (0.02, half_w * 2, top - floor_h)))


def engine_bay(u0, u1, half_w, floor_h, top_h, engine_u, cover_part="EngineCover"):
    """A tub under the bonnet plus a simple straight-six so an open hood isn't empty."""
    def fn(car, body):
        _tub(car, body, u0, u1, half_w, floor_h, top_h, closed_front=False)
        # radiator, tucked under the nose
        rh = body.surface_top(u1 - 0.06, half_w * 0.7) - 0.05
        _add(car, "EngineBay", ck.box((u1 - 0.06, 0, (floor_h + rh) / 2), (0.05, half_w * 1.6, rh - floor_h)))
        # engine block + head + cam cover + intake plenum, kept under the hood
        eu = engine_u
        ceiling = min(top_h, body.surface_top(eu + 0.3, 0.2) - 0.05)
        _add(car, "Engine", ck.box((eu, 0, floor_h + 0.18), (0.62, 0.36, 0.26)))
        head_top = min(floor_h + 0.40, ceiling - 0.08)
        _add(car, "Engine", ck.box((eu, 0, (floor_h + 0.31 + head_top) / 2), (0.60, 0.26, head_top - floor_h - 0.31)))
        _add(car, cover_part, ck.superellipsoid((eu, 0.0, ceiling - 0.05), (0.30, 0.13, 0.04), e=0.25))
        _add(car, "Engine", ck.superellipsoid((eu, -0.18, ceiling - 0.07), (0.28, 0.06, 0.05), e=0.3))
        for sd in (1, -1):
            sh = body.surface_top(u1 - 0.55, half_w - 0.10) - 0.10
            _add(car, "Engine", ck.superellipsoid((u1 - 0.55, sd * (half_w - 0.10), sh),
                                                  (0.07, 0.07, 0.06), e=0.6))
    return fn


def trunk_tub(u0, u1, half_w, floor_h, top_h):
    def fn(car, body):
        _tub(car, body, u0, u1, half_w, floor_h, top_h)
    return fn
