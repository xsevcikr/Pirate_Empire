class_name Dungeon
extends RefCounted
## One run through a tour dungeon: three to seven rooms of traps, puzzles, a chest and a skeleton guardian.
## Torches last five minutes; the entrance always has a fresh one, so the dark only makes traps harder to see.
## Dying sends the player back to the entrance with the puzzles solved so far kept.

var id: String
var cfg: Dictionary
var spec: Array = []
var rng: RandomNumberGenerator
var room: int = 0
var hp: float = 100.0
var torch_s: float = TourData.TORCH_S
var air_s: float = 0.0
var gold: int = 0
var deaths: int = 0
var puzzle: DungeonPuzzle
var trap: String = ""
var trap_done: bool = false
var chest_size: String = ""
var chest_open: bool = false
var skeleton_hp: float = 0.0
var skeleton_down_s: float = 0.0
var skeleton_reassembles: int = 0
var skeleton_done: bool = false
var _solved: Dictionary = {}  ## room index -> true, kept across deaths


func _init(dungeon_id: String, seed_value: int, hp_start: float = 100.0, rooms: Array = []) -> void:
	id = dungeon_id
	cfg = TourData.dungeon(id, rooms)
	spec = cfg["rooms"]
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	hp = hp_start
	air_s = float(cfg["air_s"])
	_enter_room()


func room_count() -> int:
	return spec.size()


func room_kind() -> String:
	return (spec[room] as String).split(":")[0]


func torch_lit() -> bool:
	return torch_s > 0.0


func is_done() -> bool:
	return room >= spec.size() - 1 and cleared()


func _enter_room() -> void:
	puzzle = null
	trap = ""
	chest_size = ""
	var kind: String = room_kind()
	var spec_part: PackedStringArray = (spec[room] as String).split(":")
	if kind == "trap":
		trap = TourData.TRAPS.keys()[rng.randi_range(0, TourData.TRAPS.size() - 1)]
		trap_done = _solved.has(room)
	elif kind == "puzzle":
		puzzle = DungeonPuzzle.new(spec_part[1], rng)
		if _solved.has(room):
			puzzle.solved = true
	elif kind == "chest":
		chest_size = _pick_chest()
		chest_open = _solved.has(room)
	elif kind == "guard":
		skeleton_hp = TourData.SKELETON_HP
		skeleton_done = _solved.has(room)
		skeleton_down_s = 0.0
		skeleton_reassembles = 0


func _pick_chest() -> String:
	var r: float = rng.randf()
	var acc: float = 0.0
	for k: String in TourData.CHEST.keys():
		acc += float(TourData.CHEST[k]["weight"])
		if r <= acc:
			return k
	return "small"


## Whether this room's challenge is out of the way.
func cleared() -> bool:
	match room_kind():
		"trap":
			return trap_done
		"puzzle":
			return puzzle.solved
		"chest":
			return chest_open
		"guard":
			return skeleton_done
	return true


func advance() -> bool:
	if not cleared() or room >= spec.size() - 1:
		return false
	_solved[room] = true
	room += 1
	_enter_room()
	return true


func tick(delta: float) -> void:
	torch_s = maxf(torch_s - delta, 0.0)
	if puzzle != null:
		puzzle.tick(delta)
	if air_s > 0.0 or float(cfg["air_s"]) > 0.0:
		_tick_air(delta)
	if skeleton_down_s > 0.0:
		skeleton_down_s -= delta
		if skeleton_down_s <= 0.0 and not skeleton_done:
			skeleton_hp = TourData.SKELETON_HP * 0.5
			skeleton_reassembles += 1
			if skeleton_reassembles >= TourData.SKELETON_MAX_REASSEMBLES:
				skeleton_done = true  # the bones give up
	if hp <= 0.0:
		die()


## The sunken temple: breathing time runs down and refills in air pockets (the entry and chest rooms).
func _tick_air(delta: float) -> void:
	if room_kind() in ["entry", "chest", "exit"]:
		air_s = float(cfg["air_s"])
		return
	air_s -= delta
	if air_s <= 0.0:
		hp -= TourData.DRAWN_AIR_DAMAGE
		air_s = float(cfg["air_s"]) * 0.5


## Look for the trap: lit torches help.
func spot_trap() -> bool:
	var chance: float = float(TourData.TRAPS[trap]["detect"]) + (TourData.TRAP_LIGHT_BONUS if torch_lit() else 0.0)
	return rng.randf() < chance


## Cross the trap room. A spotted trap can be disarmed; otherwise it fires. Either way the way on opens.
func cross_trap(spotted: bool) -> float:
	if trap_done:
		return 0.0
	trap_done = true
	if spotted and rng.randf() < float(TourData.TRAPS[trap]["disarm"]):
		return 0.0
	var dmg: float = float(TourData.TRAPS[trap]["dmg"]) * (0.5 if spotted else 1.0)
	hp -= dmg
	return dmg


func open_chest() -> int:
	if chest_open:
		return 0
	chest_open = true
	var r: Array = TourData.CHEST[chest_size]["gold"]
	var g: int = rng.randi_range(int(r[0]), int(r[1]))
	gold += g
	return g


## Hit the skeleton. Fire or a heavy blow scatters the bones for good.
func hit_skeleton(dmg: float, fire: bool = false) -> void:
	if skeleton_done or skeleton_down_s > 0.0:
		return
	skeleton_hp -= dmg
	if skeleton_hp <= 0.0:
		if fire:
			skeleton_done = true
		else:
			skeleton_down_s = TourData.SKELETON_REASSEMBLE_S


func die() -> void:
	deaths += 1
	room = 0
	hp = 100.0
	torch_s = TourData.TORCH_S
	air_s = float(cfg["air_s"])
	_enter_room()


func relight() -> void:
	torch_s = TourData.TORCH_S


## Walk the whole dungeon with the hints, cheating the fight with fire; for tests. Returns when done.
func autowalk() -> void:
	var guard: int = 0
	while not is_done() and guard < 200:
		guard += 1
		match room_kind():
			"trap":
				cross_trap(spot_trap())
			"puzzle":
				puzzle.solve_with_hints()
			"chest":
				open_chest()
			"guard":
				hit_skeleton(1000.0, true)
		if cleared():
			advance()
