class_name BoardingSide
extends RefCounted
## One side of a deck fight: a crew pool with quality, morale and officers.

var pool: float
var start: float
var morale: float = 70.0
var quality: float = 1.0
var officers: int = 0
var defense_bonus: float = 0.0
var captain_alive: bool = true

func _init(count: int, q: float = 1.0, m: float = 70.0, officer_count: int = 0) -> void:
	pool = count
	start = count
	quality = q
	morale = m
	officers = officer_count

func power() -> float:
	var morale_mod: float = clampf(0.6 + morale / 100.0 * 0.6, 0.6, 1.2)
	return pool * quality * morale_mod * (1.0 + 0.03 * officers) * (1.0 + defense_bonus)
