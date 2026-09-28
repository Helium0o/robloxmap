--[[
	Beaches: palms, umbrellas, lifeguard towers and the odd bonfire for night parties.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)

local Beach = {}

local DECOR = { collide = false, shadow = false }
local GLOW = { collide = false, shadow = false, query = false }

local SIDES = {
	{ di = 0, dj = -1 },
	{ di = 0, dj = 1 },
	{ di = -1, dj = 0 },
	{ di = 1, dj = 0 },
}

local function lifeguardTower(B, parent, x, y0, z, facing: Vector3)
	local model = Instance.new("Model")
	model.Name = "LifeguardTower"
	model.Parent = parent
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			B:block(model, "Leg", x + a * 4, y0, z + b * 4, 0.8, 10, 0.8, Color3.fromRGB(240, 240, 235), Enum.Material.Wood)
		end
	end
	B:block(model, "Cabin", x, y0 + 10, z, 10, 7, 10, Color3.fromRGB(230, 70, 60), Enum.Material.WoodPlanks)
	B:block(model, "Roof", x, y0 + 17, z, 12, 0.8, 12, Color3.fromRGB(240, 240, 235), Enum.Material.WoodPlanks)
	local lamp = B:box(model, "Lamp", Vector3.new(x, y0 + 14, z) + facing * 5.2, Vector3.new(1.2, 1.2, 1.2), Palette.WarmWindow, Enum.Material.Neon, GLOW)
	B:pointLight(lamp, Palette.SodiumLight, 30, 1.2)
end

local function bonfire(B, parent, x, y0, z)
	for k = 0, 2 do
		local a = k * math.pi / 3
		local d = Vector3.new(math.cos(a), 0, math.sin(a)) * 3
		local p = Vector3.new(x, y0 + 0.5, z)
		B:beam(parent, "Log", p - d, p + d, 0.8, 0.8, Color3.fromRGB(70, 45, 30), Enum.Material.Wood, DECOR)
	end
	local fire = B:ball(parent, "Fire", Vector3.new(x, y0 + 1.6, z), 2.6, Color3.fromRGB(255, 120, 30), Enum.Material.Neon, GLOW)
	B:pointLight(fire, Color3.fromRGB(255, 140, 60), 32, 2)
end

function Beach.build(ctx, parent, c, rng)
	local B = ctx.B
	local grid = ctx.grid
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	local toWater = nil
	for _, s in SIDES do
		if not grid:isLand(c.i + s.di, c.j + s.dj) then
			toWater = Vector3.new(s.di, 0, s.dj)
			break
		end
	end
	for _ = 1, rng:int(4, 7) do
		local px, pz = rng:range(x0 + 12, x1 - 12), rng:range(z0 + 12, z1 - 12)
		Props.palm(B, parent, rng, px, y0, pz)
	end
	if toWater then
		local center = Vector3.new((x0 + x1) / 2, y0, (z0 + z1) / 2)
		local side = Vector3.new(-toWater.Z, 0, toWater.X)
		local reach = math.abs(toWater.X) * (x1 - x0) / 2 + math.abs(toWater.Z) * (z1 - z0) / 2
		for _ = 1, rng:int(3, 5) do
			local p = center + toWater * rng:range(reach * 0.3, reach * 0.8) + side * rng:range(-110, 110)
			Props.umbrella(B, parent, rng, p.X, y0, p.Z)
		end
		if rng:chance(0.5) then
			local p = center + toWater * (reach * 0.5) + side * rng:range(-60, 60)
			lifeguardTower(B, parent, p.X, y0, p.Z, toWater)
		end
		if rng:chance(0.5) then
			local p = center + toWater * (reach * 0.2) + side * rng:range(-80, 80)
			bonfire(B, parent, p.X, y0, p.Z)
		end
	end
end

return Beach
