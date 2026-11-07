extends SceneTree
## M1 acceptance scenarios for the sloop. Run with:
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m1_sailing.gd

const SLOOP: ShipStats = preload("res://data/ships/sloop.tres")

var _failures: Array[String] = []
var _ship: Ship
var _ocean: WaveModel
var _wind: WindModel
var _scenario: int = 0
var _t: float = 0.0
var _max_heel: float = 0.0
var _max_pitch: float = 0.0
var _min_y: float = 1e9
var _speed_samples: Array[float] = []
var _frames: int = 0


func _initialize() -> void:
	_start_scenario(0)


func _start_scenario(n: int) -> void:
	if _ship:
		_ship.queue_free()
	_scenario = n
	_t = 0.0
	_max_heel = 0.0
	_max_pitch = 0.0
	_min_y = 1e9
	_speed_samples.clear()
	_wind = WindModel.new()
	_wind.speed_kn = 20.0
	match n:
		0:  # beam reach on flat sea: wind from port, heading -Z
			_ocean = WaveModel.new(0.0)
			_wind.direction = Vector2(1, 0)
		1:  # wind from dead ahead: no wind mechanics, so she sails just as fast
			_ocean = WaveModel.new(0.0)
			_wind.direction = Vector2(0, 1)
		2:  # stability in sea state 6, beam wind
			_ocean = WaveModel.new(6.0, Vector2(1, 0))
			_wind.speed_kn = 24.0
			_wind.direction = Vector2(1, 0)
	_ship = Ship.new()
	_ship.stats = SLOOP
	_ship.ocean = _ocean
	_ship.wind = _wind
	_ship.position = Vector3(0, 0.2, 0)
	root.add_child(_ship)


func _physics_process(delta: float) -> bool:
	if _ship == null:
		return false
	_t += delta
	_ocean.time += delta
	_frames += 1
	if _t > 5.0:
		_max_heel = maxf(_max_heel, absf(_ship.heel_deg()))
		_max_pitch = maxf(_max_pitch, absf(_ship.pitch_deg()))
		_min_y = minf(_min_y, _ship.global_position.y)
	match _scenario:
		0:
			if _t >= 45.0:
				var kn: float = _ship.speed_forward_ms / 0.514
				_check(kn >= 14.0 * 0.95 and kn <= 14.0 * 1.05, "beam reach speed %.2f kn within 95-105%% of 14" % kn)
				_check(_max_heel < 12.0, "heel %.1f deg < 12" % _max_heel)
				print("M1 beam reach: %.2f kn, max heel %.1f deg" % [kn, _max_heel])
				_start_scenario(1)
		1:
			if _t >= 40.0:
				var kn: float = _ship.speed_forward_ms / 0.514
				_check(kn >= 14.0 * 0.95 and kn <= 14.0 * 1.05, "into the wind speed %.2f kn within 95-105%% of 14 (no wind mechanics)" % kn)
				print("M1 into the wind: %.2f kn" % kn)
				_start_scenario(2)
		2:
			if _t >= 120.0:
				_check(_min_y > -4.0, "ship stays afloat (min y %.2f)" % _min_y)
				_check(_max_pitch < 25.0, "pitch %.1f deg < 25" % _max_pitch)
				_check(_max_heel < 35.0, "heel in sea state 6 %.1f deg < 35" % _max_heel)
				print("M1 sea state 6: min y %.2f, max pitch %.1f, max heel %.1f" % [_min_y, _max_pitch, _max_heel])
				print("M1 sailing: %s" % ("FAILED" if not _failures.is_empty() else "OK"))
				for f in _failures:
					print("  FAIL " + f)
				quit(1 if not _failures.is_empty() else 0)
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
