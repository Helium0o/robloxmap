--[[
	Offline build: runs the same generator that ships in the place and writes a ready-to-open
	Roblox place file. Run from the repository root:

		lune run scripts/build.luau                 -> dist/NeonBay.rbxl
		lune run scripts/build.luau -- --seed 7     -> different buildings
		lune run scripts/build.luau -- --layout dist/layout.json   (for preview renders)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local RbxEnv = require("./lib/rbxenv")

local args = {}
do
	local i = 1
	while i <= #process.args do
		local key = process.args[i]
		if key ~= "--" and string.sub(key, 1, 2) == "--" then
			args[string.sub(key, 3)] = process.args[i + 1] or "true"
			i += 2
		else
			i += 1 -- a bare "--" separator or a stray value
		end
	end
end

local outPath = args.out or "dist/NeonBay.rbxl"
local seed = if args.seed then tonumber(args.seed) else nil

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
workspace.StreamingEnabled = true
workspace.StreamingMinRadius = 256
workspace.StreamingTargetRadius = 1536

-- Scripts that live in the place: the generator (so it can be re-run in Studio) and the
-- client ambience script.
local generator = RbxEnv.loadTree("src/NeonBay", "NeonBay")
generator.Parent = game:GetService("ServerStorage")
local starterPlayer = game:GetService("StarterPlayer")
local playerScripts = roblox.Instance.new("StarterPlayerScripts")
playerScripts.Parent = starterPlayer
local client = RbxEnv.loadTree("src/Client", "NeonBayClient")
client.Parent = playerScripts

local env = RbxEnv.new(game)
local NeonBay = env.require(generator)
local started = os.clock()
local root, stats = NeonBay.build({ seed = seed })
local elapsed = os.clock() - started

print(
	string.format(
		"Built %s in %.1fs: %d parts, %d lights, %d signs, %d oversize",
		root.Name,
		elapsed,
		stats.parts,
		stats.lights,
		stats.signs,
		stats.oversize
	)
)
assert(stats.oversize == 0, "some parts exceeded the 2048 stud size limit")

-- per-folder part counts, handy when tuning density
local counts = {}
for _, child in root:GetChildren() do
	local n = 0
	for _, d in child:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	counts[child.Name] = n
end
for name, n in counts do
	print(string.format("  %-10s %6d parts", name, n))
end

local directory = string.match(outPath, "^(.*)/[^/]+$")
if directory and not fs.isDir(directory) then
	fs.writeDir(directory)
end
local placeData = roblox.serializePlace(game, string.match(outPath, "%.rbxlx$") ~= nil)
fs.writeFile(outPath, placeData)
print(string.format("Wrote %s (%.1f MB)", outPath, #placeData / 1e6))

-- read the file back to make sure it round-trips
local reloaded = roblox.deserializePlace(fs.readFile(outPath))
local reloadedMap = reloaded:GetService("Workspace"):FindFirstChild(root.Name)
assert(reloadedMap, "place file does not contain the map")
local reloadedParts = 0
for _, d in reloadedMap:GetDescendants() do
	if d:IsA("BasePart") then
		reloadedParts += 1
	end
end
assert(reloadedParts == stats.parts, string.format("place file has %d parts, expected %d", reloadedParts, stats.parts))
assert(reloaded:GetService("ServerStorage"):FindFirstChild("NeonBay"), "generator scripts missing from place")

-- Optional flat dump of every part for the preview renderer (tools/preview).
if args.layout then
	local function get(instance, property)
		local ok, value = pcall(function()
			return instance[property]
		end)
		return if ok then value else nil
	end
	local parts = {}
	local lights = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
			local shape = get(d, "Shape")
			local color = d.Color
			table.insert(parts, {
				c = d.ClassName,
				n = d.Name,
				s = if shape then shape.Name else "Block",
				z = { d.Size.X, d.Size.Y, d.Size.Z },
				f = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				k = { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) },
				m = d.Material.Name,
				t = get(d, "Transparency") or 0,
			})
		elseif d:IsA("Light") then
			local p = d.Parent.CFrame.Position
			local color = d.Color
			table.insert(lights, {
				c = d.ClassName,
				p = { p.X, p.Y, p.Z },
				k = { color.R, color.G, color.B },
				r = d.Range,
				b = d.Brightness,
			})
		end
	end
	fs.writeFile(args.layout, serde.encode("json", { parts = parts, lights = lights }))
	print(string.format("Wrote %s (%d parts, %d lights)", args.layout, #parts, #lights))
end
