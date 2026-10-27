extends SceneTree
## Two sloops side by side: grapple, pull together, fight, capture the loser into the fleet.

var _ocean := WaveModel.new(2.0)
var _wind := WindModel.new()
var _a: Ship
var _b: Ship
var _bc: BoardingController
var _t: float = 0.0
var _ready_to_run: bool = false
var _fails: Array[String] = []
var _finished: bool = false


func _spawn(pos: Vector3, faction: String) -> Ship:
	var s := Ship.new()
	s.stats = load("res://data/ships/sloop.tres")
	s.ocean = _ocean
	s.wind = _wind
	s.faction = faction
	s.position = pos
	root.add_child(s)
	s.sail_level = 0
	return s


func _initialize() -> void:
	_wind.speed_kn = 6.0
	_a = _spawn(Vector3(0, 0.3, 0), "player")
	_b = _spawn(Vector3(18, 0.3, 0), "pirate")
	_bc = BoardingController.new()
	_bc.attacker = _a
	_bc.target = _b
	_bc.stance = BoardingController.Stance.FULL_ASSAULT
	root.add_child(_bc)
	_bc.finished.connect(func(won: bool) -> void: _finished = true)
	await process_frame
	_a.crew.count = 36
	_b.crew.count = 20
	_ready_to_run = true


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _physics_process(delta: float) -> bool:
	if not _ready_to_run:
		return false
	_t += delta
	_ocean.time += delta
	_a.linear_velocity = Vector3.ZERO
	_b.linear_velocity = Vector3.ZERO
	_bc.process_grapple(true, delta)
	if _finished or _t > 150.0:
		_check(_finished, "boarding finished")
		_check(_bc.player_won, "larger crew won")
		_check(_t < 125.0, "resolved in under ~120 s of fight (%.0f s)" % _t)
		_check(_b.has_surrendered, "loser surrendered")
		var fleet := Fleet.new()
		var info := {"ship_value": 500.0, "cargo_value": 100.0, "prize_crew_available": 4}
		var rng := RandomNumberGenerator.new()
		var res: Dictionary = CaptureFate.resolve(CaptureFate.Fate.CAPTURE, info, rng)
		if res["ship_added"]:
			fleet.add_captured("sloop", _b.damage.hull_fraction(), 4)
		_check(fleet.size() == 1, "captured ship in fleet")
		print("M4 boarding: won=%s in %.0f s, attacker crew %d, prize crew %d" % [_bc.player_won, _t, _a.crew.count, _b.crew.count])
		if _fails.is_empty():
			print("M4 boarding: OK")
			quit(0)
		else:
			print("M4 boarding: FAILED")
			for f in _fails:
				print("  FAIL ", f)
			quit(1)
		return true
	return false
