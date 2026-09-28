--[[
	Night-time lighting: purple-blue haze, bloom for the neon, wet-looking reflections.
	Uses the Future lighting technology so every lamp casts real light.
]]

local Atmosphere = {}

local function effect(lighting: Instance, className: string, name: string): Instance
	local existing = lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = lighting
	return instance
end

function Atmosphere.apply(lighting: Instance)
	lighting.Technology = Enum.Technology.Future
	lighting.ClockTime = 0.3
	lighting.GeographicLatitude = 34
	lighting.Brightness = 0.6
	lighting.Ambient = Color3.fromRGB(24, 20, 40)
	lighting.OutdoorAmbient = Color3.fromRGB(46, 40, 82)
	lighting.EnvironmentDiffuseScale = 0.35
	lighting.EnvironmentSpecularScale = 1
	lighting.GlobalShadows = true
	lighting.ShadowSoftness = 0.25
	lighting.ExposureCompensation = 0.25

	local sky = effect(lighting, "Sky", "NeonBaySky")
	sky.StarCount = 4000
	sky.CelestialBodiesShown = true
	sky.MoonAngularSize = 14

	local atmosphere = effect(lighting, "Atmosphere", "NeonBayHaze")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(96, 70, 150)
	atmosphere.Decay = Color3.fromRGB(34, 22, 70)
	atmosphere.Glare = 0.6
	atmosphere.Haze = 2.2

	local bloom = effect(lighting, "BloomEffect", "NeonBayBloom")
	bloom.Intensity = 1.1
	bloom.Size = 30
	bloom.Threshold = 1.05

	local grade = effect(lighting, "ColorCorrectionEffect", "NeonBayGrade")
	grade.Brightness = 0.03
	grade.Contrast = 0.18
	grade.Saturation = 0.22
	grade.TintColor = Color3.fromRGB(236, 228, 255)

	local rays = effect(lighting, "SunRaysEffect", "NeonBayRays")
	rays.Intensity = 0.02
	rays.Spread = 0.6
end

return Atmosphere
