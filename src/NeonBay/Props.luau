--[[
	Small reusable props: street lamps, trees, palms, parked cars, containers, billboards...
	Everything is built from plain parts, so nothing needs uploading.
]]

local Palette = require(script.Parent.Palette)
local lookAt = require(script.Parent.Geometry).lookAt

local Props = {}

local UP = Vector3.new(0, 1, 0)
local DECOR = { collide = false, shadow = false }

Props.ShopNames = {
	"NITRO",
	"TURBO",
	"RIMS & TIRES",
	"AUDIO",
	"PARTS",
	"DINER 24/7",
	"RAMEN",
	"PIZZA",
	"NOODLE BAR",
	"KARAOKE",
	"ARCADE",
	"HOTEL",
	"MOTEL",
	"CLUB",
	"LOUNGE",
	"BAR",
	"TATTOO",
	"COFFEE",
	"DONUTS",
	"LIQUOR",
	"PAWN",
	"CINEMA",
	"BOWLING",
	"GYM",
	"LAUNDRY",
	"PHARMACY",
	"BODY KITS",
	"VINYL WRAPS",
	"TUNING",
	"DYNO",
	"NIGHT MARKET",
	"SUSHI",
	"TACOS",
	"BURGERS",
	"ELECTRONICS",
	"RECORDS",
}

Props.BillboardTexts = {
	"RACE AT MIDNIGHT",
	"NEON BAY",
	"GO FASTER",
	"TUNE IT",
	"UNDERGROUND",
	"NITROUS SALE",
	"DRIFT KINGS",
	"STREET LEGAL?",
	"BAY RADIO 99.9",
	"OPEN ALL NIGHT",
}

-- Street lamp on a sidewalk. `base` is the foot of the pole, `toward` points over the road.
function Props.streetLamp(B, parent, base: Vector3, toward: Vector3, height: number?)
	local h = height or 22
	B:column(parent, "LampPole", base.X, base.Y, base.Z, h, 0.9, Palette.Pole, Enum.Material.Metal, { shadow = false })
	local top = base + UP * h
	local tip = top + toward * 8
	B:beam(parent, "LampArm", top, tip, 0.5, 0.5, Palette.Pole, Enum.Material.Metal, DECOR)
	local c = tip - UP * 0.35
	local head = B:part({
		parent = parent,
		name = "LampHead",
		size = Vector3.new(1.6, 0.5, 3),
		cf = lookAt(c, c + toward),
		color = Palette.Sodium,
		mat = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	B:spotLight(head, Enum.NormalId.Bottom, Palette.SodiumLight, 50, 2, 120)
	return head
end

function Props.tree(B, parent, rng, x: number, y0: number, z: number, scale: number?)
	local s = (scale or 1) * rng:range(0.8, 1.25)
	local trunkH = 9 * s
	B:column(parent, "Trunk", x, y0, z, trunkH, 1.6 * s, Color3.fromRGB(70, 52, 40), Enum.Material.Wood, { shadow = false })
	local color = rng:pick(Palette.Tree)
	local d = rng:range(11, 15) * s
	B:ball(parent, "Leaves", Vector3.new(x, y0 + trunkH + d * 0.3, z), d, color, Enum.Material.Grass, { collide = false })
	if rng:chance(0.5) then
		local off = Vector3.new(rng:range(-2, 2), 0, rng:range(-2, 2)) * s
		B:ball(parent, "Leaves", Vector3.new(x, y0 + trunkH + d * 0.75, z) + off, d * 0.7, color, Enum.Material.Grass, DECOR)
	end
end

function Props.palm(B, parent, rng, x: number, y0: number, z: number)
	local lean = rng:range(0, 2 * math.pi)
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local base = Vector3.new(x, y0, z)
	local mid = base + UP * 14 + dir * 1.5
	local top = mid + UP * 13 + dir * 3.5
	local bark = Color3.fromRGB(110, 88, 62)
	B:cylinder(parent, "PalmTrunk", base, mid, 1.8, bark, Enum.Material.Wood, { shadow = false })
	B:cylinder(parent, "PalmTrunk", mid, top, 1.5, bark, Enum.Material.Wood, DECOR)
	local green = rng:pick(Palette.Tree)
	for k = 1, 6 do
		local a = lean + k * math.pi / 3 + rng:range(-0.2, 0.2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local tip = top + out * 11 - UP * 4
		B:beam(parent, "PalmLeaf", top, tip, 3.2, 0.3, green, Enum.Material.Grass, DECOR)
	end
end

-- A simple parked car. `cf` is on the ground, looking along the car.
function Props.car(B, parent, rng, cf: CFrame)
	local color = rng:pick({
		Color3.fromRGB(200, 30, 40),
		Color3.fromRGB(30, 90, 200),
		Color3.fromRGB(240, 240, 240),
		Color3.fromRGB(20, 20, 24),
		Color3.fromRGB(250, 190, 20),
		Color3.fromRGB(120, 40, 200),
		Color3.fromRGB(30, 170, 90),
		Color3.fromRGB(170, 170, 180),
	})
	local model = Instance.new("Model")
	model.Name = "ParkedCar"
	model.Parent = parent
	B:part({
		parent = model,
		name = "Body",
		size = Vector3.new(7, 2.4, 16),
		cf = cf * CFrame.new(0, 2.1, 0),
		color = color,
		mat = Enum.Material.SmoothPlastic,
		reflectance = 0.15,
	})
	B:part({
		parent = model,
		name = "Cabin",
		size = Vector3.new(6.2, 2, 8),
		cf = cf * CFrame.new(0, 4.2, 1),
		color = Color3.fromRGB(20, 26, 36),
		mat = Enum.Material.Glass,
		reflectance = 0.25,
		collide = false,
	})
	for _, wheel in { { -3.3, -5 }, { 3.3, -5 }, { -3.3, 5 }, { 3.3, 5 } } do
		B:part({
			parent = model,
			name = "Wheel",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(1.3, 3, 3),
			cf = cf * CFrame.new(wheel[1], 1.5, wheel[2]),
			color = Color3.fromRGB(18, 18, 20),
			mat = Enum.Material.SmoothPlastic,
			collide = false,
			shadow = false,
		})
	end
	-- underglow, the essential accessory
	if rng:chance(0.45) then
		B:part({
			parent = model,
			name = "Underglow",
			size = Vector3.new(6, 0.2, 14),
			cf = cf * CFrame.new(0, 0.45, 0),
			color = rng:pick(Palette.Neon),
			mat = Enum.Material.Neon,
			collide = false,
			shadow = false,
		})
	end
	return model
end

-- Shipping container: 40 ft is about 43 x 9 x 9 studs.
function Props.container(B, parent, rng, cf: CFrame, long: boolean?)
	local length = if long then 43 else 21.5
	return B:part({
		parent = parent,
		name = "Container",
		size = Vector3.new(8.7, 9.2, length),
		cf = cf * CFrame.new(0, 4.6, 0),
		color = rng:pick(Palette.Container),
		mat = Enum.Material.CorrodedMetal,
	})
end

-- Two-post billboard with a lit panel. `cf` stands on the ground looking at the viewer.
function Props.billboard(B, parent, rng, cf: CFrame, width: number, text: string?, height: number?)
	local h = height or 22
	local panelH = width * 0.36
	for _, x in { -width * 0.3, width * 0.3 } do
		B:part({
			parent = parent,
			name = "BillboardPost",
			size = Vector3.new(1.2, h, 1.2),
			cf = cf * CFrame.new(x, h / 2, 0.8),
			color = Palette.MetalDark,
			mat = Enum.Material.Metal,
		})
	end
	local neon = rng:pick(Palette.Neon)
	local panel = B:part({
		parent = parent,
		name = "Billboard",
		size = Vector3.new(width, panelH, 0.8),
		cf = cf * CFrame.new(0, h + panelH / 2, 0),
		color = Color3.fromRGB(16, 16, 22),
		mat = Enum.Material.SmoothPlastic,
		collide = false,
	})
	B:text(panel, Enum.NormalId.Front, text or rng:pick(Props.BillboardTexts), {
		color = neon,
		font = rng:pick({ Enum.Font.Arcade, Enum.Font.GothamBlack, Enum.Font.Michroma, Enum.Font.Bangers }),
		glow = 2.5,
		pixelsPerStud = 12,
	})
	B:part({
		parent = parent,
		name = "BillboardFrame",
		size = Vector3.new(width + 1, 0.6, 1),
		cf = cf * CFrame.new(0, h + panelH + 0.3, 0),
		color = neon,
		mat = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	return panel
end

-- Neon shop sign flat against a facade. `cf` is centred on the sign, looking out of the wall.
function Props.shopSign(B, parent, rng, cf: CFrame, width: number, text: string?)
	local neon = rng:pick(Palette.Neon)
	local board = B:part({
		parent = parent,
		name = "ShopSign",
		size = Vector3.new(width, 4.5, 0.5),
		cf = cf,
		color = Color3.fromRGB(14, 14, 18),
		mat = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	B:text(board, Enum.NormalId.Front, text or rng:pick(Props.ShopNames), {
		color = neon,
		font = rng:pick({ Enum.Font.GothamBlack, Enum.Font.Arcade, Enum.Font.FredokaOne, Enum.Font.Bangers, Enum.Font.Michroma }),
		glow = 3,
		pixelsPerStud = 14,
	})
	B:part({
		parent = parent,
		name = "SignTrim",
		size = Vector3.new(width + 0.6, 0.35, 0.6),
		cf = cf * CFrame.new(0, -2.5, 0),
		color = neon,
		mat = Enum.Material.Neon,
		collide = false,
		shadow = false,
	})
	return board
end

-- Tall vertical neon sign sticking out of a building corner (letters stacked).
function Props.verticalSign(B, parent, rng, cf: CFrame, text: string)
	local letters = {}
	for c in string.gmatch(text, "%S") do
		table.insert(letters, c)
	end
	local h = math.max(8, #letters * 3.2)
	local neon = rng:pick(Palette.Neon)
	local board = B:part({
		parent = parent,
		name = "VerticalSign",
		size = Vector3.new(0.8, h, 4),
		cf = cf * CFrame.new(0, -h / 2, 0),
		color = Color3.fromRGB(14, 14, 18),
		mat = Enum.Material.SmoothPlastic,
		collide = false,
		shadow = false,
	})
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		B:text(board, face, table.concat(letters, "\n"), {
			color = neon,
			font = Enum.Font.GothamBlack,
			glow = 3,
			pixelsPerStud = 12,
		})
	end
	return board
end

-- Traffic cone.
function Props.cone(B, parent, x: number, y0: number, z: number)
	B:block(parent, "ConeBase", x, y0, z, 2, 0.3, 2, Color3.fromRGB(240, 110, 20), Enum.Material.SmoothPlastic, DECOR)
	B:column(parent, "Cone", x, y0 + 0.3, z, 2.2, 1, Color3.fromRGB(240, 110, 20), Enum.Material.SmoothPlastic, { shadow = false })
end

-- Beach umbrella.
function Props.umbrella(B, parent, rng, x: number, y0: number, z: number)
	B:column(parent, "UmbrellaPole", x, y0, z, 9, 0.4, Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, DECOR)
	B:column(parent, "Umbrella", x, y0 + 8.5, z, 0.6, 12, rng:pick(Palette.Neon), Enum.Material.Fabric, DECOR)
end

return Props
