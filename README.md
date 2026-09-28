# robloxmap

Roblox map development: planning tools and Studio build scripts.

## City

`studio/city/BuildCity.lua` builds a suburban town on rolling hills in Roblox Studio:
- the ground is Roblox Terrain: grass hills, rock on steep slopes, and pavement along the streets
- winding side streets and straight 4-lane main roads that climb and dip with the land but never get steeper than 12%
- houses with garages, driveways and mailboxes, each on its own flattened lawn
- traffic lights on the main roads and stop signs on the side streets
- shop rows with parking lots, and parks with fountains, a basketball court and a playground
- an elevated ring highway that follows the hills, with on-ramps on earth embankments
- on the edge of town: a gas station, an auto repair garage, warehouses and a parking garage
- 160 cars that follow the curves and slopes, change lane for turns, and obey the lights and stop signs

The map is about 2,500 × 2,500 studs with 90 studs of height difference and 372 houses in about 10,900 parts.

To build it:

1. Open a new Baseplate place in Roblox Studio.
2. Open the **Command Bar**: press **Ctrl+9** (**⌘9** on Mac), or go to the **Script** tab → **Command Bar**. Paste the whole of `BuildCity.lua`, then press **Ctrl+Enter** or click **Run**. The terrain takes a little while.
3. Press **Play** to see the traffic.

If the Command Bar won't take the whole script, use a ModuleScript instead:

1. In the Explorer, add a **ModuleScript** to **ServerStorage** and rename it `BuildCity`.
2. Open it, replace its contents with `BuildCity.lua`, and close the tab.
3. In the Command Bar, run `require(game.ServerStorage.BuildCity:Clone())`.

The script replaces the place's terrain with the hills, puts everything else in `Workspace.City`, and installs `StarterPlayerScripts.CityTraffic`. That's a LocalScript that drives the cars and switches the signals on each player's device. It also removes the default Baseplate and moves the spawn onto a sidewalk. Running it again replaces the previous build.

### Adjusting it in Studio

The `SETTINGS` table at the top of `BuildCity.lua` switches parts of the city on and off without regenerating it. It covers houses, shops, parks, buildings, highway, outskirts, trees, street trees, street lights, lamp glow, furniture, parked cars, road markings and terrain. It also sets the number and speed of cars (`cityCars`, `highwayCars`, `citySpeed`, `highwaySpeed`), whether to install the traffic at all (`traffic`), and whether to delete the default Baseplate. Change a value, then run the script again.

`studio/city/CityTraffic.client.lua` is a copy of the traffic script with the default settings, for reading. The build script already installs it.

### Performance

- Every static part is anchored with `CanTouch` off.
- Road markings, lamps, doors and windows don't cast shadows or collide. Road markings also ignore raycasts.
- Houses, trees and other objects are Models with atomic streaming, so they stream in whole.
- Only about one street lamp in three has a real light. `lampGlow = false` removes them all.
- Parked cars have no light parts.
- Traffic is client-side and moved with `workspace:BulkMoveTo`. Lower `cityCars` and `highwayCars` for slower phones.

### Making a different city

Open `tools/city-blueprint.html` in a browser. It shows the city in 3D with moving traffic. Every road, block and building is generated from the seed, and the controls change what gets generated:

- **Roads:** straight grid, organic or winding layouts, plus how curvy the side streets are, how irregular the blocks are, 4-lane main roads, and centre lines on side streets.
- **Terrain:** how hilly it is, the size of the hills, and the steepest slope a road may have.
- **Style:** presets (Suburb, Small town, Downtown) and sliders for how many blocks are houses, shops, parks, apartments and office towers, plus the tallest building.
- **Layout:** the number of blocks, block size, house lot width and seed.
- **Extras:** the highway, on-ramps, outskirts businesses, street lights, lamp glow, street trees, street furniture, and how many trees and parked cars.
- **Traffic:** the number of cars on the streets and on the highway.

Copy the build script from the page and run it in Studio. The preview and the script use the same generator. Studio computes the hills with the same arithmetic as the page, so the terrain comes out identical.

## Small maps

`tools/map-blueprint.html` is a top-down planner for smaller maps. You drag rivers, paths, houses, trees and other pieces into place, and it writes either a Claude Desktop prompt or a Luau script.

## Testing the scripts without Studio

`tests/roblox_mock.lua` is a minimal stand-in for the Roblox API. `tests/traffic_harness.lua` checks that every part is within the 2,048-stud limit, then runs the traffic, including the traffic lights and stop signs, for a few simulated minutes. It reports cars that leave their lane, sit at the wrong height on a slope, get stuck or overlap. The mock also checks every terrain voxel write. You need the [Luau CLI](https://github.com/luau-lang/luau/releases):

```sh
{ cat tests/roblox_mock.lua; sed 's/^return true.*$//' studio/city/BuildCity.lua; cat tests/traffic_harness.lua; } > /tmp/run.lua
luau /tmp/run.lua
```
