--[[
	Test harness: loads a converter .rbxmx in Lune, fakes the imported MeshParts, then runs
	Tools.assemble / buildRoad / placeSpawn and checks the results.

		lune run tools/assetto/tests/run_tools.luau <path to _AC.rbxmx>
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local RbxEnv = require("../../../scripts/lib/rbxenv")

local V = roblox.Vector3
local path = process.args[1]
assert(path, "usage: run_tools.luau <file.rbxmx>")

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local folder = roblox.deserializeModel(fs.readFile(path))[1]
folder.Parent = workspace
local env = RbxEnv.new(game)
local Manifest = env.require(folder.Manifest)
local Tools = env.require(folder.Tools)

local function fail(message)
	print("FAIL " .. message)
	process.exit(1)
end

-- pretend the 3D importer created one MeshPart per object; every other one in metres
local imports = roblox.Instance.new("Model")
imports.Name = "Imported"
imports.Parent = workspace
for i, o in Manifest.objects do
	local part = roblox.Instance.new("MeshPart")
	part.Name = o.name
	local size = V.new(o.size[1], o.size[2], o.size[3])
	part.Size = if i % 2 == 0 then size * 0.28 else size
	part.CFrame = roblox.CFrame.new(0, 0, 0)
	part.Parent = imports
end

local placed, missing = Tools.assemble()
if placed ~= #Manifest.objects or #missing ~= 0 then
	fail(string.format("assemble placed %d of %d", placed, #Manifest.objects))
end
local model = workspace:FindFirstChild(Manifest.track)
if not model then
	fail("track model missing")
end
for _, o in Manifest.objects do
	local part = model:FindFirstChild(o.category):FindFirstChild(o.name)
	local want = V.new(o.center[1], o.center[2], o.center[3])
	if (part.CFrame.Position - want).Magnitude > 0.01 then
		fail("wrong position for " .. o.name)
	end
	if (part.Size - V.new(o.size[1], o.size[2], o.size[3])).Magnitude > 0.01 then
		fail("size not restored for " .. o.name)
	end
	if not part.Anchored then
		fail("not anchored: " .. o.name)
	end
end

local road = Tools.buildRoad()
local decks = {}
for _, p in road:GetChildren() do
	if p.Name == "Road" then
		table.insert(decks, p)
	end
end
if #decks < 20 then
	fail("road has too few parts: " .. #decks)
end
-- consecutive segments must share their top edge (smooth, no steps)
local function ends(part)
	local cf, s = part.CFrame, part.Size
	return cf * V.new(0, s.Y / 2, s.Z / 2), cf * V.new(0, s.Y / 2, -s.Z / 2)
end
local worst = 0
for _, p in decks do
	local _, b = ends(p)
	local best = math.huge
	for _, q in decks do
		if q ~= p then
			local a = ends(q)
			best = math.min(best, (a - b).Magnitude)
		end
	end
	worst = math.max(worst, best)
end
if worst > 3 then
	fail(string.format("road segments do not join (gap %.2f)", worst))
end
local line = env.require(folder.RacingLine)
local first = line.points[1]
local expectedWidth = first[4] + first[5]
if math.abs(decks[1].Size.X - expectedWidth) > 0.5 then
	fail(string.format("road width %.2f, expected %.2f", decks[1].Size.X, expectedWidth))
end
local spawn = Tools.placeSpawn()
if (spawn.CFrame.Position - V.new(first[1], first[2] + 3, first[3])).Magnitude > 0.01 then
	fail("spawn not on the start line")
end
print(string.format("ALL OK: %d meshes placed, road of %d parts (max joint gap %.3f)", placed, #decks, worst))
