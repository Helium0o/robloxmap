--!nocheck
-- CityTraffic: ambient traffic, traffic lights and stop signs for the city made by Roblox City Blueprint.
-- It runs on each player's device, so the moving cars cost no network bandwidth.
-- Reference copy with the default settings; BuildCity.lua installs this script for you.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local CITY_CARS, HWY_CARS = 100, 60
local CITY_SPEED, HWY_SPEED = 34, 72
local TURN_SPEED, ACCEL, BRAKE = 14, 16, 42
local WALK, LANE, TOP = 8, 12, 0.6
local GREEN, YELLOW = 12, 3
local CYCLE = 2 * (GREEN + YELLOW)

-- junctions: x, y, z, signal offset, city street, control (0 none, 1 lights, 2 two-way stop, 3 all-way stop), main road axis (1 x, 2 z), junction radius
local NODES = {
	{-720, 3.98, -720, -1, 1, 0, 0, 28}, {-480, 24.76, -720, -1, 1, 2, 1, 28}, {-240, 14.51, -720, 14, 1, 1, 0, 28}, {0, -12.77, -720, -1, 1, 2, 1, 28},
	{240, 16.03, -720, 28, 1, 1, 0, 28}, {480, 18.83, -720, -1, 1, 2, 1, 28}, {720, 25.31, -720, -1, 1, 0, 0, 28}, {-720, 14.37, -480, -1, 1, 2, 2, 28},
	{-494.48, 30.1, -474.45, -1, 1, 3, 0, 16}, {-240, 2.84, -474.94, -1, 1, 2, 2, 28}, {15.19, -1.5, -486.71, -1, 1, 3, 0, 16}, {240, -3.97, -469.94, -1, 1, 2, 2, 28},
	{468.61, 21.02, -464.26, -1, 1, 3, 0, 16}, {720, 5.85, -480, -1, 1, 2, 2, 28}, {-720, 0.18, -240, 8, 1, 1, 0, 28}, {-479.34, 1.91, -240, -1, 1, 2, 1, 28},
	{-240, -5.96, -240, 22, 1, 1, 0, 28}, {-14.66, 12.11, -240, -1, 1, 2, 1, 28}, {240, -11.79, -240, 6, 1, 1, 0, 28}, {470.86, -5.89, -240, -1, 1, 2, 1, 28},
	{720, -10.55, -240, 20, 1, 1, 0, 28}, {-720, -11.12, 0, -1, 1, 2, 2, 28}, {-492.67, -25.99, -7.96, -1, 1, 3, 0, 16}, {-240, 2.25, 3.66, -1, 1, 2, 2, 28},
	{7.18, -1.83, -8.04, -1, 1, 3, 0, 16}, {240, -5.65, -5.52, -1, 1, 2, 2, 28}, {483.64, -34.68, -0.47, -1, 1, 3, 0, 16}, {720, -19.64, 0, -1, 1, 2, 2, 28},
	{-720, 5.11, 240, 16, 1, 1, 0, 28}, {-481.61, -20.38, 240, -1, 1, 2, 1, 28}, {-240, 8.61, 240, 0, 1, 1, 0, 28}, {8.87, 6.49, 240, -1, 1, 2, 1, 28},
	{240, 4.63, 240, 14, 1, 1, 0, 28}, {471.85, -23.19, 240, -1, 1, 2, 1, 28}, {720, -5.1, 240, 28, 1, 1, 0, 28}, {-720, -10.95, 480, -1, 1, 2, 2, 28},
	{-475.56, -0.29, 489.16, -1, 1, 3, 0, 16}, {-240, 2.55, 494.14, -1, 1, 2, 2, 28}, {7.02, 28.91, 465.23, -1, 1, 3, 0, 16}, {240, 0.74, 493.67, -1, 1, 2, 2, 28},
	{469.2, -10.96, 472.87, -1, 1, 3, 0, 16}, {720, -22.25, 480, -1, 1, 2, 2, 28}, {-720, -0.14, 720, -1, 1, 0, 0, 28}, {-480, 8.69, 720, -1, 1, 2, 1, 28},
	{-240, -2.25, 720, 8, 1, 1, 0, 28}, {0, 21.51, 720, -1, 1, 2, 1, 28}, {240, -1.63, 720, 22, 1, 1, 0, 28}, {480, 1.2, 720, -1, 1, 2, 1, 28},
	{720, -14.89, 720, -1, 1, 0, 0, 28}, {-1153, -21.66, -1153, -1, 0, 0, 0, 28}, {1153, -30.37, -1153, -1, 0, 0, 0, 28}, {1153, -33.99, 1153, -1, 0, 0, 0, 28},
	{-1153, -20.29, 1153, -1, 0, 0, 0, 28}, {-240, -12.46, -1153, 11, 0, 1, 0, 28}, {-240, -10.78, 1153, 18, 0, 1, 0, 28}, {240, -11.23, -1153, 25, 0, 1, 0, 28},
	{240, -8.74, 1153, 2, 0, 1, 0, 28}, {-1153, 5.24, -240, 9, 0, 1, 0, 28}, {1153, -4.89, -240, 16, 0, 1, 0, 28}, {-1153, 9.42, 240, 23, 0, 1, 0, 28},
	{1153, 16.1, 240, 0, 0, 1, 0, 28},
}
local LINKS = { -- neighbour to the east, west, south, north (0 = none)
	{2, 0, 8, 0}, {3, 1, 9, 0}, {4, 2, 10, 54}, {5, 3, 11, 0}, {6, 4, 12, 56}, {7, 5, 13, 0}, {0, 6, 14, 0}, {9, 0, 15, 1},
	{10, 8, 16, 2}, {11, 9, 17, 3}, {12, 10, 18, 4}, {13, 11, 19, 5}, {14, 12, 20, 6}, {0, 13, 21, 7}, {16, 58, 22, 8}, {17, 15, 23, 9},
	{18, 16, 24, 10}, {19, 17, 25, 11}, {20, 18, 26, 12}, {21, 19, 27, 13}, {59, 20, 28, 14}, {23, 0, 29, 15}, {24, 22, 30, 16}, {25, 23, 31, 17},
	{26, 24, 32, 18}, {27, 25, 33, 19}, {28, 26, 34, 20}, {0, 27, 35, 21}, {30, 60, 36, 22}, {31, 29, 37, 23}, {32, 30, 38, 24}, {33, 31, 39, 25},
	{34, 32, 40, 26}, {35, 33, 41, 27}, {61, 34, 42, 28}, {37, 0, 43, 29}, {38, 36, 44, 30}, {39, 37, 45, 31}, {40, 38, 46, 32}, {41, 39, 47, 33},
	{42, 40, 48, 34}, {0, 41, 49, 35}, {44, 0, 0, 36}, {45, 43, 0, 37}, {46, 44, 55, 38}, {47, 45, 0, 39}, {48, 46, 57, 40}, {49, 47, 0, 41},
	{0, 48, 0, 42}, {54, 0, 58, 0}, {0, 56, 59, 0}, {0, 57, 0, 61}, {55, 0, 0, 60}, {56, 50, 3, 0}, {57, 53, 0, 45}, {51, 54, 5, 0},
	{52, 55, 0, 47}, {15, 0, 60, 50}, {0, 21, 61, 51}, {29, 0, 53, 58}, {0, 35, 52, 59},
}
local EDGES = { -- from, to, curve control x, z, pieces, half width, main road, lanes each way, slot at "from"
	{1, 2, -600, -720, 1, 24, 1, 2, 1}, {1, 8, -720, -600, 1, 24, 1, 2, 3}, {2, 3, -360, -720, 1, 24, 1, 2, 1}, {2, 9, -477.64, -596.66, 11, 12, 0, 1, 3},
	{3, 4, -120, -720, 1, 24, 1, 2, 1}, {3, 10, -240, -597.47, 1, 24, 1, 2, 3}, {4, 5, 120, -720, 1, 24, 1, 2, 1}, {4, 11, 22.54, -604.33, 10, 12, 0, 1, 3},
	{5, 6, 360, -720, 1, 24, 1, 2, 1}, {5, 12, 240, -594.97, 1, 24, 1, 2, 3}, {6, 7, 600, -720, 1, 24, 1, 2, 1}, {6, 13, 461.92, -592.68, 11, 12, 0, 1, 3},
	{7, 14, 720, -600, 1, 24, 1, 2, 3}, {8, 9, -607.71, -458.2, 10, 12, 0, 1, 1}, {8, 15, -720, -360, 1, 24, 1, 2, 3}, {9, 10, -367.24, -474.69, 1, 12, 0, 1, 1},
	{9, 16, -500.19, -356.37, 10, 12, 0, 1, 3}, {10, 11, -113.13, -496.64, 11, 12, 0, 1, 1}, {10, 17, -240, -357.47, 1, 24, 1, 2, 3}, {11, 12, 128.96, -496.6, 10, 12, 0, 1, 1},
	{11, 18, -11.13, -364.73, 11, 12, 0, 1, 3}, {12, 13, 353.96, -453.11, 10, 12, 0, 1, 1}, {12, 19, 240, -354.97, 1, 24, 1, 2, 3}, {13, 14, 595.27, -456.7, 11, 12, 0, 1, 1},
	{13, 20, 475.21, -352.18, 10, 12, 0, 1, 3}, {14, 21, 720, -360, 1, 24, 1, 2, 3}, {15, 16, -599.67, -240, 1, 24, 1, 2, 1}, {15, 22, -720, -120, 1, 24, 1, 2, 3},
	{16, 17, -359.67, -240, 1, 24, 1, 2, 1}, {16, 23, -500.53, -124.81, 10, 12, 0, 1, 3}, {17, 18, -127.33, -240, 1, 24, 1, 2, 1}, {17, 24, -240, -118.17, 1, 24, 1, 2, 3},
	{18, 19, 112.67, -240, 1, 24, 1, 2, 1}, {18, 25, 3.29, -124.68, 10, 12, 0, 1, 3}, {19, 20, 355.43, -240, 1, 24, 1, 2, 1}, {19, 26, 240, -122.76, 1, 24, 1, 2, 3},
	{20, 21, 595.43, -240, 1, 24, 1, 2, 1}, {20, 27, 481.42, -120.46, 10, 12, 0, 1, 3}, {21, 28, 720, -120, 1, 24, 1, 2, 3}, {22, 23, -607.02, -23.43, 10, 12, 0, 1, 1},
	{22, 29, -720, 120, 1, 24, 1, 2, 3}, {23, 24, -366.17, -5.72, 11, 12, 0, 1, 1}, {23, 30, -482.59, 115.82, 11, 12, 0, 1, 3}, {24, 25, -116.41, -2.19, 1, 12, 0, 1, 1},
	{24, 31, -240, 121.83, 1, 24, 1, 2, 3}, {25, 26, 123.4, 10.61, 10, 12, 0, 1, 1}, {25, 32, 11.48, 115.96, 11, 12, 0, 1, 3}, {26, 27, 362.11, -17.11, 11, 12, 0, 1, 1},
	{26, 33, 240, 117.24, 1, 24, 1, 2, 3}, {27, 28, 601.86, -18.07, 10, 12, 0, 1, 1}, {27, 34, 467.96, 119.29, 11, 12, 0, 1, 3}, {28, 35, 720, 120, 1, 24, 1, 2, 3},
	{29, 30, -600.81, 240, 1, 24, 1, 2, 1}, {29, 36, -720, 360, 1, 24, 1, 2, 3}, {30, 31, -360.8, 240, 1, 24, 1, 2, 1}, {30, 37, -463.59, 364.22, 11, 12, 0, 1, 3},
	{31, 32, -115.56, 240, 1, 24, 1, 2, 1}, {31, 38, -240, 367.07, 1, 24, 1, 2, 3}, {32, 33, 124.44, 240, 1, 24, 1, 2, 1}, {32, 39, -2.59, 352.53, 10, 12, 0, 1, 3},
	{33, 34, 355.93, 240, 1, 24, 1, 2, 1}, {33, 40, 240, 366.84, 1, 24, 1, 2, 3}, {34, 35, 595.92, 240, 1, 24, 1, 2, 1}, {34, 41, 479.91, 356.54, 10, 12, 0, 1, 3},
	{35, 42, 720, 360, 1, 24, 1, 2, 3}, {36, 37, -597.78, 484.58, 1, 12, 0, 1, 1}, {36, 43, -720, 600, 1, 24, 1, 2, 3}, {37, 38, -357.78, 491.65, 1, 12, 0, 1, 1},
	{37, 44, -487.81, 604.39, 10, 12, 0, 1, 3}, {38, 39, -117.41, 471.83, 11, 12, 0, 1, 1}, {38, 45, -240, 607.07, 1, 24, 1, 2, 3}, {39, 40, 124.19, 473.92, 10, 12, 0, 1, 1},
	{39, 46, -18.32, 592.01, 11, 12, 0, 1, 3}, {40, 41, 354.6, 483.27, 1, 12, 0, 1, 1}, {40, 47, 240, 606.84, 1, 24, 1, 2, 3}, {41, 42, 595.15, 456.95, 11, 12, 0, 1, 1},
	{41, 48, 494.66, 595.56, 11, 12, 0, 1, 3}, {42, 49, 720, 600, 1, 24, 1, 2, 3}, {43, 44, -600, 720, 1, 24, 1, 2, 1}, {44, 45, -360, 720, 1, 24, 1, 2, 1},
	{45, 46, -120, 720, 1, 24, 1, 2, 1}, {46, 47, 120, 720, 1, 24, 1, 2, 1}, {47, 48, 360, 720, 1, 24, 1, 2, 1}, {48, 49, 600, 720, 1, 24, 1, 2, 1},
	{54, 3, -240, -936.5, 1, 24, 1, 2, 3}, {45, 55, -240, 936.5, 1, 24, 1, 2, 3}, {56, 5, 240, -936.5, 1, 24, 1, 2, 3}, {47, 57, 240, 936.5, 1, 24, 1, 2, 3},
	{58, 15, -936.5, -240, 1, 24, 1, 2, 1}, {21, 59, 936.5, -240, 1, 24, 1, 2, 1}, {60, 29, -936.5, 240, 1, 24, 1, 2, 1}, {35, 61, 936.5, 240, 1, 24, 1, 2, 1},
	{50, 54, -696.5, -1153, 1, 24, 1, 2, 1}, {54, 56, 0, -1153, 1, 24, 1, 2, 1}, {56, 51, 696.5, -1153, 1, 24, 1, 2, 1}, {53, 55, -696.5, 1153, 1, 24, 1, 2, 1},
	{55, 57, 0, 1153, 1, 24, 1, 2, 1}, {57, 52, 696.5, 1153, 1, 24, 1, 2, 1}, {50, 58, -1153, -696.5, 1, 24, 1, 2, 3}, {58, 60, -1153, 0, 1, 24, 1, 2, 3},
	{60, 53, -1153, 696.5, 1, 24, 1, 2, 3}, {51, 59, 1153, -696.5, 1, 24, 1, 2, 3}, {59, 61, 1153, 0, 1, 24, 1, 2, 3}, {61, 52, 1153, 696.5, 1, 24, 1, 2, 3},
}
local RING = { rx = 870, rz = 870, rc = 140, arc = 8, sideX = 24, sideZ = 24 }
local HWY_Y = { -- highway deck height at each ring point
	19.24, 18.9, 18.51, 18.05, 17.55, 16.89, 16.55, 16.26, 16.02, 15.82, 15.65, 15.61, 15.47, 15.35, 15.23, 15.12,
	15.91, 14.92, 14.88, 14.9, 15, 15.19, 15.39, 15.8, 16.31, 16.92, 17.65, 18.48, 19.37, 20.31, 21.3, 22.35,
	23.44, 24.56, 25.68, 26.79, 27.85, 28.82, 29.71, 30.5, 31.22, 31.69, 31.95, 31.97, 31.76, 33.38, 31.16, 30.08,
	29.3, 28.49, 27.69, 26.86, 26.14, 25.53, 25.3, 25.39, 25.33, 25.18, 25.08, 26.93, 29.07, 26.19, 25.01, 25.14,
	25.35, 25.4, 25.36, 25.68, 26.55, 27.36, 27.99, 28.7, 29.56, 33.77, 32.95, 29.94, 31.81, 33.5, 27.86, 26.46,
	26.45, 24.03, 22.91, 22.28, 21.73, 21.47, 21.3, 21.61, 26.59, 22.86, 24.02, 24.86, 25.69, 26.38, 26.37, 31.58,
	26.92, 26.93, 26.78, 26.48, 26.09, 25.2, 24.58, 23.9, 23.2, 22.49, 21.78, 21.13, 20.39, 19.63, 18.94, 18.32,
	18.01, 17.44, 17.2, 17.45, 17.44, 17.55, 17.71, 18.04, 22.24, 18.94, 19.56, 19.84, 20.02, 20.08, 21.05, 22.78,
}
local VEH = {
	{ name = "Car", L = 14, parts = { {7, 2.6, 14, 0, 2.3, 0, 1, 0}, {6.4, 2.2, 7.5, 0, 4.7, 1, 2, 0}, {7.6, 2.6, 2.6, 0, 1.3, -4.6, 3, 1}, {7.6, 2.6, 2.6, 0, 1.3, 4.6, 3, 1}, {5.4, 0.6, 0.3, 0, 2.9, -7.05, 4, 0}, {5.4, 0.6, 0.3, 0, 2.9, 7.05, 5, 0} } },
	{ name = "Van", L = 15, parts = { {7.4, 5.8, 15, 0, 3.9, 0, 1, 0}, {7.5, 1.8, 11, 0, 5.3, 0.8, 2, 0}, {8, 2.6, 2.6, 0, 1.3, -5, 3, 1}, {8, 2.6, 2.6, 0, 1.3, 5, 3, 1}, {5.6, 0.7, 0.3, 0, 2.6, -7.55, 4, 0}, {5.6, 0.7, 0.3, 0, 2.6, 7.55, 5, 0} } },
	{ name = "Bus", L = 34, parts = { {8, 8.4, 34, 0, 5.4, 0, 1, 0}, {8.1, 2.6, 31, 0, 6.9, 0, 2, 0}, {8.6, 2.8, 2.8, 0, 1.4, -11, 3, 1}, {8.6, 2.8, 2.8, 0, 1.4, 11, 3, 1}, {6, 0.8, 0.3, 0, 2.8, -17.05, 4, 0}, {6, 0.8, 0.3, 0, 2.8, 17.05, 5, 0} } },
	{ name = "Truck", L = 30, parts = { {7.6, 6.4, 8, 0, 4.2, -11, 1, 0}, {8, 9.6, 21, 0, 6.3, 4.5, 6, 0}, {8.6, 2.8, 2.8, 0, 1.4, -10, 3, 1}, {8.6, 2.8, 2.8, 0, 1.4, 10, 3, 1}, {5.6, 0.7, 0.3, 0, 3, -15.05, 4, 0}, {6, 0.7, 0.3, 0, 3, 15.05, 5, 0} } },
}
local PAINT = { Color3.fromRGB(200, 40, 40), Color3.fromRGB(30, 90, 170), Color3.fromRGB(235, 235, 235), Color3.fromRGB(30, 30, 34), Color3.fromRGB(150, 155, 160), Color3.fromRGB(240, 190, 40), Color3.fromRGB(40, 130, 80), Color3.fromRGB(120, 40, 120), Color3.fromRGB(230, 110, 30) }

local function edgePoints(e)
	local A, B = NODES[e[1]], NODES[e[2]]
	local n = e[5]
	local pts = table.create(n + 1)
	for i = 0, n do
		local t = i / n
		local mt = 1 - t
		pts[i + 1] = { mt * mt * A[1] + 2 * mt * t * e[3] + t * t * B[1], A[2] + (B[2] - A[2]) * t, mt * mt * A[3] + 2 * mt * t * e[4] + t * t * B[3] }
	end
	return pts
end

local function measure(pts)
	local cum = { 0 }
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		cum[i] = cum[i - 1] + math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	return cum
end

-- position, flat direction and slope at distance s along a path
local function pointAt(pts, cum, s, hint)
	local i = hint or 1
	if i > #pts - 1 or cum[i] > s then i = 1 end
	while i < #pts - 1 and cum[i + 1] < s do i += 1 end
	local a, b = pts[i], pts[i + 1]
	local L = cum[i + 1] - cum[i]
	local t = L > 0 and (s - cum[i]) / L or 0
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local l = math.sqrt(dx * dx + dz * dz)
	if l == 0 then l = 1 end
	return a[1] + dx * t, a[2] + dy * t, a[3] + dz * t, dx / l, dz / l, dy / l, i
end

-- the same path shifted o studs to the right of the direction of travel
local function offsetPath(pts, o)
	local out = table.create(#pts)
	for i = 1, #pts do
		local p0, p1 = pts[math.max(1, i - 1)], pts[math.min(#pts, i + 1)]
		local tx, tz = p1[1] - p0[1], p1[3] - p0[3]
		local l = math.sqrt(tx * tx + tz * tz)
		if l == 0 then l = 1 end
		tx, tz = tx / l, tz / l
		out[i] = { pts[i][1] - tz * o, pts[i][2], pts[i][3] + tx * o }
	end
	return out
end

local function subPath(pts, cum, s0, s1)
	local out = {}
	if s1 <= s0 then return out end
	local x, y, z = pointAt(pts, cum, s0)
	table.insert(out, { x, y, z })
	for i = 2, #pts - 1 do
		if cum[i] > s0 and cum[i] < s1 then table.insert(out, pts[i]) end
	end
	x, y, z = pointAt(pts, cum, s1)
	table.insert(out, { x, y, z })
	return out
end

local function ringPoints(hx, hz, r)
	local pts = {}
	local cs = { { hx - r, hz - r }, { -hx + r, hz - r }, { -hx + r, -hz + r }, { hx - r, -hz + r } }
	for k = 0, 3 do
		local c = cs[k + 1]
		for i = 0, RING.arc - 1 do
			local a = (k + i / RING.arc) * math.pi / 2
			table.insert(pts, { c[1] + r * math.cos(a), c[2] + r * math.sin(a) })
		end
		local a = (k + 1) * math.pi / 2
		local ex, ez = c[1] + r * math.cos(a), c[2] + r * math.sin(a)
		local nc = cs[(k + 1) % 4 + 1]
		local nx, nz = nc[1] + r * math.cos(a), nc[2] + r * math.sin(a)
		local steps = (k % 2 == 0) and RING.sideX or RING.sideZ
		for s = 0, steps - 1 do
			table.insert(pts, { ex + (nx - ex) * s / steps, ez + (nz - ez) * s / steps })
		end
	end
	return pts
end

local OPP = { 2, 1, 4, 3 }
local HEAD = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } -- rough heading of each slot: east, west, south, north
local ROLE_COLOR = { nil, Color3.fromRGB(44, 56, 70), Color3.fromRGB(28, 28, 30), Color3.fromRGB(255, 244, 214), Color3.fromRGB(222, 40, 40), Color3.fromRGB(236, 236, 232) }
local ROLE_MAT = { Enum.Material.SmoothPlastic, Enum.Material.Glass, Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Neon, Enum.Material.SmoothPlastic }
local LAMP_ON = { R = Color3.fromRGB(255, 60, 50), Y = Color3.fromRGB(255, 196, 40), G = Color3.fromRGB(70, 235, 100) }
local LAMP_OFF = { R = Color3.fromRGB(70, 22, 20), Y = Color3.fromRGB(70, 56, 18), G = Color3.fromRGB(18, 60, 28) }

local rng = Random.new()
local old = workspace:FindFirstChild("CityTrafficCars")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "CityTrafficCars"
folder.Parent = workspace

local parts, cframes = {}, {}

local function newVehicle(kind)
	local def = VEH[kind]
	local paint = PAINT[rng:NextInteger(1, #PAINT)]
	local v = { kind = kind, len = def.L, first = #parts + 1, offs = {}, v = 0, wait = 0, stopT = 0, cleared = false, seg = 1 }
	for _, p in ipairs(def.parts) do
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		if p[8] == 1 then part.Shape = Enum.PartType.Cylinder end
		part.Size = Vector3.new(p[1], p[2], p[3])
		part.Color = ROLE_COLOR[p[7]] or paint
		part.Material = ROLE_MAT[p[7]]
		part.CastShadow = p[7] <= 2
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
		table.insert(parts, part)
		table.insert(cframes, part.CFrame)
		table.insert(v.offs, CFrame.new(p[4], p[5], p[6]))
	end
	return v
end

local function place(v, x, y, z, hx, hy, hz)
	local cf = CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + hx, y + hy, z + hz))
	for i, off in ipairs(v.offs) do
		cframes[v.first + i - 1] = cf * off
	end
end

local function pickKind(weights)
	local r = rng:NextNumber()
	for k, w in ipairs(weights) do
		if r < w then return k end
		r -= w
	end
	return 1
end

local function approach(c, target, dt)
	if c.v < target then c.v = math.min(target, c.v + ACCEL * dt) else c.v = target end
	if c.v < 0.5 then c.wait += dt else c.wait = 0 end
end

-- traffic lights --------------------------------------------------------------------
local function lightFor(n, xAxis, now)
	local off = NODES[n][4]
	if off < 0 then return "G" end
	local t = (now + off) % CYCLE
	if xAxis then
		if t < GREEN then return "G" elseif t < GREEN + YELLOW then return "Y" end
		return "R"
	end
	if t < GREEN + YELLOW then return "R" elseif t < 2 * GREEN + YELLOW then return "G" end
	return "Y"
end

local lampState = {}
local function updateLamps(now)
	for _, lamp in ipairs(CollectionService:GetTagged("CityTrafficLamp")) do
		local n, axis, l = lamp:GetAttribute("Node"), lamp:GetAttribute("Axis"), lamp:GetAttribute("Light")
		if n and NODES[n] then
			local on = lightFor(n, axis == "X", now) == l
			if lampState[lamp] ~= on then
				lampState[lamp] = on
				lamp.Color = on and LAMP_ON[l] or LAMP_OFF[l]
				lamp.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			end
		end
	end
end

-- lanes: every road gets one or two lanes each way, following its curves and hills ----
local lanes, laneOf = {}, {}
for n = 1, #NODES do laneOf[n] = {} end
for _, e in ipairs(EDGES) do
	local pts = edgePoints(e)
	local rev = table.create(#pts)
	for i = #pts, 1, -1 do table.insert(rev, pts[i]) end
	for dir = 1, 2 do
		local from, to, path, slot = e[1], e[2], pts, e[9]
		if dir == 2 then from, to, path, slot = e[2], e[1], rev, OPP[e[9]] end
		local list = {}
		for li = 1, e[8] do
			local lp = offsetPath(path, LANE * (li - 0.5))
			local cum = measure(lp)
			local lane = { pts = lp, cum = cum, len = cum[#cum], from = from, to = to, k = slot, id = #lanes + 1 }
			lane.s0 = NODES[from][8]
			lane.s1 = math.max(lane.s0 + 1, lane.len - NODES[to][8])
			table.insert(lanes, lane)
			list[li] = lane
		end
		laneOf[from][slot] = list
	end
end

local function mustStop(n, k)
	local ctl = NODES[n][6]
	return ctl == 1 or ctl == 3 or (ctl == 2 and (k <= 2 and 1 or 2) ~= NODES[n][7])
end

local function pickNext(b, k)
	local opts = {}
	for kk = 1, 4 do
		if LINKS[b][kk] ~= 0 and kk ~= OPP[k] then table.insert(opts, kk) end
	end
	if #opts == 0 then return OPP[k] end
	if LINKS[b][k] ~= 0 and rng:NextNumber() < 0.5 then return k end
	return opts[rng:NextInteger(1, #opts)]
end

-- right turns use the kerb lane of a four-lane road, left turns the inner lane
local function chooseLane(list, k, nk)
	if #list == 1 then return list[1] end
	local h, n = HEAD[k], HEAD[nk]
	if nk ~= k and n[1] == -h[2] and n[2] == h[1] then return list[2] end
	if nk ~= k and nk ~= OPP[k] then return list[1] end
	return list[rng:NextInteger(1, #list)]
end

local function planAhead(c)
	local b = c.lane.to
	local nb = LINKS[b][c.nk]
	c.nnk = pickNext(nb, c.nk)
	c.nl = chooseLane(laneOf[b][c.nk], c.nk, c.nnk)
end

local function startTurn(c)
	local lane, nl = c.lane, c.nl
	local x0, y0, z0, t0x, t0z = pointAt(lane.pts, lane.cum, lane.s1)
	local x2, y2, z2, t2x, t2z = pointAt(nl.pts, nl.cum, nl.s0)
	local dx, dz = x2 - x0, z2 - z0
	local d = math.sqrt(dx * dx + dz * dz)
	local den = t0x * t2z - t0z * t2x
	local x1, z1
	if math.abs(den) < 0.2 then
		x1, z1 = (x0 + x2) / 2, (z0 + z2) / 2
		if t0x * t2x + t0z * t2z < 0 then x1, z1 = x1 + t0x * d, z1 + t0z * d end
	else
		local u = math.clamp((dx * t2z - dz * t2x) / den, 0, d)
		x1, z1 = x0 + t0x * u, z0 + t0z * u
	end
	c.p = { x0, y0, z0, x1, (y0 + y2) / 2, z1, x2, y2, z2 }
	local l1 = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local l2 = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
	c.blen = math.max(4, (l1 + l2 + d) / 2)
	c.turning, c.u = true, 0
end

local cityCars = {}
for _ = 1, CITY_CARS do
	for _ = 1, 30 do
		local lane = lanes[rng:NextInteger(1, #lanes)]
		if lane.s1 - lane.s0 > 60 then
			local s = rng:NextNumber(lane.s0 + 5, lane.s1 - 40)
			local ok = true
			for _, o in ipairs(cityCars) do
				if o.lane.from == lane.from and o.lane.k == lane.k and math.abs(o.s - s) < 40 then
					ok = false
					break
				end
			end
			if ok then
				local c = newVehicle(pickKind({ 0.74, 0.14, 0.05, 0.07 }))
				c.s, c.turning = s, false
				c.nk = pickNext(lane.to, lane.k)
				c.lane = chooseLane(laneOf[lane.from][lane.k], lane.k, c.nk)
				planAhead(c)
				table.insert(cityCars, c)
				break
			end
		end
	end
end

-- a car at a two-way stop may go only when no main-road car is close
local function mainClear(b, groups)
	local axis = NODES[b][7]
	for k = 1, 4 do
		if (k <= 2 and 1 or 2) == axis then
			local m = LINKS[b][OPP[k]]
			if m ~= 0 then
				for _, lane in ipairs(laneOf[m][k]) do
					local g = groups[lane.id]
					if g then
						for _, o in ipairs(g) do
							if not o.turning and lane.s1 - o.s < 55 and o.v > 1 then return false end
						end
					end
				end
			end
		end
	end
	return true
end

local occ = {}
local function stepCity(dt, now)
	local groups = {}
	table.clear(occ)
	for _, c in ipairs(cityCars) do
		if c.turning then
			c.key, c.gs = c.nl.id, c.nl.s0 - (1 - c.u) * c.blen
			occ[c.lane.to] = (occ[c.lane.to] or 0) + 1
		else
			c.key, c.gs = c.lane.id, c.s
			if c.cleared then occ[c.lane.to] = (occ[c.lane.to] or 0) + 1 end
		end
		local g = groups[c.key]
		if not g then
			g = {}
			groups[c.key] = g
		end
		table.insert(g, c)
	end
	for _, c in ipairs(cityCars) do
		local lead = math.huge
		for _, o in ipairs(groups[c.key]) do
			if o ~= c and o.gs > c.gs then lead = math.min(lead, o.gs - (o.len + c.len) / 2 - 4) end
		end
		local lane = c.lane
		if c.turning then
			local target = (c.nk == lane.k) and CITY_SPEED or TURN_SPEED
			approach(c, math.min(target, math.sqrt(2 * BRAKE * math.max(0, lead - c.gs))), dt)
			c.u += c.v * dt / c.blen
			if c.u >= 1 then
				c.lane = c.nl
				c.s, c.seg, c.turning, c.cleared, c.stopT = c.lane.s0, 1, false, false, 0
				c.nk = c.nnk
				planAhead(c)
			end
		else
			local b = lane.to
			local node = NODES[b]
			local ctl = node[6]
			local sEnd = lane.s1
			local limit = lead
			local stopAt = sEnd - ((node[5] == 1 and ctl == 1) and WALK or 2) - 1.5 - c.len / 2
			if ctl == 1 then
				local light = lightFor(b, lane.k <= 2, now)
				if light ~= "G" then
					local canStop = (stopAt - c.s) > (c.v * c.v) / (2 * BRAKE) - 1
					if c.s <= stopAt + 0.5 and (light == "R" or canStop) then limit = math.min(limit, stopAt) end
				end
			elseif ctl >= 2 then
				if mustStop(b, lane.k) then
					if not c.cleared then
						if c.s >= stopAt - 1.5 and c.v < 0.5 then
							c.stopT += dt
							if c.wait > 12 or (c.stopT > 0.8 and (occ[b] or 0) == 0 and (ctl == 3 or mainClear(b, groups))) then
								c.cleared = true
								occ[b] = (occ[b] or 0) + 1
							end
						end
						if not c.cleared then limit = math.min(limit, stopAt) end
					end
				elseif (occ[b] or 0) > 0 and c.s < sEnd - 3 and c.wait < 6 then
					limit = math.min(limit, sEnd - 3)
				end
			end
			local g = groups[c.nl.id]
			if g and c.wait < 4 then
				for _, o in ipairs(g) do
					if o.gs - o.len / 2 < c.nl.s0 + c.len + 2 then
						limit = math.min(limit, sEnd - 0.5)
						break
					end
				end
			end
			local vmax = CITY_SPEED
			if c.nk ~= lane.k then vmax = math.min(vmax, math.sqrt(TURN_SPEED ^ 2 + 2 * BRAKE * math.max(0, sEnd - c.s))) end
			vmax = math.min(vmax, math.sqrt(2 * BRAKE * math.max(0, limit - c.s)))
			approach(c, vmax, dt)
			c.s = math.min(c.s + c.v * dt, math.max(c.s, limit))
			if c.s >= sEnd then
				startTurn(c)
				if not c.cleared then occ[b] = (occ[b] or 0) + 1 end
			end
		end
		if c.turning then
			local p, u = c.p, math.min(c.u, 1)
			local w0, w1, w2 = (1 - u) ^ 2, 2 * (1 - u) * u, u * u
			local x = w0 * p[1] + w1 * p[4] + w2 * p[7]
			local y = w0 * p[2] + w1 * p[5] + w2 * p[8]
			local z = w0 * p[3] + w1 * p[6] + w2 * p[9]
			local hx = 2 * (1 - u) * (p[4] - p[1]) + 2 * u * (p[7] - p[4])
			local hy = 2 * (1 - u) * (p[5] - p[2]) + 2 * u * (p[8] - p[5])
			local hz = 2 * (1 - u) * (p[6] - p[3]) + 2 * u * (p[9] - p[6])
			if hx * hx + hz * hz < 1e-6 then
				hx, hy, hz = HEAD[c.nk][1], 0, HEAD[c.nk][2]
			end
			place(c, x, y + TOP, z, hx, hy, hz)
		else
			local x, y, z, tx, tz, ty, seg = pointAt(c.lane.pts, c.lane.cum, c.s, c.seg)
			c.seg = seg
			place(c, x, y + TOP, z, tx, ty, tz)
		end
	end
end

-- ring highway -----------------------------------------------------------------------
local hwyLanes, hwyCars = {}, {}
if #HWY_Y > 0 then
	for _, o in ipairs({ 9, 21, -9, -21 }) do
		local ring = ringPoints(RING.rx - o, RING.rz - o, RING.rc - o)
		local pts = table.create(#ring + 1)
		for i, p in ipairs(ring) do pts[i] = { p[1], HWY_Y[i], p[2] } end
		pts[#ring + 1] = { ring[1][1], HWY_Y[1], ring[1][2] }
		if o < 0 then
			local rev = table.create(#pts)
			for i = #pts, 1, -1 do table.insert(rev, pts[i]) end
			pts = rev
		end
		local cum = measure(pts)
		table.insert(hwyLanes, { pts = pts, cum = cum, total = cum[#cum], cars = {} })
	end
	local perLane = math.max(1, math.ceil(HWY_CARS / #hwyLanes))
	for i = 1, HWY_CARS do
		local li = (i - 1) % #hwyLanes + 1
		local lane = hwyLanes[li]
		local c = newVehicle(pickKind({ 0.55, 0.15, 0.05, 0.25 }))
		c.s = (math.floor((i - 1) / #hwyLanes) + rng:NextNumber() * 0.3) * lane.total / perLane
		c.vmax = HWY_SPEED * ((li % 2 == 1) and rng:NextNumber(0.82, 0.95) or rng:NextNumber(0.95, 1.1))
		if c.kind >= 3 then c.vmax = math.min(c.vmax, HWY_SPEED * 0.8) end
		c.v = c.vmax
		table.insert(hwyCars, c)
		table.insert(lane.cars, c)
	end
end

local function bySpace(a, b) return a.s < b.s end
local function stepHighway(dt)
	for _, lane in ipairs(hwyLanes) do
		local list = lane.cars
		table.sort(list, bySpace)
		for i, c in ipairs(list) do
			local leader = list[i % #list + 1]
			local free = math.huge
			if leader ~= c then free = (leader.s - c.s) % lane.total - (leader.len + c.len) / 2 - 8 end
			approach(c, math.min(c.vmax, math.sqrt(2 * BRAKE * math.max(0, free))), dt)
			c.s += c.v * dt
			if c.s >= lane.total then
				c.s -= lane.total
				c.seg = 1
			end
			local x, y, z, tx, tz, ty, seg = pointAt(lane.pts, lane.cum, c.s, c.seg)
			c.seg = seg
			place(c, x, y + TOP, z, tx, ty, tz)
		end
	end
end

-- main loop ------------------------------------------------------------------------------
shared.CityTraffic = { city = cityCars, highway = hwyCars, lanes = lanes, nodes = NODES }
local lampTimer = 1
RunService.Heartbeat:Connect(function(dt)
	dt = math.min(dt, 0.1)
	local now = workspace:GetServerTimeNow()
	stepCity(dt, now)
	stepHighway(dt)
	if #parts > 0 then workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged) end
	lampTimer += dt
	if lampTimer > 0.25 then
		lampTimer = 0
		updateLamps(now)
	end
end)
