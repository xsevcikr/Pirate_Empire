class_name SeaNav
extends RefCounted
## Coarse sea navigation grid for path tests and AI trade routes: islands (with a margin) are blocked.

const CELL_M: float = 125.0
const MARGIN_M: float = 60.0

var grid := AStarGrid2D.new()
var n: int = int(WorldMap.SIZE_M / CELL_M)


func _init(gen: WorldGen) -> void:
	grid.region = Rect2i(0, 0, n, n)
	grid.cell_size = Vector2(1, 1)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for isl in gen.islands:
		var c: Vector2i = to_cell(isl["pos"])
		var rad: int = int(ceil((isl["radius"] + MARGIN_M) / CELL_M)) + 1
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var cell := Vector2i(c.x + dx, c.y + dz)
				if cell.x < 0 or cell.y < 0 or cell.x >= n or cell.y >= n:
					continue
				if cell_center(cell).distance_to(isl["pos"]) < isl["radius"] + MARGIN_M:
					grid.set_point_solid(cell, true)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x + WorldMap.HALF) / CELL_M), 0, n - 1), clampi(int((p.y + WorldMap.HALF) / CELL_M), 0, n - 1))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(-WorldMap.HALF + (c.x + 0.5) * CELL_M, -WorldMap.HALF + (c.y + 0.5) * CELL_M)


## Path of world positions from a to b through open water; empty if unreachable.
func find_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ca: Vector2i = to_cell(a)
	var cb: Vector2i = to_cell(b)
	if grid.is_point_solid(ca) or grid.is_point_solid(cb):
		return PackedVector2Array()
	var cells: Array[Vector2i] = grid.get_id_path(ca, cb)
	var out := PackedVector2Array()
	for c in cells:
		out.append(cell_center(c))
	return out
