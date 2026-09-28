--[[
	Street dressing: lane markings, crosswalks, stop lines, street lamps and traffic lights.
	Traffic light lamps are tagged "NeonBayTraffic" and cycled by the client script.
]]

local Palette = require(script.Parent.Palette)
local Props = require(script.Parent.Props)
local lookAt = require(script.Parent.Geometry).lookAt

local Streets = {}

local UP = Vector3.new(0, 1, 0)
local LINE = { collide = false, shadow = false, query = false }
local MARK_Y = 0.06 -- top of road markings above the asphalt

-- Where lamps stand along a block (0..1), per street style and side of the street.
local LAMP_SPOTS = {
	urban = { { 0.25 }, { 0.75 } },
	suburban = { { 0.5 }, {} },
	industrial = { { 0.5 }, {} },
}

local function mark(B, parent, name, center: Vector3, along: Vector3, width: number, length: number, color: Color3)
	local c = center + UP * (MARK_Y - 0.06)
	B:part({
		parent = parent,
		name = name,
		size = Vector3.new(width, 0.12, length),
		cf = lookAt(c, c + along),
		color = color,
		mat = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
		query = false,
	})
end

local function styleOf(edge): string
	local left, right = edge.left, edge.right
	local function has(key)
		return (left and left.def[key]) or (right and right.def[key])
	end
	local function isChar(ch)
		return (left and left.char == ch) or (right and right.char == ch)
	end
	if has("urban") then
		return "urban"
	elseif isChar("I") then
		return "industrial"
	end
	return "suburban"
end

local function cellSide(c): boolean
	return c ~= nil and c.def.land and c.def.streets and not c.def.noCurb
end

function Streets.build(B, root, grid, config, plan)
	local folder = B:group(root, "Streets")
	local markings = B:group(folder, "Markings")
	local lamps = B:group(folder, "Lamps")
	local signals = B:group(folder, "TrafficLights")
	local hw = config.RoadWidth / 2
	local lane = config.LaneWidth

	for _, edge in grid:streetEdges() do
		if not plan.rampEdges[edge.key] then
			local a = Vector3.new(edge.ax, 0, edge.az)
			local b = Vector3.new(edge.bx, 0, edge.bz)
			local u = (b - a).Unit
			local right = Vector3.new(-u.Z, 0, u.X)
			local s0 = a + u * (hw + 2)
			local s1 = b - u * (hw + 2)
			local len = (s1 - s0).Magnitude
			local mid = (s0 + s1) / 2
			local style = styleOf(edge)

			-- centre line (a median replaces it under the freeway); double line on busy streets
			if not plan.elevatedOver[edge.key] then
				if style == "urban" then
					for _, side in { -0.6, 0.6 } do
						mark(B, markings, "CenterLine", mid + right * side, u, 0.4, len, Palette.LineYellow)
					end
				else
					mark(B, markings, "CenterLine", mid, u, 0.5, len, Palette.LineYellow)
				end
			end
			-- lane dashes on busy streets
			if style == "urban" then
				local period = 60
				local dash = 16
				local count = math.floor(len / period)
				local start = (len - (count - 1) * period) / 2
				for k = 0, count - 1 do
					local p = s0 + u * (start + k * period)
					for _, side in { -1, 1 } do
						mark(B, markings, "LaneDash", p + right * (side * lane), u, 0.4, dash, Palette.LineWhite)
					end
				end
			end

			-- lamps on the sidewalks (edge.left is the north/west cell, edge.right south/east)
			local sides = {
				{ cell = edge.left, toCell = if edge.dir == "H" then Vector3.new(0, 0, -1) else Vector3.new(-1, 0, 0) },
				{ cell = edge.right, toCell = if edge.dir == "H" then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0) },
			}
			for index, side in sides do
				local c = side.cell
				if cellSide(c) then
					local spots = LAMP_SPOTS[style][index]
					for k, t in spots do
						-- LampDensity < 1 thins lamps out evenly (deterministic, no randomness)
						local keep = ((edge.i * 7 + edge.j * 13 + index * 5 + k * 3) % 100) < config.LampDensity * 100
						if keep then
							local p = s0:Lerp(s1, t) + side.toCell * (hw + 1.6) + UP * config.CurbHeight
							if not plan:blocksPoint(c.i, c.j, p.X, p.Z, 4) then
								Props.streetLamp(B, lamps, p, -side.toCell)
							end
						end
					end
				end
			end
		end
	end

	-- intersections
	for j = 0, grid.nz do
		for i = 0, grid.nx do
			local arms = grid:arms(i, j)
			local count = (if arms.N then 1 else 0) + (if arms.S then 1 else 0) + (if arms.E then 1 else 0) + (if arms.W then 1 else 0)
			if count >= 3 then
				local nx, nz = grid:node(i, j)
				local center = Vector3.new(nx, 0, nz)
				local quads = { grid:cellAt(i - 1, j - 1), grid:cellAt(i, j - 1), grid:cellAt(i - 1, j), grid:cellAt(i, j) }
				local urban, downtown = 0, 0
				for _, q in quads do
					if q and q.def.urban then
						urban += 1
					end
					if q and q.char == "D" then
						downtown += 1
					end
				end
				local armList = {}
				if arms.N then
					table.insert(armList, Vector3.new(0, 0, -1))
				end
				if arms.S then
					table.insert(armList, Vector3.new(0, 0, 1))
				end
				if arms.E then
					table.insert(armList, Vector3.new(1, 0, 0))
				end
				if arms.W then
					table.insert(armList, Vector3.new(-1, 0, 0))
				end
				for _, d in armList do
					local key
					if d.X > 0 then
						key = "H:" .. i .. ":" .. j
					elseif d.X < 0 then
						key = "H:" .. (i - 1) .. ":" .. j
					elseif d.Z > 0 then
						key = "V:" .. i .. ":" .. j
					else
						key = "V:" .. i .. ":" .. (j - 1)
					end
					if not plan.rampEdges[key] then
						local across = Vector3.new(-d.Z, 0, d.X)
						if downtown >= 2 then
							-- zebra crossing
							for k = -2, 2 do
								local p = center + d * (hw + 8) + across * (k * 8.5)
								mark(B, markings, "Crosswalk", p, d, 4, 10, Palette.LineWhite)
							end
						elseif urban >= 2 then
							-- stop line on the incoming lanes (drivers keep right)
							local p = center + d * (hw + 3) + across * (-hw / 2)
							mark(B, markings, "StopLine", p, across, 1, hw - 2, Palette.LineWhite)
						end
					end
				end
				-- traffic lights on downtown four-way crossings
				if count == 4 and downtown >= 2 then
					Streets.trafficLights(B, signals, config, center)
				end
			end
		end
	end
	return folder
end

-- Two signal masts on opposite corners. Lamps carry attributes read by the client script:
-- Axis = "NS" | "EW" (which traffic they control) and Light = "Red" | "Yellow" | "Green".
function Streets.trafficLights(B, parent, config, center: Vector3)
	local hw = config.RoadWidth / 2
	local model = Instance.new("Model")
	model.Name = "TrafficLight"
	model.Parent = parent
	local corners = {
		{ corner = Vector3.new(1, 0, 1), facing = Vector3.new(0, 0, 1), axis = "NS" }, -- SE corner: faces northbound traffic
		{ corner = Vector3.new(-1, 0, -1), facing = Vector3.new(0, 0, -1), axis = "NS" },
		{ corner = Vector3.new(-1, 0, 1), facing = Vector3.new(-1, 0, 0), axis = "EW" }, -- SW corner: faces eastbound traffic
		{ corner = Vector3.new(1, 0, -1), facing = Vector3.new(1, 0, 0), axis = "EW" },
	}
	local off = {
		Red = Color3.fromRGB(60, 10, 10),
		Yellow = Color3.fromRGB(60, 45, 5),
		Green = Color3.fromRGB(8, 50, 20),
	}
	local lit = {
		Red = Color3.fromRGB(255, 40, 30),
		Yellow = Color3.fromRGB(255, 190, 20),
		Green = Color3.fromRGB(40, 255, 110),
	}
	for _, c in corners do
		local base = center + c.corner * (hw + 2.5) + UP * config.CurbHeight
		local h = 18
		B:column(model, "SignalPole", base.X, base.Y, base.Z, h, 1, Palette.Pole, Enum.Material.Metal, { shadow = false })
		-- mast arm reaching over the approaching lanes
		local over = -Vector3.new(c.facing.Z, 0, -c.facing.X) -- points from the kerb over the road
		if over:Dot(-c.corner) < 0 then
			over = -over
		end
		local top = base + UP * h
		local tip = top + over * (hw * 0.7)
		B:beam(model, "SignalArm", top, tip, 0.5, 0.5, Palette.Pole, Enum.Material.Metal, LINE)
		local headC = tip - UP * 3
		local head = B:part({
			parent = model,
			name = "SignalHead",
			size = Vector3.new(1.6, 5.4, 1.2),
			cf = lookAt(headC, headC + c.facing),
			color = Color3.fromRGB(20, 20, 22),
			mat = Enum.Material.SmoothPlastic,
			collide = false,
			shadow = false,
		})
		local initial = if c.axis == "NS" then "Green" else "Red"
		for k, name in { "Red", "Yellow", "Green" } do
			local lampC = (head.CFrame * CFrame.new(0, 1.7 - (k - 1) * 1.7, -0.65))
			local lamp = B:part({
				parent = model,
				name = name,
				size = Vector3.new(1.1, 1.1, 0.2),
				cf = lampC,
				color = if name == initial then lit[name] else off[name],
				mat = if name == initial then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				collide = false,
				shadow = false,
				query = false,
			})
			lamp:SetAttribute("Axis", c.axis)
			lamp:SetAttribute("Light", name)
			lamp:AddTag("NeonBayTraffic")
		end
	end
	return model
end

return Streets
