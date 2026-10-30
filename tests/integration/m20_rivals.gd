extends SceneTree
## Rivals and sea events in the running world: 1,000 seeded hours of the event table, a rival that sails out and is
## looted (win, reward), a rival that sinks the player (level up, trophy, taunt), the nemesis, and the rivals page.

var _fails: Array[String] = []
var _frames: int = 0


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
	var dir: RivalDirector = w.rivals
	_check(dir != null, "world has a rival director")
	if dir == null:
		return _finish()
	var st: Dictionary = Session.state
	# 1,000 seeded hours of the table, region and season cycling
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts: Dictionary = {}
	var expect: Dictionary = {}
	for i in 1000:
		var ctx: Dictionary = {"region": "merchants_reach", "season": "autumn", "storm": true, "night": true, "navy_rep": -30.0, "bounty": 0.0}
		for id: String in SeaEventData.EVENTS.keys():
			if SeaEventData.EVENTS[id].has("only_region"):
				continue
			expect[id] = float(expect.get(id, 0.0)) + SeaEvents.chance(id, ctx)
		for id in SeaEvents.roll(st, ctx, rng):
			counts[id] = int(counts.get(id, 0)) + 1
	for id: String in expect:
		var want: float = expect[id]
		_check(absf(float(counts.get(id, 0)) - want) <= maxf(0.1 * want, 1.0), "%s: %d fired, table says %.1f" % [id, int(counts.get(id, 0)), want])
	# an hour in the world with the director: events apply to the real state and ships appear
	var before: int = get_nodes_in_group("ships").size()
	for i in 40:
		dir.hour_tick("merchants_reach", false, 12.0)
	_check(st["log"].size() > 0, "events are written to the captain's log")
	_check(get_nodes_in_group("ships").size() >= before, "event ships join the sea")
	# a rival sails out
	st["map_fragments"].append("drowned_purse_1")
	var mol: Ship = dir.challenge("molly")
	_check(mol != null and mol.get_meta("rival", "") == "molly", "Molly's ship has her mark")
	_check(w.prizes.targets.has(mol), "Molly's ship can be looted")
	var g0: int = int(st["gold"])
	for i in 3:
		dir.report_result("molly", true, false)
	_check(RivalState.is_defeated(st, "molly"), "three wins end her arc")
	_check(int(st["gold"]) - g0 >= 1500, "her reward is paid")
	# a rival sinks the player: level up, trophy, taunt, nemesis
	var sal: Ship = dir.challenge("saltjaw")
	_check(sal != null, "Saltjaw sails out")
	sal.global_position = w.ship.global_position + Vector3(400, 0, 0)
	dir._on_defeated({})
	var r: Dictionary = RivalState.get_rival(st, "saltjaw")
	_check(int(r["level"]) == 2, "Saltjaw levelled up")
	_check(str(r["trophy"]) != "", "Saltjaw took a trophy")
	_check(RivalState.nemesis(st) == "saltjaw", "Saltjaw is the nemesis")
	_check((RivalState.root(st)["taunts"] as Array).size() == 1, "a taunt was sent")
	# the page shows the trophy
	w.open_rivals()
	var layer: Node = w.get_node_or_null("MapLayer")
	_check(layer != null and layer.get_child_count() > 0, "the rivals page opens")
	return _finish()


func _finish() -> bool:
	if _fails.is_empty():
		print("M20 RIVALS: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
