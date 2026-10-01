--[[
	CarSetup  (Script - put it inside the imported car Model)

	Turns a car imported from cars/<Name>/<Name>.obj into a modular, drivable vehicle:
	  * paint + materials for every part
	  * wheels   : invisible cylinder colliders that spin on motor hinges; tyre, rim and
	               brake disc ride on them. Front wheels steer on a servo "knuckle"
	               (calipers steer with the wheel but don't spin)
	  * doors    : hinged at the front edge, open/close with a ProximityPrompt
	  * hood     : hinged at the windscreen, prompt to pop it (engine inside)
	  * trunk    : hinged at the rear window (on the Supra the whole glass hatch lifts),
	               the rear wing goes with it
	  * seats    : driver VehicleSeat + passenger Seat with "Drive" / "Ride" prompts
	  * lights   : headlights come on while driven, brake lights glow when braking

	Pasting this into the Command Bar with the Model selected only applies the paint
	and materials (handy while building the map). The rig is built when the game runs.

	Model attributes (all optional):
	  BodyColor  Color3   repaint the car
	  Drivable   bool     default true - false = parked prop (doors still open)
	  MaxSpeed   number   studs/s, default 140 (~140 km/h at real-world scale)
	  SteerAngle number   degrees, default 32
	  DriveType  string   "AWD" / "RWD" (default: AWD for the R34, RWD for the Supra)
	  LightsOn   bool     force the lamps on
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local model = (script and script.Parent and script.Parent:IsA("Model") and script.Parent)
	or game:GetService("Selection"):Get()[1]
assert(model and model:IsA("Model"), "CarSetup: put this Script inside the car Model (or select it)")

local FACTORY = {
	NissanSkylineGTR_R34 = { paint = Color3.fromRGB(25, 74, 160), drive = "AWD", cover = Color3.fromRGB(158, 16, 16), caliper = Color3.fromRGB(204, 158, 46) },
	ToyotaSupra_MK4 = { paint = Color3.fromRGB(176, 19, 23), drive = "RWD", cover = Color3.fromRGB(140, 142, 148), caliper = Color3.fromRGB(46, 46, 48) },
}
local factory = { paint = Color3.fromRGB(200, 200, 200), drive = "RWD", cover = Color3.fromRGB(60, 60, 60), caliper = Color3.fromRGB(60, 60, 60) }
for key, f in pairs(FACTORY) do
	if string.find(model.Name, key, 1, true) then
		factory = f
	end
end

local function attr(name, default)
	local v = model:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

-- part base name -> {Color, Material, Transparency, Reflectance}
local LOOK = {
	Glass = { Color3.fromRGB(15, 18, 21), Enum.Material.Glass, 0.3, 0.2 },
	HeadLights = { Color3.fromRGB(220, 225, 230), Enum.Material.Glass, 0.15, 0.2 },
	Lens = { Color3.fromRGB(242, 247, 255), Enum.Material.Glass, 0, 0.25 },
	Chrome = { Color3.fromRGB(190, 192, 198), Enum.Material.Metal, 0, 0.35 },
	Badge = { Color3.fromRGB(190, 192, 198), Enum.Material.Metal, 0, 0.35 },
	TailLights = { Color3.fromRGB(150, 4, 6), Enum.Material.Glass, 0.05, 0.1 },
	TailLightsInner = { Color3.fromRGB(242, 216, 216), Enum.Material.Glass, 0, 0.1 },
	Reflectors = { Color3.fromRGB(178, 6, 8), Enum.Material.Glass, 0, 0.1 },
	Indicators = { Color3.fromRGB(250, 140, 13), Enum.Material.Glass, 0, 0.1 },
	Grille = { Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic, 0, 0 },
	Trim = { Color3.fromRGB(18, 18, 19), Enum.Material.SmoothPlastic, 0, 0 },
	Splitter = { Color3.fromRGB(14, 14, 15), Enum.Material.SmoothPlastic, 0, 0.05 },
	Diffuser = { Color3.fromRGB(14, 14, 15), Enum.Material.SmoothPlastic, 0, 0.05 },
	PanelGaps = { Color3.fromRGB(5, 5, 5), Enum.Material.SmoothPlastic, 0, 0 },
	Plate = { Color3.fromRGB(242, 242, 235), Enum.Material.SmoothPlastic, 0, 0 },
	MirrorGlass = { Color3.fromRGB(180, 190, 205), Enum.Material.Glass, 0, 0.6 },
	Interior = { Color3.fromRGB(23, 23, 26), Enum.Material.Fabric, 0, 0 },
	Steering = { Color3.fromRGB(23, 23, 26), Enum.Material.SmoothPlastic, 0, 0 },
	Undertray = { Color3.fromRGB(13, 13, 13), Enum.Material.SmoothPlastic, 0, 0 },
	EngineBay = { Color3.fromRGB(13, 13, 13), Enum.Material.SmoothPlastic, 0, 0 },
	Engine = { Color3.fromRGB(77, 77, 80), Enum.Material.Metal, 0, 0.05 },
	Exhaust = { Color3.fromRGB(158, 153, 148), Enum.Material.Metal, 0, 0.2 },
	Tire = { Color3.fromRGB(16, 16, 17), Enum.Material.Rubber, 0, 0 },
	Rim = { Color3.fromRGB(184, 186, 191), Enum.Material.Metal, 0, 0.25 },
	Brake = { Color3.fromRGB(90, 90, 92), Enum.Material.Metal, 0, 0 },
}
LOOK.DoorGlass, LOOK.TrunkGlass = LOOK.Glass, LOOK.Glass
LOOK.DoorTrim, LOOK.HoodTrim = LOOK.Trim, LOOK.Trim

local PAINTED = { Body = true, Wing = true, Mirror = true, Door = true, Hood = true, Trunk = true }

-- "Rim_FR" -> "Rim", "Door_L" -> "Door", "Trim2" -> "Trim"
local function baseName(name)
	local b = string.match(name, "^(.-)_[FR][LR]$") or string.match(name, "^(.-)_[LR]$") or name
	return (string.gsub(b, "%d+$", ""))
end

local parts, byName = {}, {}
for _, inst in ipairs(model:GetDescendants()) do
	if inst:IsA("BasePart") and string.sub(inst.Name, 1, 4) ~= "Rig_" then
		table.insert(parts, inst)
		byName[inst.Name] = inst
	end
end

---------------------------------------------------------------------------
-- appearance
---------------------------------------------------------------------------
local paint = attr("BodyColor", factory.paint)
for _, part in ipairs(parts) do
	local base = baseName(part.Name)
	if PAINTED[base] then
		part.Color, part.Material, part.Reflectance = paint, Enum.Material.SmoothPlastic, 0.12
	elseif base == "EngineCover" then
		part.Color, part.Material = factory.cover, Enum.Material.Metal
	elseif base == "Caliper" then
		part.Color, part.Material = factory.caliper, Enum.Material.SmoothPlastic
	elseif LOOK[base] then
		local l = LOOK[base]
		part.Color, part.Material, part.Transparency, part.Reflectance = l[1], l[2], l[3], l[4]
	end
	if string.sub(part.Name, 1, 7) == "Marker_" then
		part.Transparency = 1
	end
	part.CanCollide = base == "Body"
	part.CanTouch = false
	part.CanQuery = base ~= "Glass"
	part.CastShadow = not (string.find(base, "Glass") or base == "PanelGaps")
	if part:IsA("MeshPart") then
		part.DoubleSided = string.find(base, "Glass") ~= nil
	end
end

if not RunService:IsRunning() then
	for _, part in ipairs(parts) do
		part.Anchored = true
	end
	print("CarSetup: paint applied to " .. model.Name .. " (rig is built when the game runs)")
	return
end

---------------------------------------------------------------------------
-- rig
---------------------------------------------------------------------------
local body = byName.Body
assert(body, "CarSetup: no 'Body' part - was the .obj imported with its groups?")
for _, tag in ipairs({ "FL", "FR", "RL", "RR" }) do
	assert(byName["Tire_" .. tag], "CarSetup: missing Tire_" .. tag)
end

-- car frame from the wheel positions (works whatever way the model is rotated)
local fl, fr, rl, rr = byName.Tire_FL.Position, byName.Tire_FR.Position, byName.Tire_RL.Position, byName.Tire_RR.Position
local right = ((fr - fl) + (rr - rl)).Unit
local fwd0 = ((fl - rl) + (fr - rr)).Unit
local up = right:Cross(fwd0).Unit
local fwd = up:Cross(right).Unit

local function frame(pos, axis, secondary)
	return CFrame.fromMatrix(pos, axis, secondary)
end

local function attachment(part, worldCF, name)
	local a = Instance.new("Attachment")
	a.Name = "Rig_" .. name
	a.CFrame = part.CFrame:ToObjectSpace(worldCF)
	a.Parent = part
	return a
end

local function weld(root, part)
	local w = Instance.new("WeldConstraint")
	w.Name = "Rig_Weld"
	w.Part0, w.Part1 = root, part
	w.Parent = part
	part.Anchored = false
	if part ~= root then
		part.Massless = true
	end
end

local function noCollide(a, b)
	local n = Instance.new("NoCollisionConstraint")
	n.Name = "Rig_NoCollide"
	n.Part0, n.Part1 = a, b
	n.Parent = a
end

local function hinge(name, p0, p1, worldCF, servo)
	local h = Instance.new("HingeConstraint")
	h.Name = "Rig_" .. name
	h.Attachment0 = attachment(p0, worldCF, name .. "0")
	h.Attachment1 = attachment(p1, worldCF, name .. "1")
	if servo then
		h.ActuatorType = Enum.ActuatorType.Servo
		h.ServoMaxTorque = math.huge
		h.AngularSpeed = 3
		h.LimitsEnabled = true
	else
		h.ActuatorType = Enum.ActuatorType.Motor
		h.MotorMaxAcceleration = 120
	end
	h.Parent = p0
	return h
end

local claimed = {}
local function group(root, names)
	claimed[root] = true
	root.Anchored = false
	for _, n in ipairs(names) do
		local p = byName[n]
		if p then
			weld(root, p)
			claimed[p] = true
		end
	end
end

local function prompt(parent, action, objectText, key)
	local a = Instance.new("Attachment")
	a.Name = "Rig_PromptPoint"
	a.Parent = parent
	local p = Instance.new("ProximityPrompt")
	p.Name = "Rig_Prompt"
	p.ActionText, p.ObjectText = action, objectText
	p.KeyboardKeyCode = key or Enum.KeyCode.E
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Parent = a
	return p, a
end

-- the chassis: Body is the root
claimed[body] = true
body.Anchored = false

-- wheels ------------------------------------------------------------------
local wheels = {}
for _, tag in ipairs({ "FL", "FR", "RL", "RR" }) do
	local tire = byName["Tire_" .. tag]
	local width = tire.Size.X
	local dia = math.max(tire.Size.Y, tire.Size.Z)
	local center = tire.Position

	local hub = Instance.new("Part")
	hub.Name = "Rig_Wheel_" .. tag
	hub.Shape = Enum.PartType.Cylinder
	hub.Size = Vector3.new(width, dia, dia)
	hub.CFrame = frame(center, right, up)
	hub.Transparency = 1
	hub.CanCollide = true
	hub.CustomPhysicalProperties = PhysicalProperties.new(0.9, 1.6, 0.05, 1, 1)
	hub.Parent = model
	group(hub, { "Tire_" .. tag, "Rim_" .. tag, "Brake_" .. tag })
	noCollide(body, hub)

	local spinCF = frame(center, -right, up) -- axis points left: + speed = forward
	local front = string.sub(tag, 1, 1) == "F"
	local w = { tag = tag, hub = hub, radius = dia / 2, front = front }
	if front then
		local knuckle = Instance.new("Part")
		knuckle.Name = "Rig_Knuckle_" .. tag
		knuckle.Size = Vector3.new(0.4, 0.4, 0.4)
		knuckle.CFrame = frame(center, right, up)
		knuckle.Transparency = 1
		knuckle.CanCollide = false
		knuckle.Parent = model
		group(knuckle, { "Caliper_" .. tag })
		noCollide(body, knuckle)
		w.steer = hinge("Steer_" .. tag, body, knuckle, frame(center, up, right), true)
		w.steer.LowerAngle, w.steer.UpperAngle = -40, 40
		w.steer.AngularSpeed = 5
		w.motor = hinge("Axle_" .. tag, knuckle, hub, spinCF, false)
	else
		local caliper = byName["Caliper_" .. tag]
		if caliper then
			weld(body, caliper)
			claimed[caliper] = true
		end
		w.motor = hinge("Axle_" .. tag, body, hub, spinCF, false)
	end
	table.insert(wheels, w)
end

-- doors, hood, trunk --------------------------------------------------------
local panels = {}
local function panel(rootName, members, markerName, axis, openAngle, label)
	local root, marker = byName[rootName], byName[markerName]
	if not (root and marker) then
		return
	end
	group(root, members)
	root.CanCollide = false
	local h = hinge("Hinge_" .. rootName, body, root, frame(marker.Position, axis, fwd), true)
	h.LowerAngle, h.UpperAngle = math.min(0, openAngle) - 1, math.max(0, openAngle) + 1
	h.ServoMaxTorque = 1e7
	h.AngularSpeed = 2.2
	h.TargetAngle = 0
	local p = prompt(root, "Open", label, Enum.KeyCode.F)
	if string.sub(rootName, 1, 4) == "Door" then
		-- put the prompt near the door handle
		p.Parent.WorldPosition = root.Position + up * 0.8
	end
	local open = false
	p.Triggered:Connect(function()
		open = not open
		h.TargetAngle = open and openAngle or 0
		p.ActionText = open and "Close" or "Open"
	end)
	panels[rootName] = { root = root, hinge = h }
end

panel("Door_R", { "DoorGlass_R", "DoorTrim_R", "Mirror_R", "MirrorGlass_R" }, "Marker_Hinge_Door_R", up, 65, "Right door")
panel("Door_L", { "DoorGlass_L", "DoorTrim_L", "Mirror_L", "MirrorGlass_L" }, "Marker_Hinge_Door_L", up, -65, "Left door")
panel("Hood", { "HoodTrim" }, "Marker_Hinge_Hood", right, 55, "Hood")
panel("Trunk", { "TrunkGlass", "TrunkTrim", "Wing" }, "Marker_Hinge_Trunk", right, -55, "Trunk")

-- everything else is welded to the body
for _, part in ipairs(parts) do
	if not claimed[part] then
		weld(body, part)
	end
end

-- seats --------------------------------------------------------------------
local function makeSeat(markerName, className, label)
	local marker = byName[markerName]
	if not marker then
		return nil
	end
	local seat = Instance.new(className)
	seat.Name = "Rig_" .. string.sub(markerName, 8)
	seat.Size = Vector3.new(1.6, 0.4, 1.6)
	seat.CFrame = frame(marker.Position, right, up)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false -- enter with the prompt, not by walking into it
	seat.Parent = model
	weld(body, seat)
	local p = prompt(seat, label, model.Name, Enum.KeyCode.E)
	-- prompt just outside the matching door
	local sideSign = (marker.Position - body.Position):Dot(right) >= 0 and 1 or -1
	p.Parent.WorldPosition = marker.Position + right * sideSign * 2.5
	p.Triggered:Connect(function(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and not seat.Occupant then
			seat:Sit(hum)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		p.Enabled = seat.Occupant == nil
	end)
	return seat
end

local driverSeat = makeSeat("Marker_DriverSeat", "VehicleSeat", "Drive")
makeSeat("Marker_PassengerSeat", "Seat", "Ride")

-- physics ownership + anchoring ---------------------------------------------------
local drivable = attr("Drivable", true)
if not drivable then
	body.Anchored = true
end

local roots = { body }
for _, w in ipairs(wheels) do
	table.insert(roots, w.hub)
end
for _, p in pairs(panels) do
	table.insert(roots, p.root)
end
local function setOwner(player)
	for _, r in ipairs(roots) do
		pcall(function()
			if player then
				r:SetNetworkOwner(player)
			else
				r:SetNetworkOwnershipAuto()
			end
		end)
	end
end

-- lights -------------------------------------------------------------------
local function glow(name, on)
	for _, part in ipairs(parts) do
		local b = baseName(part.Name)
		if b == name then
			part.Material = on and Enum.Material.Neon or LOOK[b][2]
		end
	end
end
local headLight
if byName.HeadLights then
	headLight = Instance.new("SpotLight")
	headLight.Name = "Rig_HeadLight"
	headLight.Face = Enum.NormalId.Front
	headLight.Angle, headLight.Range, headLight.Brightness = 70, 50, 4
	headLight.Color = Color3.fromRGB(255, 244, 225)
	-- point the light along the car's forward axis
	local a = attachment(byName.HeadLights, frame(byName.HeadLights.Position, right, up), "HeadLightPoint")
	headLight.Parent = a
end
local tailLight
if byName.TailLights then
	tailLight = Instance.new("PointLight")
	tailLight.Name = "Rig_TailLight"
	tailLight.Range, tailLight.Brightness, tailLight.Color = 8, 1, Color3.fromRGB(255, 30, 30)
	tailLight.Parent = byName.TailLights
end
local lightState = nil
local function setLights(running, braking)
	local forced = attr("LightsOn", false)
	local key = tostring(forced or running) .. tostring(braking)
	if key == lightState then
		return
	end
	lightState = key
	local on = forced or running
	glow("Lens", on)
	if headLight then
		headLight.Enabled = on
	end
	glow("TailLights", on or braking)
	if tailLight then
		tailLight.Enabled = on or braking
		tailLight.Brightness = braking and 3 or 1
	end
end
setLights(false, false)

-- driving ------------------------------------------------------------------
local driveType = attr("DriveType", factory.drive)
local driven = {}
for _, w in ipairs(wheels) do
	if driveType == "AWD" or not w.front then
		table.insert(driven, w)
	end
end

local mass = body.AssemblyMass
for _, w in ipairs(wheels) do
	mass = mass + w.hub.AssemblyMass
end
local fwdLocal = body.CFrame:VectorToObjectSpace(fwd)
local g = workspace.Gravity
local driveTorque = mass * g * wheels[1].radius * 1.4 / #driven
local brakeTorque = mass * g * wheels[1].radius * 1.2 / #wheels

local occupantPlayer = nil
if driverSeat then
	driverSeat.MaxSpeed = attr("MaxSpeed", 140)
	driverSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = driverSeat.Occupant
		occupantPlayer = hum and Players:GetPlayerFromCharacter(hum.Parent) or nil
		if drivable then
			setOwner(occupantPlayer)
		end
		setLights(hum ~= nil, false)
	end)
end

RunService.Heartbeat:Connect(function()
	if not drivable then
		return
	end
	local throttle = driverSeat and driverSeat.Occupant and driverSeat.ThrottleFloat or 0
	local steer = driverSeat and driverSeat.Occupant and driverSeat.SteerFloat or 0
	local maxSpeed = attr("MaxSpeed", 140)
	local speed = body.AssemblyLinearVelocity:Dot(body.CFrame:VectorToWorldSpace(fwdLocal))
	local braking = (throttle > 0 and speed < -2) or (throttle < 0 and speed > 2)

	for _, w in ipairs(wheels) do
		local isDriven = table.find(driven, w) ~= nil
		if braking or throttle == 0 then
			-- hold / brake: motors try to stop the wheels
			w.motor.AngularVelocity = 0
			w.motor.MotorMaxTorque = (throttle == 0 and driverSeat and driverSeat.Occupant) and brakeTorque * 0.08
				or brakeTorque
		elseif isDriven then
			local target = throttle > 0 and maxSpeed or -maxSpeed * 0.35
			w.motor.AngularVelocity = target / w.radius
			w.motor.MotorMaxTorque = driveTorque
		else
			w.motor.AngularVelocity = 0
			w.motor.MotorMaxTorque = 0
		end
		if w.steer then
			local fade = 1 - 0.55 * math.clamp(math.abs(speed) / maxSpeed, 0, 1)
			w.steer.TargetAngle = -steer * attr("SteerAngle", 32) * fade
		end
	end
	if driverSeat and driverSeat.Occupant then
		setLights(true, braking)
	end
end)

print(("CarSetup: %s rigged (%s, %d parts)"):format(model.Name, driveType, #parts))
