extends SceneTree
## Ten days at sea with no food: morale falls day by day, the crew mutinies on day 4, hunger starts killing
## after the three-day grace, and the ship's crew always matches the save state.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _world: Node
var _ship: Ship
var _clock: Node
var _day_offset: int = 0
var _mutiny_day: int = -1
var _log: Array[float] = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	Session.begin_new("Starver", 1, 1)
	Session.enter_world(self)


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
		return n
	for c in n.get_children():
		var r: Node = _find(c, cls)
		if r != null:
			return r
	return null


func _labels(n: Node) -> String:
	var out: String = ""
	if n is Label:
		out += (n as Label).text + "\n"
	for c in n.get_children():
		out += _labels(c)
	return out


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	var st: Dictionary = Session.state
	match _step:
		0:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_ship = _world.get("ship")
			_clock = root.get_node("GameClock")
			st["gold"] = 100000
			st["tutorial"] = "done"
			for i in 9:
				st["roster"].append({"name": "Hand %d" % i, "type": "green", "level": 1, "xp": 0})
			st["crew"] = 9
			st["supplies"]["food"] = 0.0
			st["supplies"]["water"] = 500.0
			st["supplies"]["rum"] = 1.0
			st["morale"] = 70.0
			_ship.global_position = Vector3(0, 0.3, 900)  # well away from the dock
			Session.apply_to_ship(_ship)
			_day_offset = _clock.day
			st["last_tick_day"] = _clock.day
			_check(_ship.crew.count == 9, "ship carries the nine hands")
			_step = 1
			_wait = 5
		1:
			# advance one game day at a time
			if _find(_world, "MutinyScreen") != null:
				_mutiny_day = _clock.day - _day_offset
				var ms: MutinyScreen = _find(_world, "MutinyScreen") as MutinyScreen
				_check(paused, "a mutiny pauses the game")
				ms._choose(Mutiny.Option.MAROON)
				_check(st["crew"] == 5, "marooning 40%% of nine leaves five, got %d" % st["crew"])
				_check(_ship.crew.count == 5, "ship crew follows the state after the mutiny")
				_check(absf(st["morale"] - 35.0) < 0.01, "morale 35 after marooning")
				_step = 2
				_wait = 3
				return false
			if _clock.day - _day_offset >= 10:
				_check(false, "no mutiny in ten days")
				return _finish()
			_clock.day += 1
			_wait = 3
			_log.append(st["morale"])
		2:
			_check(_mutiny_day == 4, "mutiny on day 4, got %d" % _mutiny_day)
			_check(absf(_log[1] - 56.0) < 0.01 and absf(_log[2] - 40.0) < 0.01 and absf(_log[3] - 24.0) < 0.01, "morale by day: %s" % str(_log))
			_check(_ship.crew.morale_factor() == Morale.efficiency(st["morale"]), "ship efficiency uses the morale bands")
			var screen := CrewScreen.new()
			var layer := CanvasLayer.new()
			_world.add_child(layer)
			layer.add_child(screen)
			_step = 3
			_wait = 3
		3:
			var text: String = _labels(_find(_world, "CrewScreen"))
			_check(text.contains("Morale 35"), "crew screen shows the morale")
			_check(text.contains("Hand 0") or text.contains("Hand 8"), "crew screen lists the roster")
			# keep starving: deaths must come only after the grace period and the crew must stay in step
			var before: int = st["crew"]
			for i in 6:
				_clock.day += 1
			_step = 4
			_wait = 5
		4:
			_check(st["starve_days"] >= 10 - 0, "ten starving days recorded, got %d" % st["starve_days"])
			_check(_ship.crew.count == CrewLife.fit_crew(st), "ship crew matches state after more days")
			_check(st["crew"] < 5 or st["death_accum"] > 0.0, "hunger started to kill")
			return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M13 PASS: crew life")
		quit(0)
	else:
		for f in _fails:
			print("M13 FAIL: ", f)
		quit(1)
	return true
