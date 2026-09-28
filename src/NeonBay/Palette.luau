--[[
	Colours and materials. Night-time look: dark wet asphalt, sodium street lights and a
	lot of neon, in the spirit of late-2000s street racing games.
]]

local rgb = Color3.fromRGB

local Palette = {}

Palette.Asphalt = rgb(38, 38, 44)
Palette.AsphaltDark = rgb(28, 28, 33)
Palette.Sidewalk = rgb(120, 118, 125)
Palette.Curb = rgb(150, 148, 155)
Palette.Concrete = rgb(105, 105, 112)
Palette.ConcreteDark = rgb(72, 72, 80)
Palette.Grass = rgb(46, 74, 46)
Palette.GrassDark = rgb(34, 58, 38)
Palette.Sand = rgb(196, 176, 132)
Palette.Water = rgb(10, 24, 42)
Palette.Seabed = rgb(20, 30, 36)
Palette.Rock = rgb(78, 74, 72)

Palette.LineWhite = rgb(225, 225, 225)
Palette.LineYellow = rgb(235, 180, 40)
Palette.Barrier = rgb(160, 158, 150)
Palette.Metal = rgb(90, 94, 102)
Palette.MetalDark = rgb(52, 55, 62)
Palette.Pole = rgb(60, 62, 68)
Palette.SignGreen = rgb(20, 92, 52)

Palette.Sodium = rgb(255, 170, 90) -- street lights
Palette.SodiumLight = rgb(255, 176, 110)
Palette.WarmWindow = rgb(255, 214, 150)
Palette.CoolWindow = rgb(170, 210, 255)
Palette.AviationRed = rgb(255, 30, 30)

Palette.Neon = {
	rgb(255, 40, 170), -- hot pink
	rgb(0, 225, 255), -- cyan
	rgb(150, 70, 255), -- purple
	rgb(110, 255, 70), -- lime
	rgb(255, 150, 20), -- orange
	rgb(255, 230, 60), -- yellow
	rgb(255, 50, 60), -- red
	rgb(50, 120, 255), -- blue
}

Palette.Glass = {
	rgb(24, 44, 72),
	rgb(20, 58, 70),
	rgb(40, 40, 64),
	rgb(26, 30, 44),
	rgb(52, 62, 84),
}

Palette.Facade = {
	rgb(120, 70, 58), -- brick
	rgb(150, 132, 108), -- sandstone
	rgb(92, 98, 110), -- slate
	rgb(70, 88, 96), -- teal grey
	rgb(128, 118, 128), -- mauve
	rgb(170, 160, 146), -- beige
	rgb(84, 64, 72), -- plum
	rgb(60, 66, 78), -- charcoal
}

Palette.House = {
	rgb(186, 170, 140),
	rgb(150, 160, 170),
	rgb(170, 130, 110),
	rgb(120, 140, 120),
	rgb(200, 190, 175),
	rgb(140, 120, 140),
	rgb(110, 125, 150),
}

Palette.Roof = {
	rgb(70, 50, 46),
	rgb(56, 58, 66),
	rgb(90, 64, 52),
	rgb(46, 52, 60),
}

Palette.Container = {
	rgb(170, 50, 40),
	rgb(40, 80, 150),
	rgb(40, 120, 70),
	rgb(200, 120, 30),
	rgb(120, 120, 125),
	rgb(200, 200, 195),
	rgb(40, 130, 140),
	rgb(130, 40, 90),
}

Palette.Warehouse = {
	rgb(96, 100, 108),
	rgb(120, 86, 70),
	rgb(70, 90, 110),
	rgb(140, 140, 130),
}

Palette.Tree = {
	rgb(40, 82, 44),
	rgb(52, 92, 50),
	rgb(34, 70, 48),
	rgb(64, 96, 52),
}

return Palette
