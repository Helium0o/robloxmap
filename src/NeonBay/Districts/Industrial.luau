--[[
	Industrial port: warehouses with loading doors, stacked shipping containers, gantry
	cranes on the quay, storage tanks and smokestacks with warning lights.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local lookAt = require(script.Parent.Parent.Geometry).lookAt

local Industrial = {}

local DECOR = { collide = false, shadow = false }
local GLOW = { collide = false, shadow = false, query = false }

local SIDES = {
	{ di = 0, dj = -1, dir = Vector3.new(0, 0, -1) },
	{ di = 0, dj = 1, dir = Vector3.new(0, 0, 1) },
	{ di = -1, dj = 0, dir = Vector3.new(-1, 0, 0) },
	{ di = 1, dj = 0, dir = Vector3.new(1, 0, 0) },
}

local function warehouse(B, parent, rng, x0, z0, x1, z1, y0, facing: Vector3)
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local h = rng:range(24, 40)
	local model = Instance.new("Model")
	model.Name = "Warehouse"
	model.Parent = parent
	B:block(model, "Body", cx, y0, cz, w, h, d, rng:pick(Palette.Warehouse), rng:pick({ Enum.Material.CorrodedMetal, Enum.Material.Metal, Enum.Material.DiamondPlate }))
	B:block(model, "Roof", cx, y0 + h, cz, w + 1.5, 1.2, d + 1.5, Palette.MetalDark, Enum.Material.Metal)
	-- loading doors with a sodium light above each
	local alongX = math.abs(facing.Z) > 0
	local frontLen = if alongX then w else d
	local depth = if alongX then d else w
	local front = Vector3.new(cx, y0, cz) + facing * (depth / 2)
	local frame = lookAt(front, front + facing)
	local doors = math.max(1, math.floor(frontLen / 36))
	for k = 1, doors do
		local x = -frontLen / 2 + (k - 0.5) * frontLen / doors
		B:part({
			parent = model,
			name = "LoadingDoor",
			size = Vector3.new(14, 16, 0.4),
			cf = frame * CFrame.new(x, 8, -0.2),
			color = Color3.fromRGB(70, 74, 80),
			mat = Enum.Material.DiamondPlate,
		})
		local lamp = B:part({
			parent = model,
			name = "DockLight",
			size = Vector3.new(2, 0.6, 1.4),
			cf = frame * CFrame.new(x, 18, -0.7),
			color = Palette.Sodium,
			mat = Enum.Material.Neon,
			collide = false,
			shadow = false,
			query = false,
		})
		if k == 1 then
			B:spotLight(lamp, Enum.NormalId.Bottom, Palette.SodiumLight, 40, 1.6, 110)
		end
	end
	-- roof vents
	for _ = 1, rng:int(2, 4) do
		B:column(model, "Vent", cx + rng:range(-w / 3, w / 3), y0 + h + 1.2, cz + rng:range(-d / 3, d / 3), 4, 4, Palette.Metal, Enum.Material.Metal, DECOR)
	end
end

local function containerYard(B, parent, rng, x0, z0, x1, z1, y0)
	local alongX = (x1 - x0) >= (z1 - z0)
	local len = 43
	local rowW = 9.4
	local aisle = 18
	local cols = if alongX then math.floor((x1 - x0) / (len + 4)) else math.floor((z1 - z0) / (len + 4))
	local rowsSpan = if alongX then z1 - z0 else x1 - x0
	local k = 0
	local offset = 0
	while offset + rowW <= rowsSpan do
		for col = 0, cols - 1 do
			if rng:chance(0.7) then
				local stack = rng:int(1, 3)
				local a = col * (len + 4) + len / 2
				local b = offset + rowW / 2
				local px = if alongX then x0 + a else x0 + b
				local pz = if alongX then z0 + b else z0 + a
				for level = 0, stack - 1 do
					local cf = CFrame.new(px, y0 + level * 9.25, pz) * CFrame.Angles(0, if alongX then math.pi / 2 else 0, 0)
					Props.container(B, parent, rng, cf, true)
				end
			end
		end
		k += 1
		offset += rowW
		if k % 3 == 0 then
			offset += aisle
		end
	end
end

local function crane(B, parent, rng, base: Vector3, toWater: Vector3)
	-- base: middle of the crane's footprint on the lot; toWater: unit vector to the quay
	local model = Instance.new("Model")
	model.Name = "Crane"
	model.Parent = parent
	local side = Vector3.new(-toWater.Z, 0, toWater.X)
	local color = rng:pick({ Color3.fromRGB(200, 60, 40), Color3.fromRGB(230, 170, 30), Color3.fromRGB(40, 110, 170) })
	local legH = 60
	local span = 26
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			local p = base + toWater * (a * span / 2) + side * (b * span / 2)
			B:block(model, "CraneLeg", p.X, base.Y, p.Z, 2.4, legH, 2.4, color, Enum.Material.Metal)
		end
	end
	for _, b in { -1, 1 } do
		local p = base + side * (b * span / 2) + Vector3.new(0, legH, 0)
		B:beam(model, "CraneBeam", p - toWater * (span / 2 + 1), p + toWater * (span / 2 + 1), 2.4, 3, color, Enum.Material.Metal)
	end
	-- boom reaching over the road and the water, counterweight behind
	local boomY = legH + 4
	local root = base + Vector3.new(0, boomY, 0)
	B:beam(model, "Boom", root - toWater * 40, root + toWater * 120, 5, 4, color, Enum.Material.Metal)
	B:box(model, "MachineHouse", root - toWater * 24 + Vector3.new(0, 5, 0), Vector3.new(14, 8, 14), Palette.MetalDark, Enum.Material.Metal)
	local trolley = root + toWater * 70 - Vector3.new(0, 3, 0)
	B:box(model, "Trolley", trolley, Vector3.new(6, 3, 6), Palette.MetalDark, Enum.Material.Metal, DECOR)
	B:box(model, "Hoist", trolley - Vector3.new(0, 20, 0), Vector3.new(0.4, 36, 0.4), Palette.MetalDark, Enum.Material.Metal, DECOR)
	for _, s in { -1, 1 } do
		local beacon = B:box(model, "AviationLight", root + toWater * (s > 0 and 119 or -39) + Vector3.new(0, 3, 0), Vector3.new(1.6, 1.6, 1.6), Palette.AviationRed, Enum.Material.Neon, GLOW)
		beacon:AddTag("NeonBayBlink")
	end
end

local function smokestack(B, parent, x, y0, z, h)
	B:column(parent, "Smokestack", x, y0, z, h, 12, Color3.fromRGB(150, 146, 140), Enum.Material.Concrete)
	for _, t in { 0.55, 0.8 } do
		B:column(parent, "StackStripe", x, y0 + h * t, z, 5, 12.4, Color3.fromRGB(190, 40, 40), Enum.Material.SmoothPlastic, DECOR)
	end
	local beacon = B:box(parent, "AviationLight", Vector3.new(x, y0 + h + 1, z), Vector3.new(2, 2, 2), Palette.AviationRed, Enum.Material.Neon, GLOW)
	beacon:AddTag("NeonBayBlink")
end

function Industrial.build(ctx, parent, c, rng)
	local B = ctx.B
	local grid = ctx.grid
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	B:block(parent, "Yard", (x0 + x1) / 2, y0, (z0 + z1) / 2, x1 - x0, 0.1, z1 - z0, Color3.fromRGB(70, 70, 76), Enum.Material.Concrete, GLOW)
	y0 += 0.1

	-- which side faces the water (for the crane)?
	local waterSide = nil
	for _, s in SIDES do
		if not grid:isLand(c.i + s.di, c.j + s.dj) then
			waterSide = s
			break
		end
	end

	-- warehouse strip along one side, yard in the rest
	local side = if waterSide then waterSide else rng:pick(SIDES)
	-- warehouses sit away from the water so cranes get the quay
	local whSide = if waterSide then SIDES[({ 2, 1, 4, 3 })[table.find(SIDES, waterSide) :: number]] else side
	local depth = rng:range(70, 100)
	local wx0, wz0, wx1, wz1 = x0, z0, x1, z1
	local yx0, yz0, yx1, yz1 = x0, z0, x1, z1
	if whSide.dj < 0 then
		wz1 = z0 + depth
		yz0 = wz1 + 16
	elseif whSide.dj > 0 then
		wz0 = z1 - depth
		yz1 = wz0 - 16
	elseif whSide.di < 0 then
		wx1 = x0 + depth
		yx0 = wx1 + 16
	else
		wx0 = x1 - depth
		yx1 = wx0 - 16
	end
	local facing = -whSide.dir -- loading doors face the yard
	if rng:chance(0.5) then
		-- two smaller warehouses
		if whSide.dj ~= 0 then
			local xm = (wx0 + wx1) / 2
			if not ctx:blocked(c, wx0, wz0, xm - 6, wz1) then
				warehouse(B, parent, rng, wx0, wz0, xm - 6, wz1, y0, facing)
			end
			if not ctx:blocked(c, xm + 6, wz0, wx1, wz1) then
				warehouse(B, parent, rng, xm + 6, wz0, wx1, wz1, y0, facing)
			end
		else
			local zm = (wz0 + wz1) / 2
			if not ctx:blocked(c, wx0, wz0, wx1, zm - 6) then
				warehouse(B, parent, rng, wx0, wz0, wx1, zm - 6, y0, facing)
			end
			if not ctx:blocked(c, wx0, zm + 6, wx1, wz1) then
				warehouse(B, parent, rng, wx0, zm + 6, wx1, wz1, y0, facing)
			end
		end
	elseif not ctx:blocked(c, wx0, wz0, wx1, wz1) then
		warehouse(B, parent, rng, wx0, wz0, wx1, wz1, y0, facing)
	end

	-- keep the strip next to the quay free for the cranes
	if waterSide then
		local craneZone = 44
		if waterSide.dj < 0 then
			yz0 += craneZone
		elseif waterSide.dj > 0 then
			yz1 -= craneZone
		elseif waterSide.di < 0 then
			yx0 += craneZone
		else
			yx1 -= craneZone
		end
	end
	local yardBlocked = ctx:blocked(c, yx0, yz0, yx1, yz1)
	local roll = rng:next()
	if waterSide then
		-- quay: containers plus a crane close to the water
		if not yardBlocked then
			containerYard(B, parent, rng, yx0 + 6, yz0 + 6, yx1 - 6, yz1 - 6, y0)
		end
		local toWater = waterSide.dir
		local edgeInset = 20
		local center = Vector3.new((x0 + x1) / 2, y0, (z0 + z1) / 2)
		local half = (x1 - x0) / 2
		local base = center + toWater * (half - edgeInset)
		local sideways = Vector3.new(-toWater.Z, 0, toWater.X)
		for _, s in { -0.5, 0.5 } do
			local p = base + sideways * (s * (x1 - x0) * 0.6)
			if not ctx:blocked(c, p.X - 16, p.Z - 16, p.X + 16, p.Z + 16) then
				crane(B, parent, rng, p, toWater)
			end
		end
	elseif roll < 0.55 and not yardBlocked then
		containerYard(B, parent, rng, yx0 + 6, yz0 + 6, yx1 - 6, yz1 - 6, y0)
	elseif not yardBlocked then
		-- tank farm and a smokestack
		local cx, cz = (yx0 + yx1) / 2, (yz0 + yz1) / 2
		for k = 0, 2 do
			local tx = cx + (k - 1) * 40
			B:column(parent, "Tank", tx, y0, cz, rng:range(18, 30), 32, Color3.fromRGB(205, 205, 200), Enum.Material.Metal)
		end
		if rng:chance(0.7) then
			smokestack(B, parent, cx + 60, y0, cz + rng:range(-20, 20), rng:range(80, 140))
		end
	end
end

return Industrial
