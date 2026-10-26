extends Node
## Named, seeded random streams so tests and saves are reproducible.

var base_seed: int = 0
var _streams: Dictionary = {}


func set_seed(new_seed: int) -> void:
	base_seed = new_seed
	_streams.clear()


func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(stream_name) ^ base_seed
		_streams[stream_name] = rng
	return _streams[stream_name]
