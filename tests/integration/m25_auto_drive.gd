extends SceneTree
## Auto drive and deck walking on a real sloop:
##   1. K-style toggle holds the heading while the captain walks the deck (and stays on it).
##   2. With a chart mark it sails there, stops and hands back the helm.
##   3. It steers round an island lying across its course.
##   4. A cannon hit hands the helm back at once.
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m25_auto_drive.gd

const SLOOP: ShipStats = preload("res://data/ships/sloop.tres")
const ISLAND := {"pos": Vector2(40.0, -420.0), "radius": 110.0}

var _failures: Array[String] = []
var _ship: Ship
var _ocean: WaveModel
var _wind: WindModel
var _pc: PlayerController
var _drive: AutoDrive
var _scenario: int = 0
var _t: float = 0.0
var _start_heading: Vector2
var _max_dev: float = 0.0
var _walk_from: Vector2
var _min_island: float = 1e9
var _arrived_at: float = -1.0
var _off_deck: bool = false
var _engaged: bool = false
var _min_z: float = 1e9


func _initialize() -> void:
	GameInput.register()
	_start(0)


func _start(n: int) -> void:
	if _drive != null:
		_drive.take_helm()
		_drive.queue_free()
	if _pc != null:
		_pc.queue_free()
	if _ship != null:
		_ship.queue_free()
	_scenario = n
	_t = 0.0
	_engaged = false
	_ocean = WaveModel.new(1.0)
	_wind = WindModel.new()
	_wind.speed_kn = 20.0
	_wind.direction = Vector2(1, 0)  # blowing toward +x: heading north is a beam reach, east runs downwind
	_ship = Ship.new()
	_ship.stats = SLOOP
	_ship.ocean = _ocean
	_ship.wind = _wind
	_ship.position = Vector3(0, 0.2, 0)
	_ship.add_to_group("ships")
	root.add_child(_ship)
	_pc = PlayerController.new()
	_pc.ship = _ship
	root.add_child(_pc)
	_drive = AutoDrive.new()
	_drive.controller = _pc
	root.add_child(_drive)
	_drive.pilot.islands = []
	if n == 2:
		_drive.pilot.islands = [ISLAND]


func _physics_process(delta: float) -> bool:
	if _ship == null:
		return false
	_t += delta
	_ocean.time += delta
	var pos := Vector2(_ship.global_position.x, _ship.global_position.z)
	match _scenario:
		0:
			if _t > 8.0 and not _drive.is_on():
				_check(_drive.engage(), "auto drive engages")
				_check(_pc.auto_drive, "the controller lets go of the wheel")
				_check(_drive.walker != null and _drive.walker.is_inside_tree(), "the captain is on deck")
				_start_heading = _ship.heading()
				_walk_from = _drive.walker.fighter.pos
				_drive.walker.use_keys = false
			elif _drive.is_on():
				_max_dev = maxf(_max_dev, absf(rad_to_deg(_start_heading.angle_to(_ship.heading()))))
				var w: DeckWalker = _drive.walker
				w.move_input = Vector2(0.4, 1.0) if _t < 16.0 else Vector2(-1.0, -0.3)
				var p: Vector2 = w.fighter.pos
				_min_z = minf(_min_z, p.y)
				if not w.walkable(p):
					_off_deck = true
				if _t > 30.0:
					_check(_max_dev < 6.0, "holds the heading within 6 deg (worst %.1f)" % _max_dev)
					_check(_walk_from.y - _min_z > 4.0, "the captain walked toward the bow (%.1f m)" % (_walk_from.y - _min_z))
					_check(not w.grid.is_empty(), "the deck map was read from the hull model")
					_check(not _off_deck, "the captain stays on the deck")
					_check(_ship.speed_knots() > 5.0, "still under way (%.1f kn)" % _ship.speed_knots())
					print("auto drive hold: worst heading drift %.1f deg, captain at %s" % [_max_dev, w.fighter.pos])
					_drive.toggle()
					_check(not _drive.is_on() and not _pc.auto_drive, "K again takes the helm")
					_start(1)
		1:
			if _t > 3.0 and _arrived_at < 0.0 and not _engaged:
				_engaged = true
				_check(_drive.engage(), "engages")
				_drive.pilot.engage(pos, _ship.heading(), [pos.x + 450.0, pos.y - 250.0])
			elif _drive.is_on():
				if _t > 200.0:
					_check(false, "reaches the chart mark within 200 s (%.0f m left)" % _drive.pilot.distance_left(pos))
					_start(2)
			elif _engaged and _arrived_at < 0.0:
				_arrived_at = _t
				_check(_ship.sail_level == 0, "sails furled on arrival")
				print("auto drive course: arrived after %.0f s" % _t)
			elif _arrived_at > 0.0 and _t > _arrived_at + 0.5:
				_arrived_at = -1.0
				_start(2)
		2:
			if _t > 3.0 and not _drive.is_on():
				_check(_drive.engage(), "engages")
				_drive.walker.use_keys = false
			elif _drive.is_on():
				_min_island = minf(_min_island, pos.distance_to(ISLAND["pos"]))
				if _t > 110.0:
					_check(_min_island > float(ISLAND["radius"]) + 20.0, "keeps clear of the island (closest %.0f m, radius %.0f)" % [_min_island, ISLAND["radius"]])
					_check(pos.y < -420.0, "and gets past it (z %.0f)" % pos.y)
					print("auto drive island: closest %.0f m, now at %s" % [_min_island, pos])
					_start(3)
		3:
			if _t > 3.0 and not _drive.is_on() and _t < 4.0:
				_check(_drive.engage(), "engages")
			elif _t > 6.0 and _t < 6.1 and _drive.is_on():
				_ship.hit_taken.emit({})
				_check(not _drive.is_on(), "a hit hands the helm back")
				_check(_drive.walker == null, "the captain is back at the wheel")
			elif _t > 7.0:
				_finish()
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		print("FAIL: " + msg)


func _finish() -> void:
	_scenario = -1
	if _failures.is_empty():
		print("M25 auto drive: all checks passed")
		quit(0)
	else:
		print("M25 auto drive: %d failure(s)" % _failures.size())
		quit(1)
