class_name ChunkStreamer
extends RefCounted
## Keeps only the (2r+1)^2 chunks around the player loaded. `update` returns what to load and unload.

const RADIUS: int = 2  ## 5 x 5

var loaded: Dictionary = {}  ## Vector2i -> true
var center: Vector2i = Vector2i(-99, -99)
var peak_loaded: int = 0
var loads: int = 0
var unloads: int = 0


func wanted(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dz in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var n := Vector2i(c.x + dx, c.y + dz)
			if n.x >= 0 and n.y >= 0 and n.x < WorldMap.CHUNKS and n.y < WorldMap.CHUNKS:
				out.append(n)
	return out


## Returns {"load": Array[Vector2i], "unload": Array[Vector2i]}; unloads are applied before loads so the cap holds.
func update(player_pos: Vector2) -> Dictionary:
	var c: Vector2i = WorldMap.chunk_of(player_pos)
	var res := {"load": [] as Array[Vector2i], "unload": [] as Array[Vector2i]}
	if c == center:
		return res
	center = c
	var want: Dictionary = {}
	for n in wanted(c):
		want[n] = true
	for k in loaded.keys():
		if not want.has(k):
			res["unload"].append(k)
	for k in res["unload"]:
		loaded.erase(k)
		unloads += 1
	for k in want.keys():
		if not loaded.has(k):
			loaded[k] = true
			res["load"].append(k)
			loads += 1
	peak_loaded = maxi(peak_loaded, loaded.size())
	return res
