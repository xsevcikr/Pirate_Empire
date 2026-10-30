extends SceneTree
## Both treasure tours, start to end, in the running world with combat cheats: the map is joined, the voyages are
## sailed, the paces counted, the dungeons walked, the guardians felled. Then every step of both tours is
## entered with a death first (recovery) and each step's three hint levels are read, and the tour still finishes.

var _fails: Array[String] = []
var _frames: int = 0
var _world: Node
var _dir: TourDirector
const TOURS: Array[String] = ["drowned_purse", "song_of_sirens"]


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _put_ship_at(p: Vector2) -> void:
	_world.ship.global_position = Vector3(p.x + 300.0, 0.5, p.y)
	_world.ship.linear_velocity = Vector3.ZERO


func _fresh(tour: String, at_step: int) -> void:
	var st: Dictionary = Session.state
	st["tours"] = {}
	st["map_fragments"] = []
	st["gold"] = 1000
	_dir.state = st
	_dir.turns.clear()
	_dir.wax = false
	for n in 3:
		MapFragments.add(st, TourData.fragment_id(tour, n + 1))
	var p: Dictionary = TourState.progress(st, tour)
	p["step"] = at_step
	p["checkpoint"] = at_step - 1


## Does whatever the current step of `tour` wants, with cheats for the fights. Returns false if it cannot.
func _do_step(tour: String) -> bool:
	var st: Dictionary = Session.state
	var step: Dictionary = TourState.current_step(st, tour)
	var before: int = int(TourState.progress(st, tour)["step"])
	var at: Vector2 = TourData.step_pos(step)
	match step["kind"]:
		"clue":
			var guard: int = 0
			while int(TourState.progress(st, tour)["step"]) == before and guard < 12:
				var piece: int = MapFragments.next_piece(_dir.puzzle_turns(tour))
				if piece < 0:
					break
				_dir.rotate_piece(tour, piece)
				guard += 1
		"sail", "escape":
			_put_ship_at(at)
			_dir.update_voyage(at + Vector2(300, 0), 12.0, 0.0)
		"sirens":
			_put_ship_at(at + Vector2(1200, 0))
			var f0: Vector2 = Vector2.ZERO
			_check(_dir.is_protected() == false, "unprotected before wax")
			_dir.update_voyage(Vector2(at.x + 1200.0, at.y), 12.0, 0.0, 0.5)
			_check(_dir.sirens != null and _dir.sirens.pull(Vector2(at.x + 1200.0, at.y), false) != f0, "the waters pull")
			_check(_dir.buy_wax(), "wax can be bought")
			_check(_dir.is_protected(), "wax protects")
			_put_ship_at(at)
			_dir.update_voyage(at + Vector2(300, 0), 12.0, 0.0, 0.5)
		"landing":
			_put_ship_at(at)
			_check(not _dir.count_paces(tour, 20, 18.0), "wrong count refused")
			_check(not _dir.count_paces(tour, int(step["paces"]), 11.0), "wrong time of day refused")
			_check(_dir.count_paces(tour, int(step["paces"]) + 2, 18.0), "right count at dusk accepted")
			var holes: int = 0
			while int(TourState.progress(st, tour)["step"]) == before and holes < 6:
				_dir.dig_spot(tour, 0.8)
				holes += 1
			_check(holes <= 3, "the chest turns up by the third hole, took %d" % holes)
		"dungeon":
			_put_ship_at(at)
			var run: Dungeon = _dir.start_dungeon(tour)
			_check(run != null, "dungeon starts at the island")
			if run != null:
				run.autowalk()
				_dir.finish_dungeon(tour, run)
		"guardian":
			_put_ship_at(at)
			var fight: MonsterFight = _dir.start_guardian(tour)
			_check(fight != null, "guardian is there")
			if fight != null:
				fight.cheat_kill()
				_dir.finish_guardian(tour, fight)
	return int(TourState.progress(st, tour)["step"]) > before or TourState.is_done(st, tour)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	_world = current_scene
	_dir = _world.tours
	_check(_dir != null, "world has a tour director")
	if _dir == null:
		return _finish()
	var st: Dictionary = Session.state
	# the real drop path: a rival always carries a piece
	var drop: String = MapFragments.roll_drop(st, "rival", RandomNumberGenerator.new())
	_check(drop == "drowned_purse_1", "first piece belongs to the first tour, got %s" % drop)
	# full route, both tours
	for tour: String in TOURS:
		_fresh(tour, 0)
		var g0: int = int(st["gold"])
		var n: int = 0
		while not TourState.is_done(st, tour) and n < 12:
			var ok: bool = _do_step(tour)
			_check(ok, "%s: step %d completes" % [tour, n])
			if not ok:
				break
			n += 1
		_check(TourState.is_done(st, tour), tour + " finished start to end")
		_check(int(st["gold"]) - g0 >= int(TourData.tour(tour)["reward"]["gold"]) - 25, tour + " paid the reward")
		for perk: String in TourData.tour(tour)["reward"]["perks"]:
			_check(TourState.root(st)["perks"].has(perk), "%s: perk %s won" % [tour, perk])
	# every step: die first, read all three hints, then still finish
	for tour: String in TOURS:
		var count: int = TourData.steps(tour).size()
		for i in count:
			_fresh(tour, i)
			st["gold"] = 1000
			var died: Dictionary = TourState.on_death(st, tour)
			_check(int(st["gold"]) == 800, "%s step %d: death costs 20%%" % [tour, i])
			_check(int(TourState.progress(st, tour)["step"]) == i, "%s step %d: still on the same step after dying" % [tour, i])
			_check((died["respawn"] as Vector2).length() < 20000.0, "respawn on the chart")
			for lv in range(1, 4):
				var h: Dictionary = TourState.hint(st, tour, lv)
				_check(bool(h["ok"]) and Loc.t(str(h["key"])) != str(h["key"]), "%s step %d: hint %d exists" % [tour, i, lv])
			st["gold"] = 0
			_check(TourState.hint(st, tour, 3)["cost"] == 0, "broke players still get the hint")
			var steps_done: int = 0
			while not TourState.is_done(st, tour) and steps_done < 12:
				if not _do_step(tour):
					_check(false, "%s step %d: cannot finish from here" % [tour, i])
					break
				steps_done += 1
			_check(TourState.is_done(st, tour), "%s: finishes after dying at step %d" % [tour, i])
	# a dungeon death keeps what was solved
	var run := Dungeon.new("sunken_temple", 4)
	run.advance()
	run.puzzle.solve_with_hints()
	run.advance()
	run.hp = 0.0
	run.tick(0.1)
	run.advance()
	_check(run.puzzle.solved, "the mirror puzzle stays solved after drowning")
	return _finish()


func _finish() -> bool:
	if _fails.is_empty():
		print("M18 TOURS: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
