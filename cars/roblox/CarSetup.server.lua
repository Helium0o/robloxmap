--[[
	CarSetup
	Applies paint, materials and lights to a car imported from cars/<Name>/<Name>.obj
	and welds it into a single, tidy prop.

	Two ways to use it:
	  1. Drop this Script inside the imported Model. It runs when the game starts.
	  2. In Studio, select the imported Model and paste this file into the Command Bar
	     to apply everything in edit mode (recommended, so the map looks right
	     while you build).

	Settings can be changed below, or per-car with Model attributes:
	  BodyColor (Color3), LightsOn (bool), Anchored (bool)
]]

local DEFAULTS = {
	BodyColor = nil, -- nil = factory colour for that car (see FACTORY_PAINT)
	LightsOn = false, -- neon lamps + SpotLights / PointLights
	Anchored = true, -- true for a parked map prop
}

local FACTORY_PAINT = {
	NissanSkylineGTR_R34 = Color3.fromRGB(25, 74, 160), -- Bayside Blue
	ToyotaSupra_MK4 = Color3.fromRGB(176, 19, 23), -- Renaissance Red
}

-- part base name -> {Color, Material, Transparency, Reflectance}
local LOOK = {
	Glass = { Color3.fromRGB(26, 33, 41), Enum.Material.Glass, 0.35, 0.15 },
	HeadLights = { Color3.fromRGB(220, 225, 230), Enum.Material.Glass, 0.15, 0.2 },
	Lens = { Color3.fromRGB(242, 247, 255), Enum.Material.Glass, 0, 0.25 },
	Chrome = { Color3.fromRGB(190, 192, 198), Enum.Material.Metal, 0, 0.35 },
	Badge = { Color3.fromRGB(190, 192, 198), Enum.Material.Metal, 0, 0.35 },
	TailLights = { Color3.fromRGB(178, 6, 8), Enum.Material.Glass, 0.05, 0.1 },
	TailLightsInner = { Color3.fromRGB(242, 216, 216), Enum.Material.Glass, 0, 0.1 },
	Reflectors = { Color3.fromRGB(178, 6, 8), Enum.Material.Glass, 0, 0.1 },
	Indicators = { Color3.fromRGB(250, 140, 13), Enum.Material.Glass, 0, 0.1 },
	Grille = { Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic, 0, 0 },
	Trim = { Color3.fromRGB(18, 18, 19), Enum.Material.SmoothPlastic, 0, 0 },
	PanelGaps = { Color3.fromRGB(5, 5, 5), Enum.Material.SmoothPlastic, 0, 0 },
	Plate = { Color3.fromRGB(242, 242, 235), Enum.Material.SmoothPlastic, 0, 0 },
	MirrorGlass = { Color3.fromRGB(180, 190, 205), Enum.Material.Glass, 0, 0.6 },
	Interior = { Color3.fromRGB(23, 23, 26), Enum.Material.Fabric, 0, 0 },
	Steering = { Color3.fromRGB(23, 23, 26), Enum.Material.SmoothPlastic, 0, 0 },
	Undertray = { Color3.fromRGB(13, 13, 13), Enum.Material.SmoothPlastic, 0, 0 },
	Exhaust = { Color3.fromRGB(158, 153, 148), Enum.Material.Metal, 0, 0.2 },
	Tire = { Color3.fromRGB(16, 16, 17), Enum.Material.Rubber, 0, 0 },
	Rim = { Color3.fromRGB(184, 186, 191), Enum.Material.Metal, 0, 0.25 },
	Brake = { Color3.fromRGB(90, 90, 92), Enum.Material.Metal, 0, 0 },
	Caliper = { Color3.fromRGB(204, 158, 46), Enum.Material.SmoothPlastic, 0, 0.05 },
}

local PAINTED = { Body = true, Wing = true, Mirrors = true }

-- parts that matter for collisions; everything else is visual only
local SOLID = { Body = true, Tire = true }

local model = (script and script.Parent and script.Parent:IsA("Model") and script.Parent)
	or game:GetService("Selection"):Get()[1]
assert(model and model:IsA("Model"), "CarSetup: select the imported car Model first")

local function setting(name)
	local v = model:GetAttribute(name)
	if v == nil then
		v = DEFAULTS[name]
	end
	return v
end

local carName = model.Name
local paint = setting("BodyColor")
if paint == nil then
	for key, col in pairs(FACTORY_PAINT) do
		if string.find(carName, key, 1, true) then
			paint = col
		end
	end
end
paint = paint or Color3.fromRGB(200, 200, 200)
local lightsOn = setting("LightsOn")

-- "Rim_FR" -> "Rim", "Trim2" -> "Trim"
local function baseName(name)
	local base = string.match(name, "^(%a+)_[FR][LR]$") or name
	return (string.gsub(base, "%d+$", ""))
end

local parts = {}
for _, inst in ipairs(model:GetDescendants()) do
	if inst:IsA("BasePart") then
		table.insert(parts, inst)
	end
end

for _, part in ipairs(parts) do
	local base = baseName(part.Name)
	if PAINTED[base] then
		part.Color = paint
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.12
	elseif LOOK[base] then
		local look = LOOK[base]
		part.Color, part.Material, part.Transparency, part.Reflectance = look[1], look[2], look[3], look[4]
	end
	if string.find(carName, "Supra", 1, true) and base == "Caliper" then
		part.Color = Color3.fromRGB(46, 46, 48)
	end
	part.CanCollide = SOLID[base] == true
	part.CanTouch = SOLID[base] == true
	part.CastShadow = base ~= "Glass" and base ~= "PanelGaps"
	if part:IsA("MeshPart") then
		part.DoubleSided = base == "Glass"
	end
end

-- lights ---------------------------------------------------------------
local function addLight(part, className, props)
	local existing = part:FindFirstChild("CarLight")
	if existing then
		existing:Destroy()
	end
	if not lightsOn then
		return
	end
	local light = Instance.new(className)
	light.Name = "CarLight"
	for k, v in pairs(props) do
		light[k] = v
	end
	light.Parent = part
end

for _, part in ipairs(parts) do
	local base = baseName(part.Name)
	if base == "Lens" or base == "HeadLights" then
		if lightsOn and base == "Lens" then
			part.Material = Enum.Material.Neon
		end
		if base == "HeadLights" then
			addLight(part, "SpotLight", {
				Face = Enum.NormalId.Front,
				Angle = 70,
				Range = 45,
				Brightness = 4,
				Color = Color3.fromRGB(255, 244, 225),
				Shadows = true,
			})
		end
	elseif base == "TailLights" then
		if lightsOn then
			part.Material = Enum.Material.Neon
		end
		addLight(part, "PointLight", { Range = 8, Brightness = 1.5, Color = Color3.fromRGB(255, 30, 30) })
	end
end

-- weld everything into one assembly -----------------------------------
local body = model:FindFirstChild("Body", true)
assert(body, "CarSetup: no 'Body' part found - was the .obj imported with its groups?")
model.PrimaryPart = body
for _, part in ipairs(parts) do
	part.Anchored = false
	if part ~= body then
		local weld = part:FindFirstChild("CarWeld")
		if not weld then
			weld = Instance.new("WeldConstraint")
			weld.Name = "CarWeld"
			weld.Parent = part
		end
		weld.Part0 = body
		weld.Part1 = part
	end
end
body.Anchored = setting("Anchored")

print(("CarSetup: configured %s (%d parts)"):format(carName, #parts))
