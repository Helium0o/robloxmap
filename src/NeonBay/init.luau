--[[
	Neon Bay — a night-time street racing city generator for Roblox Studio.

	Usage (Studio command bar, edit mode):
		require(game.ServerStorage.NeonBay:Clone()).build()
		require(game.ServerStorage.NeonBay:Clone()).build({ seed = 7 })

	`:Clone()` makes Studio re-read the scripts, so edits to Config take effect.
	Terrain water instead of the flat water parts (optional, Studio only):
		require(game.ServerStorage.NeonBay:Clone()).useTerrainWater()

	The previous `Workspace.NeonBay` model is replaced. Options:
		seed      number  different buildings, same street layout (default Config.Seed)
		parent    Instance  where to put the map (default workspace)
		lighting  boolean  apply the night lighting preset (default true)
		spawn     boolean  add the SpawnLocation at the garage (default true)
]]

local Config = require(script.Config)
local Builder = require(script.Builder)
local Grid = require(script.Grid)
local Ground = require(script.Ground)
local Streets = require(script.Streets)
local Freeway = require(script.Freeway)
local Districts = require(script.Districts)
local Atmosphere = require(script.Atmosphere)
local Water = require(script.Water)

local NeonBay = {}

NeonBay.Config = Config

export type Options = {
	seed: number?,
	parent: Instance?,
	lighting: boolean?,
	spawn: boolean?,
	config: { [string]: any }?,
}

function NeonBay.build(options: Options?)
	local o: Options = options or {}
	local config = o.config or Config
	local seed = o.seed or config.Seed
	local parent = o.parent or workspace

	local previous = parent:FindFirstChild(config.Name)
	if previous then
		previous:Destroy()
	end

	local root = Instance.new("Model")
	root.Name = config.Name
	local B = Builder.new(root)
	local grid = Grid.new(config)
	local plan = Freeway.plan(grid, config)

	Ground.build(B, root, grid, config)
	Streets.build(B, root, grid, config, plan)
	Freeway.build(B, root, grid, config, plan)
	local _, ctx = Districts.build(B, root, grid, config, plan, seed, o.spawn ~= false)

	root:SetAttribute("Seed", seed)
	root:SetAttribute("Parts", B.parts)
	root.Parent = parent

	if o.lighting ~= false then
		Atmosphere.apply(game:GetService("Lighting"))
	end

	return root,
		{
			parts = B.parts,
			lights = B.lights,
			signs = B.guis,
			oversize = B.oversize,
			spawn = ctx.spawn,
		}
end

-- Replaces the water parts around the island with Terrain water. Studio only.
function NeonBay.useTerrainWater(options: { config: { [string]: any }? }?)
	local config = (options and options.config) or Config
	return Water.useTerrain(config)
end

return NeonBay
