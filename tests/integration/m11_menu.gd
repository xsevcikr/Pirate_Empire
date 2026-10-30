extends SceneTree
## Menu flow: boot -> main menu -> new game -> sail -> pause -> save -> quit to menu -> continue restores state.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _menu: MainMenu
var _world: Node
var _pos := Vector3(500.0, 0.0, 100.0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	change_scene_to_file(Session.MENU_SCENE)


func _press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _step:
		0:  # main menu is up
			_menu = current_scene.get_child(0) as MainMenu if current_scene and current_scene.get_child_count() > 0 else null
			if _menu == null or _menu.continue_button == null:
				return false
			_check(_menu.continue_button.disabled, "continue must be disabled with no saves")
			_check(root.gui_get_focus_owner() == _menu.new_game_button, "new game should hold focus (keyboard/gamepad ready)")
			_menu.new_game_button.pressed.emit()
			_step = 1
			_wait = 3
		1:  # new game screen
			var ng: NewGameScreen = _find(root, "NewGameScreen") as NewGameScreen
			_check(ng != null, "new game screen should open")
			if ng == null:
				return _finish()
			ng.name_edit.text = "Anne"
			ng.difficulty.select(2)
			ng.start_button.pressed.emit()
			_step = 2
		2:  # waiting for the loading screen to hand over the world
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_check(Session.state["captain"] == "Anne" and Session.state["difficulty"] == 2, "new game values stored")
			_step = 3
			_wait = 10
		3:  # sail somewhere, change gold, open pause
			var ship: Ship = _world.get("ship")
			ship.global_position = _pos
			for i in 17:
				Session.state["roster"].append({"name": "Hand", "type": "green", "level": 1, "xp": 0})
			Session.state["crew"] = 17
			ship.crew.count = 17
			Session.state["gold"] = 1234
			var clock: Node = root.get_node("GameClock")
			clock.day = 5
			Session.state["last_tick_day"] = 5  # the jump is not five days of upkeep
			clock.hour = 9.5
			_press_action("pause")
			_step = 4
			_wait = 5
		4:  # pause menu is open, tree paused
			_check(paused, "tree should be paused")
			var pm: PauseMenu = _find(_world, "PauseMenu") as PauseMenu
			_check(pm != null, "pause menu should exist")
			if pm == null:
				return _finish()
			pm.world = _world
			var sl := SaveLoadScreen.new()
			sl.world = _world
			pm.open_child(sl)
			_step = 5
			_wait = 3
		5:  # save into slot 2
			var sl2: SaveLoadScreen = _find(_world, "SaveLoadScreen") as SaveLoadScreen
			if sl2 == null:
				_check(false, "save screen should open")
				return _finish()
			sl2.slot_buttons[2].pressed.emit()
			_check(not SaveGame.read(2).is_empty(), "slot 2 should be written")
			_step = 6
			_wait = 2
		6:  # quit to menu
			var pm2: PauseMenu = _find(_world, "PauseMenu") as PauseMenu
			Session.quit_to_menu(self)
			Session.state = {}
			var clock: Node = root.get_node("GameClock")
			clock.day = 1
			clock.hour = 1.0
			_step = 7
			_wait = 5
		7:  # back at main menu, continue is now enabled
			if current_scene == null or current_scene.name != "MainMenu" or current_scene.get_child_count() == 0:
				return false
			_menu = current_scene.get_child(0) as MainMenu
			if _menu == null or _menu.continue_button == null:
				return false
			_check(not _menu.continue_button.disabled, "continue should be enabled after saving")
			_check(not paused, "tree should be unpaused in the menu")
			_menu.continue_button.pressed.emit()
			_step = 8
		8:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_step = 9
			_wait = 5
		9:  # restored
			var ship: Ship = _world.get("ship")
			_check(ship.global_position.distance_to(_pos) < 30.0, "position restored, got %s" % str(ship.global_position))
			_check(ship.crew.count == 17, "crew restored, got %d" % ship.crew.count)
			_check(Session.state["gold"] == 1234, "gold restored")
			var clock: Node = root.get_node("GameClock")
			_check(clock.day == 5 and absf(clock.hour - 9.5) < 0.2, "time restored: day %d hour %.2f" % [clock.day, clock.hour])
			return _finish()
	return false


func _find(n: Node, cls: String) -> Node:
	if n.get_script() != null and (n.get_script() as Script).get_global_name() == cls:
		return n
	for c in n.get_children():
		var r: Node = _find(c, cls)
		if r != null:
			return r
	return null


func _finish() -> bool:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	if _fails.is_empty():
		print("M11 PASS: menu flow")
		quit(0)
	else:
		for f in _fails:
			print("M11 FAIL: ", f)
		quit(1)
	return true
