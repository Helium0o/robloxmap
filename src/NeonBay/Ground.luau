--[[
	Ground layer: asphalt slabs under every street cell, sand/grass for beach and airport
	cells, coast roads with sea barriers, sidewalks, and the ocean.

	All asphalt pieces tile the plane without overlapping (overlapping coplanar parts
	flicker). Grass and sand sit 0.15 studs higher so they may overlap safely.
]]

local Palette = require(script.Parent.Palette)
local lookAt = require(script.Parent.Geometry).lookAt

local Ground = {}

local SIDES = {
	N = { di = 0, dj = -1 },
	S = { di = 0, dj = 1 },
	W = { di = -1, dj = 0 },
	E = { di = 1, dj = 0 },
}

local GROUND_MATERIAL = {
	Grass = { Palette.Grass, Enum.Material.Grass },
	Sand = { Palette.Sand, Enum.Material.Sand },
}

local function isWater(grid, i: number, j: number): boolean
	return not grid:isLand(i, j)
end

-- Does water cell (i, j) carry a coast road strip along `side`?
local function hasStrip(grid, i: number, j: number, side: string): boolean
	local s = SIDES[side]
	return isWater(grid, i, j) and grid:isStreeted(i + s.di, j + s.dj)
end

local function slab(B, parent, name, x0, z0, x1, z1, top, depth, color, mat)
	if x1 - x0 < 0.01 or z1 - z0 < 0.01 then
		return
	end
	B:block(parent, name, (x0 + x1) / 2, top - depth, (z0 + z1) / 2, x1 - x0, depth, z1 - z0, color, mat)
end

function Ground.build(B, root, grid, config)
	local folder = B:group(root, "Ground")
	local cell = config.Cell
	local hw = config.RoadWidth / 2
	local depth = config.BaseDepth
	local bw, bh = 1.6, config.BarrierHeight

	-- 1. Street cells: one asphalt slab per merged rectangle (max 6 x 6 cells = 1920 studs).
	local streets = B:group(folder, "Streets")
	for _, r in grid:mergedRects(function(c)
		return c.def.land and c.def.streets
	end, 6) do
		local x0, z0 = grid:node(r[1], r[2])
		slab(B, streets, "Asphalt", x0, z0, x0 + r[3] * cell, z0 + r[4] * cell, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
	end

	-- 2. Land without its own streets (airport, beach): surface slab plus asphalt margins
	--    where a neighbouring street reaches in.
	local open = B:group(folder, "OpenGround")
	grid:forEachCell(function(c)
		if not (c.def.land and not c.def.streets) then
			return
		end
		local look = GROUND_MATERIAL[c.def.ground or "Grass"]
		local x0, z0, x1, z1 = grid:blockRect(c)
		slab(B, open, c.def.ground or "Ground", x0, z0, x1, z1, 0.15, depth + 0.15, look[1], look[2])
		local north, south = grid:hStreet(c.i, c.j), grid:hStreet(c.i, c.j + 1)
		if north then
			slab(B, streets, "Asphalt", c.x0, c.z0, c.x1, c.z0 + hw, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
		end
		if south then
			slab(B, streets, "Asphalt", c.x0, c.z1 - hw, c.x1, c.z1, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
		end
		local zs = if north then c.z0 + hw else c.z0
		local ze = if south then c.z1 - hw else c.z1
		if grid:vStreet(c.i, c.j) then
			slab(B, streets, "Asphalt", c.x0, zs, c.x0 + hw, ze, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
		end
		if grid:vStreet(c.i + 1, c.j) then
			slab(B, streets, "Asphalt", c.x1 - hw, zs, c.x1, ze, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
		end
		-- low sea wall where the open ground meets the water
		for side, s in SIDES do
			if isWater(grid, c.i + s.di, c.j + s.dj) and c.def.ground ~= "Sand" then
				local horizontalSide = side == "N" or side == "S"
				local edgeZ = if side == "N" then c.z0 elseif side == "S" then c.z1 else c.cz
				local edgeX = if side == "W" then c.x0 elseif side == "E" then c.x1 else c.cx
				local size = if horizontalSide then Vector3.new(cell, depth + 0.6, 1.2) else Vector3.new(1.2, depth + 0.6, cell)
				local out = Vector3.new(s.di, 0, s.dj) * 0.65
				B:box(open, "SeaWall", Vector3.new(edgeX, 0.45 - (depth + 0.6) / 2, edgeZ) + out, size, Palette.Concrete, Enum.Material.Concrete)
			end
		end
		-- beaches slope down into the water
		if c.def.ground == "Sand" then
			for _, s in SIDES do
				if isWater(grid, c.i + s.di, c.j + s.dj) then
					local out = Vector3.new(s.di, 0, s.dj)
					local run = 44
					local top, bottom = 0.15, config.WaterLevel - 4
					local edge = Vector3.new(c.cx, 0, c.cz) + out * (cell / 2)
					local center = edge + out * (run / 2) + Vector3.new(0, (top + bottom) / 2, 0)
					B:part({
						parent = open,
						name = "Shore",
						class = "WedgePart",
						size = Vector3.new(cell, top - bottom, run),
						cf = lookAt(center, center + out),
						color = Palette.Sand,
						mat = Enum.Material.Sand,
					})
				end
			end
		end
	end)

	-- 3. Coast roads: the half of a street that hangs over a water cell, with a sea barrier
	--    that doubles as the quay wall.
	local coast = B:group(folder, "Coast")
	local function barrier(x0, z0, x1, z1)
		if x1 - x0 < 0.5 and z1 - z0 < 0.5 then
			return
		end
		slab(B, coast, "SeaBarrier", x0, z0, x1, z1, bh, depth + bh, Palette.Barrier, Enum.Material.Concrete)
	end
	for j = -1, grid.nz do
		for i = -1, grid.nx do
			if isWater(grid, i, j) then
				local x0, z0 = grid:node(i, j)
				local x1, z1 = x0 + cell, z0 + cell
				local n, s = hasStrip(grid, i, j, "N"), hasStrip(grid, i, j, "S")
				local w, e = hasStrip(grid, i, j, "W"), hasStrip(grid, i, j, "E")
				-- strips (north/south span the full width, west/east fit between them)
				if n then
					slab(B, coast, "Asphalt", x0, z0, x1, z0 + hw, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
				end
				if s then
					slab(B, coast, "Asphalt", x0, z1 - hw, x1, z1, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
				end
				local zs = if n then z0 + hw else z0
				local ze = if s then z1 - hw else z1
				if w then
					slab(B, coast, "Asphalt", x0, zs, x0 + hw, ze, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
				end
				if e then
					slab(B, coast, "Asphalt", x1 - hw, zs, x1, ze, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
				end
				-- barriers: pull back where the neighbouring water cell carries a crossing strip
				local pad = 0.05
				if n then
					local a = if grid:isStreeted(i - 1, j) then x0 + hw else x0
					local b = if grid:isStreeted(i + 1, j) then x1 - hw else x1
					barrier(a, z0 + hw - bw + pad, b, z0 + hw + pad)
				end
				if s then
					local a = if grid:isStreeted(i - 1, j) then x0 + hw else x0
					local b = if grid:isStreeted(i + 1, j) then x1 - hw else x1
					barrier(a, z1 - hw - pad, b, z1 - hw + bw - pad)
				end
				if w then
					local a = if grid:isStreeted(i, j - 1) then z0 + hw else z0
					local b = if grid:isStreeted(i, j + 1) then z1 - hw else z1
					barrier(x0 + hw - bw + pad, a, x0 + hw + pad, b)
				end
				if e then
					local a = if grid:isStreeted(i, j - 1) then z0 + hw else z0
					local b = if grid:isStreeted(i, j + 1) then z1 - hw else z1
					barrier(x1 - hw - pad, a, x1 - hw + bw - pad, b)
				end
			end
		end
	end

	-- 4. Corner patches: fill the outside corner of an intersection that sits over water.
	for j = 0, grid.nz do
		for i = 0, grid.nx do
			local arms = grid:arms(i, j)
			if arms.N or arms.S or arms.E or arms.W then
				local nx, nz = grid:node(i, j)
				-- quadrant cells around the node and the two sides of that cell touching the node
				local quadrants = {
					{ i - 1, j - 1, "S", "E", -1, -1 },
					{ i, j - 1, "S", "W", 1, -1 },
					{ i - 1, j, "N", "E", -1, 1 },
					{ i, j, "N", "W", 1, 1 },
				}
				for _, q in quadrants do
					local qi, qj, sideA, sideB, sx, sz = q[1], q[2], q[3], q[4], q[5], q[6]
					if isWater(grid, qi, qj) and not hasStrip(grid, qi, qj, sideA) and not hasStrip(grid, qi, qj, sideB) then
						local ax, bx = math.min(nx, nx + sx * hw), math.max(nx, nx + sx * hw)
						local az, bz = math.min(nz, nz + sz * hw), math.max(nz, nz + sz * hw)
						slab(B, coast, "Asphalt", ax, az, bx, bz, 0, depth, Palette.Asphalt, Enum.Material.Asphalt)
						-- barriers on the two sides that face open water; outer faces sit just
						-- past the slab so they never share a plane with it
						local farX, farZ = nx + sx * hw, nz + sz * hw
						local x0b, x1b = math.min(farX + sx * 0.05, farX - sx * (bw - 0.05)), math.max(farX + sx * 0.05, farX - sx * (bw - 0.05))
						barrier(x0b, az, x1b, bz)
						local z0b, z1b = math.min(farZ + sz * 0.05, farZ - sz * (bw - 0.05)), math.max(farZ + sz * 0.05, farZ - sz * (bw - 0.05))
						local xa = if sx > 0 then ax else ax + bw - 0.05
						local xb = if sx > 0 then bx - bw + 0.05 else bx
						barrier(xa, z0b, xb, z1b)
					end
				end
			end
		end
	end

	-- 5. Sidewalks around every street block.
	local walks = B:group(folder, "Sidewalks")
	grid:forEachCell(function(c)
		if c.def.land and c.def.streets and not c.def.noCurb then
			local x0, z0, x1, z1 = grid:blockRect(c)
			slab(B, walks, "Sidewalk", x0, z0, x1, z1, config.CurbHeight, config.CurbHeight + 0.5, Palette.Sidewalk, Enum.Material.Pavement)
		end
	end)

	-- 6. Water: the bay around the island (tagged, can be swapped for Terrain water with
	--    NeonBay.useTerrainWater) and the open ocean beyond it. Tiles stay under 2048 studs.
	local waterFolder = B:group(folder, "Water")
	local function tiles(x0, z0, x1, z1, tag)
		local tile = 2000
		local x = x0
		while x < x1 - 0.5 do
			local xe = math.min(x1, x + tile)
			local z = z0
			while z < z1 - 0.5 do
				local ze = math.min(z1, z + tile)
				local waterPart = B:block(
					waterFolder,
					"Water",
					(x + xe) / 2,
					config.WaterLevel - 1,
					(z + ze) / 2,
					xe - x,
					1,
					ze - z,
					Palette.Water,
					Enum.Material.SmoothPlastic,
					{ reflectance = 0.3, transparency = 0.12, collide = false, shadow = false, query = false }
				)
				waterPart:AddTag(tag)
				B:block(waterFolder, "Seabed", (x + xe) / 2, -60, (z + ze) / 2, xe - x, 2, ze - z, Palette.Seabed, Enum.Material.Sand, {
					shadow = false,
				})
				z = ze
			end
			x = xe
		end
	end
	local near = 2 * cell -- same area that useTerrainWater fills
	local ix0, iz0 = grid.x0 - near, grid.z0 - near
	local ix1, iz1 = grid.x0 + grid.nx * cell + near, grid.z0 + grid.nz * cell + near
	local m = config.OceanMargin
	tiles(ix0, iz0, ix1, iz1, "NeonBayWater")
	tiles(ix0 - m, iz0 - m, ix1 + m, iz0, "NeonBayOcean")
	tiles(ix0 - m, iz1, ix1 + m, iz1 + m, "NeonBayOcean")
	tiles(ix0 - m, iz0, ix0, iz1, "NeonBayOcean")
	tiles(ix1, iz0, ix1 + m, iz1, "NeonBayOcean")
	return folder
end

return Ground
