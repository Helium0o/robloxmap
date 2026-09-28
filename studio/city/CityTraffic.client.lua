--!nocheck
-- CityTraffic: ambient traffic, traffic lights and stop signs for the city made by Roblox City Blueprint.
-- It runs on each player's device, so the moving cars cost no network bandwidth.
-- Reference copy with the default settings; BuildCity.lua installs this script for you.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local CITY_CARS, HWY_CARS = 100, 60
local CITY_SPEED, HWY_SPEED = 34, 72
local TURN_SPEED, ACCEL, BRAKE = 15, 16, 42
local ROAD, WALK, LANE, Y = 24, 8, 6, 0.1
local GREEN, YELLOW = 12, 3
local CYCLE = 2 * (GREEN + YELLOW)
local HWY = { rx = 860, rz = 860, rc = 140, h = 34 }

-- junctions: x, z, signal offset, is city street, control (0 none, 1 lights, 2 two-way stop, 3 all-way stop), main road axis (1 x, 2 z)
local NODES = {
	{-720, -720, -1, 1, 0, 0}, {-480, -720, -1, 1, 2, 1}, {-240, -720, 14, 1, 1, 0}, {0, -720, -1, 1, 2, 1}, {240, -720, 28, 1, 1, 0},
	{480, -720, -1, 1, 2, 1}, {720, -720, -1, 1, 0, 0}, {-720, -480, -1, 1, 2, 2}, {-480, -480, -1, 1, 3, 0}, {-240, -480, -1, 1, 2, 2},
	{0, -480, -1, 1, 3, 0}, {240, -480, -1, 1, 2, 2}, {480, -480, -1, 1, 3, 0}, {720, -480, -1, 1, 2, 2}, {-720, -240, 8, 1, 1, 0},
	{-480, -240, -1, 1, 2, 1}, {-240, -240, 22, 1, 1, 0}, {0, -240, -1, 1, 2, 1}, {240, -240, 6, 1, 1, 0}, {480, -240, -1, 1, 2, 1},
	{720, -240, 20, 1, 1, 0}, {-720, 0, -1, 1, 2, 2}, {-480, 0, -1, 1, 3, 0}, {-240, 0, -1, 1, 2, 2}, {0, 0, -1, 1, 3, 0},
	{240, 0, -1, 1, 2, 2}, {480, 0, -1, 1, 3, 0}, {720, 0, -1, 1, 2, 2}, {-720, 240, 16, 1, 1, 0}, {-480, 240, -1, 1, 2, 1},
	{-240, 240, 0, 1, 1, 0}, {0, 240, -1, 1, 2, 1}, {240, 240, 14, 1, 1, 0}, {480, 240, -1, 1, 2, 1}, {720, 240, 28, 1, 1, 0},
	{-720, 480, -1, 1, 2, 2}, {-480, 480, -1, 1, 3, 0}, {-240, 480, -1, 1, 2, 2}, {0, 480, -1, 1, 3, 0}, {240, 480, -1, 1, 2, 2},
	{480, 480, -1, 1, 3, 0}, {720, 480, -1, 1, 2, 2}, {-720, 720, -1, 1, 0, 0}, {-480, 720, -1, 1, 2, 1}, {-240, 720, 8, 1, 1, 0},
	{0, 720, -1, 1, 2, 1}, {240, 720, 22, 1, 1, 0}, {480, 720, -1, 1, 2, 1}, {720, 720, -1, 1, 0, 0}, {-1131, -1131, -1, 0, 0, 0},
	{1131, -1131, -1, 0, 0, 0}, {1131, 1131, -1, 0, 0, 0}, {-1131, 1131, -1, 0, 0, 0}, {-240, -1131, 11, 0, 1, 0}, {-240, 1131, 18, 0, 1, 0},
	{240, -1131, 25, 0, 1, 0}, {240, 1131, 2, 0, 1, 0}, {-1131, -240, 9, 0, 1, 0}, {1131, -240, 16, 0, 1, 0}, {-1131, 240, 23, 0, 1, 0},
	{1131, 240, 0, 0, 1, 0},
}
local LINKS = { -- neighbour to the east, west, south, north (0 = none)
	{2, 0, 8, 0}, {3, 1, 9, 0}, {4, 2, 10, 54}, {5, 3, 11, 0}, {6, 4, 12, 56}, {7, 5, 13, 0}, {0, 6, 14, 0}, {9, 0, 15, 1},
	{10, 8, 16, 2}, {11, 9, 17, 3}, {12, 10, 18, 4}, {13, 11, 19, 5}, {14, 12, 20, 6}, {0, 13, 21, 7}, {16, 58, 22, 8}, {17, 15, 23, 9},
	{18, 16, 24, 10}, {19, 17, 25, 11}, {20, 18, 26, 12}, {21, 19, 27, 13}, {59, 20, 28, 14}, {23, 0, 29, 15}, {24, 22, 30, 16}, {25, 23, 31, 17},
	{26, 24, 32, 18}, {27, 25, 33, 19}, {28, 26, 34, 20}, {0, 27, 35, 21}, {30, 60, 36, 22}, {31, 29, 37, 23}, {32, 30, 38, 24}, {33, 31, 39, 25},
	{34, 32, 40, 26}, {35, 33, 41, 27}, {61, 34, 42, 28}, {37, 0, 43, 29}, {38, 36, 44, 30}, {39, 37, 45, 31}, {40, 38, 46, 32}, {41, 39, 47, 33},
	{42, 40, 48, 34}, {0, 41, 49, 35}, {44, 0, 0, 36}, {45, 43, 0, 37}, {46, 44, 55, 38}, {47, 45, 0, 39}, {48, 46, 57, 40}, {49, 47, 0, 41},
	{0, 48, 0, 42}, {54, 0, 58, 0}, {0, 56, 59, 0}, {0, 57, 0, 61}, {55, 0, 0, 60}, {56, 50, 3, 0}, {57, 53, 0, 45}, {51, 54, 5, 0},
	{52, 55, 0, 47}, {15, 0, 60, 50}, {0, 21, 61, 51}, {29, 0, 53, 58}, {0, 35, 52, 59},
}
local VEH = {
	{ name = "Car", L = 14, parts = { {7, 2.6, 14, 0, 2.3, 0, 1, 0}, {6.4, 2.2, 7.5, 0, 4.7, 1, 2, 0}, {7.6, 2.6, 2.6, 0, 1.3, -4.6, 3, 1}, {7.6, 2.6, 2.6, 0, 1.3, 4.6, 3, 1}, {5.4, 0.6, 0.3, 0, 2.9, -7.05, 4, 0}, {5.4, 0.6, 0.3, 0, 2.9, 7.05, 5, 0} } },
	{ name = "Van", L = 15, parts = { {7.4, 5.8, 15, 0, 3.9, 0, 1, 0}, {7.5, 1.8, 11, 0, 5.3, 0.8, 2, 0}, {8, 2.6, 2.6, 0, 1.3, -5, 3, 1}, {8, 2.6, 2.6, 0, 1.3, 5, 3, 1}, {5.6, 0.7, 0.3, 0, 2.6, -7.55, 4, 0}, {5.6, 0.7, 0.3, 0, 2.6, 7.55, 5, 0} } },
	{ name = "Bus", L = 34, parts = { {8, 8.4, 34, 0, 5.4, 0, 1, 0}, {8.1, 2.6, 31, 0, 6.9, 0, 2, 0}, {8.6, 2.8, 2.8, 0, 1.4, -11, 3, 1}, {8.6, 2.8, 2.8, 0, 1.4, 11, 3, 1}, {6, 0.8, 0.3, 0, 2.8, -17.05, 4, 0}, {6, 0.8, 0.3, 0, 2.8, 17.05, 5, 0} } },
	{ name = "Truck", L = 30, parts = { {7.6, 6.4, 8, 0, 4.2, -11, 1, 0}, {8, 9.6, 21, 0, 6.3, 4.5, 6, 0}, {8.6, 2.8, 2.8, 0, 1.4, -10, 3, 1}, {8.6, 2.8, 2.8, 0, 1.4, 10, 3, 1}, {5.6, 0.7, 0.3, 0, 3, -15.05, 4, 0}, {6, 0.7, 0.3, 0, 3, 15.05, 5, 0} } },
}
local PAINT = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(30, 90, 170), Color3.fromRGB(235, 235, 235), Color3.fromRGB(30, 30, 34), Color3.fromRGB(150, 155, 160), Color3.fromRGB(240, 190, 40), Color3.fromRGB(40, 130, 80), Color3.fromRGB(120, 40, 120), Color3.fromRGB(230, 110, 30) }

local DX, DZ, OPP = { 1, -1, 0, 0 }, { 0, 0, 1, -1 }, { 2, 1, 4, 3 }
local ROLE_COLOR = { nil, Color3.fromRGB(44, 56, 70), Color3.fromRGB(28, 28, 30), Color3.fromRGB(255, 244, 214), Color3.fromRGB(222, 40, 40), Color3.fromRGB(236, 236, 232) }
local ROLE_MAT = { Enum.Material.SmoothPlastic, Enum.Material.Glass, Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Neon, Enum.Material.SmoothPlastic }
local LAMP_ON = { R = Color3.fromRGB(255, 60, 50), Y = Color3.fromRGB(255, 196, 40), G = Color3.fromRGB(70, 235, 100) }
local LAMP_OFF = { R = Color3.fromRGB(70, 22, 20), Y = Color3.fromRGB(70, 56, 18), G = Color3.fromRGB(18, 60, 28) }

local rng = Random.new()
local old = workspace:FindFirstChild("CityTrafficCars")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "CityTrafficCars"
folder.Parent = workspace

local parts, cframes = {}, {}

local function newVehicle(kind)
	local def = VEH[kind]
	local paint = PAINT[rng:NextInteger(1, #PAINT)]
	local v = { kind = kind, len = def.L, first = #parts + 1, offs = {}, v = 0, wait = 0, stopT = 0, cleared = false }
	for _, p in ipairs(def.parts) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if p[8] == 1 then part.Shape = Enum.PartType.Cylinder end
		part.Size = Vector3.new(p[1], p[2], p[3])
		part.Color = ROLE_COLOR[p[7]] or paint
		part.Material = ROLE_MAT[p[7]]
		part.CastShadow = p[7] <= 2
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
		table.insert(parts, part)
		table.insert(cframes, part.CFrame)
		table.insert(v.offs, CFrame.new(p[4], p[5], p[6]))
	end
	return v
end

local function place(v, x, y, z, hx, hz)
	local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + hx, y, z + hz))
	for i, off in ipairs(v.offs) do
		cframes[v.first + i - 1] = cf * off
	end
end

local function pickKind(weights)
	local r = rng:NextNumber()
	for k, w in ipairs(weights) do
		if r < w then return k end
		r -= w
	end
	return 1
end

-- traffic lights ---------------------------------------------------------------
local function lightFor(n, xAxis, now)
	local off = NODES[n][3]
	if off < 0 then return "G" end
	local t = (now + off) % CYCLE
	if xAxis then
		if t < GREEN then return "G" elseif t < GREEN + YELLOW then return "Y" end
		return "R"
	end
	if t < GREEN + YELLOW then return "R" elseif t < 2 * GREEN + YELLOW then return "G" end
	return "Y"
end

local lampState = {}
local function updateLamps(now)
	for _, lamp in ipairs(CollectionService:GetTagged("CityTrafficLamp")) do
		local n, axis, l = lamp:GetAttribute("Node"), lamp:GetAttribute("Axis"), lamp:GetAttribute("Light")
		if n and NODES[n] then
			local on = lightFor(n, axis == "X", now) == l
			if lampState[lamp] ~= on then
				lampState[lamp] = on
				lamp.Color = on and LAMP_ON[l] or LAMP_OFF[l]
				lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
end

-- streets ------------------------------------------------------------------------
local function edgeLen(a, b)
	return math.abs(NODES[b][1] - NODES[a][1]) + math.abs(NODES[b][2] - NODES[a][2])
end

local function mustStop(n, k)
	local ctl = NODES[n][5]
	return ctl == 1 or ctl == 3 or (ctl == 2 and (k <= 2 and 1 or 2) ~= NODES[n][6])
end

local function pickNext(b, k)
	local opts = {}
	for kk = 1, 4 do
		if LINKS[b][kk] ~= 0 and kk ~= OPP[k] then table.insert(opts, kk) end
	end
	if #opts == 0 then return OPP[k] end
	if LINKS[b][k] ~= 0 and rng:NextNumber() < 0.5 then return k end
	return opts[rng:NextInteger(1, #opts)]
end

local function startTurn(c)
	local b, k1, k2 = c.b, c.k, c.nk
	local bx, bz = NODES[b][1], NODES[b][2]
	local d1x, d1z, d2x, d2z = DX[k1], DZ[k1], DX[k2], DZ[k2]
	local p0x, p0z = bx - d1x * ROAD / 2 - d1z * LANE, bz - d1z * ROAD / 2 + d1x * LANE
	local p2x, p2z = bx + d2x * ROAD / 2 - d2z * LANE, bz + d2z * ROAD / 2 + d2x * LANE
	local p1x, p1z
	if k1 == k2 then
		p1x, p1z = (p0x + p2x) / 2, (p0z + p2z) / 2
	elseif k2 == OPP[k1] then
		p1x, p1z = bx + d1x * ROAD / 2, bz + d1z * ROAD / 2
	elseif d1z == 0 then
		p1x, p1z = bx - d2z * LANE, bz + d1x * LANE
	else
		p1x, p1z = bx - d1z * LANE, bz + d2x * LANE
	end
	local function dist(ax, az, cx, cz) return math.sqrt((cx - ax) ^ 2 + (cz - az) ^ 2) end
	c.p = { p0x, p0z, p1x, p1z, p2x, p2z }
	c.blen = math.max(4, (dist(p0x, p0z, p1x, p1z) + dist(p1x, p1z, p2x, p2z) + dist(p0x, p0z, p2x, p2z)) / 2)
	c.nxt = LINKS[b][k2]
	c.turning, c.u = true, 0
end

local function approach(c, target, dt)
	if c.v < target then c.v = math.min(target, c.v + ACCEL * dt) else c.v = target end
	if c.v < 0.5 then c.wait += dt else c.wait = 0 end
end

local cityCars = {}
for _ = 1, CITY_CARS do
	for _ = 1, 30 do
		local a = rng:NextInteger(1, #NODES)
		local k = rng:NextInteger(1, 4)
		local b = LINKS[a][k]
		if b ~= 0 then
			local len = edgeLen(a, b)
			local s = rng:NextNumber(ROAD / 2 + 10, len - ROAD / 2 - 40)
			local ok = true
			for _, o in ipairs(cityCars) do
				if o.a == a and o.b == b and math.abs(o.s - s) < 40 then
					ok = false
					break
				end
			end
			if ok then
				local c = newVehicle(pickKind({ 0.74, 0.14, 0.05, 0.07 }))
				c.a, c.b, c.k, c.s, c.turning = a, b, k, s, false
				c.nk = pickNext(b, k)
				table.insert(cityCars, c)
				break
			end
		end
	end
end

-- a car on a main road may cross a two-way stop only when no main-road car is close
local function mainClear(b, groups)
	local axis = NODES[b][6]
	for k = 1, 4 do
		if (k <= 2 and 1 or 2) == axis then
			local m = LINKS[b][OPP[k]]
			if m ~= 0 then
				local g = groups[m * 4096 + b]
				if g then
					local len = edgeLen(m, b)
					for _, o in ipairs(g) do
						if not o.turning and len - o.s < 55 and o.v > 1 then return false end
					end
				end
			end
		end
	end
	return true
end

local occ = {}
local function stepCity(dt, now)
	local groups = {}
	table.clear(occ)
	for _, c in ipairs(cityCars) do
		if c.turning then
			c.key, c.gs = c.b * 4096 + c.nxt, ROAD / 2 - (1 - c.u) * c.blen
			occ[c.b] = (occ[c.b] or 0) + 1
		else
			c.key, c.gs = c.a * 4096 + c.b, c.s
			if c.cleared then occ[c.b] = (occ[c.b] or 0) + 1 end
		end
		local g = groups[c.key]
		if not g then
			g = {}
			groups[c.key] = g
		end
		table.insert(g, c)
	end
	for _, c in ipairs(cityCars) do
		local lead = math.huge
		for _, o in ipairs(groups[c.key]) do
			if o ~= c and o.gs > c.gs then
				lead = math.min(lead, o.gs - (o.len + c.len) / 2 - 4)
			end
		end
		if c.turning then
			local target = (c.k == c.nk) and CITY_SPEED or TURN_SPEED
			approach(c, math.min(target, math.sqrt(2 * BRAKE * math.max(0, lead - c.gs))), dt)
			c.u += c.v * dt / c.blen
			if c.u >= 1 then
				c.a, c.b, c.k = c.b, c.nxt, c.nk
				c.s, c.turning, c.cleared, c.stopT = ROAD / 2, false, false, 0
				c.nk = pickNext(c.b, c.k)
			end
		else
			local len = edgeLen(c.a, c.b)
			local sEnd = len - ROAD / 2
			local limit = lead
			local node = NODES[c.b]
			local ctl = node[5]
			local stopAt = len - ROAD / 2 - ((node[4] == 1 and ctl == 1) and WALK or 2) - 1.5 - c.len / 2
			if ctl == 1 then
				local light = lightFor(c.b, c.k <= 2, now)
				if light ~= "G" then
					local canStop = (stopAt - c.s) > (c.v * c.v) / (2 * BRAKE) - 1
					if c.s <= stopAt + 0.5 and (light == "R" or canStop) then limit = math.min(limit, stopAt) end
				end
			elseif ctl >= 2 then
				if mustStop(c.b, c.k) then
					if not c.cleared then
						if c.s >= stopAt - 1.5 and c.v < 0.5 then
							c.stopT += dt
							if c.wait > 12 or (c.stopT > 0.8 and (occ[c.b] or 0) == 0 and (ctl == 3 or mainClear(c.b, groups))) then
								c.cleared = true
								occ[c.b] = (occ[c.b] or 0) + 1
							end
						end
						if not c.cleared then limit = math.min(limit, stopAt) end
					end
				elseif (occ[c.b] or 0) > 0 and c.s < sEnd - 3 and c.wait < 6 then
					limit = math.min(limit, sEnd - 3)
				end
			end
			local g = groups[c.b * 4096 + LINKS[c.b][c.nk]]
			if g and c.wait < 4 then
				for _, o in ipairs(g) do
					if o.gs - o.len / 2 < ROAD / 2 + c.len + 2 then
						limit = math.min(limit, sEnd - 0.5)
						break
					end
				end
			end
			local vmax = CITY_SPEED
			if c.nk ~= c.k then vmax = math.min(vmax, math.sqrt(TURN_SPEED ^ 2 + 2 * BRAKE * math.max(0, sEnd - c.s))) end
			vmax = math.min(vmax, math.sqrt(2 * BRAKE * math.max(0, limit - c.s)))
			approach(c, vmax, dt)
			c.s = math.min(c.s + c.v * dt, math.max(c.s, limit))
			if c.s >= sEnd then
				startTurn(c)
				if not c.cleared then occ[c.b] = (occ[c.b] or 0) + 1 end
			end
		end
		if c.turning then
			local p, u = c.p, math.min(c.u, 1)
			local w0, w1, w2 = (1 - u) ^ 2, 2 * (1 - u) * u, u * u
			local x, z = w0 * p[1] + w1 * p[3] + w2 * p[5], w0 * p[2] + w1 * p[4] + w2 * p[6]
			local hx = 2 * (1 - u) * (p[3] - p[1]) + 2 * u * (p[5] - p[3])
			local hz = 2 * (1 - u) * (p[4] - p[2]) + 2 * u * (p[6] - p[4])
			if hx * hx + hz * hz < 1e-6 then hx, hz = DX[c.nk], DZ[c.nk] end
			place(c, x, Y, z, hx, hz)
		else
			local ax, az, dx, dz = NODES[c.a][1], NODES[c.a][2], DX[c.k], DZ[c.k]
			place(c, ax + dx * c.s - dz * LANE, Y, az + dz * c.s + dx * LANE, dx, dz)
		end
	end
end

-- ring highway ---------------------------------------------------------------------
local function roundedRect(hx, hz, r, n)
	local pts = {}
	local centres = { { hx - r, hz - r }, { -hx + r, hz - r }, { -hx + r, -hz + r }, { hx - r, -hz + r } }
	for k = 0, 3 do
		local c = centres[k + 1]
		for i = 0, n do
			local a = (k + i / n) * math.pi / 2
			table.insert(pts, { c[1] + r * math.cos(a), c[2] + r * math.sin(a) })
		end
	end
	return pts
end

local lanes = {}
for _, o in ipairs({ 9, 21, -9, -21 }) do
	local pts = roundedRect(HWY.rx - o, HWY.rz - o, HWY.rc - o, 12)
	if o < 0 then
		local rev = {}
		for i = #pts, 1, -1 do table.insert(rev, pts[i]) end
		pts = rev
	end
	local cum, total = { 0 }, 0
	for i = 1, #pts do
		local a, b = pts[i], pts[i % #pts + 1]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		cum[i + 1] = total
	end
	table.insert(lanes, { pts = pts, cum = cum, total = total, cars = {} })
end

local hwyCars = {}
local perLane = math.max(1, math.ceil(HWY_CARS / #lanes))
for i = 1, HWY_CARS do
	local lane = (i - 1) % #lanes + 1
	local c = newVehicle(pickKind({ 0.55, 0.15, 0.05, 0.25 }))
	c.lane, c.seg = lane, 1
	c.s = (math.floor((i - 1) / #lanes) + rng:NextNumber() * 0.3) * lanes[lane].total / perLane
	c.vmax = HWY_SPEED * ((lane % 2 == 1) and rng:NextNumber(0.82, 0.95) or rng:NextNumber(0.95, 1.1))
	if c.kind >= 3 then c.vmax = math.min(c.vmax, HWY_SPEED * 0.8) end
	c.v = c.vmax
	table.insert(hwyCars, c)
	table.insert(lanes[lane].cars, c)
end

local function bySpace(a, b) return a.s < b.s end
local function stepHighway(dt)
	for _, lane in ipairs(lanes) do
		local list = lane.cars
		table.sort(list, bySpace)
		for i, c in ipairs(list) do
			local leader = list[i % #list + 1]
			local free = math.huge
			if leader ~= c then free = (leader.s - c.s) % lane.total - (leader.len + c.len) / 2 - 8 end
			approach(c, math.min(c.vmax, math.sqrt(2 * BRAKE * math.max(0, free))), dt)
			c.s += c.v * dt
			if c.s >= lane.total then
				c.s -= lane.total
				c.seg = 1
			end
			while c.seg < #lane.pts and lane.cum[c.seg + 1] < c.s do c.seg += 1 end
			local a, b = lane.pts[c.seg], lane.pts[c.seg % #lane.pts + 1]
			local segLen = lane.cum[c.seg + 1] - lane.cum[c.seg]
			local t = segLen > 0 and (c.s - lane.cum[c.seg]) / segLen or 0
			place(c, a[1] + (b[1] - a[1]) * t, HWY.h + Y, a[2] + (b[2] - a[2]) * t, b[1] - a[1], b[2] - a[2])
		end
	end
end

-- main loop ------------------------------------------------------------------------
local lampTimer = 1
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local now = workspace:GetServerTimeNow()
	stepCity(dt, now)
	stepHighway(dt)
	if #parts > 0 then workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged) end
	lampTimer += dt
	if lampTimer > 0.25 then
		lampTimer = 0
		updateLamps(now)
	end
end)
