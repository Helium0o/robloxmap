--[[
	Fills every block with buildings according to its district letter in Config.Map.
	Each block gets its own random stream, so changing one block leaves the others alone.
]]

local Rng = require(script.Parent.Rng)
local Downtown = require(script.Downtown)
local Commercial = require(script.Commercial)
local Residential = require(script.Residential)
local Industrial = require(script.Industrial)
local Park = require(script.Park)
local OpenLot = require(script.OpenLot)
local Garage = require(script.Garage)
local Beach = require(script.Beach)
local Airport = require(script.Airport)

local Districts = {}

-- Map letter -> block builder. Airport cells are handled as whole regions below.
local recipes = {
	D = Downtown,
	C = Commercial,
	R = Residential,
	I = Industrial,
	P = Park,
	X = OpenLot,
	G = Garage,
	B = Beach,
	["."] = { build = Park.field },
}

function Districts.build(B, root, grid, config, plan, seed: number, withSpawn: boolean)
	local folder = B:group(root, "Districts")

	-- centre of downtown: towers get taller towards it
	local sx, sz, n = 0, 0, 0
	grid:forEachCell(function(c)
		if c.char == "D" then
			sx += c.cx
			sz += c.cz
			n += 1
		end
	end)

	local ctx = {
		B = B,
		grid = grid,
		config = config,
		plan = plan,
		seed = seed,
		withSpawn = withSpawn,
		downtown = if n > 0 then Vector3.new(sx / n, 0, sz / n) else Vector3.zero,
		spawn = nil,
	}

	-- Buildable area of a block: inside the sidewalk, standing on the curb.
	function ctx.lot(_, c)
		local x0, z0, x1, z1 = grid:blockRect(c)
		if c.def.noCurb or not c.def.streets then
			return x0, z0, x1, z1, if c.def.streets then 0 else 0.15
		end
		local s = config.Sidewalk
		return x0 + s, z0 + s, x1 - s, z1 - s, config.CurbHeight
	end

	-- True if the freeway passes over this rectangle (building would poke through).
	function ctx.blocked(_, c, x0, z0, x1, z1)
		return plan:blocksRect(c.i, c.j, x0, z0, x1, z1)
	end

	grid:forEachCell(function(c)
		local recipe = recipes[c.char]
		if recipe then
			local districtFolder = B:group(folder, c.def.name)
			local block = B:group(districtFolder, string.format("%s_%d_%d", c.char, c.i, c.j), "Model")
			recipe.build(ctx, block, c, Rng.new(seed, c.i, c.j, c.char))
		end
	end)
	Airport.build(ctx, B:group(folder, "Airport"), Rng.new(seed, "airport"))

	return folder, ctx
end

return Districts
