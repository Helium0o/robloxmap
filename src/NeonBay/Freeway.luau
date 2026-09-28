--[[
	Elevated freeway: ring road, bridge, ramps, pillars, lights and overhead signs.

	The freeway follows grid streets from intersection to intersection:
	  * straight-through intersections: the deck simply continues,
	  * 90 degree turns: a smooth curve (fillet) that cuts across the corner block,
	  * junctions (3+ connections) and dead ends: a flat square "plaza" deck,
	  * ramps: a deck that drops from the freeway to the next ground intersection over one block.
	Stretches over water become a suspension bridge with towers and glowing cables.
]]

local Grid = require(script.Parent.Grid)
local Palette = require(script.Parent.Palette)
local lookAt = require(script.Parent.Geometry).lookAt

local Freeway = {}

local DIRS = {
	N = Vector3.new(0, 0, -1),
	S = Vector3.new(0, 0, 1),
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
}

local function dirName(di: number, dj: number): string
	if di > 0 then
		return "E"
	elseif di < 0 then
		return "W"
	elseif dj > 0 then
		return "S"
	end
	return "N"
end

local function nodeKey(i: number, j: number): string
	return i .. ":" .. j
end

local function sign(v: number): number
	return if v > 0 then 1 elseif v < 0 then -1 else 0
end

local function horizontal(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z).Unit
end

local function rightOf(d: Vector3): Vector3
	return Vector3.new(-d.Z, 0, d.X)
end

--------------------------------------------------------------------------------------------
-- Planning: pure data, no instances. Streets and districts read it to stay out of the way.
--------------------------------------------------------------------------------------------

function Freeway.plan(grid, config)
	local fw = config.Freeway or { Lines = {}, Ramps = {}, Signs = {} }
	local width = config.DeckWidth
	local radius = config.FilletRadius
	local plan = {
		nodes = {},
		edges = {},
		ramps = {},
		edgeByKey = {},
		rampEdges = {}, -- ground street edges replaced by a ramp
		elevatedOver = {}, -- ground street edges with a freeway overhead
		zones = {}, -- cells partly covered by a curve: { i, j, cx, cz, r0, r1 }
	}

	local function getNode(i: number, j: number)
		local key = nodeKey(i, j)
		local node = plan.nodes[key]
		if not node then
			assert(
				i >= 0 and i <= grid.nx and j >= 0 and j <= grid.nz,
				string.format("Freeway node (%d, %d) is outside the map", i, j)
			)
			local x, z = grid:node(i, j)
			node = { i = i, j = j, x = x, z = z, key = key, conns = {}, elevated = true }
			plan.nodes[key] = node
		end
		return node
	end

	for _, line in fw.Lines do
		local corners = line.corners
		local last = if line.closed then #corners else #corners - 1
		for c = 1, last do
			local p = corners[c]
			local q = corners[(c % #corners) + 1]
			assert(
				p[1] == q[1] or p[2] == q[2],
				string.format("Freeway %q: corners must share a row or column", line.name or "?")
			)
			local di, dj = sign(q[1] - p[1]), sign(q[2] - p[2])
			local i, j = p[1], p[2]
			while i ~= q[1] or j ~= q[2] do
				local a, b = getNode(i, j), getNode(i + di, j + dj)
				local dir, ei, ej = Grid.edgeBetween(a.i, a.j, b.i, b.j)
				local key = Grid.edgeKey(dir, ei, ej)
				if not plan.edgeByKey[key] then
					local info = grid:edge(dir, ei, ej)
					local edge = {
						key = key,
						dir = dir,
						i = ei,
						j = ej,
						a = a,
						b = b,
						line = line.name or "Freeway",
						overWater = not (info.left and info.left.def.land) and not (info.right and info.right.def.land),
					}
					plan.edgeByKey[key] = edge
					table.insert(plan.edges, edge)
					a.conns[dirName(b.i - a.i, b.j - a.j)] = edge
					b.conns[dirName(a.i - b.i, a.j - b.j)] = edge
					if not edge.overWater and grid:hasStreet(dir, ei, ej) then
						plan.elevatedOver[key] = true
					end
				end
				i += di
				j += dj
			end
		end
	end

	for _, ramp in fw.Ramps or {} do
		local top = plan.nodes[nodeKey(ramp.from[1], ramp.from[2])]
		assert(top, string.format("Ramp start (%d, %d) is not on the freeway", ramp.from[1], ramp.from[2]))
		local gi, gj = ramp.to[1], ramp.to[2]
		assert(not plan.nodes[nodeKey(gi, gj)], string.format("Ramp end (%d, %d) must be a ground intersection", gi, gj))
		local dir, ei, ej = Grid.edgeBetween(top.i, top.j, gi, gj)
		assert(grid:hasStreet(dir, ei, ej), string.format("Ramp to (%d, %d) must follow a street", gi, gj))
		local d = dirName(gi - top.i, gj - top.j)
		assert(not top.conns[d], string.format("Ramp from (%d, %d) overlaps the freeway", top.i, top.j))
		local gx, gz = grid:node(gi, gj)
		local key = Grid.edgeKey(dir, ei, ej)
		local edge = { key = key, dir = dir, i = ei, j = ej, top = top, d = d, gx = gx, gz = gz, ramp = true }
		top.conns[d] = edge
		plan.rampEdges[key] = true
		plan.edgeByKey[key] = edge
		table.insert(plan.ramps, edge)
	end

	-- Node shapes and where each connection leaves the node ("port" distance from the centre).
	for _, node in plan.nodes do
		local names = {}
		for name in node.conns do
			table.insert(names, name)
		end
		table.sort(names)
		node.names = names
		if #names == 2 and DIRS[names[1]]:Dot(DIRS[names[2]]) < -0.5 then
			node.kind = "straight"
			node.port = 0
		elseif #names == 2 then
			node.kind = "corner"
			node.port = radius
			local d1, d2 = DIRS[names[1]], DIRS[names[2]]
			local center = Vector3.new(node.x, 0, node.z) + (d1 + d2) * radius
			node.arcCenter = center
			node.d1, node.d2 = d1, d2
			local quadrant = d1 + d2
			local ci = node.i + (if quadrant.X > 0 then 0 else -1)
			local cj = node.j + (if quadrant.Z > 0 then 0 else -1)
			table.insert(plan.zones, {
				i = ci,
				j = cj,
				cx = center.X,
				cz = center.Z,
				r0 = radius - width / 2 - 10,
				r1 = radius + width / 2 + 10,
				-- the curve only occupies the quarter of the ring that faces the intersection
				d1 = d1,
				d2 = d2,
			})
		else
			node.kind = "plaza"
			node.port = width / 2
		end
	end

	-- True when an axis-aligned rectangle inside cell (i, j) would hit a freeway curve.
	function plan.blocksRect(_, i: number, j: number, x0: number, z0: number, x1: number, z1: number): boolean
		for _, zone in plan.zones do
			if zone.i == i and zone.j == j then
				-- clip the rectangle to the curve's quarter (plus the deck half-width)
				local margin = width / 2 + 10
				for _, d in { zone.d1, zone.d2 } do
					if d.X > 0 then
						x1 = math.min(x1, zone.cx + margin)
					elseif d.X < 0 then
						x0 = math.max(x0, zone.cx - margin)
					elseif d.Z > 0 then
						z1 = math.min(z1, zone.cz + margin)
					else
						z0 = math.max(z0, zone.cz - margin)
					end
				end
				if x1 <= x0 or z1 <= z0 then
					continue
				end
				local nx = math.clamp(zone.cx, x0, x1)
				local nz = math.clamp(zone.cz, z0, z1)
				local near = math.sqrt((nx - zone.cx) ^ 2 + (nz - zone.cz) ^ 2)
				local fx = math.max(math.abs(x0 - zone.cx), math.abs(x1 - zone.cx))
				local fz = math.max(math.abs(z0 - zone.cz), math.abs(z1 - zone.cz))
				local far = math.sqrt(fx * fx + fz * fz)
				if near <= zone.r1 and far >= zone.r0 then
					return true
				end
			end
		end
		return false
	end

	function plan.blocksPoint(self, i: number, j: number, x: number, z: number, r: number): boolean
		return self:blocksRect(i, j, x - r, z - r, x + r, z + r)
	end

	return plan
end

--------------------------------------------------------------------------------------------
-- Geometry helpers
--------------------------------------------------------------------------------------------

-- Extra length needed at a horizontal bend so the outside edge of a strip has no gap.
local function bendExtension(p0: Vector3, p1: Vector3, p2: Vector3, width: number): number
	local a, b = horizontal(p1 - p0), horizontal(p2 - p1)
	local cosTheta = math.clamp(a:Dot(b), -1, 1)
	local theta = math.acos(cosTheta)
	return width / 2 * math.tan(theta / 2) + 0.05
end

-- One part per span along a polyline of top-surface points.
local function sweep(B, parent, name, pts, width, depth, color, mat, extra)
	local n = #pts
	for k = 1, n - 1 do
		local a, b = pts[k], pts[k + 1]
		local seg = b - a
		local len = seg.Magnitude
		if len > 0.05 then
			local u = seg / len
			local e0 = if k > 1 then bendExtension(pts[k - 1], a, b, width) else 0
			local e1 = if k < n - 1 then bendExtension(a, b, pts[k + 2], width) else 0
			local top = a + u * ((len + e1 - e0) / 2)
			local spec = {
				parent = parent,
				name = name,
				size = Vector3.new(width, depth, len + e0 + e1),
				cf = lookAt(top, top + u) * CFrame.new(0, -depth / 2, 0),
				color = color,
				mat = mat,
			}
			if extra then
				for key, value in extra do
					spec[key] = value
				end
			end
			B:part(spec)
		end
	end
end

-- Offsets a polyline sideways (positive = right of travel) and optionally up.
local function offset(pts, side: number, up: number?)
	local out = {}
	local n = #pts
	local lift = Vector3.new(0, up or 0, 0)
	for k = 1, n do
		local dirIn = if k > 1 then horizontal(pts[k] - pts[k - 1]) else nil
		local dirOut = if k < n then horizontal(pts[k + 1] - pts[k]) else nil
		local d = if dirIn and dirOut then (dirIn + dirOut).Unit else (dirIn or dirOut)
		local right = rightOf(d)
		local miter = 1
		if dirIn and dirOut then
			miter = 1 / math.max(right:Dot(rightOf(dirIn)), 0.5)
		end
		out[k] = pts[k] + right * (side * miter) + lift
	end
	return out
end

local function raise(pts, dy: number)
	local out = {}
	for k, p in pts do
		out[k] = p + Vector3.new(0, dy, 0)
	end
	return out
end

-- Smooth ramp profile: 0 at u = 0, 1 at u = 1, zero slope at both ends.
local function easeRamp(u: number): number
	local a = 0.25
	if u < a then
		return u * u / (2 * a * (1 - a))
	elseif u > 1 - a then
		return 1 - (1 - u) * (1 - u) / (2 * a * (1 - a))
	end
	return (u - a / 2) / (1 - a)
end

--------------------------------------------------------------------------------------------
-- Building
--------------------------------------------------------------------------------------------

local ACCENT = {
	Ring = Palette.Neon[1],
	["Bay Bridge"] = Palette.Neon[2],
}

local function roadSurface(B, folder, config, pts, accent, options)
	local width = config.DeckWidth
	local depth = options.depth or config.DeckThickness
	local bw = 1.6
	local bh = config.BarrierHeight
	local noCollideLine = { collide = false, shadow = false }
	sweep(B, folder, "Deck", pts, width, depth, Palette.Asphalt, Enum.Material.Asphalt)
	for _, side in { -1, 1 } do
		local rail = raise(offset(pts, side * (width / 2 - bw / 2)), bh)
		sweep(B, folder, "Barrier", rail, bw, bh + 0.3, Palette.Barrier, Enum.Material.Concrete)
		local line = raise(offset(pts, side * 0.7), 0.06)
		sweep(B, folder, "CenterLine", line, 0.45, 0.12, Palette.LineYellow, Enum.Material.SmoothPlastic, noCollideLine)
		if accent and not options.noGlow then
			local glow = raise(offset(pts, side * (width / 2 + 0.2)), -0.6)
			sweep(B, folder, "Underglow", glow, 0.4, 0.5, accent, Enum.Material.Neon, noCollideLine)
		end
	end
end

-- Dashed lane lines on a straight, flat stretch.
local function laneDashes(B, folder, config, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	if len < 30 then
		return
	end
	local u = (b - a) / len
	local right = rightOf(u)
	local dash, period = 10, 30
	local count = math.floor((len - 10) / period)
	local start = (len - (count - 1) * period) / 2
	for k = 0, count - 1 do
		local c = a + u * (start + k * period) + Vector3.new(0, 0.06, 0)
		for _, side in { -1, 1 } do
			local p = c + right * (side * config.LaneWidth * 0.95)
			B:part({
				parent = folder,
				name = "LaneDash",
				size = Vector3.new(0.45, 0.12, dash),
				cf = lookAt(p, p + u) * CFrame.new(0, -0.06, 0),
				color = Palette.LineWhite,
				collide = false,
				shadow = false,
			})
		end
	end
end

local function lamp(B, folder, base: Vector3, toward: Vector3)
	-- base: top of the barrier; toward: horizontal unit vector pointing over the road
	local poleHeight = 16
	B:box(folder, "LampPole", base + Vector3.new(0, poleHeight / 2, 0), Vector3.new(0.8, poleHeight, 0.8), Palette.Pole, Enum.Material.Metal, {
		shadow = false,
	})
	local top = base + Vector3.new(0, poleHeight, 0)
	local tip = top + toward * 7
	B:beam(folder, "LampArm", top, tip, 0.5, 0.5, Palette.Pole, Enum.Material.Metal, { collide = false, shadow = false })
	local head = B:box(folder, "LampHead", tip - Vector3.new(0, 0.4, 0), Vector3.new(2.6, 0.5, 1.6), Palette.Sodium, Enum.Material.Neon, {
		collide = false,
		shadow = false,
	})
	B:spotLight(head, Enum.NormalId.Bottom, Palette.SodiumLight, 55, 2.2, 120)
end

local function pillar(B, folder, config, x: number, z: number, along: Vector3, groundY: number)
	local deckBottom = config.FreewayHeight - config.DeckThickness
	local capH = 3
	local colTop = deckBottom - capH
	B:box(
		folder,
		"Pillar",
		Vector3.new(x, (groundY + colTop) / 2, z),
		Vector3.new(6, colTop - groundY, 6),
		Palette.Concrete,
		Enum.Material.Concrete
	)
	local p = Vector3.new(x, deckBottom - capH / 2, z)
	B:part({
		parent = folder,
		name = "PierCap",
		size = Vector3.new(config.DeckWidth - 6, capH, 7),
		cf = lookAt(p, p + along),
		color = Palette.ConcreteDark,
		mat = Enum.Material.Concrete,
	})
end

local function median(B, folder, config, a: Vector3, b: Vector3)
	local len = (b - a).Magnitude
	if len < 10 then
		return
	end
	local u = (b - a) / len
	local c = (a + b) / 2 + Vector3.new(0, config.CurbHeight / 2, 0)
	B:part({
		parent = folder,
		name = "Median",
		size = Vector3.new(7, config.CurbHeight, len),
		cf = lookAt(c, c + u),
		color = Palette.Curb,
		mat = Enum.Material.Concrete,
	})
end

local function buildEdge(B, folder, config, grid, edge)
	local H = config.FreewayHeight
	local a, b = edge.a, edge.b
	local pa = Vector3.new(a.x, H, a.z)
	local pb = Vector3.new(b.x, H, b.z)
	local u = (pb - pa).Unit
	local startP = pa + u * a.port
	local endP = pb - u * b.port
	local accent = ACCENT[edge.line] or Palette.Neon[3]
	if (endP - startP):Dot(u) > 0.1 then
		roadSurface(B, folder, config, { startP, endP }, accent, {
			depth = if edge.overWater then 5 else config.DeckThickness,
		})
		laneDashes(B, folder, config, startP, endP)
		-- lamps alternate sides
		local right = rightOf(u)
		local len = (endP - startP).Magnitude
		local lamps = math.max(1, math.floor(len / 120 * config.LampDensity + 0.5))
		for k = 1, lamps do
			local t = (k - 0.5) / lamps
			local side = if k % 2 == 0 then -1 else 1
			local base = startP:Lerp(endP, t) + right * (side * (config.DeckWidth / 2 - 0.8)) + Vector3.new(0, config.BarrierHeight, 0)
			lamp(B, folder, base, right * -side)
		end
	end
	-- supports
	local span = pb - pa
	if not edge.overWater then
		for _, t in { 1 / 3, 2 / 3 } do
			local p = pa + span * t
			local fromStart = (p - pa).Magnitude
			local fromEnd = (pb - p).Magnitude
			if fromStart > a.port + 8 and fromEnd > b.port + 8 then
				pillar(B, folder, config, p.X, p.Z, u, config.CurbHeight)
			end
		end
		if grid:hasStreet(edge.dir, edge.i, edge.j) then
			local clear = config.RoadWidth / 2 + 8
			local m0 = Vector3.new(pa.X, 0, pa.Z) + u * math.max(clear, a.port)
			local m1 = Vector3.new(pb.X, 0, pb.Z) - u * math.max(clear, b.port)
			if (m1 - m0):Dot(u) > 10 then
				median(B, folder, config, m0, m1)
			end
		end
	end
end

local function buildCorner(B, folder, config, node, line)
	local H = config.FreewayHeight
	local R = config.FilletRadius
	local center = node.arcCenter
	local d1, d2 = node.d1, node.d2
	local steps = 12
	local pts = {}
	for k = 0, steps do
		local theta = (k / steps) * math.pi / 2
		local p = center - (d2 * math.cos(theta) + d1 * math.sin(theta)) * R
		pts[k + 1] = Vector3.new(p.X, H, p.Z)
	end
	roadSurface(B, folder, config, pts, ACCENT[line] or Palette.Neon[3], {})
	local mid = center - (d1 + d2).Unit * R
	local tangent = (d1 - d2).Unit
	pillar(B, folder, config, mid.X, mid.Z, tangent, 0.8)
	-- two lamps on the outside of the curve
	for _, theta in { math.pi / 8, 3 * math.pi / 8 } do
		local radial = -(d2 * math.cos(theta) + d1 * math.sin(theta))
		local base = center + radial * (R + config.DeckWidth / 2 - 0.8)
		lamp(B, folder, Vector3.new(base.X, H + config.BarrierHeight, base.Z), -radial)
	end
end

local function buildPlaza(B, folder, config, node)
	local H = config.FreewayHeight
	local w = config.DeckWidth
	local T = config.DeckThickness
	B:box(folder, "Plaza", Vector3.new(node.x, H - T / 2, node.z), Vector3.new(w, T, w), Palette.Asphalt, Enum.Material.Asphalt)
	local bh = config.BarrierHeight
	for name, d in DIRS do
		if not node.conns[name] then
			local c = Vector3.new(node.x, H + bh / 2, node.z) + d * (w / 2 - 0.8)
			local size = if math.abs(d.X) > 0 then Vector3.new(1.6, bh, w) else Vector3.new(w, bh, 1.6)
			B:box(folder, "Barrier", c, size, Palette.Barrier, Enum.Material.Concrete)
		end
	end
end

local function buildRamp(B, folder, config, edge)
	local H = config.FreewayHeight
	local top = edge.top
	local d = DIRS[edge.d]
	local startP = Vector3.new(top.x, 0, top.z) + d * top.port
	local endP = Vector3.new(edge.gx, 0, edge.gz) - d * (config.RoadWidth / 2)
	local steps = 16
	local pts = {}
	for k = 0, steps do
		local u = k / steps
		local p = startP:Lerp(endP, u)
		pts[k + 1] = Vector3.new(p.X, H * (1 - easeRamp(u)), p.Z)
	end
	-- solid embankment under a thin road surface
	for k = 1, steps do
		local a, b = pts[k], pts[k + 1]
		local seg = b - a
		local len = seg.Magnitude
		local u = seg / len
		local depth = math.max(a.Y, b.Y) + 4
		local topC = (a + b) / 2 - Vector3.new(0, 0.2, 0)
		B:part({
			parent = folder,
			name = "Embankment",
			size = Vector3.new(config.DeckWidth + 0.6, depth, len + 0.1),
			cf = lookAt(topC, topC + u) * CFrame.new(0, -depth / 2, 0),
			color = Palette.Concrete,
			mat = Enum.Material.Concrete,
		})
	end
	roadSurface(B, folder, config, pts, nil, { depth = 1.2, noGlow = true })
end

-- Suspension bridge dressing for a straight run of over-water edges.
local function buildSuspension(B, folder, config, p0: Vector3, p1: Vector3)
	local H = config.FreewayHeight
	local water = config.WaterLevel
	local L = (p1 - p0).Magnitude
	local u = (p1 - p0) / L
	local right = rightOf(u)
	local halfW = config.DeckWidth / 2 + 5
	local towerTop = H + 150
	local sagLow = H + 14
	local t1, t2 = L * 0.25, L * 0.75
	local cableColor = Palette.Neon[2]

	for _, s in { t1, t2 } do
		local c = p0 + u * s
		-- foundation in the water
		local pierC = Vector3.new(c.X, water - 14, c.Z)
		B:part({
			parent = folder,
			name = "TowerPier",
			size = Vector3.new(halfW * 2 + 20, 32, 26),
			cf = lookAt(pierC, pierC + u),
			color = Palette.ConcreteDark,
			mat = Enum.Material.Concrete,
		})
		for _, side in { -1, 1 } do
			local base = Vector3.new(c.X, water, c.Z) + right * (side * halfW)
			local legTop = Vector3.new(base.X, towerTop, base.Z)
			B:part({
				parent = folder,
				name = "TowerLeg",
				size = Vector3.new(8, towerTop - water, 10),
				cf = lookAt((base + legTop) / 2, (base + legTop) / 2 + u),
				color = Palette.Metal,
				mat = Enum.Material.Metal,
			})
			-- glowing accents up both faces of the leg
			for _, face in { -1, 1 } do
				local g = Vector3.new(base.X, (H + towerTop) / 2, base.Z) + u * (face * 5.2)
				B:part({
					parent = folder,
					name = "TowerGlow",
					size = Vector3.new(1.2, towerTop - H - 8, 0.4),
					cf = lookAt(g, g + u),
					color = cableColor,
					mat = Enum.Material.Neon,
					collide = false,
					shadow = false,
				})
			end
			local beacon = B:box(folder, "AviationLight", legTop + Vector3.new(0, 1, 0), Vector3.new(2, 2, 2), Palette.AviationRed, Enum.Material.Neon, {
				collide = false,
				shadow = false,
			})
			beacon:AddTag("NeonBayBlink")
			B:pointLight(beacon, Palette.AviationRed, 30, 3)
		end
		-- cross beams
		for _, y in { H - 8, H + 60, H + 115, towerTop - 4 } do
			local cc = Vector3.new(c.X, y, c.Z)
			B:part({
				parent = folder,
				name = "TowerBeam",
				size = Vector3.new(halfW * 2 + 8, if y < H then 8 else 6, 8),
				cf = lookAt(cc, cc + u),
				color = Palette.Metal,
				mat = Enum.Material.Metal,
			})
		end
	end

	-- cable height along the bridge (s = distance from p0)
	local anchorY = H + config.BarrierHeight + 1
	local function cableY(s: number): number
		if s <= t1 then
			local t = s / t1
			return anchorY + (towerTop - anchorY) * t - 12 * 4 * t * (1 - t)
		elseif s >= t2 then
			local t = (L - s) / (L - t2)
			return anchorY + (towerTop - anchorY) * t - 12 * 4 * t * (1 - t)
		end
		local t = (s - t1) / (t2 - t1)
		return sagLow + (towerTop - sagLow) * (2 * t - 1) ^ 2
	end

	local step = 32
	local count = math.floor(L / step)
	for _, side in { -1, 1 } do
		local prev = nil
		for k = 0, count do
			local s = math.min(L, k * step)
			local p = p0 + u * s + right * (side * halfW)
			local cp = Vector3.new(p.X, cableY(s), p.Z)
			if prev then
				B:cylinder(folder, "Cable", prev, cp, 1.6, cableColor, Enum.Material.Neon, { collide = false, shadow = false })
			end
			prev = cp
			local nearTower = math.abs(s - t1) < 6 or math.abs(s - t2) < 6
			if k > 0 and k < count and not nearTower then
				local deckTop = H + config.BarrierHeight
				if cp.Y - deckTop > 2 then
					B:box(
						folder,
						"Hanger",
						Vector3.new(p.X, (cp.Y + deckTop) / 2, p.Z),
						Vector3.new(0.5, cp.Y - deckTop, 0.5),
						Palette.MetalDark,
						Enum.Material.Metal,
						{ collide = false, shadow = false }
					)
				end
			end
		end
	end
end

local function buildSign(B, folder, config, plan, sign)
	local a = plan.nodes[nodeKey(sign.at[1], sign.at[2])]
	local b = plan.nodes[nodeKey(sign.toward[1], sign.toward[2])]
	assert(a and b, "Freeway sign must be placed between two freeway intersections")
	local H = config.FreewayHeight
	local pa, pb = Vector3.new(a.x, H, a.z), Vector3.new(b.x, H, b.z)
	local u = (pb - pa).Unit
	local right = rightOf(u)
	local c = pa + u * (a.port + 40)
	local w = config.DeckWidth
	local postH = 26
	for _, side in { -1, 1 } do
		local base = c + right * (side * (w / 2 + 1.5))
		B:box(folder, "GantryPost", base + Vector3.new(0, postH / 2 - 4, 0), Vector3.new(1.4, postH + 8, 1.4), Palette.Metal, Enum.Material.Metal)
	end
	local beamC = c + Vector3.new(0, postH - 1, 0)
	B:part({
		parent = folder,
		name = "GantryBeam",
		size = Vector3.new(w + 6, 1.4, 1.4),
		cf = lookAt(beamC, beamC + u),
		color = Palette.Metal,
		mat = Enum.Material.Metal,
	})
	local boardC = c + Vector3.new(0, postH - 7, 0)
	local board = B:part({
		parent = folder,
		name = "SignBoard",
		size = Vector3.new(w - 8, 9, 0.6),
		cf = lookAt(boardC, boardC - u),
		color = Palette.SignGreen,
		mat = Enum.Material.SmoothPlastic,
		collide = false,
	})
	B:text(board, Enum.NormalId.Front, sign.text, {
		font = Enum.Font.Highway,
		glow = 1.2,
		pixelsPerStud = 16,
	})
end

function Freeway.build(B, root, grid, config, plan)
	local folder = B:group(root, "Freeway")
	local lines = {}
	for _, edge in plan.edges do
		local group = B:group(folder, edge.line)
		lines[edge.line] = group
		buildEdge(B, group, config, grid, edge)
	end
	for _, node in plan.nodes do
		local anyEdge = nil
		for _, e in node.conns do
			if not e.ramp then
				anyEdge = e
				break
			end
		end
		local group = if anyEdge then lines[anyEdge.line] else folder
		if node.kind == "corner" then
			buildCorner(B, group, config, node, anyEdge and anyEdge.line)
		elseif node.kind == "plaza" then
			buildPlaza(B, group, config, node)
		end
	end
	local ramps = B:group(folder, "Ramps")
	for _, edge in plan.ramps do
		buildRamp(B, ramps, config, edge)
	end
	-- Suspension bridges: consecutive over-water edges of one line (edges are stored in
	-- travel order, so a run is a contiguous stretch of the list).
	local runs = {}
	local current = nil
	for _, edge in plan.edges do
		if edge.overWater and current and current[#current].b == edge.a and current[#current].line == edge.line then
			table.insert(current, edge)
		elseif edge.overWater then
			current = { edge }
			table.insert(runs, current)
		else
			current = nil
		end
	end
	for _, run in runs do
		local p0 = Vector3.new(run[1].a.x, config.FreewayHeight, run[1].a.z)
		local p1 = Vector3.new(run[#run].b.x, config.FreewayHeight, run[#run].b.z)
		local group = B:group(folder, run[1].line)
		local straight = true
		for _, e in run do
			local v = Vector3.new(e.b.x - e.a.x, 0, e.b.z - e.a.z).Unit
			if v:Dot((p1 - p0).Unit) < 0.999 then
				straight = false
			end
		end
		if #run >= 3 and straight then
			local model = B:group(group, "Suspension", "Model")
			model.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
			buildSuspension(B, model, config, p0, p1)
		else
			for _, e in run do
				local a = Vector3.new(e.a.x, 0, e.a.z)
				local b = Vector3.new(e.b.x, 0, e.b.z)
				local u = (b - a).Unit
				for _, t in { 1 / 3, 2 / 3 } do
					local p = a:Lerp(b, t)
					pillar(B, group, config, p.X, p.Z, u, config.WaterLevel - 30)
				end
			end
		end
	end
	for _, sign in (config.Freeway and config.Freeway.Signs) or {} do
		buildSign(B, B:group(folder, "Signs"), config, plan, sign)
	end
	return folder
end

return Freeway
