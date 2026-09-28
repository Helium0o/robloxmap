--[[
	Neon Bay ambience (runs on each player's client, so it costs the server nothing):
	  * aviation beacons tagged "NeonBayBlink" blink once per second,
	  * traffic signal lamps tagged "NeonBayTraffic" cycle green -> yellow -> red.
	Works with StreamingEnabled: lamps that stream in pick up the current state.
]]

local CollectionService = game:GetService("CollectionService")

local BLINK_TAG = "NeonBayBlink"
local TRAFFIC_TAG = "NeonBayTraffic"

local LIT = {
	Red = Color3.fromRGB(255, 40, 30),
	Yellow = Color3.fromRGB(255, 190, 20),
	Green = Color3.fromRGB(40, 255, 110),
}
local OFF = {
	Red = Color3.fromRGB(60, 10, 10),
	Yellow = Color3.fromRGB(60, 45, 5),
	Green = Color3.fromRGB(8, 50, 20),
}

-- 22 second cycle: north-south traffic first, then east-west.
local function signalState(t: number): (string, string)
	local phase = t % 22
	if phase < 9 then
		return "Green", "Red"
	elseif phase < 11 then
		return "Yellow", "Red"
	elseif phase < 20 then
		return "Red", "Green"
	end
	return "Red", "Yellow"
end

local currentNS, currentEW = signalState(os.clock())

local function applySignal(lamp: Instance)
	if not lamp:IsA("BasePart") then
		return
	end
	local axis = lamp:GetAttribute("Axis")
	local light = lamp:GetAttribute("Light")
	if not LIT[light] then
		return
	end
	local active = if axis == "NS" then currentNS else currentEW
	local on = active == light
	lamp.Color = if on then LIT[light] else OFF[light]
	lamp.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

CollectionService:GetInstanceAddedSignal(TRAFFIC_TAG):Connect(applySignal)
for _, lamp in CollectionService:GetTagged(TRAFFIC_TAG) do
	applySignal(lamp)
end

local beaconsOn = true
local function applyBeacon(beacon: Instance)
	if beacon:IsA("BasePart") then
		beacon.Transparency = if beaconsOn then 0 else 0.85
	end
end
CollectionService:GetInstanceAddedSignal(BLINK_TAG):Connect(applyBeacon)

task.spawn(function()
	local lastBlink = 0
	while true do
		local now = os.clock()
		local ns, ew = signalState(now)
		if ns ~= currentNS or ew ~= currentEW then
			currentNS, currentEW = ns, ew
			for _, lamp in CollectionService:GetTagged(TRAFFIC_TAG) do
				applySignal(lamp)
			end
		end
		if now - lastBlink >= 1 then
			lastBlink = now
			beaconsOn = not beaconsOn
			for _, beacon in CollectionService:GetTagged(BLINK_TAG) do
				applyBeacon(beacon)
			end
		end
		task.wait(0.2)
	end
end)
