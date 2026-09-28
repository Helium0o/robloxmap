--[[
	Commercial blocks: rows of shops and mid-rise buildings with neon signs, lit storefronts,
	awnings, vertical signs and rooftop billboards. A small parking lot fills the middle.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local Frontage = require(script.Parent.Frontage)
local lookAt = require(script.Parent.Parent.Geometry).lookAt

local Commercial = {}

local DECOR = { collide = false, shadow = false }
local GLOW = { collide = false, shadow = false, query = false }

local function darker(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

function Commercial.shop(ctx, parent, rng, fx0, fz0, fx1, fz1, y0, facing, height)
	local B = ctx.B
	local w, d = fx1 - fx0, fz1 - fz0
	local cx, cz = (fx0 + fx1) / 2, (fz0 + fz1) / 2
	local color = rng:pick(Palette.Facade)
	local mat = rng:pick({
		Enum.Material.Brick,
		Enum.Material.Concrete,
		Enum.Material.Plaster,
		Enum.Material.SmoothPlastic,
		Enum.Material.Sandstone,
	})
	local model = Instance.new("Model")
	model.Name = "Shop"
	model.Parent = parent
	B:block(model, "Body", cx, y0, cz, w, height, d, color, mat)
	B:block(model, "Cornice", cx, y0 + height, cz, w + 1.2, 1.4, d + 1.2, darker(color, 0.6), Enum.Material.Concrete, DECOR)

	local front, frontW = Frontage.facade(fx0, fz0, fx1, fz1, facing, y0)
	local neon = rng:pick(Palette.Neon)
	B:part({
		parent = model,
		name = "Storefront",
		size = Vector3.new(frontW - 4, 9, 0.6),
		cf = front * CFrame.new(0, 5.5, -0.3),
		color = Color3.fromRGB(30, 44, 64),
		mat = Enum.Material.Glass,
		reflectance = 0.2,
	})
	-- warm light spilling out of the shop
	B:part({
		parent = model,
		name = "ShopLight",
		size = Vector3.new(frontW - 5, 7.6, 0.2),
		cf = front * CFrame.new(0, 5.2, -0.05),
		color = Palette.WarmWindow,
		mat = Enum.Material.Neon,
		transparency = 0.7,
		collide = false,
		shadow = false,
		query = false,
	})
	B:part({
		parent = model,
		name = "NeonTrim",
		size = Vector3.new(frontW - 3, 0.5, 0.5),
		cf = front * CFrame.new(0, 10.6, -0.35),
		color = neon,
		mat = Enum.Material.Neon,
		collide = false,
		shadow = false,
		query = false,
	})
	if height > 17 then
		Props.shopSign(B, model, rng, front * CFrame.new(0, 14, -0.35), math.min(frontW - 6, 30))
	end
	if rng:chance(0.35) then
		B:part({
			parent = model,
			name = "Awning",
			size = Vector3.new(frontW - 5, 0.4, 6),
			cf = front * CFrame.new(0, 10, -3) * CFrame.Angles(math.rad(-12), 0, 0),
			color = rng:pick({ Palette.Neon[1], Palette.Neon[3], Color3.fromRGB(150, 30, 40), Color3.fromRGB(30, 90, 80) }),
			mat = Enum.Material.Fabric,
			collide = false,
		})
	end
	-- lit windows on upper floors
	if height > 34 then
		local lit = if rng:chance(0.7) then Palette.WarmWindow else Palette.CoolWindow
		local y = y0 + 20
		while y < y0 + height - 6 do
			if rng:chance(0.55) then
				B:block(model, "LitFloor", cx, y, cz, w + 0.4, 1.4, d + 0.4, lit, Enum.Material.Neon, {
					transparency = 0.55,
					collide = false,
					shadow = false,
					query = false,
				})
			end
			y += 13
		end
	end
	if height > 34 and rng:chance(0.2) then
		local along = Vector3.new(-facing.Z, 0, facing.X)
		local p = front.Position + along * (frontW / 2 - 2) + facing * 2.4 + Vector3.new(0, height - 4, 0)
		Props.verticalSign(B, model, rng, lookAt(p, p + facing), rng:pick({ "HOTEL", "BAR", "CLUB", "MOTEL", "NOODLE", "LIVE" }))
	end
	if rng:chance(0.12) and frontW > 30 then
		local roof = Vector3.new(cx, y0 + height + 0.7, cz)
		Props.billboard(B, model, rng, lookAt(roof, roof + facing), math.min(frontW * 0.8, 44), nil, 10)
	end
	return model
end

function Commercial.build(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	local distance = (Vector3.new(c.cx, 0, c.cz) - ctx.downtown).Magnitude
	local closeness = math.clamp(1 - distance / 2200, 0, 1)
	local cx0, cz0, cx1, cz1 = Frontage.layout(rng, x0, z0, x1, z1, {
		depth = { 44, 72 },
		width = { 34, 72 },
		gap = { 0, 4 },
	}, function(fx0, fz0, fx1, fz1, facing)
		if ctx:blocked(c, fx0, fz0, fx1, fz1) then
			return
		end
		local height = rng:range(16, 36) + rng:range(0, 70) * closeness
		Commercial.shop(ctx, parent, rng, fx0, fz0, fx1, fz1, y0, facing, height)
	end)
	-- parking courtyard with a few cars
	if cx1 - cx0 > 40 and cz1 - cz0 > 40 then
		B:block(parent, "Parking", (cx0 + cx1) / 2, y0, (cz0 + cz1) / 2, cx1 - cx0, 0.1, cz1 - cz0, Palette.AsphaltDark, Enum.Material.Asphalt, GLOW)
		for k = 1, rng:int(1, 4) do
			local px = cx0 + 14 + (k - 1) * 12
			if px < cx1 - 10 then
				local pz = if rng:chance(0.5) then cz0 + 12 else cz1 - 12
				if not ctx:blocked(c, px - 6, pz - 10, px + 6, pz + 10) then
					Props.car(B, parent, rng, CFrame.new(px, y0 + 0.1, pz) * CFrame.Angles(0, if rng:chance(0.5) then 0 else math.pi, 0))
				end
			end
		end
	end
end

return Commercial
