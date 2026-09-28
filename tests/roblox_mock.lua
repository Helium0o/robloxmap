--!nocheck
-- Minimal Roblox API mock for testing the generated scripts outside Studio.
local V3mt = {}
V3mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return nil
end
V3mt.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3mt.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
Vector3 = {}
function Vector3.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __v3 = true }, V3mt) end
Vector3.zero = Vector3.new(0, 0, 0)
local function cross(a, b) return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end

-- CFrame: position p, rotation columns r (right), u (up), b (back = -look)
local CFmt = {}
CFrame = {}
local function mkcf(p, r, u, b) return setmetatable({ p = p, r = r, u = u, b = b, __cf = true }, CFmt) end
local function rotv(cf, v) return cf.r * v.X + cf.u * v.Y + cf.b * v.Z end
CFmt.__index = function(cf, k)
	if k == "Position" then return cf.p end
	if k == "LookVector" then return -cf.b end
	if k == "RightVector" then return cf.r end
	if k == "UpVector" then return cf.u end
	return nil
end
CFmt.__mul = function(a, b)
	if type(b) == "table" and b.__cf then
		return mkcf(a.p + rotv(a, b.p), rotv(a, b.r), rotv(a, b.u), rotv(a, b.b))
	end
	return a.p + rotv(a, b)
end
CFmt.__add = function(a, v) return mkcf(a.p + v, a.r, a.u, a.b) end
function CFrame.new(x, y, z)
	if type(x) == "table" then return mkcf(x, Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)) end
	return mkcf(Vector3.new(x or 0, y or 0, z or 0), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1))
end
function CFrame.Angles(rx, ry, rz)
	local function rotX(t) return mkcf(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, math.cos(t), math.sin(t)), Vector3.new(0, -math.sin(t), math.cos(t))) end
	local function rotY(t) return mkcf(Vector3.zero, Vector3.new(math.cos(t), 0, -math.sin(t)), Vector3.new(0, 1, 0), Vector3.new(math.sin(t), 0, math.cos(t))) end
	local function rotZ(t) return mkcf(Vector3.zero, Vector3.new(math.cos(t), math.sin(t), 0), Vector3.new(-math.sin(t), math.cos(t), 0), Vector3.new(0, 0, 1)) end
	return rotX(rx) * rotY(ry) * rotZ(rz)
end
function CFrame.lookAt(eye, target)
	local look = (target - eye).Unit
	local right = cross(look, Vector3.new(0, 1, 0))
	if right.Magnitude < 1e-6 then right = Vector3.new(1, 0, 0) end
	right = right.Unit
	local up = cross(right, look)
	return mkcf(eye, right, up, -look)
end

Color3 = {}
function Color3.new(r, g, b) return { R = r, G = g, B = b } end
function Color3.fromRGB(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end
UDim2 = { fromScale = function(x, y) return { x, y } end }

local function enumTable(path)
	return setmetatable({}, { __index = function(t, k) local v = enumTable(path .. "." .. k) rawset(t, k, v) return v end, __tostring = function() return path end })
end
Enum = enumTable("Enum")

-- instances -------------------------------------------------------------------
STATS = { parts = 0, maxSize = 0, bad = {}, tags = {}, byClass = {} }
local Inst = {}
local function isA(obj, cls)
	if obj.ClassName == cls then return true end
	if cls == "BasePart" then return obj.ClassName == "Part" or obj.ClassName == "SpawnLocation" or obj.ClassName == "WedgePart" end
	if cls == "Instance" then return true end
	return false
end
local methods = {}
function methods:Destroy() self.Parent = nil end
function methods:FindFirstChild(name) for _, c in ipairs(self.__children) do if c.Name == name then return c end end return nil end
function methods:WaitForChild(name) return self:FindFirstChild(name) end
function methods:FindFirstChildOfClass(cls) for _, c in ipairs(self.__children) do if c.ClassName == cls then return c end end return nil end
function methods:GetChildren() local t = {} for _, c in ipairs(self.__children) do table.insert(t, c) end return t end
function methods:GetDescendants()
	local t = {}
	local function walk(o) for _, c in ipairs(o.__children) do table.insert(t, c) walk(c) end end
	walk(self)
	return t
end
function methods:IsA(cls) return isA(self, cls) end
function methods:SetAttribute(k, v) self.__attrs[k] = v end
function methods:GetAttribute(k) return self.__attrs[k] end

local function checkPart(obj)
	local s = obj.Size
	if s and obj.CFrame then
		local m = math.max(s.X, s.Y, s.Z)
		if m > STATS.maxSize then STATS.maxSize = m end
		if s.X <= 0 or s.Y <= 0 or s.Z <= 0 or s.X > 2048 or s.Y > 2048 or s.Z > 2048 or s.X ~= s.X then
			table.insert(STATS.bad, ("bad size %s x %s x %s (%s)"):format(s.X, s.Y, s.Z, obj.Name))
		end
		local p = obj.CFrame.p
		if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then table.insert(STATS.bad, "NaN position " .. obj.Name) end
	end
end

local instMT = {}
instMT.__index = function(obj, k)
	if methods[k] then return methods[k] end
	return rawget(obj, "__props")[k]
end
instMT.__newindex = function(obj, k, v)
	local props = rawget(obj, "__props")
	if k == "Parent" then
		local old = props.Parent
		if old then
			for i, c in ipairs(old.__children) do if c == obj then table.remove(old.__children, i) break end end
		end
		props.Parent = v
		if v then table.insert(v.__children, obj) end
		return
	end
	if k == "Shape" and props.Size then error("set Shape before Size to avoid resize") end
	props[k] = v
	if (k == "Size" or k == "CFrame") and (obj.ClassName == "Part" or obj.ClassName == "SpawnLocation" or obj.ClassName == "WedgePart") then checkPart(obj) end
end
function Instance_new(cls)
	local obj = setmetatable({ __children = {}, __attrs = {}, __props = { ClassName = cls, Name = cls } }, instMT)
	rawset(obj, "ClassName", cls)
	if cls == "Part" or cls == "SpawnLocation" or cls == "WedgePart" then STATS.parts += 1 end
	STATS.byClass[cls] = (STATS.byClass[cls] or 0) + 1
	return obj
end
Instance = { new = Instance_new }

shared = {}
Region3 = { new = function(a, b) return { min = a, max = b, Size = b - a } end }
TERRAIN = { writes = 0, voxels = 0, solid = 0 }
workspace = Instance_new("Workspace")
workspace.Name = "Workspace"
workspace.CurrentCamera = { CFrame = CFrame.new() }
local terrainObj = Instance_new("Terrain")
workspace.Terrain = terrainObj
function methods:Clear() end
function methods:WriteVoxels(region, res, mats, occs)
	assert(res == 4, "resolution must be 4")
	local s = region.Size
	local nx, ny, nz = s.X / 4, s.Y / 4, s.Z / 4
	assert(nx == math.floor(nx) and ny == math.floor(ny) and nz == math.floor(nz), "region size not a multiple of 4")
	assert(region.min.X % 4 == 0 and region.min.Y % 4 == 0 and region.min.Z % 4 == 0, "region corner not on the voxel grid")
	assert(nx * ny * nz <= 4194304, "region too big")
	assert(#mats == nx and #occs == nx, ("x size mismatch %d vs %d"):format(#mats, nx))
	for i = 1, nx do
		assert(#mats[i] == ny and #occs[i] == ny, "y size mismatch")
		for v = 1, ny do
			assert(#mats[i][v] == nz and #occs[i][v] == nz, "z size mismatch")
			for j = 1, nz do
				local o = occs[i][v][j]
				assert(mats[i][v][j] ~= nil, "nil material")
				assert(o >= 0 and o <= 1, "bad occupancy " .. tostring(o))
				if o > 0 then TERRAIN.solid += 1 end
			end
		end
	end
	TERRAIN.writes += 1
	TERRAIN.voxels += nx * ny * nz
end
local serverTime = 1000
function methods:GetServerTimeNow() return serverTime end
function ADVANCE(dt) serverTime += dt end
BULK = { parts = nil, cframes = nil, calls = 0 }
function methods:BulkMoveTo(parts, cframes, mode)
	assert(#parts == #cframes, "BulkMoveTo length mismatch")
	for i, cf in ipairs(cframes) do
		assert(type(cf) == "table" and cf.__cf, "not a CFrame at " .. i)
		local p = cf.p
		assert(p.X == p.X and p.Y == p.Y and p.Z == p.Z, "NaN cframe at " .. i)
	end
	BULK.parts, BULK.cframes = parts, cframes
	BULK.calls += 1
end
local base = Instance_new("Part")
base.Name = "Baseplate"
base.Parent = workspace
local sp = Instance_new("SpawnLocation")
sp.Parent = workspace

local starterPlayer = Instance_new("StarterPlayer")
local sps = Instance_new("StarterPlayerScripts")
sps.Parent = starterPlayer
HEARTBEAT = {}
local services = {
	CollectionService = {
		AddTag = function(_, inst, tag) STATS.tags[tag] = STATS.tags[tag] or {} table.insert(STATS.tags[tag], inst) end,
		GetTagged = function(_, tag) local out = {} for _, i in ipairs(STATS.tags[tag] or {}) do table.insert(out, i) end return out end,
	},
	ChangeHistoryService = { TryBeginRecording = function() return "rec" end, FinishRecording = function() end },
	StarterPlayer = starterPlayer,
	RunService = { Heartbeat = { Connect = function(_, fn) table.insert(HEARTBEAT, fn) end } },
}
game = { GetService = function(_, name) return services[name] end }

local seed = 1
Random = {}
function Random.new(s)
	local st = s or 12345
	local r = {}
	local function nxt() st = (st * 48271) % 2147483647 return st / 2147483647 end
	function r:NextNumber(a, b) a = a or 0 b = b or 1 return a + nxt() * (b - a) end
	function r:NextInteger(a, b) return a + math.floor(nxt() * (b - a + 1)) end
	return r
end
