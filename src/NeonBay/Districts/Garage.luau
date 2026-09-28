--[[
	Garage hub: the player's base. A workshop with four lit bays (performance, paint,
	body kits, car lot), a big rooftop sign, a showroom forecourt and the spawn point.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local lookAt = require(script.Parent.Parent.Geometry).lookAt

local Garage = {}

local GLOW = { collide = false, shadow = false, query = false }

local BAYS = { "PERFORMANCE", "PAINT SHOP", "BODY KITS", "CAR LOT" }

function Garage.build(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	local cx = (x0 + x1) / 2
	B:block(parent, "Forecourt", cx, y0, (z0 + z1) / 2, x1 - x0, 0.1, z1 - z0, Color3.fromRGB(44, 44, 52), Enum.Material.Concrete, GLOW)
	y0 += 0.1

	-- workshop along the south edge, facing north into the forecourt
	local depth, height = 64, 30
	local bz1 = z1 - 8
	local bz0 = bz1 - depth
	local bx0, bx1 = x0 + 12, x1 - 12
	local width = bx1 - bx0
	local model = Instance.new("Model")
	model.Name = "Workshop"
	model.Parent = parent
	B:block(model, "Body", cx, y0, (bz0 + bz1) / 2, width, height, depth, Color3.fromRGB(34, 34, 42), Enum.Material.Metal)
	B:block(model, "Roof", cx, y0 + height, (bz0 + bz1) / 2, width + 2, 1.4, depth + 2, Palette.MetalDark, Enum.Material.Metal)
	local facing = Vector3.new(0, 0, -1)
	local front = Vector3.new(cx, y0, bz0)
	local frame = lookAt(front, front + facing)
	local bayW = width / #BAYS
	for k, label in BAYS do
		local x = -width / 2 + (k - 0.5) * bayW
		local neon = Palette.Neon[(k % #Palette.Neon) + 1]
		B:part({
			parent = model,
			name = "BayDoor",
			size = Vector3.new(bayW - 12, 18, 0.4),
			cf = frame * CFrame.new(x, 9, -0.2),
			color = Color3.fromRGB(18, 20, 26),
			mat = Enum.Material.Glass,
			reflectance = 0.25,
		})
		B:part({
			parent = model,
			name = "BayLight",
			size = Vector3.new(bayW - 14, 16, 0.2),
			cf = frame * CFrame.new(x, 8.6, -0.05),
			color = Palette.CoolWindow,
			mat = Enum.Material.Neon,
			transparency = 0.6,
			collide = false,
			shadow = false,
			query = false,
		})
		-- neon frame around each bay
		for _, bar in {
			{ 0, 18.6, bayW - 10, 0.8 },
			{ -(bayW - 11) / 2, 9, 0.8, 18.4 },
			{ (bayW - 11) / 2, 9, 0.8, 18.4 },
		} do
			B:part({
				parent = model,
				name = "BayFrame",
				size = Vector3.new(bar[3], bar[4], 0.6),
				cf = frame * CFrame.new(x + bar[1], bar[2], -0.4),
				color = neon,
				mat = Enum.Material.Neon,
				collide = false,
				shadow = false,
				query = false,
			})
		end
		Props.shopSign(B, model, rng, frame * CFrame.new(x, 22.5, -0.4), bayW - 14, label)
	end
	-- rooftop sign
	local signBase = Vector3.new(cx, y0 + height + 0.7, bz0 + 6)
	Props.billboard(B, model, rng, lookAt(signBase, signBase + facing), math.min(width * 0.45, 84), "NEON BAY GARAGE", 8)

	-- showroom cars on the forecourt
	local rowZ = bz0 - 30
	for k = 0, 5 do
		local px = bx0 + 24 + k * ((width - 48) / 5)
		Props.car(B, parent, rng, CFrame.new(px, y0, rowZ) * CFrame.Angles(0, math.pi, 0))
	end

	-- spawn point in the forecourt, facing the street
	if ctx.withSpawn then
		local spawnPos = Vector3.new(cx, y0, (z0 + rowZ) / 2)
		local spawn = B:part({
			parent = parent,
			name = "SpawnLocation",
			class = "SpawnLocation",
			size = Vector3.new(16, 1, 16),
			cf = lookAt(spawnPos + Vector3.new(0, 0.5, 0), spawnPos + Vector3.new(0, 0.5, -1)),
			color = Palette.Neon[2],
			mat = Enum.Material.Neon,
			transparency = 0.2,
		})
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.AllowTeamChangeOnTouch = false
		ctx.spawn = spawn
	end
end

return Garage
