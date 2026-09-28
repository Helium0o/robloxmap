# robloxmap

Roblox map development: planning tools and Studio build scripts.

## City

`studio/city/BuildCity.lua` builds a city in Roblox Studio. It has downtown towers, midrise blocks, parking garages, houses with garages, parks, an elevated ring highway with on-ramps, a gas station, an auto repair garage, warehouses, parking lots, billboards, street furniture and traffic signals. The map is about 2,100 × 2,100 studs and about 11,000 parts.

To build it:

1. Open a new Baseplate place in Roblox Studio.
2. Open **View → Command Bar**, paste the whole of `BuildCity.lua` and press Enter.
3. Press **Play** to see the traffic.

If the Command Bar won't take the whole script, use a ModuleScript instead:

1. In the Explorer, add a **ModuleScript** to **ServerStorage** and rename it `BuildCity`.
2. Open it, replace its contents with `BuildCity.lua`, and close the tab.
3. In the Command Bar, run `require(game.ServerStorage.BuildCity:Clone())`.

The script puts everything in `Workspace.City` and installs `StarterPlayerScripts.CityTraffic`, a LocalScript that drives the cars and switches the signals on each player's device. It also removes the default Baseplate and moves the spawn onto a sidewalk. Running it again replaces the previous build.

`studio/city/CityTraffic.client.lua` is a copy of that traffic script for reading. The build script already installs it.

### Making a different city

Open `tools/city-blueprint.html` in a browser. It shows the city in 3D with moving traffic. You can change the number of blocks, the block size and the seed, and copy a new build script. The build script and the preview come from the same generator.

## Small maps

`tools/map-blueprint.html` is a top-down planner for smaller maps. You drag rivers, paths, houses, trees and other pieces into place, and it writes either a Claude Desktop prompt or a Luau script.

## Testing the scripts without Studio

`tests/roblox_mock.lua` is a minimal stand-in for the Roblox API. `tests/traffic_harness.lua` checks that every part is within the 2,048-stud limit, then runs the traffic for a few simulated minutes. It reports cars that leave the road, get stuck or overlap. You need the [Luau CLI](https://github.com/luau-lang/luau/releases):

```sh
{ cat tests/roblox_mock.lua; sed 's/^return true.*$//' studio/city/BuildCity.lua; cat tests/traffic_harness.lua; } > /tmp/run.lua
luau /tmp/run.lua
```
