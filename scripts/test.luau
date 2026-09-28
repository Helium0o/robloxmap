--[[
	Offline checks for the Neon Bay generator. Run from the repository root:

		lune run scripts/test.luau

	Builds the city in memory and verifies geometry that is easy to break when editing:
	part sizes, ramp surfaces, the freeway clearance, overlapping road slabs, the spawn...
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local RbxEnv = require("./lib/rbxenv")

local failures = 0
local checks = 0
local function check(ok: boolean, message: string)
	checks += 1
	if not ok then
		failures += 1
		print("FAIL  " .. message)
	end
end

local function build(seed: number?)
	local game = roblox.Instance.new("DataModel")
	local generator = RbxEnv.loadTree("src/NeonBay", "NeonBay")
	generator.Parent = game:GetService("ServerStorage")
	local env = RbxEnv.new(game)
	local NeonBay = env.require(generator)
	local root, stats = NeonBay.build({ seed = seed })
	return root, stats, env, generator
end

local root, stats, env, generator = build()
local Geometry = env.require(generator.Geometry)
local Config = env.require(generator.Config)

-- 1. basic stats -------------------------------------------------------------------------
check(stats.parts > 5000, "city has a reasonable number of parts: " .. stats.parts)
check(stats.parts < 40000, "city stays under 40k parts: " .. stats.parts)
check(stats.oversize == 0, "no part exceeds 2048 studs")
check(stats.spawn ~= nil and stats.spawn.ClassName == "SpawnLocation", "spawn location exists")

local parts = {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	end
end
local badSize, unanchored = 0, 0
for _, p in parts do
	local s = p.Size
	if s.X <= 0 or s.Y <= 0 or s.Z <= 0 or s.X > 2048 or s.Y > 2048 or s.Z > 2048 then
		badSize += 1
	end
	if not p.Anchored then
		unanchored += 1
	end
end
check(badSize == 0, "all part sizes are within (0, 2048]: " .. badSize .. " bad")
check(unanchored == 0, "all parts are anchored: " .. unanchored .. " loose")

-- 2. lookAt matches the direction for any vector ------------------------------------------
local dirs = {
	Vector3 = nil,
}
local V = roblox.Vector3
for _, d in { V.new(1, 0, 0), V.new(0, 0, 1), V.new(-1, 0, 0), V.new(0, 0, -1), V.new(1, 0, 1), V.new(3, 1, -2), V.new(0, -1, 5), V.new(0, 1, 0), V.new(0.2, -1, 0) } do
	local cf = Geometry.lookAt(V.new(5, 6, 7), V.new(5, 6, 7) + d)
	local err = (cf.LookVector - d.Unit).Magnitude
	check(err < 1e-4, string.format("lookAt(%s) looks the right way (err %.5f)", tostring(d), err))
	check(math.abs(cf.RightVector:Dot(cf.LookVector)) < 1e-4, "lookAt frame is orthogonal")
	if math.abs(d.Unit.Y) < 0.99 then
		check(math.abs(cf.RightVector.Y) < 1e-4 and cf.UpVector.Y > 0, "lookAt keeps the frame upright")
	end
end
_ = dirs

-- 3. ramp surfaces are continuous and reach both levels ----------------------------------
local ramps = root.Freeway.Ramps
local function topEnds(part)
	local cf, size = part.CFrame, part.Size
	local a = cf * V.new(0, size.Y / 2, size.Z / 2)
	local b = cf * V.new(0, size.Y / 2, -size.Z / 2)
	return a, b
end
local decks = {}
for _, p in ramps:GetChildren() do
	if p.Name == "Deck" then
		table.insert(decks, p)
	end
end
check(#decks >= 4 * 16, "every ramp has deck segments: " .. #decks)
local maxGap, maxHeight, minHeight = 0, -math.huge, math.huge
for _, p in decks do
	local a, b = topEnds(p)
	maxHeight = math.max(maxHeight, a.Y, b.Y)
	minHeight = math.min(minHeight, a.Y, b.Y)
	-- the end of each segment must touch the start of another one (or be a ramp end)
	local best = math.huge
	for _, q in decks do
		if q ~= p then
			local qa = topEnds(q)
			best = math.min(best, (qa - b).Magnitude)
		end
	end
	local isEnd = math.abs(b.Y) < 0.6
	if not isEnd then
		maxGap = math.max(maxGap, best)
	end
end
check(maxGap < 0.5, string.format("ramp segments join up (largest gap %.2f studs)", maxGap))
check(math.abs(maxHeight - Config.FreewayHeight) < 0.5, "ramps start at freeway height: " .. maxHeight)
check(minHeight < 0.6, "ramps come down to street level: " .. minHeight)

-- 4. no two asphalt slabs overlap (coplanar overlaps flicker) -----------------------------
local slabs = {}
for _, d in root.Ground:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "Asphalt" then
		local p, s = d.CFrame.Position, d.Size
		table.insert(slabs, { p.X - s.X / 2, p.Z - s.Z / 2, p.X + s.X / 2, p.Z + s.Z / 2 })
	end
end
local overlaps = 0
for i = 1, #slabs do
	local a = slabs[i]
	for j = i + 1, #slabs do
		local b = slabs[j]
		local w = math.min(a[3], b[3]) - math.max(a[1], b[1])
		local h = math.min(a[4], b[4]) - math.max(a[2], b[2])
		if w > 0.01 and h > 0.01 then
			overlaps += 1
		end
	end
end
check(overlaps == 0, "asphalt slabs do not overlap: " .. overlaps .. " overlaps")

-- 5. buildings stay clear of the elevated freeway ----------------------------------------
local bodies = {}
local cellSize = 64
local hash = {}
for _, d in root.Districts:GetDescendants() do
	if d:IsA("BasePart") and (d.Name == "Body" or d.Name == "Tower") and d.Parent.Name ~= "ParkedCar" and d.Parent.Name ~= "Airliner" then
		local p, s = d.CFrame.Position, d.Size
		-- district buildings are axis aligned or turned by 90 degrees
		local r = d.CFrame.RightVector
		local sx, sz = if math.abs(r.X) > 0.5 then s.X else s.Z, if math.abs(r.X) > 0.5 then s.Z else s.X
		local box = { p.X - sx / 2, p.Y - s.Y / 2, p.Z - sz / 2, p.X + sx / 2, p.Y + s.Y / 2, p.Z + sz / 2, d }
		table.insert(bodies, box)
		for gx = math.floor(box[1] / cellSize), math.floor(box[4] / cellSize) do
			for gz = math.floor(box[3] / cellSize), math.floor(box[6] / cellSize) do
				local key = gx .. ":" .. gz
				hash[key] = hash[key] or {}
				table.insert(hash[key], box)
			end
		end
	end
end
local hits = {}
for _, d in root.Freeway:GetDescendants() do
	if d:IsA("BasePart") and (d.Name == "Deck" or d.Name == "Plaza") then
		local cf, s = d.CFrame, d.Size
		for u = -0.5, 0.5, 0.125 do
			for w = -0.5, 0.5, 0.05 do
				local p = cf * V.new(u * s.X, -s.Y / 2, w * s.Z)
				local bucket = hash[math.floor(p.X / cellSize) .. ":" .. math.floor(p.Z / cellSize)]
				if bucket then
					for _, b in bucket do
						if p.X > b[1] and p.X < b[4] and p.Z > b[3] and p.Z < b[6] and p.Y < b[5] and p.Y > b[2] then
							hits[b[7]] = true
						end
					end
				end
			end
		end
	end
end
local hitCount = 0
for part in hits do
	hitCount += 1
	if hitCount <= 5 then
		print("      building under the freeway: " .. part:GetFullName())
	end
end
check(hitCount == 0, "no building pokes through a freeway deck: " .. hitCount)
check(#bodies > 500, "districts produced buildings: " .. #bodies)

-- 6. same seed, same city ------------------------------------------------------------------
local root2, stats2 = build()
check(stats2.parts == stats.parts, "building twice gives the same part count")
local a, b = root:GetDescendants(), root2:GetDescendants()
check(#a == #b, "building twice gives the same instance count")
local _, stats3 = build(12345)
check(stats3.parts ~= stats.parts, "a different seed changes the city")

-- 7. LampDensity really thins out the street lamps --------------------------------------
do
	local game = roblox.Instance.new("DataModel")
	local tree = RbxEnv.loadTree("src/NeonBay", "NeonBay")
	tree.Parent = game:GetService("ServerStorage")
	local env2 = RbxEnv.new(game)
	local NeonBay = env2.require(tree)
	local half = table.clone(env2.require(tree.Config))
	half.LampDensity = 0.5
	local _, halfStats = NeonBay.build({ config = half })
	local ratio = halfStats.lights / stats.lights
	check(ratio > 0.4 and ratio < 0.8, string.format("LampDensity 0.5 keeps %.0f%% of the lights", ratio * 100))
end

-- 8. no raw CFrame.lookAt in the generator (see Geometry.luau) ----------------------------
local function scan(dir: string)
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			scan(path)
		elseif entry ~= "Geometry.luau" and string.match(entry, "%.luau$") then
			local source = fs.readFile(path)
			check(not string.find(source, "CFrame.lookAt", 1, true), path .. " uses Geometry.lookAt, not CFrame.lookAt")
		end
	end
end
scan("src/NeonBay")

print(string.format("%d checks, %d failed", checks, failures))
if failures > 0 then
	process.exit(1)
end
