extends SceneTree
## Destruction in the running world: a ship runs into an island and is hurt by the impact formula, cannon fire
## cracks and breaks a fort wall into rubble (debris stays under 300), buildings are rebuilt after 3 days, and a
## sinking ship breaks up into wreckage and leaves a wreck on the chart.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _hull0: float = 0.0
var _port: PortScene
var _walls: Array[DestructibleBuilding] = []
var _rep0: float = 0.0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _go(step: int, wait: int = 3) -> void:
	_step = step
	_wait = wait
	_frames = 0


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	_frames += 1
	var st: Dictionary = Session.state
	match _step:
		0:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_ship = _world.get("ship")
			_check(_world.debris != null, "world has a debris manager")
			# Haven Rock: island of radius 160 at the origin, core 147 m. Sail at it from the south at 10 knots.
			_ship.global_position = Vector3(0, 0.3, 168)
			_ship.rotation = Vector3.ZERO
			_ship.sail_level = 0
			_hull0 = _ship.damage.hull_hp_total()
			_ship.linear_velocity = Vector3(0, 0, -10.0 * 0.5144)
			_go(1, 1)
		1:
			if _ship.damage.hull_hp_total() >= _hull0 and _frames < 900:
				_ship.linear_velocity = Vector3(0, _ship.linear_velocity.y, -10.0 * 0.5144)
				return false
			_check(_ship.damage.hull_hp_total() < _hull0, "the island hurt the hull")
			_check(_hull0 - _ship.damage.hull_hp_total() > 20.0, "and by a real amount, %f" % (_hull0 - _ship.damage.hull_hp_total()))
			_ship.grounding.release()
			# fort at Port Regal
			var dock: Vector2 = PortData.PORTS["albion"]["dock"]
			_ship.linear_velocity = Vector3.ZERO
			_ship.global_position = Vector3(dock.x, 0.3, dock.y + 100.0)
			_world.streamer.load_all_near(dock)
			_go(2, 10)
		2:
			_port = _world.streamer.ports.get("albion") as PortScene
			_check(_port != null, "Port Regal built")
			if _port == null:
				return _finish()
			for b in _port.buildings:
				if b.kind == "wall":
					_walls.append(b)
			_check(_walls.size() == 19, "level 3 wall has 19 wall segments plus the gate, got %d" % _walls.size())
			_check(_port.buildings.size() > 25, "harbour has many buildings, got %d" % _port.buildings.size())
			var towers: int = 0
			for b in _port.buildings:
				if b.kind == "tower":
					towers += 1
			_check(towers == 4, "four cannon towers at a level 3 fort, got %d" % towers)
			_rep0 = float(st["rep"]["navy"])
			var w: DestructibleBuilding = _walls[3]
			var gun: String = "12pdr"
			var shots: int = 0
			var stage_seen: Dictionary = {}
			while w.is_alive() and shots < 400:
				w.take_shot(w.global_position, Vector3.BACK, Vector3.FORWARD, gun, "round", 150.0, _ship)
				stage_seen[DestructionData.crack_stage(w.fraction())] = true
				shots += 1
			_check(not w.is_alive() and w.is_ruin, "wall segment fell")
			_check(stage_seen.has(1) and stage_seen.has(2), "it cracked at 66% and 33% on the way")
			_check(shots >= 12 and shots <= 20, "level 3 segment (%d HP) falls in 15 shots of 70, took %d" % [int(w.max_hp), shots])
			_check(st["destroyed"].has(w.building_id), "save remembers the ruin")
			_check(float(st["rep"]["navy"]) < _rep0, "navy think less of you")
			_check(_world.debris.count() > 0 and _world.debris.count() <= 300, "rubble spawned, count %d" % _world.debris.count())
			# batter the rest of the wall to test the cap
			for ww in _walls:
				while ww.is_alive():
					ww.take_shot(ww.global_position, Vector3.BACK, Vector3.FORWARD, gun, "round", 120.0, _ship)
			_check(_world.debris.count() <= 300, "debris stays under 300 bodies, got %d" % _world.debris.count())
			_go(3, 5)
		3:
			# three days later everything comes back
			st["day"] = int(st["day"]) + 3
			_world._rebuild_tick()
			var all_whole: bool = true
			for ww in _walls:
				if ww.is_ruin:
					all_whole = false
			_check(all_whole, "walls rebuilt after three days")
			_check(st["destroyed"].is_empty() or not st["destroyed"].has(_walls[3].building_id), "ruin forgotten")
			# a ship sinks
			var target: Ship = _world._make_ship(load("res://data/ships/sloop.tres"), Vector3(900, 0.5, 900), 0.0, "merchant")
			target.crew.count = 6
			var before: int = _world.debris.count()
			var wrecks0: int = st["wrecks"].size()
			target.damage.sunk = true
			target.damage.sank.emit()
			_go(4, 3)
		4:
			_check(_world.debris.count() > 10, "wreckage floats where she went down, got %d" % _world.debris.count())
			_check(st["wrecks"].size() >= 1, "a wreck is recorded on the chart")
			return _finish()
	if _frames > 3000:
		_fails.append("timed out in step %d" % _step)
		return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M17 DESTRUCTION: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
