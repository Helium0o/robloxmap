"""
Nissan Skyline GT-R (BNR34), 1999-2002.

Reference data (see cars/README.md for sources):
  length 4600 mm, width 1785 mm, height 1360 mm, wheelbase 2665 mm
  track 1481 / 1491 mm (F/R), tyres 245/40 ZR18 on 18x9 alloys
  curb weight ~1560 kg
Design cues modelled: boxy wedge profile, notchback coupe roof, angular
headlights, upper grille + large three-opening front bumper, NACA hood
duct, quad round tail lights, tall pillar-mounted rear wing, single
large exhaust tip, RHD interior, 10-spoke (5 twin-spoke) wheels.
"""

import math
import carkit as ck
import assemble as A

L = 4.60
FRONT_AXLE = 3.645
REAR_AXLE = FRONT_AXLE - 2.665
R_TIRE = 0.327          # 245/40R18 -> 653 mm diameter
RIM_R = 0.2286 + 0.006   # 18" bead seat + flange
TRACK_F, TRACK_R = 1.481 / 2, 1.491 / 2

BODY = {
    "zT": [(0.00, 0.97), (0.30, 1.010), (0.95, 1.030), (1.15, 1.055), (1.28, 1.115),
           (1.72, 1.345), (1.95, 1.360), (2.55, 1.360), (2.80, 1.330), (3.32, 1.000),
           (3.42, 0.965), (3.70, 0.945), (4.20, 0.880), (4.45, 0.820), (4.60, 0.730)],
    "zRE": [(0.00, 0.955), (0.95, 1.000), (1.15, 1.020), (1.72, 1.300), (1.95, 1.315),
            (2.55, 1.315), (2.80, 1.290), (3.34, 0.935), (3.60, 0.915), (4.45, 0.790),
            (4.60, 0.700)],
    "zBelt": [(0.00, 0.900), (0.30, 0.965), (1.00, 0.985), (1.60, 0.960), (2.50, 0.925),
              (3.30, 0.895), (3.65, 0.880), (4.20, 0.835), (4.45, 0.770), (4.60, 0.680)],
    "wB": [(0.00, 0.835), (0.10, 0.862), (0.45, 0.868), (2.30, 0.862), (4.10, 0.868),
           (4.42, 0.860), (4.55, 0.835), (4.60, 0.805)],
    "zMid": [(0.0, 0.745), (2.3, 0.735), (4.6, 0.715)],
    "zF": [(0.00, 0.30), (0.22, 0.20), (0.45, 0.13), (4.20, 0.13), (4.42, 0.11),
           (4.60, 0.14)],
    "wF": [(0.00, 0.70), (0.55, 0.80), (0.60, 0.58), (1.36, 0.58), (1.41, 0.82),
           (3.24, 0.82), (3.27, 0.585), (4.03, 0.585), (4.08, 0.78), (4.60, 0.66)],
    "wGH": [(0.00, 0.70), (1.10, 0.775), (3.40, 0.775), (4.60, 0.62)],
    "wR": [(0.00, 0.66), (1.10, 0.715), (1.40, 0.640), (1.80, 0.600), (2.60, 0.600),
           (3.00, 0.645), (3.40, 0.730), (4.60, 0.580)],
    "under": [(0, 0.014), (4.6, 0.014)],
    "over": [(0, 0.040), (4.6, 0.045)],
}

# ---------------------------------------------------------------- decals
D = []
rp = ck.rounded_poly
circ = ck.circle_poly

# headlights: solid units on a plane fitted to the nose (see A.lamp_unit) -
# a clean trapezoid with straight top/bottom edges, the inner end chamfered
# toward the grille, two equal projectors on one level line
HL = rp([(0.398, 0.648), (0.836, 0.648), (0.836, 0.762), (0.390, 0.762), (0.370, 0.705)], 0.012)
HL_BEZEL = rp([(0.390, 0.640), (0.844, 0.640), (0.844, 0.770), (0.382, 0.770), (0.360, 0.705)], 0.016)
HL_ELS = (A.projector_els(0.535, 0.702, 0.042) + A.projector_els(0.708, 0.702, 0.042) + [
    dict(part="Indicators", poly=rp([(0.772, 0.656), (0.828, 0.656), (0.828, 0.690), (0.772, 0.690)], 0.006),
         z0=-0.004, z1=0.003),
    dict(part="Chrome", poly=[(0.430, 0.749), (0.828, 0.749), (0.828, 0.755), (0.430, 0.755)],
         z0=-0.004, z1=0.002),
    dict(part="HeadlightGlass", poly=HL, z0=0.017, z1=0.020),
])
# upper grille between the lights + badge
D.append(dict(part="Grille", view="front", sym=False, out=0.003,
              poly=rp([(-0.36, 0.680), (0.36, 0.680), (0.39, 0.735), (-0.39, 0.735)], 0.02), frame=(0.022, 0.014)))
D.append(dict(part="Badge", view="front", sym=False, out=0.013,
              poly=rp([(-0.055, 0.695), (0.055, 0.695), (0.055, 0.722), (-0.055, 0.722)], 0.008)))
# bumper: big centre intake + two side ducts + chin spoiler
D.append(dict(part="Grille", view="front", sym=False, out=0.003,
              poly=rp([(-0.33, 0.305), (0.33, 0.305), (0.36, 0.475), (-0.36, 0.475)], 0.04), frame=(0.022, 0.014)))
D.append(dict(part="Grille", view="front", out=0.003,
              poly=rp([(0.45, 0.305), (0.73, 0.330), (0.76, 0.470), (0.47, 0.470)], 0.035), frame=(0.022, 0.014)))
D.append(dict(part="Trim", view="front", sym=False, out=0.004,
              poly=rp([(-0.70, 0.125), (0.70, 0.125), (0.72, 0.185), (-0.72, 0.185)], 0.02)))

# rear: quad round tail lights
# the GT-R's signature quad rings: outer lamps are tail/brake, the inner pair
# carries the reverse light in the centre
# (the four round tail lamps are solid units - see SPEC["extras"])
D.append(dict(part="Badge", view="rear", sym=False, out=0.005,
              poly=rp([(-0.07, 0.86), (0.07, 0.86), (0.07, 0.89), (-0.07, 0.89)], 0.008)))
D += A.plate("rear", -0.185, 0.185, 0.525, 0.655)
D.append(dict(part="Trim", view="rear", sym=False, out=0.003,
              poly=rp([(-0.74, 0.30), (0.74, 0.30), (0.70, 0.18), (-0.70, 0.18)], 0.03)))
D.append(dict(part="Reflectors", view="rear", out=0.004,
              poly=rp([(0.58, 0.40), (0.76, 0.40), (0.76, 0.43), (0.58, 0.43)], 0.008)))

# glass
GLASS = dict(windshield=(2.84, 3.36), rear=(1.19, 1.71),
             side=[(1.60, 2.09), (2.16, 3.40)])
D.append(dict(part="Trim", view="top", sym=False, out=0.002,
              poly=[(3.36, -0.70), (3.43, -0.70), (3.43, 0.70), (3.36, 0.70)]))
# hood NACA duct (carbon on the V-spec)
D.append(dict(part="HoodTrim", view="top", sym=False, out=0.002,
              poly=rp([(3.82, -0.11), (3.98, -0.06), (3.98, 0.06), (3.82, 0.11)], 0.02)))

# panel gaps, handles, side indicators, fuel flap
D.append(A.line("side", [(3.150, 0.24), (3.160, 0.60), (3.185, 0.86)], part="DoorTrim*"))
D.append(A.line("side", [(2.045, 0.25), (2.045, 0.60), (2.055, 0.90)], part="DoorTrim*"))
D.append(A.line("side", [(2.045, 0.245), (3.150, 0.235)], part="DoorTrim*"))
D.append(dict(part="DoorTrim*", view="side", out=0.004,
              poly=rp([(2.14, 0.835), (2.30, 0.835), (2.30, 0.862), (2.14, 0.862)], 0.01)))
D.append(dict(part="Indicators", view="side", out=0.004,
              poly=rp([(4.06, 0.70), (4.14, 0.70), (4.14, 0.725), (4.06, 0.725)], 0.008)))
D.append(A.line("side", ck.circle_poly(1.48, 0.83, 0.07, 24) + [ck.circle_poly(1.48, 0.83, 0.07, 24)[0]],
                sym=False))
D[-1]["side"] = 1
# bumper shut lines front and rear
D.append(A.line("front", [(-0.80, 0.60), (0.0, 0.615), (0.80, 0.60)], sym=False))
D.append(A.line("rear", [(-0.78, 0.71), (0.0, 0.72), (0.78, 0.71)], sym=False))
# trunk lid + hood shut lines
D.append(A.line("top", [(0.16, -0.70), (0.16, 0.70)], sym=False))
D.append(A.line("top", [(4.42, -0.70), (4.42, 0.70)], sym=False))

SPEC = dict(
    name="NissanSkylineGTR_R34",
    length=L,
    body=BODY,
    arch_r=0.352,
    end_r=(0.0, 0.0),        # flat, tessellated end faces (no pinched rounding)
    end_p=3.0,
    # nose: corners swept back, bumper top leaning into the hood, chin tucked under
    # straight lean lines in side view (pow 1); squarer corners in plan (pow 3)
    ends=dict(front=dict(zone=0.60, plan=0.12, top=0.06, bot=0.09, plan_pow=5.0, top_pow=1, bot_pow=1),
              rear=dict(zone=0.50, plan=0.10, top=0.05, bot=0.10, plan_pow=3.0, top_pow=1, bot_pow=1)),
    flare=0.026,
    bevel=0.005,
    crease_gap=0.07,
    flush=True,
    panels=dict(door=dict(u=(2.03, 3.165), top=(2.09, 3.40)),
                hood=(3.42, 4.47), trunk=(0.06, 1.17)),
    wheels=[
        dict(tag="FR", u=FRONT_AXLE, half_track=TRACK_F, R=R_TIRE, rim_r=RIM_R, width=0.245),
        dict(tag="FL", u=FRONT_AXLE, half_track=-TRACK_F, R=R_TIRE, rim_r=RIM_R, width=0.245),
        dict(tag="RR", u=REAR_AXLE, half_track=TRACK_R, R=R_TIRE, rim_r=RIM_R, width=0.245),
        dict(tag="RL", u=REAR_AXLE, half_track=-TRACK_R, R=R_TIRE, rim_r=RIM_R, width=0.245),
    ],
    rim_style=dict(spokes=5, twin=True, spoke_w=0.030, dish=0.034, style="taper", e=0.12),
    disc_r=0.162,
    decals=D,
    glass=GLASS,
)


def wing(car, body):
    hw = 1.185
    chord, le = 0.25, 0.43
    span = 0.80
    pitch = math.radians(-7)
    prof = [(a, b) for a, b in ck.airfoil(chord, 0.11, camber=0.04)]
    path = [(0, -span, 0), (0, span, 0)]
    V, F = ck.sweep(prof, path, up_hint=(-1, 0, 0))
    A._add(car, "Wing", ck.xform((V, F), ck.rot_s(pitch), (le, 0, hw)))
    # small gurney flap
    A._add(car, "Wing", ck.box((le - chord + 0.01, 0, hw + 0.035), (0.012, span * 2, 0.03)))
    for sgn in (1, -1):
        s = 0.47 * sgn
        base = body.surface_top(0.30, s)
        hgt = hw - base + 0.01
        stay = ck.box((0, 0, 0), (0.14, 0.028, hgt))
        A._add(car, "Wing", ck.xform(stay, ck.rot_s(math.radians(-8)),
                                     (0.31, s, base + hgt / 2 - 0.01)))
        # end caps
        cap = ck.superellipsoid((le - chord / 2, span * sgn, hw - 0.005), (chord / 2 + 0.01, 0.008, 0.045),
                                e=0.3, nu=8, nv=4)
        A._add(car, "Wing", cap)


SPEC["extras"] = [
    A.lamp_unit("front", HL, HL_ELS, bezel=HL_BEZEL),
    # GT-R quad rings: outer pair tail/brake, inner pair with reverse centres
    A.round_lamp_unit("rear", 0.630, 0.865, 0.100),
    A.round_lamp_unit("rear", 0.375, 0.865, 0.100, centre="TailLightsInner"),
    wing,
    A.mirrors(3.21, 1.035, 0.115),
    A.interior_markers(seat_u=2.30, seat_s=0.38, floor_h=0.18, driver_side=1),
    A.splitter(depth=0.05, inset=0.05, back=0.28),
    A.diffuser(0.62, fins=5),
    A.engine_bay(3.45, 4.40, 0.56, 0.32, 0.86, engine_u=3.95),
    A.trunk_tub(0.22, 1.12, 0.62, 0.46, 0.95),
    A.interior(seat_u=2.30, seat_s=0.38, dash_u=3.05, wheel_side=1, floor_h=0.18,
               belt_h=0.93, roof_h=1.33, half_w=0.80, rear_seat_u=1.55),
    A.exhaust(None, -0.52, 0.255, 0.052, length=0.22),
    A.undertray(0.25, 4.40, 0.60, 0.135),
]
