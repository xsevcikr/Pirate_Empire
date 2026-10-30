extends SceneTree
## M23 in the running world: Skull Atoll loads with a levelled pad and a claim sign, the player lands from the
## piers' water, claims the atoll, places and upgrades buildings in build mode, the lagoon shows them with piers,
## moored ships and villagers, a day fills the chest, coming ashore empties it, and a big lagoon streams in
## without a long frame.

const HITCH_MS: float = 50.0

var _fails: Array[String] = []
var _frames: int = 0
var _step: int = 0
var _wait: int = 0
var _mode: LagoonBuildMode
var _last_us: int = 0
var _worst_ms: float = 0.0
var _start: int = -1


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.state["gold"] = 300000
	Session.state["fame"] = 99999
	Session.state["tutorial"] = "done"
	var dock: Vector2 = LagoonData.dock_point()
	Session.state["pos"] = [dock.x, dock.y]
	Session.enter_world(self)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	var w: Node = current_scene
	if _start < 0:
		_start = _frames
	var lagoon: LagoonScene = w.streamer.lagoon
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:
			_check(lagoon != null, "Skull Atoll is loaded and has a lagoon node")
			if lagoon == null:
				return _finish()
			lagoon.flush()
			var isl: Island = lagoon.island
			_check(absf(isl.ground_y(LagoonData.cell_local(Vector2i(2, 2))) - LagoonData.PAD_H_M) < 0.01, "the build ground is level")
			_check(lagoon.node_for("sign") != null, "an unclaimed atoll shows the claim sign")
			_check(w.can_land_lagoon(), "the player can land off the piers")
			w.open_lagoon()
			_step = 1
			_wait = 5
		1:
			var scr: LagoonScreen = w.get_node("PortLayer").get_child(0)
			_check(paused, "ashore pauses the sea")
			scr._claim()
			_check(Lagoon.claimed(Session.state), "the atoll is claimed from the lagoon screen")
			scr._open_build_mode()
			_step = 2
			_wait = 3
		2:
			_mode = w.get_node_or_null("LagoonBuildMode")
			_check(_mode != null, "build mode opens")
			if _mode == null:
				return _finish()
			_check(get_root().get_viewport().get_camera_3d() == _mode._cam, "build mode looks down from its own camera")
			_mode.pick("hut")
			_mode.move_cursor(Vector2i(1, 0))
			_check(_mode._ghost != null, "a see-through hut shows on the free plot")
			_check(_mode.confirm(), "the hut is built")
			_mode.pick("tavern")
			_mode.move_cursor(Vector2i(-1, 0))
			_mode.confirm()
			_mode.pick("tavern")
			_mode.move_cursor(Vector2i(1, 0))
			_mode.upgrade_selected()
			_check(int(Lagoon.building_at(Session.state, Vector2i(1, 0))["lv"]) == 2, "the hut is upgraded from build mode")
			_mode.move_cursor(Vector2i(5, 0))
			_mode.pick("hut")
			_check(not _mode.confirm(), "a closed plot refuses")
			_mode.finish()
			_step = 3
			_wait = 3
		3:
			_check(get_root().get_viewport().get_camera_3d() != null and w.get_node_or_null("LagoonBuildMode") == null, "build mode closes")
			lagoon.flush()
			_check(lagoon.node_for("b1,0") != null and lagoon.node_for("b-1,0") != null, "the buildings stand in the lagoon")
			_check(lagoon.node_for("hall") != null, "the captain's hall stands in the middle")
			Lagoon.build_pier(Session.state)
			Session.state["fleet"].append({"class": "brigantine", "name": "Prize", "crew": 0, "hull": 0.5})
			Session.state["fleet"].append({"class": "sloop", "name": "Spare", "crew": 0, "hull": 1.0})
			var scr2: LagoonScreen = w.get_node("PortLayer").get_child(0)
			scr2.close()
			_step = 4
			_wait = 5
		4:
			_check(not paused, "setting sail unpauses")
			lagoon.flush()
			_check(lagoon.node_for("p0") != null, "the pier stands")
			_check(lagoon.node_for("s0") != null and lagoon.node_for("s1") != null, "one ship at the pier and one at anchor")
			for d in 6:
				w._lagoon_day()
			_check(int(Lagoon.data(Session.state)["pop"]) > 0, "pirates moved in")
			_check(float(Lagoon.data(Session.state)["chest"]) > 0.0, "the chest fills while away")
			_step = 5
			_wait = 20
		5:
			_check(lagoon.villager_count() == mini(int(Lagoon.data(Session.state)["pop"]), LagoonData.MAX_VILLAGERS), "a villager walks for every resident")
			var gold: int = int(Session.state["gold"])
			var chest: int = int(float(Lagoon.data(Session.state)["chest"]))
			w.open_lagoon()
			_check(int(Session.state["gold"]) == gold + chest, "coming ashore empties the chest into the purse")
			var scr3: LagoonScreen = w.get_node("PortLayer").get_child(0)
			scr3.close()
			_step = 6
			_wait = 3
		6:
			# grow a big lagoon and let it stream in a few pieces a frame
			var s: Dictionary = Session.state
			for i in 3:
				Lagoon.rank_up(s)
			for c in LagoonData.cells(3):
				Lagoon.place(s, LagoonData.ORDER[absi(c.x * 3 + c.y) % LagoonData.ORDER.size()], c)
			lagoon.sync()
			_check(lagoon.pending() > 20, "a big change is queued, not built at once")
			_last_us = Time.get_ticks_usec()
			_step = 7
		7:
			var now: int = Time.get_ticks_usec()
			_worst_ms = maxf(_worst_ms, (now - _last_us) / 1000.0)
			_last_us = now
			if lagoon.pending() == 0:
				_check(_worst_ms < HITCH_MS, "the lagoon streams in without a long frame (worst %.1f ms)" % _worst_ms)
				print("lagoon stream worst frame %.1f ms" % _worst_ms)
				return _finish()
	if _frames - _start > 4000:
		_check(false, "timed out at step %d" % _step)
		return _finish()
	return false


func _finish() -> bool:
	for f in _fails:
		print("FAIL m23: " + f)
	print("m23_lagoon: %s" % ("ok" if _fails.is_empty() else "%d failures" % _fails.size()))
	Kenney.clear_caches()
	quit(1 if not _fails.is_empty() else 0)
	return true
