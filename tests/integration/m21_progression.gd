extends SceneTree
## Progression in the running world: sinking and looting give XP and log entries, levels grant points, a skill rank
## changes the live ship, achievements unlock from real events and survive a save, the skill, log and customize
## pages open, customization reaches the ship's sails and flag, and every mini-game screen builds and plays.

var _fails: Array[String] = []
var _frames: int = 0
var _step: int = 0
var _screens: Array[Node] = []


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
	var st: Dictionary = Session.state
	match _step:
		0:
			_check(w.progress != null, "the world has a progress director")
			if w.progress == null:
				return _finish()
			var bus: Node = Svc.node("EventBus")
			# a ship goes down far from us, then a prize is taken, then a boarding is won
			bus.ship_sunk.emit(Vector2(900.0, 900.0), "brigantine")
			_check(Progression.xp(st) == 60, "sinking a brigantine (tier 3) gives 60 XP, got %d" % Progression.xp(st))
			_check(Achievements.unlocked(st, "first_blood"), "First Blood unlocks from a real sinking")
			bus.prize_taken.emit({"class_id": "sloop", "rival": ""})
			_check(Progression.xp(st) == 60 + 70, "a captured sloop gives 70 XP")
			bus.boarding_resolved.emit(true, 12, true)
			_check(Achievements.unlocked(st, "parry_master") and Achievements.unlocked(st, "one_against_many"), "boarding achievements unlock")
			bus.trade_made.emit("sell", "rum", 10.0, 640)
			_check(int(st["trade_rem"]) == 40, "trade XP keeps its remainder")
			bus.stat_event.emit("kedged_free", 1.0)
			_check(Achievements.unlocked(st, "hard_aground"), "kedging free unlocks Hard Aground")
			_check((st["log"] as Array).size() >= 4, "the log wrote itself")
			# levels grant points
			Progression.add_xp(st, ProgressionData.xp_to_reach(4))
			_check(int(st["captain_level"]) >= 4 and Progression.points_free(st) >= 3, "levels grant skill points")
			# a skill rank changes the live ship
			var r0: float = w.ship.broadside.reload_scale
			Progression.spend(st, "gunnery.reload")
			Session.apply_to_ship(w.ship)
			_check(w.ship.broadside.reload_scale < r0, "gunnery reload shortens the live reload")
			Progression.spend(st, "gunnery.double_shot")
			Session.apply_to_ship(w.ship)
			_check(w.ship.broadside.double_shot_chance > 0.0, "double shot reaches the broadside")
			# islands: move next to one and let the director notice
			var isl: Dictionary = PortData.gen().islands[0]
			w.ship.global_position = Vector3((isl["pos"] as Vector2).x, 0.0, (isl["pos"] as Vector2).y)
			w.progress._tick = 10.0
			_go(1)
		1:
			_check((st["islands_seen"] as Array).size() >= 1, "arriving at an island discovers it")
			_check(Achievements.value(st, "islands_found") >= 1.0, "discoveries are counted")
			# the pages
			w.open_skills()
			_check(w.get_node_or_null("MapLayer") != null, "the skills page opens")
			_close_layer(w)
			w.open_log()
			_check(w.get_node_or_null("MapLayer") != null, "the log page opens")
			_close_layer(w)
			w.open_customize()
			var layer: Node = w.get_node_or_null("MapLayer")
			_check(layer != null, "the customize page opens")
			Customization.set_sail(st, 2, 2)
			Customization.set_flag(st, 3, 4, 2)
			Customization.set_hull(st, 2, 1, 2, false)
			Customization.set_figurehead(st, "lion")
			w.apply_customization()
			var m: ShaderMaterial = w.ship.visuals.sail_materials[0]
			_check(int(m.get_shader_parameter("pattern")) == 2, "the sail pattern reaches the ship")
			_check(w.ship.visuals.root.get_node_or_null("Custom") != null, "the figurehead and stern are fitted")
			var f: ShaderMaterial = w.ship.visuals.flag_materials[w.ship.visuals.flag_materials.size() - 1]
			_check(int(f.get_shader_parameter("layout")) == 2, "the flag layout reaches the ship")
			_close_layer(w)
			# save and load round trip keeps the lot
			var back: Dictionary = SaveGame.from_json(SaveGame.to_json(st))
			_check(Achievements.unlocked(back, "first_blood") and Progression.xp(back) == Progression.xp(st), "progress survives a save")
			_check(int(back["custom"]["sail"]["pattern"]) == 2, "customization survives a save")
			# the mini-game screens
			var holder := Control.new()
			root.add_child(holder)
			var menu := MiniGameMenu.new()
			holder.add_child(menu)
			_screens = [menu, DiceScreen.make(50, true, 3), BonesScreen.make(50, 4), TimingScreen.make("arm", 5), TimingScreen.make("knife", 6),
				TimingScreen.make("drinking", 7), RangeScreen.make(8), FishingScreen.make(9)]
			for s in _screens.slice(1):
				holder.add_child(s)
				(s as Control).visible = false
			_go(2)
		2:
			for s in _screens:
				_check(s.get_child_count() > 0, "%s built its page" % s.get_class())
			var dice: DiceScreen = _screens[1]
			dice.game.mine = [1, 2, 3, 4, 5] as Array[int]
			dice._bid()
			_check(dice.game.bid_qty > 0, "the dice game answers a bid")
			var knife: TimingScreen = _screens[4]
			for i in 3:
				knife._cursor = 0.5
				knife._press()
			_check(knife._phase == "done", "three throws end the knife game")
			_check(Customization.owns(st, "coat", "duelist"), "a perfect knife game wins the duelist coat")
			var g0: int = int(st["gold"])
			var bones: BonesScreen = _screens[2]
			bones.game.stand()
			bones._rebuild()
			_check(int(st["gold"]) != g0 or bones.game.outcome == "push", "a finished bones game settles the stake")
			w.ship.linear_velocity = Vector3.ZERO
			w.open_fishing()
			_check(w.get_node_or_null("MapLayer") != null, "fishing opens when the ship is still")
			return _finish()
	return false


func _go(n: int) -> void:
	_step = n
	_frames = 0


func _close_layer(w: Node) -> void:
	var l: Node = w.get_node_or_null("MapLayer")
	if l != null:
		w.remove_child(l)
		l.queue_free()


func _finish() -> bool:
	if _fails.is_empty():
		print("M21 PROGRESSION: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
