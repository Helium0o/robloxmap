# Assetto Corsa track → Roblox

This guide covers two things:

1. how to share a big Assetto Corsa (AC) track with this repository (and Claude) without
   uploading hundreds of megabytes, and
2. how to turn the track into something Roblox Studio can load.

Both use one script, [`tools/assetto/ac2roblox.py`](../tools/assetto/ac2roblox.py). It needs
only Python 3.9 or newer. [Pillow](https://pypi.org/project/pillow/) is optional; with it the
converter also samples building colours from their textures and draws a `preview.png`.

## First: are you allowed to?

Most AC mod tracks are someone else's work, and many forbid converting them. Some tracks are
also ripped from other games, for example *Need for Speed* maps, which belong to EA.
Publishing those on Roblox can get your experience taken down, and **this repository is
public**, so anything you upload to it can be downloaded by anyone. Convert tracks you built
yourself or have written permission for. If a KN5 file is encrypted or protected, the
converter stops with "not a standard KN5 file". That means the author does not want it
converted.

## Why a 600 MB track can't go straight into Roblox (or a chat)

| Limit | Value |
| --- | --- |
| Triangles per mesh (MeshPart) | 20,000 |
| Part size | 2048 studs per axis |
| Texture size | 1024 × 1024 (each image is uploaded and moderated separately) |
| Chat attachments | small files only |
| GitHub, upload in the browser | 25 MB per file |
| GitHub, `git push` | 100 MB per file |

Nearly all of those 600 MB are texture images packed inside the `.kn5` files. The road, the
terrain and the buildings, which are what Roblox needs, are usually only 30–150 MB.

## Step 1 – Install Python (Windows)

Get Python from [python.org](https://www.python.org/downloads/) and tick **Add python.exe to
PATH** in the installer. Then open *Command Prompt* in this repository's folder (download it
with **Code → Download ZIP** on GitHub if you don't use git) and run:

```bat
pip install pillow
python tools\assetto\ac2roblox.py --version
```

## Step 2 – Look inside the track

```bat
python tools\assetto\ac2roblox.py inspect "C:\Program Files (x86)\Steam\steamapps\common\assettocorsa\content\tracks\YOUR_TRACK"
```

The result shows the triangles per category (road, kerb, grass, walls, buildings, trees...),
how much of the file is textures, the layouts, and whether there is an AI racing line
(`ai/fast_lane.ai`). Add `-v` to list every mesh.

## Step 3a – Share the track here (small package)

```bat
python tools\assetto\ac2roblox.py pack "...\tracks\YOUR_TRACK" -o ac_upload
```

This copies the geometry without textures, plus the AI line and the `data`/`ui` files, into
`ac_upload\YOUR_TRACK_slim.zip`. The zip is split into 24 MB parts (`.zip.001`, `.zip.002`,
...) when it is bigger than that. On a test track, 620 MB went down to 22 MB.

To upload it:

1. **Make the repository private first** if the track isn't yours to share: *Settings →
   General → Danger Zone → Change repository visibility*.
2. On github.com open the repository, **Add file → Upload files**, drag in all the parts, and
   at the bottom choose **Create a new branch** (for example `track-upload`). Commit.
3. Tell Claude the branch name. It can fetch that branch and run the converter for you.

If you use git on the command line instead, commit the parts to a new branch and push. Keep
every file under 100 MB. Don't commit the original 600 MB folder: GitHub rejects files over
100 MB, and large files stay in the repository history forever.

## Step 3b – Convert it yourself

```bat
python tools\assetto\ac2roblox.py convert "...\tracks\YOUR_TRACK" -o ac_output
```

This produces:

```
ac_output/
  meshes/*.obj            one Roblox-sized mesh each (<= 19,000 triangles, <= 1024 studs)
  YOUR_TRACK_AC.rbxmx     helper model for Studio (Tools, Manifest, RacingLine scripts)
  manifest.json           where every mesh goes, its category and colour
  preview.png             top-down picture (with Pillow)
  luau/                   the same scripts as plain files
```

Useful options:

| Option | What it does |
| --- | --- |
| `--layout NAME` | pick a layout (tracks with several, see `inspect`) |
| `--drop building ground` | leave categories out (fewer meshes to import) |
| `--keep foliage alpha` | keep trees and see-through meshes (skipped by default) |
| `--mirror` | use when `preview.png` is the mirror image of the track's `map.png` |
| `--studs-per-meter 3.571` | scale; the default makes 1 stud = 0.28 m (Roblox character scale) |
| `--exclude REGEX` / `--include REGEX` | skip or force meshes by name |

Skipped by default: trees and other see-through meshes (they look wrong without their
textures), crowds, sky domes, distant LOD copies, animated meshes and AC helper objects
(`AC_START_0`, ...).

The converter also fixes triangle winding: Roblox only draws the front of each triangle, so
every mesh is checked against its normals and flipped when it faces the wrong way.

## Step 4 – Import into Roblox Studio

1. **File → Import**. Select all the `.obj` files in `ac_output\meshes` at once (they go into
   the import queue). Keep the defaults (Scale Unit: **Studs**, World Forward: **Front**,
   World Up: **Top**). You can set one item up and use right-click → **Apply settings to all**.
   Then click **Import**.
2. Right-click **Workspace → Insert from File...** and pick `ac_output\YOUR_TRACK_AC.rbxmx`.
3. Open **View → Command Bar** and run:

   ```lua
   require(workspace.YOUR_TRACK_AC.Tools).assemble()
   ```

   This finds every imported mesh by name, moves it into place, and sets material, colour,
   anchoring and precise collision. It also fixes meshes that were imported with the wrong
   unit.
4. For smooth driving, add a road made of parts along the AI racing line:

   ```lua
   require(workspace.YOUR_TRACK_AC.Tools).buildRoad({ invisible = true }) -- collision layer under the meshes
   require(workspace.YOUR_TRACK_AC.Tools).buildRoad()                     -- or a visible road (no meshes needed)
   require(workspace.YOUR_TRACK_AC.Tools).placeSpawn()                    -- spawn on the start line
   ```

   Roblox cars drive better on flat parts than on detailed meshes. A common trick is
   `buildRoad({ invisible = true })` with `CanCollide` turned off on the `road` meshes.

Big tracks can produce 100+ meshes. Import them in batches, or drop categories you don't need.
To go further, merge and decimate the OBJ files in Blender first; keep each object under
20,000 triangles.

## Using the track together with Neon Bay

Put it in its own place, not next to the city: Roblox physics gets less precise far from
the origin, and a full circuit is thousands of studs long. A Roblox experience can hold several
places and teleport players between them.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `not a standard KN5 file` | The file is protected or encrypted and can't be converted. |
| Track is mirrored | Convert again with `--mirror`. |
| `assemble()` says meshes are missing | Import all `.obj` files first; their names must not be changed. |
| `assemble()` says meshes look rotated | Re-import with World Forward = Front and World Up = Top. |
| A mesh is invisible from one side | Select it and turn on `DoubleSided` in Properties. |
| Driving is bumpy | Use `buildRoad({ invisible = true })` and turn off `CanCollide` on the road meshes. |
| Too many meshes | `--drop building ground`, or a larger `--tile` (up to 2000). |

## How it works (for the curious)

* `aclib/kn5.py` reads the KN5 format (header `sc6969`, textures, materials, a node tree of
  dummies and meshes) using memory mapping, so a 600 MB file opens in a fraction of a second.
* AC and Roblox both use right-handed, Y-up coordinates. Positions are scaled from metres to
  studs and centred, with the lowest road surface at y = 0.
* Meshes are sorted into categories using AC's physics naming (`1ROAD`, `1KERB`, `2GRASS`...,
  which is also how the game decides grip) and keywords in mesh or material names.
* Triangles are cut into tiles and chunks that fit Roblox's limits. The AI spline
  (`fast_lane.ai`: positions plus left/right track widths) is simplified into the racing
  line that `buildRoad()` uses.
