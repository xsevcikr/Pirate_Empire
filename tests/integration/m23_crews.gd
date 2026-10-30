extends SceneTree
## M23 rival pirate crews in the running world: their lagoons on the sea, a warband in their colours, guards on a
## claimed island whose stash pays out, a crew that boards the player and is fought on deck, the flagship at the
## lagoon that ends a crew, and the crews page.
##   godot --headless --path . --fixed-fps 60 -s res://tests/integration/m23_crews.gd

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
	var dir: CrewDirector = w.crews
	_check(dir != null, "world has a crew director")
	if dir == null:
		return _finish()
	var st: Dictionary = Session.state
	_check(dir.lagoon_nodes.is_empty(), "no lagoon is built far from the player")
	var lp: Vector2 = CrewData.lagoon_pos("sea_wolves")
	var home: Vector3 = w.ship.global_position
	w.ship.global_position = Vector3(lp.x + 2000.0, home.y, lp.y)
	dir.build_near_lagoons()
	_check(dir.lagoon_nodes.has("sea_wolves") and dir.lagoon_nodes.size() == 1, "the near lagoon is built")
	w.ship.global_position = home
	# a warband in the crew's colours
	var band: Array[Ship] = dir.send_warband("red_hand")
	_check(not band.is_empty(), "the Red Hand sends a warband")
	for s in band:
		_check(s.get_meta("crew", "") == "red_hand" and w.prizes.targets.has(s), "warband ship is a crew ship and a prize")
		_check(s.get_meta("deck_faction", "") == "crew_red_hand", "its men fight as the Red Hand")
	# a claimed island: guards appear, beating both pays the stash
	var r := RandomNumberGenerator.new()
	r.seed = 4
	var n: Dictionary = PirateCrews.act(st, "black_gulls", "claim_island", r)
	var isl: String = n["args"][1]
	var guards: Array[Ship] = dir.guard_island(isl)
	_check(guards.size() == 2, "two guards at the claimed island")
	var g0: int = int(st["gold"])
	var stash: int = int(PirateCrews.root(st)["claims"][isl]["stash"])
	for g in guards:
		w.prizes.finish_prize(g, {"gold": 0, "cargo": {}, "supplies": {}, "map_fragment": ""}, CaptureFate.Fate.STRIP_AND_SINK)
		g.queue_free()
	_check(not PirateCrews.root(st)["claims"].has(isl), "the claim is gone")
	_check(int(st["gold"]) - g0 >= stash, "the stash is paid")
	# a crew ship comes alongside and boards: the deck fight settles it
	var wolf: Ship = dir.spawn_crew_ship("sea_wolves", "sloop", Vector2(w.ship.global_position.x + 30.0, w.ship.global_position.z), CrewDirector.ROLE_WARBAND)
	w.ship.crew.count = 12
	var crew0: int = w.ship.crew.count
	var gold0: int = int(st["gold"])
	var deck: DeckCombat = dir.crew_boards_player(wolf)
	_check(deck != null and deck.outcome != DeckCombat.Outcome.ONGOING, "the boarding fight is fought to the end")
	_check(w.ship.crew.count <= crew0, "the fight costs men")
	if deck != null and bool(deck.result()["player_won"]):
		_check(not is_instance_valid(wolf) or wolf.is_queued_for_deletion() or wolf.has_surrendered, "repelled boarders strike")
	else:
		_check(int(st["gold"]) < gold0, "beaten: the crew takes gold")
	# the lagoon: flagship and guards; taking the flagship ends the crew
	var at_lagoon: Array[Ship] = dir.defend_lagoon("bone_tide")
	_check(at_lagoon.size() >= 2 and at_lagoon[0].get_meta("crew_role", "") == CrewDirector.ROLE_FLAGSHIP, "the flagship waits in the lagoon")
	_check(bool(PirateCrews.get_crew(st, "bone_tide")["lagoon_known"]), "the lagoon goes on the record")
	w.prizes.finish_prize(at_lagoon[0], {"gold": 0, "cargo": {}, "supplies": {}, "map_fragment": ""}, CaptureFate.Fate.STRIP_AND_SINK)
	_check(not PirateCrews.alive_ids(st).has("bone_tide"), "the Bone Tide is finished")
	# a day of crew life writes news
	var made: Array[Dictionary] = dir.day_tick()
	_check(not made.is_empty(), "the crews act each day")
	# the crews page opens from the rivals page
	w.open_rivals()
	var layer: Node = w.get_node_or_null("MapLayer")
	_check(layer != null and layer.get_child_count() > 0, "the rivals page opens")
	if layer != null and layer.get_child_count() > 0:
		var rs: RivalScreen = layer.get_child(0) as RivalScreen
		rs.open_child(CrewsScreen.new())
		_check(layer.get_child_count() == 2, "the crews page opens")
	return _finish()


func _finish() -> bool:
	if _fails.is_empty():
		print("M23 CREWS: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
