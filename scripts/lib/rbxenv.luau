--[[
	Runs Roblox-style Luau (script / require(script.Child) / Instance.new / workspace ...)
	inside Lune, so the exact code that ships in the place can also be executed offline.

	Only instance *data* is emulated: there is no physics, rendering or task scheduler.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local RbxEnv = {}

-- Builds a ModuleScript/Script tree from a folder, the way Rojo maps files:
--   foo.luau -> ModuleScript, foo.server.luau -> Script, foo.client.luau -> LocalScript,
--   a folder with init.luau -> ModuleScript named after the folder.
function RbxEnv.loadTree(path: string, name: string): any
	local initPath = path .. "/init.luau"
	local inst
	if fs.isFile(initPath) then
		inst = roblox.Instance.new("ModuleScript")
		inst.Source = fs.readFile(initPath)
	else
		inst = roblox.Instance.new("Folder")
	end
	inst.Name = name
	local entries = fs.readDir(path)
	table.sort(entries)
	for _, entry in entries do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			RbxEnv.loadTree(full, entry).Parent = inst
		elseif entry ~= "init.luau" then
			local className, base
			if string.match(entry, "%.server%.luau$") then
				className, base = "Script", string.gsub(entry, "%.server%.luau$", "")
			elseif string.match(entry, "%.client%.luau$") then
				className, base = "LocalScript", string.gsub(entry, "%.client%.luau$", "")
			elseif string.match(entry, "%.luau$") then
				className, base = "ModuleScript", string.gsub(entry, "%.luau$", "")
			end
			if className then
				local child = roblox.Instance.new(className)
				child.Name = base
				child.Source = fs.readFile(full)
				child.Parent = inst
			end
		end
	end
	return inst
end

-- Creates a `require` that understands ModuleScript instances, plus the globals that
-- Roblox scripts expect.
function RbxEnv.new(game: any)
	local cache = {}
	local globals = {
		game = game,
		workspace = game:GetService("Workspace"),
		Instance = roblox.Instance,
		Vector2 = roblox.Vector2,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Font = roblox.Font,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		warn = function(...)
			print("[warn]", ...)
		end,
	}

	local function rbxRequire(module: any)
		assert(typeof(module) == "Instance" and module.ClassName == "ModuleScript", "require expects a ModuleScript")
		if cache[module] ~= nil then
			return cache[module]
		end
		local env = table.clone(globals)
		env.script = module
		env.require = rbxRequire
		local chunk = luau.load(module.Source, { debugName = module:GetFullName(), environment = env })
		local result = chunk()
		cache[module] = result
		return result
	end
	globals.require = rbxRequire

	return {
		require = rbxRequire,
		globals = globals,
	}
end

return RbxEnv
