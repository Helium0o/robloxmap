--[[
	Open lots: flat asphalt behind jersey barriers with floodlights, a cone slalom and a
	small car meet. Good for drifting and drag launches.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local lookAt = require(script.Parent.Parent.Geometry).lookAt

local OpenLot = {}

local GLOW = { collide = false, shadow = false, query = false }

function OpenLot.build(ctx, parent, c, rng)
	local B = ctx.B
	local x0, z0, x1, z1, y0 = ctx:lot(c)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local inset = 4
	local bh = ctx.config.BarrierHeight
	local gapHalf = 30
	-- barrier ring with an entrance in the middle of every side
	local function wall(ax, az, bx, bz)
		if ctx:blocked(c, math.min(ax, bx) - 1, math.min(az, bz) - 1, math.max(ax, bx) + 1, math.max(az, bz) + 1) then
			return
		end
		B:beam(parent, "Barrier", Vector3.new(ax, y0 + bh / 2, az), Vector3.new(bx, y0 + bh / 2, bz), 1.6, bh, Palette.Barrier, Enum.Material.Concrete)
	end
	local ix0, iz0, ix1, iz1 = x0 + inset, z0 + inset, x1 - inset, z1 - inset
	wall(ix0, iz0, cx - gapHalf, iz0)
	wall(cx + gapHalf, iz0, ix1, iz0)
	wall(ix0, iz1, cx - gapHalf, iz1)
	wall(cx + gapHalf, iz1, ix1, iz1)
	wall(ix0, iz0, ix0, cz - gapHalf)
	wall(ix0, cz + gapHalf, ix0, iz1)
	wall(ix1, iz0, ix1, cz - gapHalf)
	wall(ix1, cz + gapHalf, ix1, iz1)

	-- floodlight towers in the corners
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local px, pz = cx + sx * ((x1 - x0) / 2 - 14), cz + sz * ((z1 - z0) / 2 - 14)
			if not ctx:blocked(c, px - 6, pz - 6, px + 6, pz + 6) then
				B:column(parent, "FloodPole", px, y0, pz, 44, 1.6, Palette.Pole, Enum.Material.Metal)
				local head = B:box(parent, "Floodlight", Vector3.new(px, y0 + 44.8, pz), Vector3.new(7, 1.6, 7), Color3.fromRGB(235, 240, 255), Enum.Material.Neon, GLOW)
				B:spotLight(head, Enum.NormalId.Bottom, Color3.fromRGB(225, 232, 255), 60, 2.5, 130)
			end
		end
	end

	-- cone slalom down the middle
	local alongX = rng:chance(0.5)
	for k = -3, 3 do
		local t = k * 24
		local px = if alongX then cx + t else cx + (if k % 2 == 0 then 6 else -6)
		local pz = if alongX then cz + (if k % 2 == 0 then 6 else -6) else cz + t
		if not ctx:blocked(c, px - 2, pz - 2, px + 2, pz + 2) then
			Props.cone(B, parent, px, y0, pz)
		end
	end

	-- a small car meet along one side
	local side = rng:int(1, 4)
	for k = 1, rng:int(3, 6) do
		local t = -60 + k * 22
		local px, pz, yaw
		if side == 1 then
			px, pz, yaw = cx + t, iz0 + 16, 0
		elseif side == 2 then
			px, pz, yaw = cx + t, iz1 - 16, math.pi
		elseif side == 3 then
			px, pz, yaw = ix0 + 16, cz + t, math.pi / 2
		else
			px, pz, yaw = ix1 - 16, cz + t, -math.pi / 2
		end
		if not ctx:blocked(c, px - 10, pz - 10, px + 10, pz + 10) then
			Props.car(B, parent, rng, CFrame.new(px, y0, pz) * CFrame.Angles(0, yaw, 0))
		end
	end

	-- sign facing the lot
	local signPos = Vector3.new(cx, y0, if side == 1 then iz1 - 8 else iz0 + 8)
	local lookDir = if side == 1 then Vector3.new(0, 0, -1) else Vector3.new(0, 0, 1)
	if not ctx:blocked(c, signPos.X - 26, signPos.Z - 4, signPos.X + 26, signPos.Z + 4) then
		Props.billboard(B, parent, rng, lookAt(signPos, signPos + lookDir), 44, rng:pick({ "DRIFT ZONE", "MIDNIGHT MEET", "DRAG CLUB" }), 16)
	end
end

return OpenLot
