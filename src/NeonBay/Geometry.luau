--[[
	Small geometry helpers.

	`lookAt` is a drop-in replacement for CFrame.lookAt built on CFrame.fromMatrix. Roblox's
	own CFrame.lookAt is fine, but some offline Luau runtimes used to pre-build the place get
	it wrong, and every orientation in the map goes through here so both agree exactly.
]]

local Geometry = {}

local UP = Vector3.new(0, 1, 0)
local X_AXIS = Vector3.new(1, 0, 0)
local Z_AXIS = Vector3.new(0, 0, 1)

-- Frame at `position` whose LookVector points at `target`.
function Geometry.lookAt(position: Vector3, target: Vector3, up: Vector3?): CFrame
	local look = target - position
	local length = look.Magnitude
	if length < 1e-9 then
		return CFrame.new(position)
	end
	look /= length
	local right = look:Cross(up or UP)
	if right.Magnitude < 1e-6 then
		-- looking straight up or down: pick any horizontal right vector
		right = look:Cross(if math.abs(look.X) < 0.9 then X_AXIS else Z_AXIS)
	end
	right = right.Unit
	local newUp = right:Cross(look)
	return CFrame.fromMatrix(position, right, newUp, -look)
end

return Geometry
