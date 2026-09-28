local spsx = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
local ls = spsx:FindFirstChild("CityTraffic")
assert(ls, "no traffic script")
print("parts", STATS.parts, "max size", STATS.maxSize, "bad", #STATS.bad, "baseplate gone", workspace:FindFirstChild("Baseplate") == nil)
for i = 1, math.min(10, #STATS.bad) do print(STATS.bad[i]) end
print("terrain writes", TERRAIN.writes, "voxels", TERRAIN.voxels, "solid", TERRAIN.solid)
print("lamps", #(STATS.tags.CityTrafficLamp or {}), "pointlights", STATS.byClass.PointLight, "surfaceguis", STATS.byClass.SurfaceGui, "wedges", STATS.byClass.WedgePart)
local fn, err = loadstring(ls.Source)
assert(fn, err)
fn()
local T = shared.CityTraffic
local NODES = T.nodes
print("city cars", #T.city, "hwy cars", #T.highway, "lanes", #T.lanes)
local DT = 1 / 30
local lastPos = {}
local offroad, badHeight, overlaps, samples = 0, 0, 0, 0
local MINUTES = tonumber(MINUTES_OVERRIDE or 3)
local function segDist(px, pz, a, b)
	local dx, dz = b[1] - a[1], b[3] - a[3]
	local l = dx * dx + dz * dz
	local t = l > 0 and ((px - a[1]) * dx + (pz - a[3]) * dz) / l or 0
	t = math.clamp(t, 0, 1)
	return math.sqrt((a[1] + dx * t - px) ^ 2 + (a[3] + dz * t - pz) ^ 2), a[2] + (b[2] - a[2]) * t
end
local all = {}
for _, c in ipairs(T.city) do table.insert(all, c) end
for _, c in ipairs(T.highway) do table.insert(all, c) end
for f = 1, math.floor(30 * 60 * MINUTES) do
	ADVANCE(DT)
	for _, h in ipairs(HEARTBEAT) do h(DT) end
	if f % 15 == 0 then
		samples += 1
		local cfs = BULK.cframes
		local pos = {}
		for i, c in ipairs(all) do
			pos[i] = (cfs[c.first + 2].p + cfs[c.first + 3].p) * 0.5
		end
		for i, c in ipairs(T.city) do
			local p = pos[i]
			if c.turning then
				local N = NODES[c.lane.to]
				if math.sqrt((p.X - N[1]) ^ 2 + (p.Z - N[3]) ^ 2) > N[8] + 16 then
					offroad += 1
					if offroad < 4 then print("turn far from junction", i, p.X, p.Z) end
				end
			else
				local best, by = math.huge, 0
				local pts = c.lane.pts
				for k = 1, #pts - 1 do
					local d, y = segDist(p.X, p.Z, pts[k], pts[k + 1])
					if d < best then best, by = d, y end
				end
				if best > 1.6 then
					offroad += 1
					if offroad < 4 then print("off lane", i, best, p.X, p.Z) end
				end
				if math.abs(p.Y - (by + 0.6 + 1.3)) > 1.6 then
					badHeight += 1
					if badHeight < 4 then print("wrong height", i, p.Y, by) end
				end
			end
		end
		for i = 1, #all do
			for j = i + 1, #all do
				if (pos[i] - pos[j]).Magnitude < 4 then overlaps += 1 end
			end
		end
		if f % (30 * 30) == 0 then
			local stuck = 0
			for i = 1, #all do
				if lastPos[i] and (pos[i] - lastPos[i]).Magnitude < 5 then stuck += 1 end
				lastPos[i] = pos[i]
			end
			print(("t=%ds cars barely moving over last 30s: %d"):format(f // 30, stuck))
		end
	end
end
print("samples", samples, "off-road samples", offroad, "wrong-height samples", badHeight, "overlapping pairs (<4 studs) summed over samples", overlaps)
