--[[
	Turns the ASCII map into cells, intersections (nodes) and street edges.

	Coordinates: map column i / row j (both from 0). Cell (i, j) covers
	x in [x0 + i*cell, x0 + (i+1)*cell] and z in [z0 + j*cell, z0 + (j+1)*cell];
	+X is east and +Z is south, exactly like Roblox Studio's top view.
	Node (i, j) is the intersection at the top-left corner of cell (i, j).

	Edge "H", i, j runs east from node (i, j) to node (i+1, j): cells (i, j-1) north / (i, j) south.
	Edge "V", i, j runs south from node (i, j) to node (i, j+1): cells (i-1, j) west / (i, j) east.
]]

local Grid = {}
Grid.__index = Grid

export type Cell = {
	i: number,
	j: number,
	char: string,
	def: { [string]: any },
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	cx: number,
	cz: number,
}

export type Edge = {
	key: string,
	dir: string, -- "H" or "V"
	i: number,
	j: number,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	left: Cell?, -- north (H) or west (V)
	right: Cell?, -- south (H) or east (V)
}

function Grid.new(config)
	local map = config.Map
	local nz = #map
	local nx = #map[1]
	local cell = config.Cell
	local self = setmetatable({
		config = config,
		nx = nx,
		nz = nz,
		cell = cell,
		x0 = -nx * cell / 2,
		z0 = -nz * cell / 2,
		cells = {},
	}, Grid)
	for j = 0, nz - 1 do
		local row = map[j + 1]
		assert(#row == nx, string.format("Map row %d has %d characters, expected %d", j, #row, nx))
		for i = 0, nx - 1 do
			local char = string.sub(row, i + 1, i + 1)
			local def = config.Districts[char]
			assert(def, string.format("Unknown map character %q at column %d, row %d", char, i, j))
			local x0 = self.x0 + i * cell
			local z0 = self.z0 + j * cell
			self.cells[i + j * nx] = {
				i = i,
				j = j,
				char = char,
				def = def,
				x0 = x0,
				z0 = z0,
				x1 = x0 + cell,
				z1 = z0 + cell,
				cx = x0 + cell / 2,
				cz = z0 + cell / 2,
			}
		end
	end
	return self
end

function Grid:cellAt(i: number, j: number): Cell?
	if i < 0 or j < 0 or i >= self.nx or j >= self.nz then
		return nil
	end
	return self.cells[i + j * self.nx]
end

function Grid:forEachCell(fn: (Cell) -> ())
	for j = 0, self.nz - 1 do
		for i = 0, self.nx - 1 do
			fn(self.cells[i + j * self.nx])
		end
	end
end

function Grid:node(i: number, j: number): (number, number)
	return self.x0 + i * self.cell, self.z0 + j * self.cell
end

function Grid:isLand(i: number, j: number): boolean
	local c = self:cellAt(i, j)
	return c ~= nil and c.def.land == true
end

function Grid:isStreeted(i: number, j: number): boolean
	local c = self:cellAt(i, j)
	return c ~= nil and c.def.streets == true
end

-- A street runs along an edge when at least one neighbouring cell asks for streets.
function Grid:hStreet(i: number, j: number): boolean
	if i < 0 or i >= self.nx or j < 0 or j > self.nz then
		return false
	end
	return self:isStreeted(i, j - 1) or self:isStreeted(i, j)
end

function Grid:vStreet(i: number, j: number): boolean
	if j < 0 or j >= self.nz or i < 0 or i > self.nx then
		return false
	end
	return self:isStreeted(i - 1, j) or self:isStreeted(i, j)
end

function Grid:hasStreet(dir: string, i: number, j: number): boolean
	return if dir == "H" then self:hStreet(i, j) else self:vStreet(i, j)
end

function Grid.edgeKey(dir: string, i: number, j: number): string
	return dir .. ":" .. i .. ":" .. j
end

-- Edge between two neighbouring nodes, in either order.
function Grid.edgeBetween(ai: number, aj: number, bi: number, bj: number): (string, number, number)
	if aj == bj and math.abs(ai - bi) == 1 then
		return "H", math.min(ai, bi), aj
	elseif ai == bi and math.abs(aj - bj) == 1 then
		return "V", ai, math.min(aj, bj)
	end
	error(string.format("Nodes (%d,%d) and (%d,%d) are not neighbours", ai, aj, bi, bj))
end

function Grid:edge(dir: string, i: number, j: number): Edge
	local ax, az = self:node(i, j)
	local bx, bz, left, right
	if dir == "H" then
		bx, bz = self:node(i + 1, j)
		left, right = self:cellAt(i, j - 1), self:cellAt(i, j)
	else
		bx, bz = self:node(i, j + 1)
		left, right = self:cellAt(i - 1, j), self:cellAt(i, j)
	end
	return {
		key = Grid.edgeKey(dir, i, j),
		dir = dir,
		i = i,
		j = j,
		ax = ax,
		az = az,
		bx = bx,
		bz = bz,
		left = left,
		right = right,
	}
end

-- Every edge that carries a street.
function Grid:streetEdges(): { Edge }
	local list = {}
	for j = 0, self.nz do
		for i = 0, self.nx - 1 do
			if self:hStreet(i, j) then
				table.insert(list, self:edge("H", i, j))
			end
		end
	end
	for i = 0, self.nx do
		for j = 0, self.nz - 1 do
			if self:vStreet(i, j) then
				table.insert(list, self:edge("V", i, j))
			end
		end
	end
	return list
end

-- Which streets leave node (i, j): north, east, south, west.
function Grid:arms(i: number, j: number): { N: boolean, E: boolean, S: boolean, W: boolean }
	return {
		N = self:vStreet(i, j - 1),
		S = self:vStreet(i, j),
		W = self:hStreet(i - 1, j),
		E = self:hStreet(i, j),
	}
end

-- Inner rectangle of a cell once the half streets around it are removed.
function Grid:blockRect(c: Cell): (number, number, number, number)
	local h = self.config.RoadWidth / 2
	local x0, z0, x1, z1 = c.x0, c.z0, c.x1, c.z1
	if self:vStreet(c.i, c.j) then
		x0 += h
	end
	if self:vStreet(c.i + 1, c.j) then
		x1 -= h
	end
	if self:hStreet(c.i, c.j) then
		z0 += h
	end
	if self:hStreet(c.i, c.j + 1) then
		z1 -= h
	end
	return x0, z0, x1, z1
end

-- Axis-aligned rectangles covering all cells whose char is in `chars`, merged greedily.
function Grid:mergedRects(accept: (Cell) -> boolean, maxCells: number?): { { number } }
	local limit = maxCells or 6
	local used = {}
	local rects = {}
	for j = 0, self.nz - 1 do
		for i = 0, self.nx - 1 do
			local idx = i + j * self.nx
			if not used[idx] and accept(self.cells[idx]) then
				local w = 1
				while
					w < limit
					and i + w < self.nx
					and not used[i + w + j * self.nx]
					and accept(self.cells[i + w + j * self.nx])
				do
					w += 1
				end
				local h = 1
				local grow = true
				while grow and h < limit and j + h < self.nz do
					for k = 0, w - 1 do
						local id = i + k + (j + h) * self.nx
						if used[id] or not accept(self.cells[id]) then
							grow = false
							break
						end
					end
					if grow then
						h += 1
					end
				end
				for dj = 0, h - 1 do
					for di = 0, w - 1 do
						used[i + di + (j + dj) * self.nx] = true
					end
				end
				table.insert(rects, { i, j, w, h })
			end
		end
	end
	return rects
end

return Grid
