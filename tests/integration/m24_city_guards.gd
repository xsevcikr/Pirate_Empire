extends SceneTree
## City guards in the running world: firing on a harbour sends its watch out, the boats hunt the player and are
## prizes, beating the last one pays the war chest into the save and the ship's shot locker, and the city cannot
## call a new watch straight away. Sailing off makes a second watch give up.
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m24_city_guards.gd

var _fails: Array[String] = []
var _frames: int = 0
var _step: int = 0
var _boats: Array = []
var _other: String = ""


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	var w: Node = current_scene
	var g: CityGuards = w.get("guards")
	var st: Dictionary = Session.state
	match _step:
		0:
			_check(g != null, "world has the city watch")
			if g == null:
				return _finish()
			CannonTower.alert.clear()
			CannonTower.raise_alert("blackwater")
			_step = 1
			_frames = 0
			return false
		1:
			if _frames < 60:
				return false
			_check(g.active.has("blackwater"), "firing on Blackwater sends its watch out")
			if not g.active.has("blackwater"):
				return _finish()
			_boats = (g.active["blackwater"] as Array).duplicate()
			var tier: String = PortData.PORTS["blackwater"]["tier"]
			_check(_boats.size() == CityGuardData.wave_for(tier).size(), "a full wave for a %s" % tier)
			for b: Ship in _boats:
				_check(w.prizes.targets.has(b), "guard boat is a prize")
				_check(b.ai != null and b.faction == CityGuardData.GUARD_FACTION, "guard boat is crewed and hostile")
			var gold0: int = int(st["gold"])
			var round0: int = int(w.ship.broadside.ammo["round"])
			var shots0: int = int(st["pistol_shots"])
			var rum0: float = float(st["supplies"]["rum"])
			for i in _boats.size():
				var b: Ship = _boats[i]
				w.prizes.finish_prize(b, {"gold": 0, "cargo": {}, "supplies": {}, "map_fragment": ""}, CaptureFate.Fate.STRIP_AND_SINK)
				if i < _boats.size() - 1:
					_check(g.active.has("blackwater"), "the watch fights on while a boat is left")
				b.queue_free()
			var r: Dictionary = CityGuardData.reward_for(tier)
			_check(not g.active.has("blackwater"), "the watch is beaten")
			_check(int(st["gold"]) == gold0 + int(r["gold"]), "the war chest pays gold")
			_check(int(w.ship.broadside.ammo["round"]) == round0 + int(r["round"]), "round shot goes into the locker")
			_check(int(st["pistol_shots"]) == shots0 + int(r["pistol_shots"]), "pistol shot is paid")
			_check(float(st["supplies"]["rum"]) > rum0, "rum is paid")
			CannonTower.raise_alert("blackwater")
			_step = 2
			_frames = 0
			return false
		2:
			if _frames < 30:
				return false
			_check(not g.active.has("blackwater"), "no new watch straight after a defeat")
			# a second city's watch gives up once the player sails far off
			for id: String in PortData.PORTS:
				if id != "blackwater":
					_other = id
					break
			var launched: Array[Ship] = g.launch(_other)
			_check(not launched.is_empty(), "another city launches its watch")
			var dock: Vector2 = PortData.PORTS[_other]["dock"]
			w.ship.global_position = Vector3(dock.x + CityGuardData.GIVE_UP_M + 500.0, w.ship.global_position.y, dock.y)
			_step = 3
			_frames = 0
			return false
		3:
			if _frames < 30:
				return false
			_check(not g.active.has(_other), "the watch gives up when the player sails off")
			return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M24 CITY GUARDS: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
