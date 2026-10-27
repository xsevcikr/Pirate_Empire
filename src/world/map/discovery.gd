class_name Discovery
extends RefCounted
## Fog of war: one bit per chunk (256 chunks = 32 bytes).

var bits: PackedByteArray = PackedByteArray()


func _init() -> void:
	bits.resize(WorldMap.CHUNKS * WorldMap.CHUNKS / 8)


func reveal(c: Vector2i) -> void:
	var i: int = WorldMap.chunk_index(c)
	bits[i >> 3] = bits[i >> 3] | (1 << (i & 7))


## Reveal a disc of chunks (the view radius around the player).
func reveal_around(p: Vector2, radius_m: float = 1500.0) -> void:
	var c: Vector2i = WorldMap.chunk_of(p)
	var n: int = int(ceil(radius_m / WorldMap.CHUNK_M))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if k.x < 0 or k.y < 0 or k.x >= WorldMap.CHUNKS or k.y >= WorldMap.CHUNKS:
				continue
			if WorldMap.chunk_center(k).distance_to(p) <= radius_m + WorldMap.CHUNK_M * 0.5:
				reveal(k)


func is_revealed(c: Vector2i) -> bool:
	var i: int = WorldMap.chunk_index(c)
	return (bits[i >> 3] >> (i & 7)) & 1 == 1


func count() -> int:
	var n: int = 0
	for i in WorldMap.CHUNKS * WorldMap.CHUNKS:
		if (bits[i >> 3] >> (i & 7)) & 1 == 1:
			n += 1
	return n


func to_bytes() -> PackedByteArray:
	return bits.duplicate()


static func from_bytes(b: PackedByteArray) -> Discovery:
	var d := Discovery.new()
	if b.size() == d.bits.size():
		d.bits = b.duplicate()
	return d
