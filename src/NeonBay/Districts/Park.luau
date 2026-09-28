--[[
	Parks and open fields: lawns, paths, a lit fountain, trees and billboards.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local lookAt = require(script.Parent.Parent.Geometry).lookAt

local Park = {}

local GLOW = { collide = false, shadow = false, query = false }

local function lawn(B, parent, x0, z0, x1, z1, y0)
	B:block(parent, "Lawn", (x0 + x1) / 2, y0, (z0 + z1) / 2, x1 - x0, 0.2, z1 - z0, Palette.GrassDark, Enum.Material.Grass, GLOW)
	return y0 + 0.2
end

function Park.build(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	y0 = lawn(B, parent, x0, z0, x1, z1, y0)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = x1 - x0, z1 - z0
	-- cross-shaped paths
	B:block(parent, "Path", cx, y0, cz, w, 0.1, 10, Palette.Sidewalk, Enum.Material.Pavement, GLOW)
	B:block(parent, "Path", cx, y0, cz, 10, 0.1, d, Palette.Sidewalk, Enum.Material.Pavement, GLOW)
	-- fountain
	if not ctx:blocked(c, cx - 20, cz - 20, cx + 20, cz + 20) then
		B:column(parent, "FountainRim", cx, y0, cz, 2.4, 34, Palette.Concrete, Enum.Material.Concrete)
		local water = B:column(parent, "FountainWater", cx, y0 + 0.4, cz, 2.2, 31, Palette.Neon[2], Enum.Material.Neon, {
			transparency = 0.35,
			collide = false,
			shadow = false,
		})
		B:pointLight(water, Palette.Neon[2], 30, 1.5)
		B:column(parent, "FountainSpout", cx, y0, cz, 9, 3, Palette.Concrete, Enum.Material.Marble)
	end
	-- trees away from the paths
	for _ = 1, rng:int(8, 14) do
		local tx, tz = rng:range(x0 + 10, x1 - 10), rng:range(z0 + 10, z1 - 10)
		local onPath = math.abs(tx - cx) < 14 or math.abs(tz - cz) < 14
		if not onPath and not ctx:blocked(c, tx - 8, tz - 8, tx + 8, tz + 8) then
			Props.tree(B, parent, rng, tx, y0, tz, 1.15)
		end
	end
	-- short lamps along the paths
	for _, off in { { -60, 0 }, { 60, 0 }, { 0, -60 }, { 0, 60 } } do
		local p = Vector3.new(cx + off[1] + (if off[2] ~= 0 then 7 else 0), y0, cz + off[2] + (if off[1] ~= 0 then 7 else 0))
		if not ctx:blocked(c, p.X - 4, p.Z - 4, p.X + 4, p.Z + 4) then
			B:column(parent, "ParkLampPost", p.X, p.Y, p.Z, 10, 0.6, Palette.Pole, Enum.Material.Metal, { shadow = false })
			local globe = B:ball(parent, "ParkLamp", p + Vector3.new(0, 10.8, 0), 1.8, Palette.WarmWindow, Enum.Material.Neon, GLOW)
			B:pointLight(globe, Palette.SodiumLight, 26, 1.2)
		end
	end
end

-- Open field: lawn, a few trees and a roadside billboard.
function Park.field(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	y0 = lawn(B, parent, x0, z0, x1, z1, y0)
	for _ = 1, rng:int(4, 7) do
		local tx, tz = rng:range(x0 + 10, x1 - 10), rng:range(z0 + 10, z1 - 10)
		if not ctx:blocked(c, tx - 8, tz - 8, tx + 8, tz + 8) then
			Props.tree(B, parent, rng, tx, y0, tz, 1.1)
		end
	end
	local p = Vector3.new((x0 + x1) / 2, y0, z0 + 20)
	Props.billboard(B, parent, rng, lookAt(p, p + Vector3.new(0, 0, -1)), 48, nil, 24)
end

return Park
