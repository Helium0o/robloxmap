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


def build(spec):
    L = spec["length"]
    car = ck.Car(spec["name"], L)
    wheels = spec["wheels"]  # list of dict(u, half_track, R, rim_r, width)
    body = ck.Body(L, spec["body"], [(w["u"], w["R"]) for w in wheels[::2]],
                   spec["arch_r"], end_r=spec.get("end_r", (0.10, 0.10)),
                   glass=spec.get("glass"))
    for pname, (V, F) in body.mesh().items():
        car.part(pname).add(V, F, orient=False)
    body.build_table()
    car.body = body

    # ---- projected details --------------------------------------------
    for d in spec["decals"]:
        part, view, poly = d["part"], d["view"], d["poly"]
        kw = {k: d[k] for k in ("out", "depth", "maxlen", "bulge", "yaw", "pitch", "pivot") if k in d}
        sym = d.get("sym", True)
        if view == "side":
            sides = (1, -1) if sym else (d.get("side", 1),)
            for sd in sides:
                _add(car, part, ck.decal(body, poly, "side", side=sd, **kw))
        else:
            _add(car, part, ck.decal(body, poly, view, **kw))
            if sym:
                mp = ck.mirror_poly_s(poly) if view in ("front", "rear") else ck.mirror_poly_top(poly)
                _add(car, part, ck.decal(body, mp, view, **kw))

    # ---- wheels -------------------------------------------------------
    for w in wheels:
        side = 1 if w["half_track"] > 0 else -1
        tag = w["tag"]
        center = np.array([w["u"], w["half_track"], w["R"]])
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

    # ---- custom extras (wing, mirrors, interior, exhaust...) ------------
    for fn in spec.get("extras", []):
        fn(car, body)
    return car


# --------------------------------------------------------------------------
# reusable extras
# --------------------------------------------------------------------------

def mirrors(u, h, reach, size=(0.075, 0.10, 0.058), stalk_part="Mirrors"):
    def fn(car, body):
        s_body = body.surface_side(u, h - 0.04)
        cs = s_body + reach
        V, F = ck.superellipsoid((u, cs, h), size, e=0.45, nu=18, nv=10)
        _add(car, "Mirrors", (V, F), mirror=True)
        # stalk
        sl = reach - size[1] * 0.6 + 0.02
        _add(car, "Mirrors", ck.box((u + 0.01, s_body + sl / 2 - 0.01, h - 0.035), (0.06, sl, 0.025)),
             mirror=True)
        # mirror glass on the rear face
        V, F = ck.superellipsoid((u - size[0] * 0.92, cs, h), (0.012, size[1] * 0.82, size[2] * 0.75),
                                 e=0.45, nu=18, nv=8)
        _add(car, "MirrorGlass", (V, F), mirror=True)
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


def exhaust(u, s, h, r, length=0.20, oval=1.0, part="Exhaust", tilt=0.0):
    def fn(car, body):
        prof = [(r * 0.80, 0.0), (r, 0.0), (r, length), (r * 0.8, length), (r * 0.8, 0.01)]
        V, F = ck.lathe(prof, (0, 0, 0), "u", 28)
        V = np.array(V)
        V[:, 2] *= 1.0 / oval
        _add(car, part, (V + np.array([u, s, h]), F))
        # dark inner
        inner = [(0.001, 0.03), (r * 0.79, 0.03), (r * 0.79, 0.06), (0.001, 0.06)]
        V, F = ck.lathe(inner, (0, 0, 0), "u", 20)
        V = np.array(V)
        V[:, 2] *= 1.0 / oval
        _add(car, "Undertray", (V + np.array([u, s, h]), F))
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
