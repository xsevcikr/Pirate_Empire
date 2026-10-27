extends SceneTree
## M3 acceptance scenarios for ship AI.
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m3_ai.gd

const DUEL_SEEDS: int = 4
const DUEL_LIMIT_S: float = 360.0

var _ocean := WaveModel.new(2.0)
var _wind := WindModel.new()
var _pm: ProjectileManager
var _ships: Array[Ship] = []
var _t: float = 0.0
var _failures: Array[String] = []
var _stage: int = 0
var _run: int = 0
var _setup_frames: int = 0
var _min_sep: float = 1e9
var _duel_times: Array[float] = []
var _ready_to_run: bool = false


func _initialize() -> void:
	_wind.speed_kn = 14.0
	_wind.direction = Vector2(1, 0)
	_pm = ProjectileManager.new()
	_pm.ocean = _ocean
	root.add_child(_pm)
	_begin_duel(1)


func _spawn(path: String, pos: Vector3, yaw: float, faction: String, personality: String) -> Ship:
	var s := Ship.new()
	s.stats = load(path)
	s.ocean = _ocean
	s.wind = _wind
	s.faction = faction
	s.position = pos
	s.rotation_degrees.y = yaw
	root.add_child(s)
	s.sail_level = 3
	var ai := ShipAI.new()
	ai.ship = s
	ai.personality = personality
	s.ai = ai
	s.add_child(ai)
	_ships.append(s)
	return s


func _clear() -> void:
	for s in _ships:
		if is_instance_valid(s):
			root.remove_child(s)
			s.queue_free()
	_ships.clear()
	_ocean.time = 0.0
	_t = 0.0


func _begin_duel(seed_value: int) -> void:
	_clear()
	_ready_to_run = false
	var a: Ship = _spawn("res://data/ships/sloop.tres", Vector3(-150, 0.3, 0), 0.0, "navy", "disciplined")
	var b: Ship = _spawn("res://data/ships/sloop.tres", Vector3(150, 0.3, 0), 180.0, "pirate", "aggressive")
	a.ai.waypoints = [Vector3(0, 0, -400)]
	b.ai.waypoints = [Vector3(0, 0, -400)]
	a.ai.rng.seed = seed_value
	b.ai.rng.seed = seed_value + 1000
	await process_frame
	for s in [a, b]:
		s.broadside.projectiles = _pm
		s.damage.rng.seed = seed_value * 7 + s.get_index()
		s.broadside._rng.seed = seed_value * 13 + s.get_index()  # gun spread was the one unseeded random source
	_ready_to_run = true


func _begin_formation() -> void:
	_clear()
	_ready_to_run = false
	_min_sep = 1e9
	for i in 3:
		var s: Ship = _spawn("res://data/ships/sloop.tres", Vector3(-30 + i * 35, 0.3, 100 + i * 12), 0.0, "navy", "disciplined")
		s.ai.waypoints = [Vector3(0, 0, -900)]
	await process_frame
	for s in _ships:
		s.broadside.projectiles = _pm
	_ready_to_run = true


func _begin_flee() -> void:
	_clear()
	_ready_to_run = false
	var weak: Ship = _spawn("res://data/ships/sloop.tres", Vector3(0, 0.3, 0), 0.0, "pirate", "cautious")
	var strong: Ship = _spawn("res://data/ships/frigate.tres", Vector3(300, 0.5, 0), 180.0, "navy", "disciplined")
	strong.ai.waypoints = [Vector3(0, 0, -900)]
	weak.ai.waypoints = [Vector3(0, 0, -900)]
	await process_frame
	for s in _ships:
		s.broadside.projectiles = _pm
	_ready_to_run = true


func _physics_process(delta: float) -> bool:
	if not _ready_to_run:
		return false
	_t += delta
	_ocean.time += delta
	for s in _ships:
		pass
	match _stage:
		0:  # duels
			var a: Ship = _ships[0]
			var b: Ship = _ships[1]
			var over: bool = a.damage.sunk or b.damage.sunk or a.has_surrendered or b.has_surrendered
			if over or _t >= DUEL_LIMIT_S:
				_duel_times.append(_t)
				var lost: float = 2.0 - a.damage.hull_fraction() - b.damage.hull_fraction()
				_check(over or lost >= 0.35, "duel %d decisive within %.0f s (a hull %.0f%% b hull %.0f%%)" % [_run + 1, DUEL_LIMIT_S, a.damage.hull_fraction() * 100.0, b.damage.hull_fraction() * 100.0])
				_run += 1
				if _run < DUEL_SEEDS:
					_begin_duel(_run + 1)
				else:
					var total: float = 0.0
					for d in _duel_times:
						total += d
					print("M3 duels: %d runs, mean %.0f s, max %.0f s" % [_run, total / _run, _duel_times.max()])
					_stage = 1
					_begin_formation()
		1:  # formation: no collisions
			for i in _ships.size():
				for j in range(i + 1, _ships.size()):
					_min_sep = minf(_min_sep, _ships[i].global_position.distance_to(_ships[j].global_position))
			if _t >= 60.0:
				_check(_min_sep > 14.0, "formation never closer than 14 m (min %.1f)" % _min_sep)
				print("M3 formation: min separation %.1f m" % _min_sep)
				_stage = 2
				_begin_flee()
		2:  # weak ship flees a strong one
			var weak: Ship = _ships[0]
			if weak.ai.state == AiLogic.State.FLEE or weak.has_surrendered:
				print("M3 flee: weak sloop switched to %s after %.0f s" % [AiLogic.State.keys()[weak.ai.state], _t])
				_finish()
			elif _t > 90.0:
				_check(false, "weak sloop never fled (state %s)" % AiLogic.State.keys()[weak.ai.state])
				_finish()
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	print("M3 AI: %s" % ("FAILED" if not _failures.is_empty() else "OK"))
	for f in _failures:
		print("  FAIL " + f)
	quit(1 if not _failures.is_empty() else 0)
