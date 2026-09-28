--[[
	Lines buildings up along the four sides of a lot so every facade faces a street.
	North and south rows run the full width; west and east rows fit between them.
]]

local lookAt = require(script.Parent.Parent.Geometry).lookAt

local Frontage = {}

export type Options = {
	depth: { number }, -- {min, max} depth of each row
	width: { number }, -- {min, max} width of each building along the street
	gap: { number }?, -- {min, max} space between neighbours
	setback: number?, -- distance from the lot edge (front yard)
}

-- place(fx0, fz0, fx1, fz1, facing) is called once per building footprint.
function Frontage.layout(rng, x0: number, z0: number, x1: number, z1: number, o: Options, place)
	local setback = o.setback or 0
	local gap = o.gap or { 0, 0 }
	local dN = rng:range(o.depth[1], o.depth[2])
	local dS = rng:range(o.depth[1], o.depth[2])
	local dW = rng:range(o.depth[1], o.depth[2])
	local dE = rng:range(o.depth[1], o.depth[2])
	local cross = 6 -- spacing between the long rows and the short rows

	local runs = {
		{ from = x0, to = x1, facing = Vector3.new(0, 0, -1), depth = dN },
		{ from = x0, to = x1, facing = Vector3.new(0, 0, 1), depth = dS },
		{ from = z0 + setback + dN + cross, to = z1 - setback - dS - cross, facing = Vector3.new(-1, 0, 0), depth = dW },
		{ from = z0 + setback + dN + cross, to = z1 - setback - dS - cross, facing = Vector3.new(1, 0, 0), depth = dE },
	}
	for _, run in runs do
		local t = run.from
		local minW = o.width[1]
		while run.to - t >= minW do
			local w = rng:range(o.width[1], o.width[2])
			local space = rng:range(gap[1], gap[2])
			if run.to - (t + w + space) < minW then
				w = run.to - t
				space = 0
			end
			local depth = run.depth * rng:range(0.8, 1)
			local a, b = t, t + w
			local f = run.facing
			if f.Z < 0 then
				place(a, z0 + setback, b, z0 + setback + depth, f)
			elseif f.Z > 0 then
				place(a, z1 - setback - depth, b, z1 - setback, f)
			elseif f.X < 0 then
				place(x0 + setback, a, x0 + setback + depth, b, f)
			else
				place(x1 - setback - depth, a, x1 - setback, b, f)
			end
			t = b + space
		end
	end
	-- the free courtyard in the middle
	return x0 + setback + dW + cross, z0 + setback + dN + cross, x1 - setback - dE - cross, z1 - setback - dS - cross
end

-- Frame on the street side of a footprint: origin at ground level in the middle of the
-- facade, looking out of the building. Returns the frame and the facade width.
function Frontage.facade(fx0: number, fz0: number, fx1: number, fz1: number, facing: Vector3, y0: number): (CFrame, number, number)
	local cx, cz = (fx0 + fx1) / 2, (fz0 + fz1) / 2
	local alongX = math.abs(facing.Z) > 0
	local width = if alongX then fx1 - fx0 else fz1 - fz0
	local depth = if alongX then fz1 - fz0 else fx1 - fx0
	local front = Vector3.new(cx, y0, cz) + facing * (depth / 2)
	return lookAt(front, front + facing), width, depth
end

return Frontage
