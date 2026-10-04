# Handoff: Roblox car assets (R34 GT-R and Supra MK4)

Branch `claude/trusting-pasteur-c8tfx3`, PR https://github.com/Helium0o/robloxmap/pull/2.
Everything below is committed on that branch. `cars/README.md` is the user-facing doc
(import steps, rig, attributes); this file is for whoever continues the work.

## What exists

| Path | What |
| --- | --- |
| `cars/<Car>/<Car>.obj` + `.mtl` | Generated models (studs, +X right, +Y up, −Z forward). Each OBJ group becomes one MeshPart in Roblox |
| `cars/<Car>/preview*.png` | Renders used in the README / PR |
| `cars/generator/` | Python generator (numpy only). `python3 build.py` rebuilds both cars |
| `cars/roblox/CarSetup.server.lua` | Script that goes inside the imported Model: paint and materials, wheel hinges (spin and steer), doors/hood/trunk on prompts, seats, lights, AWD/RWD drive |
| `cars/tools/` | three.js preview renderer (`preview.html`, `shot.mjs`) |

Current numbers: R34 ~28.6k triangles, Supra ~26.7k, 53 parts each. Biggest single
part is ~5.5k (Roblox caps a mesh at 20k).

## User requirements (hard rules)

- **≤ 45,000 triangles per car in total.** It's for a network racing game.
  `build.py --budget` enforces it and refuses to export.
- **Modular:** wheels spin and steer, doors/hood/trunk open. Keep the part names and
  `Marker_*` parts; `CarSetup` finds everything by name.
- **Look:** semi-realistic and sporty, defined panels rather than blobby/round,
  wheels cheap (~700 triangles each including brakes).
- **Lights:** straight edges, round and level lenses, embedded flush in the body,
  not sticking out.

## Feedback history

The user is picky about the visual result and checks screenshots in Studio. Their
complaints so far, in order:

1. Too round, toy-like. Fixed with panel-style cross-sections and crisp creases.
2. Front and rear faces flat. Fixed with the nose/tail warp (`ends`).
3. Headlights wobbly and misaligned. Rebuilt as `lamp_unit` on a fitted plane.
4. Lights sticking out. Lamp layers are now cast onto the paint (`LampPlane.conform`).
5. R34 front still a flat wall. Fixed by lowering `zMid` toward the nose.
   **Awaiting their verdict.** The corner between the R34's front face and side is
   now fairly sharp; offer to soften it.

Always render and look before claiming something is fixed.

## How to work

```bash
cd cars/generator && python3 build.py            # rebuild both (~40 s); prints triangles per part
python3 build.py --only r34                       # one car
cd ../tools && npm install                        # once: three + playwright-core
cd .. && python3 -m http.server 8765              # serve cars/ (leave running)
cd tools && CHROME_PATH="<path to chrome>" node shot.mjs NissanSkylineGTR_R34 out.png \
  '&cols=2&dist=34&views=[[0.9,0.25,-1],[1,0.03,0]]'
```

`shot.mjs` query options:

- `views`: camera directions (x right, y up, z back; front of car is −z)
- `dist`: camera distance
- `cols`: grid columns
- `tgt=[x,y,z]`: offset the look-at point, for close-ups (studs)
- `pose=1`: opens doors/hood/trunk and steers the front wheels, using the markers

## Generator architecture (`cars/generator/`)

- **`carkit.py`**
  - `Body`: a loft along `u`, the length from the rear. Each cross-section comes
    from keyframed params in each car's `BODY` dict:
    - `zF`/`wF`: floor and wheel wells
    - `wB`: width
    - `zMid`: character crease
    - `zBelt`: shoulder
    - `wGH`/`wR`/`zRE`/`zT`: greenhouse and roof
    - `under`/`over`
  - Wheel arches are cut by raising the sill over each wheel; `flare` bulges the sides.
  - **Profile clamps matter:** `zBelt ≥ crease + 0.07` and `zRE ≥ zBelt + ~0.05`. A
    high `zMid` at the nose stops the hood from dropping; that was the flat-R34 bug.
  - `warp()`: shapes nose and tail after lofting (`ends`: `plan` sweeps corners
    back, `top` leans the top back, `bot` tucks the chin, each with a `*_pow`).
  - End faces are concentric rings, so there are no slivers.
  - `mesh()` splits faces into Body / Glass / Trim / Door_X / Hood / Trunk by
    region (`glass`, `panels` in the spec).
  - `decal()` / `project()`: details (grilles, gaps, plates, small lights) are 2D
    outlines cast onto `body.tri_mesh`, the exported triangles. Front/rear layers
    are forced ≥ 7 mm proud to avoid z-fighting on curved paint.
  - `LampPlane`: best-fit plane frame for a lamp, so shapes are drawn flat. Its
    `conform()` casts each layer onto the paint along the plane normal.
  - Exporter: per-part hard-edge angles (`Car.HARD`), with creases running along
    the car kept sharp; parts over 19k triangles are split automatically.
- **`assemble.py`**
  - `build(spec)` wires everything.
  - `MERGE` folds same-colour parts together (fewer MeshParts).
  - Extras: `lamp_unit`, `round_lamp_unit`, `projector_els`, `mirrors`, `interior`,
    `engine_bay`, `trunk_tub`, `splitter`, `diffuser`, `exhaust`.
- **`r34.py` / `supra.py`**
  - Dimensions are from real specs (sources in `cars/README.md`).
  - `D` is the decal list. Lamps and wing are in `SPEC["extras"]`.
  - Front/rear decal polygons are in (s, h) metres in front view; side decals are
    (u, h); top decals are (u, s).
- **`palette.py`**: colours, mirrored in `CarSetup.server.lua`.

## Gotchas

- Coordinates `(u, s, h)` are left-handed. Winding and orientation checks must be
  done in the output frame (`to_out`); `orient_closed` handles closed meshes.
- Lamps or decals placed across an edge (nose top edge, rear-panel top edge)
  look broken. Probe the surface first with `ck.mesh_raycast(body.tri_mesh, ...)`
  and keep lamps on one face.
- `CarSetup` is untested in real Roblox (no Studio in the cloud container). Hinge
  directions were verified only through the `pose=1` preview. Expect tuning:
  `MaxSpeed`, torque, steering. There's no suspension yet.
- Re-running `build.py` overwrites the OBJs. Regenerate previews afterwards if
  they're referenced in the README.

## Open ideas the user hasn't asked for yet

- Softer R34 front corners, or a rounder nose.
- Suspension (spring constraints) in `CarSetup`.
- A far-distance LOD version (~8k triangles: no interior, engine or opening panels).
