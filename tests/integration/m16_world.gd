extends SceneTree
## The named world: islands stream in and out as the ship sails a lap of the whole map without a frame over
## 50 ms, the chart reveals and routes, any port can be docked, and the dock district can be walked.

const HITCH_MS: float = 50.0

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _lap: Array[Vector2] = []
var _lap_i: int = 0
var _last_us: int = 0
var _worst_ms: float = 0.0
var _worst_at: String = ""
var _district: DockDistrict
var _menu: PortMenu


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
		return n
	for c in n.get_children():
		var r: Node = _find(c, cls)
		if r != null:
			return r
	return null


func _go(step: int, wait: int = 3) -> void:
	_step = step
	_wait = wait
	_frames = 0


func _place(p: Vector2) -> void:
	_ship.global_position = Vector3(p.x, 0.3, p.y)
	_ship.linear_velocity = Vector3.ZERO
	_ship.angular_velocity = Vector3.ZERO
	_ship.sail_level = 0


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
			var s: WorldStreamer = _world.streamer
			_check(s.loaded.size() >= 1 and s.loaded.size() < 24, "only nearby islands load at the start, got %d" % s.loaded.size())
			_check(s.ports.has("blackwater"), "Blackwater harbour built")
			# a lap: round the regions at ~700 m steps, avoiding island discs
			for corner in [Vector2(-6500, 6500), Vector2(6500, 6500), Vector2(6500, -6500), Vector2(-6500, -6500), Vector2(0, 700)]:
				_lap.append(corner)
			_lap = _densify(_lap)
			_go(1, 5)
		1:
			# warm-up frames done: start timing the lap
			if _lap_i == 0:
				_last_us = Time.get_ticks_usec()
			var now: int = Time.get_ticks_usec()
			if _frames > 3:
				var ms: float = float(now - _last_us) / 1000.0
				if ms > _worst_ms:
					_worst_ms = ms
					_worst_at = "step %d at %s" % [_lap_i, str(_lap[mini(_lap_i, _lap.size() - 1)])]
			_last_us = now
			if _lap_i < _lap.size():
				_place(_lap[_lap_i])
				_lap_i += 1
				_wait = 1
				return false
			var streamer: WorldStreamer = _world.streamer
			_check(streamer.loads > 10, "the lap loaded many islands, got %d" % streamer.loads)
			_check(streamer.unloads > 5, "and unloaded them again, got %d" % streamer.unloads)
			_check(streamer.peak_loaded <= 14, "never more than 14 islands at once, peak %d" % streamer.peak_loaded)
			print("M16 stream: loads %d unloads %d peak %d worst frame %.1f ms (%s)" % [streamer.loads, streamer.unloads, streamer.peak_loaded, _worst_ms, _worst_at])
			_check(_worst_ms <= HITCH_MS, "worst frame %.1f ms over %.0f ms (%s)" % [_worst_ms, HITCH_MS, _worst_at])
			_go(2, 5)
		2:
			var disc: Discovery = SaveGame.restore_discovery(str(st["discovery"]))
			_check(disc.count() > 40, "sailing revealed the chart, %d chunks" % disc.count())
			_place(Vector2(0, 700))
			_go(3, 3)
		3:
			var screen := WorldMapScreen.new()
			screen.player_pos = Vector2(0, 700)
			screen.max_speed_kn = 11.0
			_world.add_child(screen)
			screen.set_goal(Vector2(-3000, 5200))
			_check(not screen.route.is_empty(), "chart finds a route")
			_check(screen.eta_hours() > 0.2, "ETA is more than 12 minutes, got %f" % screen.eta_hours())
			_check(st["course"].size() == 2, "course stored in the save")
			var known: int = 0
			for isl in screen.chart.gen.islands:
				if screen.island_known(isl):
					known += 1
			_check(known >= 3, "discovered islands show, got %d" % known)
			screen.close()
			_go(4, 3)
		4:
			var dock: Vector2 = PortData.PORTS["albion"]["dock"]
			_world.streamer.load_all_near(dock)
			_place(dock + Vector2(10, 0))
			_go(5, 5)
		5:
			_check(_world.dock_port() == "albion", "docking zone of Port Regal, got '%s'" % _world.dock_port())
			_check(_world.can_dock(), "can dock at Port Regal")
			_world.open_port()
			_go(6, 4)
		6:
			_menu = _find(_world, "PortMenu") as PortMenu
			_check(_menu != null and _menu.port_id == "albion", "port menu is for albion")
			_menu._walk_the_docks()
			_go(7, 4)
		7:
			_district = _find(_world, "DockDistrict") as DockDistrict
			if _district == null:
				_district = _find(current_scene, "DockDistrict") as DockDistrict
			_check(_district != null, "dock district built")
			if _district == null:
				return _finish()
			_check(_district.doors.size() >= 6, "market, shipyard, tavern, outfitter, quests, bank and the pier, got %d" % _district.doors.size())
			var target: Vector3 = Vector3.ZERO
			for d in _district.doors:
				if d["kind"] == "market":
					target = d["pos"]
			var guard: int = 0
			while Vector2(_district.captain.position.x, _district.captain.position.z).distance_to(Vector2(target.x, target.z)) > 2.0 and guard < 400:
				var to: Vector2 = Vector2(target.x - _district.captain.position.x, target.z - _district.captain.position.z)
				_district.step(to, 0.1)
				guard += 1
			_check(_district.nearest_door() == "market", "standing at the market door, got '%s'" % _district.nearest_door())
			var opened: Array[String] = []
			_district.door_used.connect(func(k: String) -> void: opened.append(k))
			_district.use_nearest()
			_check(opened == ["market"], "door opens the market, got %s" % str(opened))
			_district.active = true
			_district.leave()
			_go(8, 3)
		8:
			_check(_menu.visible, "port menu comes back after leaving the district")
			_menu.close()
			return _finish()
	if _frames > 6000:
		_fails.append("timed out in step %d" % _step)
		return _finish()
	return false


## Fill in points along the legs so no step is more than ~600 m.
func _densify(pts: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var at: Vector2 = Vector2(0, 420)
	for p in pts:
		var n: int = maxi(int(at.distance_to(p) / 600.0), 1)
		for k in range(1, n + 1):
			out.append(at.lerp(p, float(k) / float(n)))
		at = p
	return out


func _finish() -> bool:
	if _fails.is_empty():
		print("M16 WORLD: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
