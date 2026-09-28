--[[
	Neon Bay — layout and tuning.

	The city is drawn as ASCII art: every character is one grid cell of `Cell` x `Cell` studs.
	Streets run along the cell borders, so every block is surrounded by road. Edit `Map`
	to reshape the city, then rebuild (see README.md).

	Legend
	  ~  water            D  downtown towers     C  commercial / neon shops
	  R  residential      I  industrial / port   P  park
	  A  airport          B  beach               X  open lot (drift / drag meet spot)
	  G  garage hub (spawn point, shop signs)    .  open field

	Freeway nodes are grid intersections written as { column, row }, counted from 0 at the
	top-left corner of `Map`. Column n is the vertical street on the left edge of map column n.
]]

local Config = {}

Config.Name = "NeonBay"
Config.Seed = 24601

-- Dimensions (studs). 1 stud is roughly 0.28 m, so a lane is about 3.4 m.
Config.Cell = 320 -- grid pitch: one block plus one street
Config.LaneWidth = 12
Config.RoadWidth = 48 -- four lanes, street centred on the cell border
Config.Sidewalk = 12
Config.CurbHeight = 0.8
Config.BaseDepth = 12 -- thickness of the ground slabs (top face at y = 0)
Config.WaterLevel = -4
Config.OceanMargin = 3000 -- open water drawn around the map

-- Elevated freeway
Config.FreewayHeight = 36 -- top of the deck; ground streets keep 33 studs of clearance
Config.DeckThickness = 3
Config.DeckWidth = 48
Config.BarrierHeight = 3.2
Config.FilletRadius = 144 -- radius of the curves where the freeway turns

-- Street lamps: 1 = default, 0.5 = about half as many (lighter for phones).
Config.LampDensity = 1

Config.Map = {
	"~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~RRRRPPRRR~~~~~~~~~~~~",
	"~~RRRRRPPRRRR~~~~AAAAA~~",
	"~.RRCCRRRRCCR~~~~AAAAA~~",
	"~.RCCCCCCCCCI~~~~AAAAA~~",
	"~RRCCDDDDCCII~~~~AAAAA~~",
	"~PPCDDDDDDCII~~~~IICCR~~",
	"~PPCDDDDDDCII~~~~IICCR~~",
	"~RRCDDDDDDCII~~~~CCCRR~~",
	"~RRCGDDDDCCII~~~~RRRRB~~",
	"~RRCCCCCCCXII~~~~RPPRB~~",
	"~BRRRCCXXCCII~~~~RRRBB~~",
	"~BBRRRRPPRRII~~~~~BBB~~~",
	"~~BBBRRRRRR~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~",
	"~~~~~~~~~~~~~~~~~~~~~~~~",
}

-- land: solid ground. streets: generates streets on all four sides of the cell.
-- ground: surface material of the cell when it has no block on it.
Config.Districts = {
	["~"] = { name = "Water", land = false, streets = false },
	["."] = { name = "Field", land = true, streets = true, ground = "Grass" },
	D = { name = "Downtown", land = true, streets = true, urban = true },
	C = { name = "Commercial", land = true, streets = true, urban = true },
	G = { name = "Garage", land = true, streets = true, urban = true },
	R = { name = "Residential", land = true, streets = true },
	I = { name = "Industrial", land = true, streets = true },
	P = { name = "Park", land = true, streets = true },
	X = { name = "OpenLot", land = true, streets = true, noCurb = true },
	A = { name = "Airport", land = true, streets = false, ground = "Grass" },
	B = { name = "Beach", land = true, streets = false, ground = "Sand" },
}

Config.Freeway = {
	-- Elevated lines: consecutive corners must share a row or a column.
	Lines = {
		{ name = "Ring", closed = true, corners = { { 3, 4 }, { 11, 4 }, { 11, 11 }, { 3, 11 } } },
		{ name = "Bay Bridge", corners = { { 11, 7 }, { 18, 7 } } },
	},
	-- Ramps drop from an elevated node to the neighbouring ground intersection.
	Ramps = {
		{ from = { 3, 7 }, to = { 2, 7 } },
		{ from = { 7, 4 }, to = { 7, 3 } },
		{ from = { 7, 11 }, to = { 7, 12 } },
		{ from = { 18, 7 }, to = { 19, 7 } },
	},
	-- Overhead signs: placed on the edge that starts at `at` and runs toward `toward`.
	Signs = {
		{ at = { 5, 4 }, toward = { 6, 4 }, text = "DOWNTOWN  ·  NEXT EXIT" },
		{ at = { 11, 9 }, toward = { 11, 8 }, text = "BAY BRIDGE  ·  AIRPORT" },
		{ at = { 9, 11 }, toward = { 8, 11 }, text = "BEACH  ·  DRIFT LOT" },
		{ at = { 3, 6 }, toward = { 3, 5 }, text = "WEST SIDE  ·  PARK" },
		{ at = { 16, 7 }, toward = { 17, 7 }, text = "EAST BAY  ·  AIRPORT" },
	},
}

-- Where players spawn (a garage hub cell).
Config.SpawnDistrict = "G"

return Config
