extends SceneTree
## M2 acceptance: a sloop broadside damages a brigantine, projectiles are pooled and
## returned, and the target eventually sinks under repeated fire.
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m2_combat.gd

var _ocean := WaveModel.new(0.0)
var _wind := WindModel.new()
var _pm: ProjectileManager
var _attacker: Ship
var _target: Ship
var _t: float = 0.0
var _failures: Array[String] = []
var _phase: int = 0
var _fired_before: int = 0
var _hull_after_first: float = 1.0
var _ready_to_run: bool = false


func _initialize() -> void:
	_wind.speed_kn = 0.0
	_pm = ProjectileManager.new()
	_pm.ocean = _ocean
	root.add_child(_pm)
	_attacker = _make("res://data/ships/sloop.tres", Vector3(0, 0.2, 0), 0.0)
	_target = _make("res://data/ships/brigantine.tres", Vector3(90, 0.2, 0), 90.0)
	await process_frame  # ships run _ready on the first frame
	_attacker.broadside.projectiles = _pm
	_target.broadside.projectiles = _pm
	_ready_to_run = true
	_attacker.broadside.spread_scale = 0.0
	_attacker.broadside.gun_id = "12pdr"
	_attacker.broadside.elevation_deg = 0.0


func _make(path: String, pos: Vector3, yaw: float) -> Ship:
	var s := Ship.new()
	s.stats = load(path)
	s.ocean = _ocean
	s.wind = _wind
	s.sail_level = 0
	s.position = pos
	s.rotation_degrees.y = yaw
	root.add_child(s)
	return s


func _physics_process(delta: float) -> bool:
	if not _ready_to_run:
		return false
	_t += delta
	_ocean.time += delta
	match _phase:
		0:
			if _t > 4.0:  # let both ships settle
				var el: float = _attacker.broadside.elevation_for_range(1, _attacker.global_position.distance_to(_target.global_position))
				_attacker.broadside.set_elevation(el)
				_fired_before = _attacker.broadside.ammo["round"]
				var n: int = _attacker.broadside.fire(1)
				_check(n == 4, "first broadside fires all 4 loaded guns, fired %d" % n)
				_phase = 1
				_t = 0.0
		1:
			if _t > 5.0:
				_check(_pm.active_count() == 0, "projectile pool drains (%d active)" % _pm.active_count())
				_check(_attacker.broadside.ammo["round"] == _fired_before - 4, "ammo decremented by 4")
				_check(_pm.hits + _pm.misses == 4, "all 4 balls resolved (hits %d misses %d)" % [_pm.hits, _pm.misses])
				_check(_pm.hits >= 1, "at least one ball of an aimed broadside (%d)" % _pm.hits)
				_check(_target.damage.hull_fraction() < 1.0 or _target.damage.water_total() > 0.0 or _target.damage.sail_health() < 1.0, "target took damage")
				_hull_after_first = _target.damage.hull_fraction()
				print("M2 first broadside: hits %d/4, target hull %.1f%%" % [_pm.hits, _hull_after_first * 100.0])
				var n: int = _attacker.broadside.fire(1)
				_check(n == 0, "guns are still reloading right after firing, but %d fired" % n)
				_phase = 2
				_t = 0.0
		2:
			# keep firing, reloading instantly and resupplying, until the target is sunk
			_attacker.broadside.ammo["round"] = 300
			if _attacker.broadside.ready_count(1) == _attacker.broadside.gun_count():
				var rng_m: float = _attacker.global_position.distance_to(_target.global_position)
				_attacker.broadside.set_elevation(_attacker.broadside.elevation_for_range(1, rng_m))
				_attacker.broadside.fire(1)
			_attacker.crew.count = _attacker.crew.crew_max
			if _target.damage.sunk:
				print("M2 target sunk after %.0f s, hull %.1f%%, flooding %.0f%%" % [_t, _target.damage.hull_fraction() * 100.0, _target.damage.flood_fraction() * 100.0])
				_phase = 3
				_t = 0.0
			elif _t > 600.0:
				_check(false, "target never sank in 600 s of fire (hull %.1f%%, flood %.0f%%)" % [_target.damage.hull_fraction() * 100.0, _target.damage.flood_fraction() * 100.0])
				_finish()
		3:
			if _t > 20.0:
				_check(_target.global_position.y < -1.0, "sunk target actually sinks in the water (y %.2f)" % _target.global_position.y)
				_check(_pm.active_count() <= 4, "pool bounded")
				_finish()
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	print("M2 combat: %s" % ("FAILED" if not _failures.is_empty() else "OK"))
	for f in _failures:
		print("  FAIL " + f)
	quit(1 if not _failures.is_empty() else 0)
