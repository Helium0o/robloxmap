--!nocheck
-- CityTraffic: ambient traffic and signals for the city made by Roblox City Blueprint.
-- It runs on each player's device, so the moving cars cost no network bandwidth.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ROAD, WALK, LANE, Y = 24, 8, 6, 0.1
local CITY_SPEED, TURN_SPEED = 34, 15
local ACCEL, BRAKE = 16, 42
local GREEN, YELLOW = 12, 3
local CYCLE = 2 * (GREEN + YELLOW)
local CITY_CARS, HWY_CARS = 130, 80
local HWY = { rx = 690, rz = 690, rc = 140, h = 34 }

local NODES = { -- x, z, signal offset (-1 = no signal), is city street
	{-550, -550, -1, 1}, {-330, -550, 7, 1}, {-110, -550, 14, 1}, {110, -550, 21, 1}, {330, -550, 28, 1}, {550, -550, -1, 1},
	{-550, -330, 12, 1}, {-330, -330, 19, 1}, {-110, -330, 26, 1}, {110, -330, 3, 1}, {330, -330, 10, 1}, {550, -330, 17, 1},
	{-550, -110, 24, 1}, {-330, -110, 1, 1}, {-110, -110, 8, 1}, {110, -110, 15, 1}, {330, -110, 22, 1}, {550, -110, 29, 1},
	{-550, 110, 6, 1}, {-330, 110, 13, 1}, {-110, 110, 20, 1}, {110, 110, 27, 1}, {330, 110, 4, 1}, {550, 110, 11, 1},
	{-550, 330, 18, 1}, {-330, 330, 25, 1}, {-110, 330, 2, 1}, {110, 330, 9, 1}, {330, 330, 16, 1}, {550, 330, 23, 1},
	{-550, 550, -1, 1}, {-330, 550, 7, 1}, {-110, 550, 14, 1}, {110, 550, 21, 1}, {330, 550, 28, 1}, {550, 550, -1, 1},
	{-961, -961, -1, 0}, {961, -961, -1, 0}, {961, 961, -1, 0}, {-961, 961, -1, 0}, {-110, -961, 10, 0}, {-110, 961, 17, 0},
	{110, -961, 24, 0}, {110, 961, 1, 0}, {-961, -110, 8, 0}, {961, -110, 15, 0}, {-961, 110, 22, 0}, {961, 110, 29, 0},
}
local LINKS = { -- neighbour to the east, west, south, north (0 = none)
	{2, 0, 7, 0}, {3, 1, 8, 0}, {4, 2, 9, 41}, {5, 3, 10, 43}, {6, 4, 11, 0}, {0, 5, 12, 0}, {8, 0, 13, 1}, {9, 7, 14, 2},
	{10, 8, 15, 3}, {11, 9, 16, 4}, {12, 10, 17, 5}, {0, 11, 18, 6}, {14, 45, 19, 7}, {15, 13, 20, 8}, {16, 14, 21, 9}, {17, 15, 22, 10},
	{18, 16, 23, 11}, {46, 17, 24, 12}, {20, 47, 25, 13}, {21, 19, 26, 14}, {22, 20, 27, 15}, {23, 21, 28, 16}, {24, 22, 29, 17}, {48, 23, 30, 18},
	{26, 0, 31, 19}, {27, 25, 32, 20}, {28, 26, 33, 21}, {29, 27, 34, 22}, {30, 28, 35, 23}, {0, 29, 36, 24}, {32, 0, 0, 25}, {33, 31, 0, 26},
	{34, 32, 42, 27}, {35, 33, 44, 28}, {36, 34, 0, 29}, {0, 35, 0, 30}, {41, 0, 45, 0}, {0, 43, 46, 0}, {0, 44, 0, 48}, {42, 0, 0, 47},
	{43, 37, 3, 0}, {44, 40, 0, 33}, {38, 41, 4, 0}, {39, 42, 0, 34}, {13, 0, 47, 37}, {0, 18, 48, 38}, {19, 0, 40, 45}, {0, 24, 39, 46},
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
	local v = { kind = kind, len = def.L, first = #parts + 1, offs = {}, v = 0, wait = 0 }
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

-- traffic signals ------------------------------------------------------------
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

-- city streets ---------------------------------------------------------------
local function edgeLen(a, b)
	return math.abs(NODES[b][1] - NODES[a][1]) + math.abs(NODES[b][2] - NODES[a][2])
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
			local s = rng:NextNumber(ROAD / 2 + 10, len - ROAD / 2 - 30)
			local ok = true
			for _, o in ipairs(cityCars) do
				if o.a == a and o.b == b and math.abs(o.s - s) < 40 then
					ok = false
					break
				end
			end
			if ok then
				local c = newVehicle(pickKind({ 0.72, 0.14, 0.07, 0.07 }))
				c.a, c.b, c.k, c.s, c.turning = a, b, k, s, false
				c.nk = pickNext(b, k)
				table.insert(cityCars, c)
				break
			end
		end
	end
end

local function stepCity(dt, now)
	local groups = {}
	for _, c in ipairs(cityCars) do
		if c.turning then
			c.key, c.gs = c.b * 4096 + c.nxt, ROAD / 2 - (1 - c.u) * c.blen
		else
			c.key, c.gs = c.a * 4096 + c.b, c.s
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
				c.s, c.turning = ROAD / 2, false
				c.nk = pickNext(c.b, c.k)
			end
		else
			local len = edgeLen(c.a, c.b)
			local sEnd = len - ROAD / 2
			local limit = lead
			local light = lightFor(c.b, c.k <= 2, now)
			if light ~= "G" then
				local stopAt = len - ROAD / 2 - (NODES[c.b][4] == 1 and WALK or 0) - 1.5 - c.len / 2
				local canStop = (stopAt - c.s) > (c.v * c.v) / (2 * BRAKE) - 1
				if c.s <= stopAt + 0.5 and (light == "R" or canStop) then limit = math.min(limit, stopAt) end
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
			if c.s >= sEnd then startTurn(c) end
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

-- ring highway ---------------------------------------------------------------
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
	table.insert(lanes, { pts = pts, cum = cum, total = total })
end

local hwyCars = {}
for i = 1, HWY_CARS do
	local lane = (i - 1) % #lanes + 1
	local c = newVehicle(pickKind({ 0.55, 0.15, 0.05, 0.25 }))
	c.lane, c.seg = lane, 1
	c.s = (math.floor((i - 1) / #lanes) + rng:NextNumber() * 0.3) * lanes[lane].total / math.ceil(HWY_CARS / #lanes)
	c.vmax = (lane % 2 == 1) and rng:NextNumber(62, 72) or rng:NextNumber(72, 84)
	if c.kind >= 3 then c.vmax = math.min(c.vmax, 60) end
	c.v = c.vmax
	table.insert(hwyCars, c)
end

local function stepHighway(dt)
	for _, c in ipairs(hwyCars) do
		local lane = lanes[c.lane]
		local gap, leader = math.huge, nil
		for _, o in ipairs(hwyCars) do
			if o ~= c and o.lane == c.lane then
				local d = (o.s - c.s) % lane.total
				if d > 0 and d < gap then gap, leader = d, o end
			end
		end
		local free = leader and (gap - (leader.len + c.len) / 2 - 8) or math.huge
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

-- main loop ------------------------------------------------------------------
local lampTimer = 1
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local now = workspace:GetServerTimeNow()
	stepCity(dt, now)
	stepHighway(dt)
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	lampTimer += dt
	if lampTimer > 0.25 then
		lampTimer = 0
		updateLamps(now)
	end
end)
