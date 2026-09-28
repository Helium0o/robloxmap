--[[
	Deterministic random numbers (Park-Miller "minimal standard" generator).

	Every block gets its own stream seeded from (seed, column, row, salt), so editing one
	part of the map does not reshuffle the rest of the city. All arithmetic stays below
	2^53, which keeps results identical in Roblox Studio and in the offline builder.
]]

local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 48271

local function mix(h: number, value: number): number
	h = (h * 31 + (math.floor(value) % MODULUS) + 7) % MODULUS
	return (h * MULTIPLIER) % MODULUS
end

-- Accepts numbers and strings; returns a seed in [1, MODULUS - 1].
local function hash(...): number
	local h = 1234567
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" then
			for c = 1, #value do
				h = mix(h, string.byte(value, c))
			end
		else
			h = mix(h, value)
		end
	end
	return if h == 0 then 1 else h
end

export type Rng = typeof(setmetatable({} :: { state: number }, Rng))

function Rng.new(...): Rng
	local self = setmetatable({ state = hash(...) }, Rng)
	self:next()
	self:next()
	return self
end

-- Uniform float in [0, 1).
function Rng.next(self: Rng): number
	self.state = (self.state * MULTIPLIER) % MODULUS
	return (self.state - 1) / (MODULUS - 1)
end

-- Uniform float in [a, b).
function Rng.range(self: Rng, a: number, b: number): number
	return a + (b - a) * self:next()
end

-- Uniform integer in [a, b].
function Rng.int(self: Rng, a: number, b: number): number
	return math.min(b, a + math.floor(self:next() * (b - a + 1)))
end

function Rng.chance(self: Rng, p: number): boolean
	return self:next() < p
end

function Rng.pick<T>(self: Rng, list: { T }): T
	return list[self:int(1, #list)]
end

-- Picks from { {weight, value}, ... }.
function Rng.weighted<T>(self: Rng, options: { { any } }): T
	local total = 0
	for _, option in options do
		total += option[1]
	end
	local roll = self:next() * total
	for _, option in options do
		roll -= option[1]
		if roll < 0 then
			return option[2]
		end
	end
	return options[#options][2]
end

function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

Rng.hash = hash

return Rng
