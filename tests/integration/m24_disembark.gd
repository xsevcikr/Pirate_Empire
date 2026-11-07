extends SceneTree
## Harbour docking on foot: F near a harbour (and only there, and only slow) ties the ship up alongside the pier,
## the captain walks into the dock district with his crew behind him and his ship lies at the pier; walking back
## onto the pier takes him aboard and the ship is where he left her.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _district: DockDistrict
var _menu: PortMenu
var _berth: Dictionary


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	for i in 5:
		Session.state["roster"].append({"name": "Hand %d" % i, "type": ["gunner", "swordsman", "seasoned", "green", "musketeer"][i], "level": 1, "xp": 0})
	Session.state["crew"] = Session.state["roster"].size()
	Session.enter_world(self)


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
		return n
	for c in n.get_children():
		var r: Node = _find(c, cls)
		if r != null:
			return r
	return null


func _count_kind(n: Node, kind: String) -> int:
	var c: int = 1 if n.has_meta("kind") and n.get_meta("kind") == kind else 0
	for ch in n.get_children():
		c += _count_kind(ch, kind)
	return c


func _go(step: int, wait: int = 3) -> void:
	_step = step
	_wait = wait
	_frames = 0


func _place(p: Vector2, speed_ms: float = 0.0) -> void:
	_ship.global_position = Vector3(p.x, 0.3, p.y)
	_ship.linear_velocity = -_ship.global_transform.basis.z * speed_ms
	_ship.angular_velocity = Vector3.ZERO
	_ship.sail_level = 0


func _press_f() -> void:
	var ev := InputEventAction.new()
	ev.action = "disembark"
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = "disembark"
	up.pressed = false
	Input.parse_input_event(up)


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
			_go(1, 30)
		1:
			# out at sea F is the gun elevation: nothing happens
			var sea := Vector2(0, 420)
			for c in [Vector2(0, 1200), Vector2(1500, 1500), Vector2(-2500, 300), Vector2(3000, -3000)]:
				if PortData.port_near(c, 400.0) == "" and not LagoonData.near_dock(c):
					sea = c
					break
			_place(sea)
			_check(not _world.can_disembark(), "no harbour near: F does not disembark")
			_check(_world.harbour_hint() == "", "no harbour hint at sea, got '%s'" % _world.harbour_hint())
			var dock: Vector2 = PortData.PORTS["albion"]["dock"]
			_world.streamer.load_all_near(dock)
			_place(dock + Vector2(10, 0), 5.0)
			_go(2, 1)
		2:
			_check(_world.dock_port() == "albion", "in Port Regal's dock zone, got '%s'" % _world.dock_port())
			if _ship.speed_knots() > Mooring.MAX_SPEED_KN:
				_check(not _world.can_disembark(), "too fast to tie up")
				_check(_world.harbour_hint() == Loc.t("moor.too_fast"), "hint says slow down, got '%s'" % _world.harbour_hint())
			_place(PortData.PORTS["albion"]["dock"] + Vector2(10, 0))
			_go(3, 4)
		3:
			_check(_world.can_disembark(), "slow in the dock zone: F works")
			_check(_world.harbour_hint().contains("F"), "hint names F, got '%s'" % _world.harbour_hint())
			_berth = Mooring.berth("albion", _ship.stats.length_m, _ship.stats.beam_m)
			_press_f()
			_go(4, 6)
		4:
			_menu = _find(_world, "PortMenu") as PortMenu
			_check(_menu != null and _menu.on_foot, "F opened the harbour on foot")
			_check(paused, "the world waits while the captain is ashore")
			var at: Vector2 = Vector2(_ship.global_position.x, _ship.global_position.z)
			_check(at.distance_to(_berth["pos"]) < 0.5, "ship tied up at the berth, %s vs %s" % [at, _berth["pos"]])
			_check(_ship.sail_level == 0 and _ship.linear_velocity.length() < 0.01, "sails furled and still")
			_district = _find(current_scene, "DockDistrict") as DockDistrict
			_check(_district != null, "walked straight into the dock district")
			if _district == null or _menu == null:
				return _finish()
			_check(not _menu.visible, "no menu over the street")
			_check(_district.followers.size() == 5, "five crew came ashore, got %d" % _district.followers.size())
			_check(_count_kind(_district, "shore_crew") == 5, "five crew drawn in the street")
			_check(_count_kind(_district, "moored_ship") == 1, "own ship drawn at the pier")
			# walk up the street: the crew follow
			for i in 40:
				_district.step(Vector2(0, -1), 0.05)
				_district.follow(0.05)
			var cap: Vector2 = Vector2(_district.captain.position.x, _district.captain.position.z)
			for f in _district.followers:
				_check(f.pos.distance_to(cap) < 8.0, "crewman keeps up with the captain (%.1f m)" % f.pos.distance_to(cap))
				_check(f.pos.y > cap.y, "crewman walks behind the captain")
			# and back down to the pier
			var pier: Vector3 = Vector3.ZERO
			for d in _district.doors:
				if d["kind"] == "pier":
					pier = d["pos"]
			var guard: int = 0
			while Vector2(_district.captain.position.x, _district.captain.position.z).distance_to(Vector2(pier.x, pier.z)) > 1.5 and guard < 400:
				_district.step(Vector2(pier.x - _district.captain.position.x, pier.z - _district.captain.position.z), 0.05)
				guard += 1
			_check(_district.nearest_door() == "pier", "at the gangway, got '%s'" % _district.nearest_door())
			_district.use_nearest()
			_go(5, 6)
		5:
			_check(_world.get_node_or_null("PortLayer") == null, "back aboard: harbour closed")
			_check(not paused, "the world runs again")
			var at2: Vector2 = Vector2(_ship.global_position.x, _ship.global_position.z)
			_check(at2.distance_to(_berth["pos"]) < 1.5, "ship still at the berth when the captain comes back")
			return _finish()
	if _frames > 6000:
		_fails.append("timed out in step %d" % _step)
		return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M24 DISEMBARK: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
