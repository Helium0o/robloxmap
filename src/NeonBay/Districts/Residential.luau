--[[
	Residential blocks: gabled houses with front yards and lit windows, or a pair of
	apartment buildings. Trees fill the back gardens.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local Frontage = require(script.Parent.Frontage)

local Residential = {}

local GLOW = { collide = false, shadow = false, query = false }

local function house(ctx, parent, rng, fx0, fz0, fx1, fz1, y0, facing)
	local B = ctx.B
	local front, width, depth = Frontage.facade(fx0, fz0, fx1, fz1, facing, y0)
	-- `front` sits on the facade; move to the middle of the house
	local base = front * CFrame.new(0, 0, depth / 2)
	local h = rng:range(12, 18)
	local color = rng:pick(Palette.House)
	local model = Instance.new("Model")
	model.Name = "House"
	model.Parent = parent
	B:part({
		parent = model,
		name = "Body",
		size = Vector3.new(width, h, depth),
		cf = base * CFrame.new(0, h / 2, 0),
		color = color,
		mat = rng:pick({ Enum.Material.Plaster, Enum.Material.WoodPlanks, Enum.Material.Brick, Enum.Material.SmoothPlastic }),
	})
	local roofColor = rng:pick(Palette.Roof)
	if rng:chance(0.75) then
		local roofH = rng:range(6, 9)
		local half = depth / 2 + 1
		for _, sideSign in { -1, 1 } do
			B:part({
				parent = model,
				name = "Roof",
				class = "WedgePart",
				size = Vector3.new(width + 2, roofH, half),
				cf = base * CFrame.new(0, h + roofH / 2, sideSign * half / 2) * CFrame.Angles(0, if sideSign > 0 then math.pi else 0, 0),
				color = roofColor,
				mat = Enum.Material.RoofShingles,
			})
		end
	else
		B:part({
			parent = model,
			name = "RoofTrim",
			size = Vector3.new(width + 1, 1.2, depth + 1),
			cf = base * CFrame.new(0, h + 0.6, 0),
			color = roofColor,
			mat = Enum.Material.Concrete,
		})
	end
	local doorX = rng:range(-width / 4, width / 4)
	B:part({
		parent = model,
		name = "Door",
		size = Vector3.new(4, 7.5, 0.4),
		cf = front * CFrame.new(doorX, 3.75, -0.2),
		color = Color3.fromRGB(60, 40, 30),
		mat = Enum.Material.Wood,
		collide = false,
	})
	-- porch light and a lit window or two
	B:part({
		parent = model,
		name = "PorchLight",
		size = Vector3.new(0.8, 0.8, 0.4),
		cf = front * CFrame.new(doorX + 3.4, 8.2, -0.3),
		color = Palette.WarmWindow,
		mat = Enum.Material.Neon,
		collide = false,
		shadow = false,
		query = false,
	})
	for _ = 1, rng:int(0, 2) do
		local wx = rng:range(-width / 2 + 4, width / 2 - 4)
		if math.abs(wx - doorX) > 5 then
			B:part({
				parent = model,
				name = "Window",
				size = Vector3.new(4.5, 3.5, 0.3),
				cf = front * CFrame.new(wx, h * 0.6, -0.15),
				color = if rng:chance(0.8) then Palette.WarmWindow else Palette.CoolWindow,
				mat = Enum.Material.Neon,
				transparency = 0.25,
				collide = false,
				shadow = false,
				query = false,
			})
		end
	end
	return model
end

local function apartments(ctx, parent, c, rng, x0, z0, x1, z1, y0)
	local B = ctx.B
	local vertical = rng:chance(0.5)
	local halves = if vertical
		then { { x0 + 14, z0 + 14, (x0 + x1) / 2 - 10, z1 - 14 }, { (x0 + x1) / 2 + 10, z0 + 14, x1 - 14, z1 - 14 } }
		else { { x0 + 14, z0 + 14, x1 - 14, (z0 + z1) / 2 - 10 }, { x0 + 14, (z0 + z1) / 2 + 10, x1 - 14, z1 - 14 } }
	for _, r in halves do
		local w, d = r[3] - r[1], r[4] - r[2]
		-- slimmer slab inside each half
		local fx0, fz0, fx1, fz1 = r[1], r[2], r[3], r[4]
		if vertical then
			fz0 += d * 0.15
			fz1 -= d * 0.15
		else
			fx0 += w * 0.15
			fx1 -= w * 0.15
		end
		if not ctx:blocked(c, fx0, fz0, fx1, fz1) then
			local h = rng:range(34, 72)
			local cx, cz = (fx0 + fx1) / 2, (fz0 + fz1) / 2
			local model = Instance.new("Model")
			model.Name = "Apartments"
			model.Parent = parent
			local color = rng:pick(Palette.House)
			B:block(model, "Body", cx, y0, cz, fx1 - fx0, h, fz1 - fz0, color, Enum.Material.Concrete)
			B:block(model, "RoofTrim", cx, y0 + h, cz, fx1 - fx0 + 1, 1.4, fz1 - fz0 + 1, Palette.ConcreteDark, Enum.Material.Concrete)
			local lit = if rng:chance(0.7) then Palette.WarmWindow else Palette.CoolWindow
			local y = y0 + 9
			while y < y0 + h - 4 do
				if rng:chance(0.6) then
					B:block(model, "LitFloor", cx, y, cz, fx1 - fx0 + 0.4, 1.4, fz1 - fz0 + 0.4, lit, Enum.Material.Neon, {
						transparency = 0.6,
						collide = false,
						shadow = false,
						query = false,
					})
				end
				y += 11
			end
		end
	end
	for _ = 1, rng:int(3, 6) do
		local tx, tz = rng:range(x0 + 8, x1 - 8), rng:range(z0 + 8, z1 - 8)
		local nearX = math.abs(tx - (x0 + x1) / 2) < 12
		local nearZ = math.abs(tz - (z0 + z1) / 2) < 12
		if ((vertical and nearX) or (not vertical and nearZ)) and not ctx:blocked(c, tx - 8, tz - 8, tx + 8, tz + 8) then
			Props.tree(B, parent, rng, tx, y0, tz)
		end
	end
end

function Residential.build(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	B:block(parent, "Lawn", (x0 + x1) / 2, y0, (z0 + z1) / 2, x1 - x0, 0.2, z1 - z0, Palette.Grass, Enum.Material.Grass, GLOW)
	y0 += 0.2
	if rng:chance(0.3) then
		apartments(ctx, parent, c, rng, x0, z0, x1, z1, y0)
		return
	end
	local cx0, cz0, cx1, cz1 = Frontage.layout(rng, x0, z0, x1, z1, {
		depth = { 30, 40 },
		width = { 32, 48 },
		gap = { 10, 18 },
		setback = 10,
	}, function(fx0, fz0, fx1, fz1, facing)
		if not ctx:blocked(c, fx0, fz0, fx1, fz1) then
			house(ctx, parent, rng, fx0, fz0, fx1, fz1, y0, facing)
		end
	end)
	-- back gardens
	for _ = 1, rng:int(3, 7) do
		local tx, tz = rng:range(cx0 + 8, cx1 - 8), rng:range(cz0 + 8, cz1 - 8)
		if not ctx:blocked(c, tx - 8, tz - 8, tx + 8, tz + 8) then
			Props.tree(B, parent, rng, tx, y0, tz)
		end
	end
end

return Residential
