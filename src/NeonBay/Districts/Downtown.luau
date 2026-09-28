--[[
	Downtown: glass and concrete towers with neon crowns, lit floors, rooftop beacons.
	Towers get taller towards the middle of the downtown area.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)

local Downtown = {}

local DECOR = { collide = false, shadow = false }
local GLOW = { collide = false, shadow = false, query = false }

local function band(B, parent, name, cx, y, cz, w, d, h, color, transparency)
	B:block(parent, name, cx, y, cz, w, h, d, color, Enum.Material.Neon, {
		collide = false,
		shadow = false,
		query = false,
		transparency = transparency,
	})
end

local function rooftop(B, parent, rng, cx, top, cz, w, d, height)
	if height > 190 then
		local mastH = rng:range(18, 46)
		B:block(parent, "Antenna", cx, top, cz, 1.4, mastH, 1.4, Palette.Metal, Enum.Material.Metal, DECOR)
		local beacon = B:box(parent, "AviationLight", Vector3.new(cx, top + mastH + 1, cz), Vector3.new(2.2, 2.2, 2.2), Palette.AviationRed, Enum.Material.Neon, GLOW)
		beacon:AddTag("NeonBayBlink")
	end
	if rng:chance(0.35) and w > 50 and d > 50 then
		-- helipad with a glowing rim
		local pad = math.min(w, d) * 0.6
		B:column(parent, "HelipadGlow", cx, top, cz, 0.5, pad + 1.6, Palette.Neon[6], Enum.Material.Neon, GLOW)
		B:column(parent, "Helipad", cx, top, cz, 0.8, pad, Palette.ConcreteDark, Enum.Material.Concrete)
	else
		for _ = 1, rng:int(1, 3) do
			local uw, ud = rng:range(6, 14), rng:range(6, 14)
			local ux = cx + rng:range(-w / 2 + uw, w / 2 - uw)
			local uz = cz + rng:range(-d / 2 + ud, d / 2 - ud)
			B:block(parent, "RoofUnit", ux, top, uz, uw, rng:range(3, 7), ud, Palette.MetalDark, Enum.Material.Metal, DECOR)
		end
	end
end

local function tower(B, parent, rng, x0: number, z0: number, x1: number, z1: number, y0: number, height: number)
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local neon = rng:pick(Palette.Neon)
	local style = rng:weighted({ { 4, "glass" }, { 3, "bands" }, { 3, "stepped" } })
	local model = Instance.new("Model")
	model.Name = "Tower"
	-- keep a low-detail stand-in visible when the tower is streamed out (skyline)
	model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	model.Parent = parent
	local top = y0 + height

	if style == "glass" then
		B:block(model, "Body", cx, y0, cz, w, height, d, rng:pick(Palette.Glass), Enum.Material.Glass, { reflectance = 0.18 })
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				B:block(model, "EdgeGlow", cx + sx * w / 2, y0 + 10, cz + sz * d / 2, 1.1, height - 12, 1.1, neon, Enum.Material.Neon, GLOW)
			end
		end
		band(B, model, "Crown", cx, top - 7, cz, w + 0.8, d + 0.8, 2.4, neon, 0)
		band(B, model, "Crown", cx, top - 12, cz, w + 0.8, d + 0.8, 1, neon, 0.3)
	elseif style == "bands" then
		local facade = rng:pick(Palette.Facade)
		local mat = rng:pick({ Enum.Material.Concrete, Enum.Material.SmoothPlastic, Enum.Material.Slate, Enum.Material.Marble })
		B:block(model, "Body", cx, y0, cz, w, height, d, facade, mat)
		local lit = if rng:chance(0.6) then Palette.WarmWindow else Palette.CoolWindow
		local gap = rng:range(14, 24)
		local y = y0 + 14
		local count = 0
		while y < top - 10 and count < 18 do
			if rng:chance(0.72) then
				band(B, model, "LitFloor", cx, y, cz, w + 0.5, d + 0.5, 1.6, lit, 0.55)
			end
			y += gap
			count += 1
		end
		band(B, model, "Crown", cx, top - 3, cz, w + 1, d + 1, 2, neon, 0)
	else
		local tiers = rng:int(2, 3)
		local tw, td, ty = w, d, y0
		local lastW, lastD = w, d
		local remaining = height
		local color = rng:pick(Palette.Facade)
		local mat = rng:pick({ Enum.Material.Concrete, Enum.Material.Glass, Enum.Material.Marble })
		for t = 1, tiers do
			local th = if t == tiers then remaining else remaining * rng:range(0.45, 0.6)
			B:block(model, "Body", cx, ty, cz, tw, th, td, color, mat, { reflectance = if mat == Enum.Material.Glass then 0.15 else nil })
			band(B, model, "TierGlow", cx, ty + th - 2, cz, tw + 0.6, td + 0.6, 1.2, neon, 0)
			lastW, lastD = tw, td
			ty += th
			remaining -= th
			tw *= rng:range(0.62, 0.8)
			td *= rng:range(0.62, 0.8)
		end
		top = ty
		w, d = lastW, lastD
	end

	-- street-level lobby glow in a different colour
	band(B, model, "LobbyGlow", cx, y0 + 12, cz, (x1 - x0) + 0.6, (z1 - z0) + 0.6, 1, rng:pick(Palette.Neon), 0)
	rooftop(B, model, rng, cx, top, cz, w, d, height)
	return model
end

-- Splits the lot into 1, 2 or 4 parcels separated by small alleys.
local function parcels(rng, x0, z0, x1, z1)
	local gap = 12
	local pattern = rng:weighted({ { 3, 1 }, { 4, 2 }, { 3, 4 } })
	if pattern == 1 then
		return { { x0, z0, x1, z1 } }
	end
	local xm = (x0 + x1) / 2 + rng:range(-24, 24)
	local zm = (z0 + z1) / 2 + rng:range(-24, 24)
	if pattern == 2 then
		if rng:chance(0.5) then
			return { { x0, z0, xm - gap / 2, z1 }, { xm + gap / 2, z0, x1, z1 } }
		end
		return { { x0, z0, x1, zm - gap / 2 }, { x0, zm + gap / 2, x1, z1 } }
	end
	return {
		{ x0, z0, xm - gap / 2, zm - gap / 2 },
		{ xm + gap / 2, z0, x1, zm - gap / 2 },
		{ x0, zm + gap / 2, xm - gap / 2, z1 },
		{ xm + gap / 2, zm + gap / 2, x1, z1 },
	}
end

function Downtown.build(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	local distance = (Vector3.new(c.cx, 0, c.cz) - ctx.downtown).Magnitude
	local closeness = math.clamp(1 - distance / 1500, 0, 1)
	local base = 190 + 470 * closeness ^ 1.2
	local list = parcels(rng, x0, z0, x1, z1)
	local shrink = if #list == 4 then 0.75 elseif #list == 2 then 0.9 else 1
	for _, p in list do
		-- slender footprint centred in the parcel; the rest becomes a plaza
		local margin = rng:range(6, 16)
		local pw, pd = p[3] - p[1] - 2 * margin, p[4] - p[2] - 2 * margin
		local tw, td = math.min(pw, rng:range(70, 140)), math.min(pd, rng:range(70, 140))
		local pcx, pcz = (p[1] + p[3]) / 2, (p[2] + p[4]) / 2
		local fx0, fz0, fx1, fz1 = pcx - tw / 2, pcz - td / 2, pcx + tw / 2, pcz + td / 2
		local landmark = if rng:chance(0.12) then 1.35 else 1
		if fx1 - fx0 > 30 and fz1 - fz0 > 30 then
			if ctx:blocked(c, fx0, fz0, fx1, fz1) then
				-- the freeway curves over this corner: leave a small plaza with trees
				for _ = 1, 3 do
					local tx, tz = rng:range(fx0, fx1), rng:range(fz0, fz1)
					if not ctx:blocked(c, tx - 8, tz - 8, tx + 8, tz + 8) then
						Props.tree(B, parent, rng, tx, y0, tz, 0.9)
					end
				end
			else
				tower(B, parent, rng, fx0, fz0, fx1, fz1, y0, base * rng:range(0.6, 1.15) * shrink * landmark)
			end
		end
	end
	-- a couple of sidewalk trees
	local bx0, bz0, bx1, bz1 = ctx.grid:blockRect(c)
	for _ = 1, 2 do
		local side = rng:int(1, 4)
		local t = rng:range(0.15, 0.85)
		local tx = if side == 1 then bx0 + 5 elseif side == 2 then bx1 - 5 else bx0 + (bx1 - bx0) * t
		local tz = if side == 3 then bz0 + 5 elseif side == 4 then bz1 - 5 else bz0 + (bz1 - bz0) * t
		if not ctx:blocked(c, tx - 6, tz - 6, tx + 6, tz + 6) then
			Props.tree(B, parent, rng, tx, ctx.config.CurbHeight, tz, 0.8)
		end
	end
end

return Downtown
