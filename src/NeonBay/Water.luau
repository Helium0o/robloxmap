--[[
	Optional: swap the flat water parts for real Roblox Terrain water (waves, reflections,
	swimming). Studio only - the offline builder cannot write terrain.

		require(game.ServerStorage.NeonBay:Clone()).useTerrainWater()

	Only the bay and the sea next to the island become terrain; the far ocean stays as parts
	to keep the voxel count low.
]]

local Grid = require(script.Parent.Grid)

local Water = {}

function Water.useTerrain(config, depth: number?)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	assert(terrain, "Workspace has no Terrain")
	local grid = Grid.new(config)
	local d = depth or 16
	local top = config.WaterLevel
	local filled = 0
	for j = -2, grid.nz + 1 do
		for i = -2, grid.nx + 1 do
			if not grid:isLand(i, j) then
				local x0, z0 = grid:node(i, j)
				local center = Vector3.new(x0 + config.Cell / 2, top - d / 2, z0 + config.Cell / 2)
				terrain:FillBlock(CFrame.new(center), Vector3.new(config.Cell, d, config.Cell), Enum.Material.Water)
				filled += 1
			end
		end
	end
	terrain.WaterColor = Color3.fromRGB(12, 36, 60)
	terrain.WaterReflectance = 1
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 8

	-- hide the part water that terrain replaced (build() brings it back)
	local map = workspace:FindFirstChild(config.Name)
	if map then
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") and part:HasTag("NeonBayWater") then
				part.Transparency = 1
			end
		end
	end
	return filled
end

return Water
