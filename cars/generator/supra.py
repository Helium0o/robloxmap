"""
Toyota Supra Turbo (JZA80 / "MK4"), 1993-2002.

Reference data (see cars/README.md for sources):
  length 4520 mm, width 1810 mm, height 1275 mm, wheelbase 2550 mm
  track 1520 / 1525 mm (F/R), tyres 235/45 ZR17 front, 255/40 ZR17 rear
  curb weight ~1570-1590 kg (Turbo)
Design cues modelled: long low pointed nose, rounded "coke bottle" body
with wide rear hips, heavily raked windscreen, bubble roof and large
glass hatch, oval tri-beam headlights, big centre mouth with flanking
ducts and amber indicators, hoop rear wing, full-width tail panel with
twin round lamps per side, LHD interior, 5-spoke 17" wheels.
"""

import math
import carkit as ck
import assemble as A

L = 4.52
FRONT_AXLE = 3.46
REAR_AXLE = FRONT_AXLE - 2.55
RIM_R = 0.2159 + 0.006   # 17" bead seat + flange
R_F = 0.3215             # 235/45R17 -> 643 mm
R_R = 0.3200             # 255/40R17 -> 636 mm
TRACK_F, TRACK_R = 1.520 / 2, 1.525 / 2

BODY = {
    "zT": [(0.00, 0.930), (0.20, 0.975), (0.55, 0.990), (0.80, 1.005), (0.98, 1.050),
           (1.60, 1.235), (1.95, 1.272), (2.25, 1.268), (2.45, 1.240), (3.05, 0.930),
           (3.20, 0.900), (3.60, 0.835), (4.10, 0.755), (4.40, 0.680), (4.52, 0.600)],
    "zRE": [(0.00, 0.900), (0.55, 0.950), (0.80, 0.970), (1.60, 1.180), (1.95, 1.215),
            (2.25, 1.212), (2.45, 1.185), (3.07, 0.885), (3.60, 0.800), (4.10, 0.720),
            (4.40, 0.660), (4.52, 0.575)],
    "zBelt": [(0.00, 0.860), (0.40, 0.905), (0.92, 0.915), (1.50, 0.895), (2.40, 0.860),
              (3.10, 0.840), (3.46, 0.820), (4.00, 0.740), (4.35, 0.660), (4.52, 0.565)],
    "wB": [(0.00, 0.840), (0.12, 0.862), (0.50, 0.870), (0.92, 0.872), (1.40, 0.868),
           (2.00, 0.860), (2.60, 0.860), (3.10, 0.864), (3.46, 0.866), (3.90, 0.858),
           (4.25, 0.825), (4.45, 0.760), (4.52, 0.690)],
    "zMid": [(0.0, 0.66), (2.3, 0.62), (4.52, 0.56)],
    "zF": [(0.00, 0.29), (0.25, 0.19), (0.45, 0.115), (4.10, 0.115), (4.35, 0.11),
           (4.52, 0.17)],
    "wF": [(0.00, 0.66), (0.48, 0.80), (0.53, 0.60), (1.30, 0.60), (1.35, 0.83),
           (3.05, 0.83), (3.08, 0.62), (3.84, 0.62), (3.90, 0.76), (4.52, 0.55)],
    "wGH": [(0.00, 0.66), (0.60, 0.760), (1.00, 0.775), (3.00, 0.775), (4.52, 0.50)],
    "wR": [(0.00, 0.62), (0.80, 0.700), (1.20, 0.640), (1.70, 0.575), (2.30, 0.570),
           (2.60, 0.600), (3.07, 0.715), (4.00, 0.660), (4.52, 0.450)],
    "under": [(0, 0.022), (4.52, 0.022)],
    "over": [(0, 0.070), (2.0, 0.075), (4.52, 0.060)],
}

D = []
rp = ck.rounded_poly
HL_PROJ = dict(yaw=24, pitch=28, pivot=(0.60, 0.64))
TL_PROJ = dict(yaw=26, pitch=0, pivot=(0.55, 0.83))
circ = ck.circle_poly

# ---- front: oval tri-beam headlights on the nose corners
HL = circ(0.600, 0.640, 0.205, 40, ry=0.052, rot=math.radians(5))
D.append(dict(part="Trim", view="front", out=0.002, **HL_PROJ,
              poly=circ(0.600, 0.640, 0.218, 40, ry=0.064, rot=math.radians(5))))
D.append(dict(part="HeadLights", view="front", poly=HL, out=0.005, **HL_PROJ))
for k, cs in enumerate((0.470, 0.585, 0.700)):
    ch = 0.640 + (cs - 0.600) * math.tan(math.radians(5))
    D.append(dict(part="Chrome", view="front", poly=circ(cs, ch, 0.040, 22), out=0.009, **HL_PROJ))
    D.append(dict(part="Lens", view="front", poly=circ(cs, ch, 0.028, 20), out=0.012, **HL_PROJ,
                  bulge=0.006))
# big centre mouth with the number plate recess above it
D.append(dict(part="Grille", view="front", sym=False, out=0.003,
              poly=rp([(-0.40, 0.255), (0.40, 0.255), (0.36, 0.430), (0.0, 0.445),
                       (-0.36, 0.430)], 0.07)))
D.append(dict(part="Grille", view="front", out=0.003,
              poly=rp([(0.52, 0.265), (0.76, 0.300), (0.78, 0.380), (0.55, 0.375)], 0.035)))
D.append(dict(part="Indicators", view="front", out=0.005,
              poly=rp([(0.53, 0.400), (0.79, 0.410), (0.80, 0.445), (0.56, 0.440)], 0.015)))
D.append(dict(part="Badge", view="front", sym=False, out=0.006,
              poly=circ(0.0, 0.565, 0.040, 24, ry=0.026)))
D.append(dict(part="Trim", view="front", sym=False, out=0.004,
              poly=rp([(-0.60, 0.130), (0.60, 0.130), (0.62, 0.175), (-0.62, 0.175)], 0.02)))

# ---- rear: full-width tail panel with two round lamps each side
D.append(dict(part="Trim", view="rear", sym=False, out=0.003,
              poly=rp([(-0.77, 0.760), (0.77, 0.760), (0.78, 0.900), (-0.78, 0.900)], 0.03)))
D.append(dict(part="TailLights", view="rear", sym=False, out=0.005,
              poly=rp([(-0.30, 0.785), (0.30, 0.785), (0.30, 0.875), (-0.30, 0.875)], 0.02)))
for cs, inner in ((0.660, "TailLightsInner"), (0.440, "Indicators")):
    D.append(dict(part="Chrome", view="rear", poly=circ(cs, 0.830, 0.092, 36), out=0.006, **TL_PROJ))
    D.append(dict(part="TailLights", view="rear", poly=circ(cs, 0.830, 0.082, 36), out=0.009,
                  bulge=0.008, **TL_PROJ))
    D.append(dict(part=inner, view="rear", poly=circ(cs, 0.830, 0.036, 24), out=0.019, **TL_PROJ))
D.append(dict(part="Badge", view="rear", sym=False, out=0.009,
              poly=rp([(-0.10, 0.818), (0.10, 0.818), (0.10, 0.842), (-0.10, 0.842)], 0.008)))
D += A.plate("rear", -0.18, 0.18, 0.505, 0.635)
D.append(dict(part="Trim", view="rear", sym=False, out=0.003,
              poly=rp([(-0.72, 0.30), (0.72, 0.30), (0.68, 0.19), (-0.68, 0.19)], 0.03)))
D.append(dict(part="Reflectors", view="rear", out=0.004,
              poly=rp([(0.52, 0.40), (0.74, 0.40), (0.74, 0.43), (0.52, 0.43)], 0.008)))

# ---- glass
GLASS = dict(windshield=(2.50, 3.05), rear=(0.85, 1.71),
             side=[(1.28, 1.86), (1.92, 3.10)])
D.append(dict(part="Trim", view="top", sym=False, out=0.002,
              poly=[(3.05, -0.69), (3.11, -0.69), (3.11, 0.69), (3.05, 0.69)]))

# ---- panel gaps, handles, markers
D.append(A.line("side", [(2.970, 0.23), (2.985, 0.60), (3.010, 0.81)], part="DoorTrim*"))
D.append(A.line("side", [(1.855, 0.24), (1.855, 0.60), (1.865, 0.86)], part="DoorTrim*"))
D.append(A.line("side", [(1.855, 0.235), (2.970, 0.225)], part="DoorTrim*"))
D.append(dict(part="DoorTrim*", view="side", out=0.004,
              poly=rp([(1.93, 0.800), (2.09, 0.800), (2.09, 0.826), (1.93, 0.826)], 0.01)))
D.append(dict(part="Indicators", view="side", out=0.004,
              poly=rp([(4.12, 0.44), (4.26, 0.44), (4.26, 0.47), (4.12, 0.47)], 0.01)))
D.append(dict(part="Reflectors", view="side", out=0.004,
              poly=rp([(0.22, 0.48), (0.36, 0.48), (0.36, 0.51), (0.22, 0.51)], 0.01)))
D.append(A.line("top", [(4.43, -0.62), (4.47, 0.0), (4.43, 0.62)], sym=False))
D.append(A.line("top", [(0.06, -0.66), (0.06, 0.66)], sym=False))

SPEC = dict(
    name="ToyotaSupra_MK4",
    length=L,
    body=BODY,
    arch_r=0.348,
    end_r=(0.08, 0.10),
    end_p=3.2,
    flare=0.040,
    bevel=0.010,
    crease_gap=0.06,
    flush=True,
    panels=dict(door=dict(u=(1.84, 2.985), top=(1.86, 3.10)),
                hood=(3.12, 4.40), trunk=(0.06, 1.71)),
    wheels=[
        dict(tag="FR", u=FRONT_AXLE, half_track=TRACK_F, R=R_F, rim_r=RIM_R, width=0.235),
        dict(tag="FL", u=FRONT_AXLE, half_track=-TRACK_F, R=R_F, rim_r=RIM_R, width=0.235),
        dict(tag="RR", u=REAR_AXLE, half_track=TRACK_R, R=R_R, rim_r=RIM_R, width=0.255),
        dict(tag="RL", u=REAR_AXLE, half_track=-TRACK_R, R=R_R, rim_r=RIM_R, width=0.255),
    ],
    rim_style=dict(spokes=5, twin=False, spoke_w=0.048, dish=0.036, style="taper", e=0.12),
    disc_r=0.161,
    decals=D,
    glass=GLASS,
)


def hoop_wing(car, body):
    """The MK4's signature hoop spoiler: one swept airfoil, legs on the deck."""
    u0 = 0.30
    deck = body.surface_top(u0, 0.66)
    top = deck + 0.255
    chord = 0.23
    prof = [(a - chord * 0.55, b) for a, b in ck.airfoil(chord, 0.12, camber=0.03)]
    path = []
    legs = 0.66
    r = 0.12
    # left leg up, round corner, across, round corner, right leg down
    for t in [0.0, 0.3, 0.6, 1.0]:
        path.append((u0, -legs - 0.03 * (1 - t), deck - 0.01 + (top - r - deck + 0.01) * t))
    for k in range(1, 7):
        a = math.pi - k * (math.pi / 2) / 6
        path.append((u0, -legs + r + r * math.cos(a), top - r + r * math.sin(a)))
    for s in [-0.3, 0.0, 0.3]:
        path.append((u0, s, top + 0.006 * (1 - (s / 0.66) ** 2)))
    for k in range(0, 6):
        a = math.pi / 2 - k * (math.pi / 2) / 6
        path.append((u0, legs - r + r * math.cos(a), top - r + r * math.sin(a)))
    for t in [1.0, 0.6, 0.3, 0.0]:
        path.append((u0, legs + 0.03 * (1 - t), deck - 0.01 + (top - r - deck + 0.01) * t))
    V, F = ck.sweep(prof, path, up_hint=(-1, 0, 0))
    # slight angle of attack
    V = (V - [u0, 0, top]) @ ck.rot_s(math.radians(-4)).T + [u0, 0, top]
    A._add(car, "Wing", (V, F))
    # third brake light on the wing
    A._add(car, "TailLights", ck.box((u0 - chord * 0.45, 0, top + 0.005), (0.02, 0.30, 0.018)))


SPEC["extras"] = [
    hoop_wing,
    A.mirrors(2.93, 0.975, 0.11, size=(0.08, 0.10, 0.052)),
    A.interior_markers(seat_u=2.05, seat_s=0.38, floor_h=0.16, driver_side=-1),
    A.splitter(depth=0.06, inset=0.06, back=0.30),
    A.diffuser(0.58, fins=4),
    A.engine_bay(3.15, 4.30, 0.56, 0.30, 0.80, engine_u=3.65),
    A.trunk_tub(0.22, 1.15, 0.62, 0.44, 0.92),
    A.interior(seat_u=2.05, seat_s=0.38, dash_u=2.78, wheel_side=-1, floor_h=0.16,
               belt_h=0.88, roof_h=1.22, half_w=0.80, rear_seat_u=1.38),
    A.exhaust(-0.03, 0.50, 0.24, 0.058, length=0.22),
    A.undertray(0.25, 4.30, 0.60, 0.13),
]
