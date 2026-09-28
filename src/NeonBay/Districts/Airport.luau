--[[
	Airport: built once per connected group of "A" cells. A long runway (a proper drag
	strip), taxiway, apron with parked airliners, terminal, control tower and hangars.
]]

local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Parent.Props)
local lookAt = require(script.Parent.Parent.Geometry).lookAt

local Airport = {}

local DECOR = { collide = false, shadow = false }
local GLOW = { collide = false, shadow = false, query = false }

local function regions(grid)
	local seen = {}
	local list = {}
	grid:forEachCell(function(c)
		if c.char == "A" and not seen[c] then
			local stack = { c }
			seen[c] = true
			local x0, z0, x1, z1 = c.x0, c.z0, c.x1, c.z1
			while #stack > 0 do
				local cur = table.remove(stack)
				x0, z0 = math.min(x0, cur.x0), math.min(z0, cur.z0)
				x1, z1 = math.max(x1, cur.x1), math.max(z1, cur.z1)
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local n = grid:cellAt(cur.i + d[1], cur.j + d[2])
					if n and n.char == "A" and not seen[n] then
						seen[n] = true
						table.insert(stack, n)
					end
				end
			end
			table.insert(list, { x0 = x0, z0 = z0, x1 = x1, z1 = z1 })
		end
	end)
	return list
end

-- Everything below is laid out along local X (runway direction) with local Z across.
local function airliner(B, parent, rng, frame: CFrame)
	local model = Instance.new("Model")
	model.Name = "Airliner"
	model.Parent = parent
	local white = Color3.fromRGB(235, 236, 240)
	local livery = rng:pick(Palette.Neon)
	local function part(name, size, offset, color, mat, shape, extra)
		local spec = {
			parent = model,
			name = name,
			size = size,
			cf = frame * offset,
			color = color,
			mat = mat or Enum.Material.SmoothPlastic,
			shape = shape,
		}
		if extra then
			for k, v in extra do
				spec[k] = v
			end
		end
		return B:part(spec)
	end
	-- fuselage along local Z (the frame looks along the aircraft)
	part("Fuselage", Vector3.new(84, 11, 11), CFrame.new(0, 9, 0) * CFrame.Angles(0, math.pi / 2, 0), white, nil, Enum.PartType.Cylinder)
	part("Nose", Vector3.new(11, 11, 11), CFrame.new(0, 9, -42), white, nil, Enum.PartType.Ball)
	part("Wing", Vector3.new(76, 1.2, 14), CFrame.new(0, 6.5, 2), white)
	part("Stabilizer", Vector3.new(30, 1, 8), CFrame.new(0, 10, 38), white)
	part("Fin", Vector3.new(1.2, 16, 12), CFrame.new(0, 21, 36), livery, nil, nil, { reflectance = 0.1 })
	part("Stripe", Vector3.new(11.2, 1.2, 70), CFrame.new(0, 10, 0), livery, Enum.Material.Neon, nil, GLOW)
	for _, s in { -1, 1 } do
		part("Engine", Vector3.new(10, 5, 5), CFrame.new(s * 16, 4.5, -2) * CFrame.Angles(0, math.pi / 2, 0), Palette.Metal, Enum.Material.Metal, Enum.PartType.Cylinder)
		part("NavLight", Vector3.new(0.8, 0.8, 0.8), CFrame.new(s * 38, 6.8, 2), if s < 0 then Color3.fromRGB(255, 40, 40) else Color3.fromRGB(40, 255, 90), Enum.Material.Neon, nil, GLOW)
	end
	for _, z in { -28, 6 } do
		part("Gear", Vector3.new(3, 4, 3), CFrame.new(0, 2, z), Palette.MetalDark, Enum.Material.Metal, nil, DECOR)
	end
end

local function hangar(B, parent, frame: CFrame, width, depth, height)
	B:part({
		parent = parent,
		name = "Hangar",
		size = Vector3.new(width, height, depth),
		cf = frame * CFrame.new(0, height / 2, 0),
		color = Color3.fromRGB(96, 104, 112),
		mat = Enum.Material.CorrodedMetal,
	})
	-- arched roof: a cylinder half sunk into the box
	B:part({
		parent = parent,
		name = "HangarRoof",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(depth, width, width),
		cf = frame * CFrame.new(0, height - width * 0.36, 0) * CFrame.Angles(0, math.pi / 2, 0),
		color = Color3.fromRGB(120, 126, 134),
		mat = Enum.Material.Metal,
	})
	B:part({
		parent = parent,
		name = "HangarDoorGlow",
		size = Vector3.new(width - 8, 1, 0.5),
		cf = frame * CFrame.new(0, height - 3, -depth / 2 - 0.3),
		color = Palette.Neon[2],
		mat = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
end

function Airport.build(ctx, root, rng)
	local B = ctx.B
	local config = ctx.config
	local list = regions(ctx.grid)
	for index, r in list do
		local parent = B:group(root, "Airport" .. (if index > 1 then tostring(index) else ""), "Model")
		local inset = config.RoadWidth / 2 + 10
		local x0, z0, x1, z1 = r.x0 + inset, r.z0 + inset, r.x1 - inset, r.z1 - inset
		local alongX = (x1 - x0) >= (z1 - z0)
		local length = if alongX then x1 - x0 else z1 - z0
		local across = if alongX then z1 - z0 else x1 - x0
		local center = Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)
		-- local frame: +X along the runway, +Z towards the terminal (south / east side)
		local frame = if alongX then CFrame.new(center) else CFrame.new(center) * CFrame.Angles(0, -math.pi / 2, 0)
		local y = 0.15
		local function slab(name, lx, lz, sx, sz, top, color, mat)
			return B:part({
				parent = parent,
				name = name,
				size = Vector3.new(sx, 0.4, sz),
				cf = frame * CFrame.new(lx, top - 0.2, lz),
				color = color,
				mat = mat or Enum.Material.Asphalt,
			})
		end
		local function light(name, lx, lz, color)
			B:part({
				parent = parent,
				name = name,
				size = Vector3.new(0.9, 0.9, 0.9),
				cf = frame * CFrame.new(lx, y + 0.7, lz),
				color = color,
				mat = Enum.Material.Neon,
				collide = false,
				shadow = false,
				query = false,
			})
		end

		-- runway
		local runwayZ = -across / 2 + across * 0.3
		local runwayL = length - 120
		local runwayW = 96
		slab("Runway", 0, runwayZ, runwayL, runwayW, y + 0.25, Color3.fromRGB(34, 34, 38))
		local dash = 40
		for x = -runwayL / 2 + 150, runwayL / 2 - 150, dash * 2 do
			slab("RunwayCenterline", x, runwayZ, dash, 1.6, y + 0.3, Palette.LineWhite, Enum.Material.SmoothPlastic)
		end
		for _, endSign in { -1, 1 } do
			local ex = endSign * (runwayL / 2 - 30)
			for k = -3, 3 do
				if k ~= 0 then
					slab("Threshold", ex, runwayZ + k * 11, 40, 5, y + 0.3, Palette.LineWhite, Enum.Material.SmoothPlastic)
				end
			end
			for k = -2, 2 do
				light("ThresholdLight", endSign * (runwayL / 2 - 4), runwayZ + k * 18, if endSign < 0 then Color3.fromRGB(60, 255, 120) else Color3.fromRGB(255, 50, 50))
			end
		end
		for x = -runwayL / 2 + 20, runwayL / 2 - 20, 60 do
			light("RunwayLight", x, runwayZ - runwayW / 2 - 2, Color3.fromRGB(255, 244, 220))
			light("RunwayLight", x, runwayZ + runwayW / 2 + 2, Color3.fromRGB(255, 244, 220))
		end

		-- taxiway and connectors
		local taxiZ = runwayZ + runwayW / 2 + 70
		local taxiL = runwayL - 200
		slab("Taxiway", 0, taxiZ, taxiL, 40, y + 0.25, Color3.fromRGB(40, 40, 44))
		slab("TaxiLine", 0, taxiZ, taxiL, 0.8, y + 0.3, Palette.LineYellow, Enum.Material.SmoothPlastic)
		for _, s in { -1, 1 } do
			local tx = s * (taxiL / 2 - 20)
			local gapZ = (taxiZ - 20) - (runwayZ + runwayW / 2)
			slab("TaxiConnector", tx, runwayZ + runwayW / 2 + gapZ / 2, 40, gapZ + 1, y + 0.25, Color3.fromRGB(40, 40, 44))
		end
		for x = -taxiL / 2 + 10, taxiL / 2 - 10, 80 do
			light("TaxiLight", x, taxiZ - 22, Color3.fromRGB(60, 120, 255))
			light("TaxiLight", x, taxiZ + 22, Color3.fromRGB(60, 120, 255))
		end

		-- apron and terminal
		local apronZ0 = taxiZ + 20
		local terminalDepth = 60
		local terminalZ = across / 2 - terminalDepth / 2 - 12
		local apronZ1 = terminalZ - terminalDepth / 2
		local apronL = math.min(taxiL * 0.7, 900)
		slab("Apron", 0, (apronZ0 + apronZ1) / 2, apronL, apronZ1 - apronZ0, y + 0.25, Color3.fromRGB(58, 58, 64), Enum.Material.Concrete)
		local terminalL = apronL * 0.65
		local terminal = Instance.new("Model")
		terminal.Name = "Terminal"
		terminal.Parent = parent
		B:part({
			parent = terminal,
			name = "Body",
			size = Vector3.new(terminalL, 26, terminalDepth),
			cf = frame * CFrame.new(0, y + 13, terminalZ),
			color = Color3.fromRGB(26, 40, 60),
			mat = Enum.Material.Glass,
			reflectance = 0.2,
		})
		B:part({
			parent = terminal,
			name = "Roof",
			size = Vector3.new(terminalL + 16, 2, terminalDepth + 16),
			cf = frame * CFrame.new(0, y + 27, terminalZ),
			color = Color3.fromRGB(200, 204, 210),
			mat = Enum.Material.Metal,
		})
		for _, face in { -1, 1 } do
			B:part({
				parent = terminal,
				name = "Glow",
				size = Vector3.new(terminalL, 1.2, 0.4),
				cf = frame * CFrame.new(0, y + 25.5, terminalZ + face * (terminalDepth / 2 + 0.3)),
				color = Palette.Neon[2],
				mat = Enum.Material.Neon,
				collide = false,
				shadow = false,
				query = false,
			})
			B:part({
				parent = terminal,
				name = "Interior",
				size = Vector3.new(terminalL - 4, 18, 0.2),
				cf = frame * CFrame.new(0, y + 11, terminalZ + face * (terminalDepth / 2 - 0.3)),
				color = Palette.WarmWindow,
				mat = Enum.Material.Neon,
				transparency = 0.6,
				collide = false,
				shadow = false,
				query = false,
			})
		end
		local signC = frame * CFrame.new(0, y + 34, terminalZ + terminalDepth / 2 - 4)
		local sign = B:part({
			parent = terminal,
			name = "TerminalSign",
			size = Vector3.new(math.min(terminalL * 0.6, 150), 10, 1),
			cf = signC * CFrame.Angles(0, math.pi, 0),
			color = Color3.fromRGB(14, 14, 20),
			mat = Enum.Material.SmoothPlastic,
			collide = false,
		})
		B:text(sign, Enum.NormalId.Front, "NEON BAY INTERNATIONAL", { color = Palette.Neon[2], font = Enum.Font.Michroma, glow = 3, pixelsPerStud = 8 })
		-- jet bridges
		for k = -1, 1 do
			B:part({
				parent = terminal,
				name = "JetBridge",
				size = Vector3.new(6, 6, 30),
				cf = frame * CFrame.new(k * terminalL * 0.3, y + 12, terminalZ - terminalDepth / 2 - 15),
				color = Color3.fromRGB(180, 184, 190),
				mat = Enum.Material.Metal,
			})
		end

		-- parked airliners, noses to the jet bridges
		for k = -1, 1 do
			if rng:chance(0.8) then
				local p = frame * CFrame.new(k * terminalL * 0.3, y + 0.25, terminalZ - terminalDepth / 2 - 30 - 50)
				airliner(B, parent, rng, p * CFrame.Angles(0, math.pi, 0))
			end
		end

		-- control tower at the west end of the terminal
		local towerX = -terminalL / 2 - 60
		local tb = frame * CFrame.new(towerX, y, terminalZ)
		local tp = tb.Position
		B:column(parent, "TowerShaft", tp.X, tp.Y, tp.Z, 80, 12, Color3.fromRGB(200, 200, 205), Enum.Material.Concrete)
		B:column(parent, "TowerCab", tp.X, tp.Y + 80, tp.Z, 11, 26, Color3.fromRGB(30, 50, 70), Enum.Material.Glass, { reflectance = 0.25 })
		B:column(parent, "TowerCabGlow", tp.X, tp.Y + 80, tp.Z, 1, 27, Palette.Neon[2], Enum.Material.Neon, GLOW)
		B:column(parent, "TowerRoof", tp.X, tp.Y + 91, tp.Z, 2, 30, Color3.fromRGB(200, 200, 205), Enum.Material.Metal)
		local beacon = B:box(parent, "AviationLight", Vector3.new(tp.X, tp.Y + 101, tp.Z), Vector3.new(2, 2, 2), Palette.AviationRed, Enum.Material.Neon, GLOW)
		B:box(parent, "TowerMast", Vector3.new(tp.X, tp.Y + 96, tp.Z), Vector3.new(0.8, 8, 0.8), Palette.Metal, Enum.Material.Metal, DECOR)
		beacon:AddTag("NeonBayBlink")

		-- hangars at the east end, doors facing the taxiway
		for k = 0, 1 do
			local hx = terminalL / 2 + 70 + k * 100
			if hx + 45 < length / 2 then
				hangar(B, parent, frame * CFrame.new(hx, y, terminalZ - 10), 84, 70, 30)
			end
		end

		-- apron floodlights
		for _, fx in { -apronL / 2 + 20, apronL / 2 - 20 } do
			local p = (frame * CFrame.new(fx, y, apronZ0 + 10)).Position
			B:column(parent, "ApronPole", p.X, p.Y, p.Z, 40, 1.4, Palette.Pole, Enum.Material.Metal)
			local head = B:box(parent, "ApronFlood", p + Vector3.new(0, 40.8, 0), Vector3.new(6, 1.4, 6), Color3.fromRGB(240, 240, 255), Enum.Material.Neon, GLOW)
			B:spotLight(head, Enum.NormalId.Bottom, Color3.fromRGB(230, 235, 255), 60, 2, 130)
		end
		-- billboard towards the access road
		local bb = frame * CFrame.new(apronL / 2 + 40, y, across / 2 - 16)
		Props.billboard(B, parent, rng, lookAt(bb.Position, bb.Position + frame:VectorToWorldSpace(Vector3.new(0, 0, 1))), 40, "FLY NEON BAY", 18)
	end
end

return Airport
