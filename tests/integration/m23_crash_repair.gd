extends SceneTree
## Crash damage and crew repair in the running world: the player's cutter rams a sloop square on its side. Both
## hulls are hurt, the sloop (struck on the beam) far worse for its size; both are holed at the point of contact
## and take on water. The player's crew patch the hole with the ship's timber and pump her dry, the damage
## panel shows it all, and the holes and water survive a save and load.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _sloop: Ship
var _hull0: float = 0.0
var _sloop0: float = 0.0


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
	match _step:
		0:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_ship = _world.get("ship")
			_check(_ship.damage.control != null, "the player's ship has damage control")
			_check(_world.get("damage_panel") != null, "the world has a damage panel")
			# open water well south of the start: a sloop lying across our bow, 40 m ahead
			var at := Vector3(600.0, 0.3, 1400.0)
			_ship.global_position = at
			_ship.rotation = Vector3.ZERO
			_ship.sail_level = 0
			_sloop = _world.call("_make_ship", load("res://data/ships/sloop.tres"), at + Vector3(0, 0, -40.0), 90.0, "merchant")
			_sloop.ai = ShipAI.new()  # not added: it lies still, but counts as an AI ship
			_sloop.sail_level = 0
			_go(1, 20)
		1:
			_hull0 = _ship.damage.hull_hp_total()
			_sloop0 = _sloop.damage.hull_hp_total()
			_ship.linear_velocity = Vector3(0, 0, -9.0 * 0.5144)
			_go(2, 1)
		2:
			if _ship.damage.hull_hp_total() >= _hull0 and _frames < 900:
				_ship.linear_velocity = Vector3(0, _ship.linear_velocity.y, -9.0 * 0.5144)
				return false
			var mine: float = _hull0 - _ship.damage.hull_hp_total()
			var theirs: float = _sloop0 - _sloop.damage.hull_hp_total()
			print("ram at 9 kn: cutter took %.0f of %.0f HP, sloop took %.0f of %.0f HP; holes %d / %d" % [mine, _ship.stats.hull_hp, theirs, _sloop.stats.hull_hp, _ship.damage.breaches.size(), _sloop.damage.breaches.size()])
			_check(mine > 10.0, "the ram hurt our bow, %f" % mine)
			_check(theirs > mine, "the sloop, struck on the beam, took more (%f vs %f)" % [theirs, mine])
			_check(_ship.damage.breaches.size() >= 1, "our bow is holed")
			_check(_sloop.damage.breaches.size() >= 1, "the sloop is holed")
			if not _ship.damage.breaches.is_empty():
				_check(int(_ship.damage.breaches[0]["section"]) == 0, "our hole is in the bow, section %d" % int(_ship.damage.breaches[0]["section"]))
				_check((_ship.damage.breaches[0]["pos"] as Vector3).z < 0.0, "at the front of the hull")
			if not _sloop.damage.breaches.is_empty():
				var s: int = int(_sloop.damage.breaches[0]["section"])
				_check(s == 1 or s == 2, "the sloop's hole is in its side, section %d" % s)
			_check(_ship.damage.leak_total() > 0.0, "we are taking water")
			var bv: BreachVisuals = _ship.breach_visuals
			_check(bv != null and bv.get_child_count() == _ship.damage.breaches.size(), "every hole is drawn on the hull")
			_ship.linear_velocity = Vector3.ZERO
			_ship.global_position += Vector3(0, 0, 60.0)
			_go(3, 120)
		3:
			_check(_ship.damage.water_total() > 0.0, "water came in, %f" % _ship.damage.water_total())
			var panel: DamagePanel = _world.get("damage_panel")
			_check(panel != null and DamagePanel.hurt(_ship.damage), "the damage panel has something to show")
			# save with the hole open, then load it back
			Session.capture(_world)
			var dmg: Dictionary = Session.state["ship_damage"]
			_check((dmg.get("breaches", []) as Array).size() == _ship.damage.breaches.size(), "the save keeps the holes")
			var back: Dictionary = SaveGame.from_json(SaveGame.to_json(Session.state))
			_check((back["ship_damage"]["breaches"] as Array).size() == _ship.damage.breaches.size(), "and a JSON round trip too")
			# timber aboard and every hand on repair: the crew plank the holes and pump her out
			Session.state["supplies"]["timber"] = 20.0
			Session.state["crew"] = 12
			Session.apply_to_ship(_ship)
			_ship.crew.focus = CrewState.Focus.REPAIR
			_go(4, 1)
		4:
			if (_ship.damage.open_breach_count() > 0 or _ship.damage.water_total() > 0.05) and _frames < 60 * 240:
				return false
			print("crew patched and pumped in %.1f s, timber left %.1f" % [_frames / 60.0, float(Session.state["supplies"]["timber"])])
			_check(_ship.damage.open_breach_count() == 0, "the crew patched every hole (%d frames)" % _frames)
			_check(_ship.damage.water_total() < 0.05, "and pumped her dry, %f t left" % _ship.damage.water_total())
			_check(float(Session.state["supplies"]["timber"]) < 20.0, "using the ship's timber")
			var planked: bool = false
			for c in _ship.breach_visuals.get_children():
				if c.get_meta("state", "") == "patched":
					planked = true
			_check(planked, "the patch shows on the hull")
			# a shipyard repair clears it all
			Session.state["gold"] = 99999
			_check(PortService.repair(Session.state), "the shipyard repairs her")
			Session.apply_to_ship(_ship)
			_check(_ship.damage.breaches.is_empty(), "no holes after the shipyard")
			_check(_ship.breach_visuals.get_child_count() == 0, "and none drawn")
			return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M23 CRASH REPAIR: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
