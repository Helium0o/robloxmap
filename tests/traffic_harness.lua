local spsx = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
local ls = spsx:FindFirstChild("CityTraffic")
assert(ls, "no traffic script")
print("parts", STATS.parts, "max size", STATS.maxSize, "bad", #STATS.bad, "baseplate gone", workspace:FindFirstChild("Baseplate") == nil)
for i = 1, math.min(10, #STATS.bad) do print(STATS.bad[i]) end
print("lamps", #(STATS.tags.CityTrafficLamp or {}), "pointlights", STATS.byClass.PointLight, "surfaceguis", STATS.byClass.SurfaceGui)
local src = ls.Source
local fn, err = loadstring(src)
assert(fn, err)
fn()
local a = src:find("local NODES = ", 1, true)
local b = src:find("local VEH = ", 1, true)
local NODES, LINKS = loadstring(src:sub(a, b - 1) .. "\nreturn NODES, LINKS")()
local cc = tonumber(src:match("local CITY_CARS, HWY_CARS = (%d+)"))
local hc = tonumber(src:match("local CITY_CARS, HWY_CARS = %d+, (%d+)"))
print("city cars", cc, "hwy cars", hc, "nodes", #NODES, "moving parts", BULK.parts and #BULK.parts or 0)
local DT = 1 / 30
local lastPos = {}
local offroad, overlaps, samples = 0, 0, 0
local MINUTES = tonumber(MINUTES_OVERRIDE or 4)
for f = 1, 30 * 60 * MINUTES do
	ADVANCE(DT)
	for _, h in ipairs(HEARTBEAT) do h(DT) end
	if f % 15 == 0 then
		samples += 1
		local cfs = BULK.cframes
		local pos = {}
		for i = 1, cc + hc do
			local b0 = (i - 1) * 6
			pos[i] = (cfs[b0 + 3].p + cfs[b0 + 4].p) * 0.5
		end
		for i = 1, cc do
			local p = pos[i]
			local ok = false
			for n = 1, #NODES do
				local nx, nz = NODES[n][1], NODES[n][2]
				if math.abs(p.X - nx) < 16 and math.abs(p.Z - nz) < 16 then ok = true break end
				for _, k in ipairs({ 1, 3 }) do
					local m = LINKS[n][k]
					if m ~= 0 then
						local mx, mz = NODES[m][1], NODES[m][2]
						if k == 1 and p.X >= nx - 1 and p.X <= mx + 1 and math.abs(math.abs(p.Z - nz) - 6) < 1.5 then ok = true break end
						if k == 3 and p.Z >= nz - 1 and p.Z <= mz + 1 and math.abs(math.abs(p.X - nx) - 6) < 1.5 then ok = true break end
					end
				end
				if ok then break end
			end
			if not ok then
				offroad += 1
				if offroad < 5 then print("offroad", i, p.X, p.Z) end
			end
		end
		for i = 1, cc + hc do
			for j = i + 1, cc + hc do
				if (pos[i] - pos[j]).Magnitude < 4 then overlaps += 1 end
			end
		end
		if f % (30 * 30) == 0 then
			local stuck = 0
			for i = 1, cc + hc do
				if lastPos[i] and (pos[i] - lastPos[i]).Magnitude < 5 then stuck += 1 end
				lastPos[i] = pos[i]
			end
			print(("t=%ds cars barely moving over last 30s: %d"):format(f // 30, stuck))
		end
	end
end
print("samples", samples, "offroad samples", offroad, "overlapping pairs (<4 studs) summed over samples", overlaps)
