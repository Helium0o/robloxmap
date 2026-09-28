--[[
	Part factory. Every piece of the map is created through here so that defaults stay
	consistent: anchored, smooth surfaces, no touch events, and cheap collision/shadow
	settings on small decorative parts.
]]

local lookAt = require(script.Parent.Geometry).lookAt

local Builder = {}
Builder.__index = Builder

local UP = Vector3.new(0, 1, 0)
local RIGHT = Vector3.new(1, 0, 0)
local MAX_SIZE = 2048 -- Roblox limit per axis

export type Spec = {
	parent: Instance,
	name: string?,
	class: string?, -- "Part" (default), "WedgePart", "CornerWedgePart"
	shape: Enum.PartType?,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	collide: boolean?, -- default true
	shadow: boolean?, -- default true
	query: boolean?, -- default = collide
}

function Builder.new(root: Instance)
	local self = setmetatable({
		root = root,
		parts = 0,
		lights = 0,
		guis = 0,
		oversize = 0,
	}, Builder)
	return self
end

function Builder:group(parent: Instance, name: string, className: string?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local group = Instance.new(className or "Folder")
	group.Name = name
	group.Parent = parent
	return group
end

function Builder:part(spec: Spec): BasePart
	local size = spec.size
	if size.X > MAX_SIZE or size.Y > MAX_SIZE or size.Z > MAX_SIZE then
		-- Roblox would silently clamp the part; keep going but record it so tests catch it.
		self.oversize += 1
		size = Vector3.new(math.min(size.X, MAX_SIZE), math.min(size.Y, MAX_SIZE), math.min(size.Z, MAX_SIZE))
	end
	local part = Instance.new(spec.class or "Part")
	part.Name = spec.name or "Part"
	if spec.shape then
		part.Shape = spec.shape
	end
	part.Anchored = true
	part.Size = size
	part.CFrame = spec.cf
	part.Color = spec.color
	part.Material = spec.mat or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.transparency then
		part.Transparency = spec.transparency
	end
	if spec.reflectance then
		part.Reflectance = spec.reflectance
	end
	local collide = spec.collide ~= false
	part.CanCollide = collide
	part.CanTouch = false
	part.CanQuery = if spec.query ~= nil then spec.query else collide
	part.CastShadow = spec.shadow ~= false
	part.Parent = spec.parent
	self.parts += 1
	return part
end

-- Axis-aligned box from a centre point.
function Builder:box(
	parent: Instance,
	name: string,
	center: Vector3,
	size: Vector3,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local spec: any = {
		parent = parent,
		name = name,
		size = size,
		cf = CFrame.new(center),
		color = color,
		mat = mat,
	}
	if extra then
		for k, v in extra do
			spec[k] = v
		end
	end
	return self:part(spec)
end

-- Box standing on the ground: `x, z` centre, `y0` bottom, `w, h, d` size.
function Builder:block(
	parent: Instance,
	name: string,
	x: number,
	y0: number,
	z: number,
	w: number,
	h: number,
	d: number,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	return self:box(parent, name, Vector3.new(x, y0 + h / 2, z), Vector3.new(w, h, d), color, mat, extra)
end

-- Box whose long (Z) axis runs from a to b; `up` defaults to world up.
function Builder:beam(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local dir = b - a
	local length = dir.Magnitude
	assert(length > 1e-4, "beam needs two distinct points")
	local up = if math.abs(dir.Y / length) > 0.999 then RIGHT else UP
	local spec: any = {
		parent = parent,
		name = name,
		size = Vector3.new(width, height, length),
		cf = lookAt((a + b) / 2, b, up),
		color = color,
		mat = mat,
	}
	if extra then
		for k, v in extra do
			spec[k] = v
		end
	end
	return self:part(spec)
end

-- Cylinder from a to b (Roblox cylinders run along their X axis).
function Builder:cylinder(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local dir = b - a
	local length = dir.Magnitude
	assert(length > 1e-4, "cylinder needs two distinct points")
	local x = dir / length
	local up = if math.abs(x.Y) > 0.99 then RIGHT else UP
	local z = x:Cross(up).Unit
	local y = z:Cross(x)
	local spec: any = {
		parent = parent,
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(length, diameter, diameter),
		cf = CFrame.fromMatrix((a + b) / 2, x, y, z),
		color = color,
		mat = mat,
	}
	if extra then
		for k, v in extra do
			spec[k] = v
		end
	end
	return self:part(spec)
end

-- Vertical cylinder standing on (x, y0, z).
function Builder:column(
	parent: Instance,
	name: string,
	x: number,
	y0: number,
	z: number,
	height: number,
	diameter: number,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local spec: any = {
		parent = parent,
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(height, diameter, diameter),
		cf = CFrame.new(x, y0 + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		color = color,
		mat = mat,
	}
	if extra then
		for k, v in extra do
			spec[k] = v
		end
	end
	return self:part(spec)
end

function Builder:ball(
	parent: Instance,
	name: string,
	center: Vector3,
	diameter: number,
	color: Color3,
	mat: Enum.Material?,
	extra: { [string]: any }?
): BasePart
	local spec: any = {
		parent = parent,
		name = name,
		shape = Enum.PartType.Ball,
		size = Vector3.new(diameter, diameter, diameter),
		cf = CFrame.new(center),
		color = color,
		mat = mat,
	}
	if extra then
		for k, v in extra do
			spec[k] = v
		end
	end
	return self:part(spec)
end

function Builder:pointLight(part: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	self.lights += 1
	return light
end

function Builder:spotLight(
	part: BasePart,
	face: Enum.NormalId,
	color: Color3,
	range: number,
	brightness: number,
	angle: number
): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Angle = angle
	light.Shadows = false
	light.Parent = part
	self.lights += 1
	return light
end

export type TextOptions = {
	color: Color3?,
	background: Color3?,
	font: Enum.Font?,
	glow: number?, -- SurfaceGui brightness; > 1 blooms at night
	pixelsPerStud: number?,
}

-- Writes text on one face of a part (uses no uploaded assets).
function Builder:text(part: BasePart, face: Enum.NormalId, text: string, options: TextOptions?): SurfaceGui
	local o: TextOptions = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.pixelsPerStud or 20
	gui.LightInfluence = 0
	gui.Brightness = o.glow or 2
	gui.MaxDistance = 1500
	gui.ClipsDescendants = true
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromEnum(o.font or Enum.Font.GothamBlack)
	label.TextColor3 = o.color or Color3.new(1, 1, 1)
	if o.background then
		label.BackgroundColor3 = o.background
		label.BackgroundTransparency = 0
	else
		label.BackgroundTransparency = 1
	end
	label.BorderSizePixel = 0
	label.Parent = gui
	gui.Parent = part
	self.guis += 1
	return gui
end

return Builder
