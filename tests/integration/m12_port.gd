extends SceneTree
## First hour in short: leave the dock, board the fishing lugger, return, sell the fish, hire four crew,
## buy food, take a job, and buy a Sloop with the Cutter traded in.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _lugger: Ship
var _menu: PortMenu
var _gold_before: int = 0
var _food_before: float = 0.0


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


func _labels(n: Node) -> String:
	var out: String = ""
	if n is Label:
		out += (n as Label).text + "\n"
	for c in n.get_children():
		out += _labels(c)
	return out


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _go(step: int, wait: int = 3) -> void:
	_step = step
	_wait = wait
	_frames = 0


func _teleport_to_dock() -> void:
	_ship.global_position = Vector3(0, 0.3, 385)
	_ship.linear_velocity = Vector3.ZERO
	_ship.angular_velocity = Vector3.ZERO
	_ship.sail_level = 0


func _open_screen(screen: PortScreen) -> void:
	_menu = _find(_world, "PortMenu") as PortMenu
	screen.port_id = _menu.port_id
	_menu.open_child(screen)


func _close_screen(screen: Node) -> void:
	screen.closed.emit()


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
			_check(_ship.stats.class_id == "cutter", "should start in a cutter")
			_check(st["gold"] == 100 and st["crew"] == 0, "start with 100 gold and no crew")
			_check(_ship.crew.count == 0, "ship has no crew")
			_check(absf(_ship.damage.hull_fraction() - 0.7) < 0.02, "hull at 70%%, got %.2f" % _ship.damage.hull_fraction())
			_check(int(_ship.broadside.ammo["round"]) == 40 and _ship.broadside.gun_id == "swivel", "40 swivel shots")
			_check(st["tutorial"] == "leave_dock", "tutorial starts at leave_dock")
			_ship.global_position = Vector3(0, 0.3, 700)
			_ship.sail_level = 1
			_go(1, 10)
		1:
			_check(st["tutorial"] == "into_wind", "leaving the dock advances the tutorial, got %s" % st["tutorial"])
			root.get_node("EventBus").tutorial_event.emit("faced_wind")
			root.get_node("EventBus").tutorial_event.emit("timer")
			_check(st["tutorial"] == "back_to_dock", "tutorial reaches back_to_dock, got %s" % st["tutorial"])
			_teleport_to_dock()
			_go(2, 20)
		2:
			_check(_world.can_dock(), "ship should be able to dock at the pier")
			_press("interact")
			_go(3, 5)
		3:
			_menu = _find(_world, "PortMenu") as PortMenu
			_check(_menu != null and paused, "port menu open and game paused")
			_check(st["tutorial"] == "find_finn", "docking advances to find_finn, got %s" % st["tutorial"])
			var tav := TavernScreen.new()
			_open_screen(tav)
			_go(4, 3)
		4:
			var tav2: TavernScreen = _find(_world, "TavernScreen") as TavernScreen
			tav2._talk_finn()
			_check(st["tutorial"] == "hunt_lugger", "Finn sends us after the lugger, got %s" % st["tutorial"])
			_check(_world.prizes.targets.size() == 1, "lugger spawned")
			_lugger = _world.prizes.targets[0]
			_menu.close()
			_go(5, 5)
		5:
			_check(not paused, "leaving port unpauses")
			# Loading the world takes a varying number of frames and the clock runs through them, so the crew's daily
			# meal may already have been eaten: count the food from here, at midday so no meal falls inside the boarding.
			root.get_node("GameClock").hour = 12.0
			_food_before = float(st["supplies"]["food"])
			_lugger.sail_level = 0
			_lugger.linear_velocity = Vector3.ZERO
			var right: Vector3 = _lugger.global_transform.basis.x
			_ship.global_position = _lugger.global_position + right * 18.0
			_ship.rotation = _lugger.rotation
			_ship.linear_velocity = Vector3.ZERO
			_ship.angular_velocity = Vector3.ZERO
			_ship.sail_level = 0
			Input.action_press("grapple")
			_go(6, 1)
		6:
			var prize: PrizeScreen = _find(_world, "PrizeScreen") as PrizeScreen
			if prize == null:
				if _frames > 3000:
					_check(false, "boarding never finished")
					return _finish()
				return false
			Input.action_release("grapple")
			_check(paused, "prize screen pauses the game")
			prize._choose(CaptureFate.Fate.RELEASE)
			_check(st["gold"] >= 160 and st["gold"] <= 190, "loot gold 60-90, got %d" % st["gold"])
			_check(is_equal_approx(float(st["supplies"]["food"]) - _food_before, 6.0), "6 food looted")
			_check(int(st["cargo"].get("fish", 0)) == 10, "a crate of fish looted")
			_check(st["tutorial"] == "return_port", "looting advances to return_port, got %s" % st["tutorial"])
			_teleport_to_dock()
			_go(7, 20)
		7:
			_press("interact")
			_go(8, 5)
		8:
			_check(st["tutorial"] == "sell_fish", "docking again advances to sell_fish, got %s" % st["tutorial"])
			var market := MarketScreen.new()
			_open_screen(market)
			_go(9, 3)
		9:
			var ms: MarketScreen = _find(_world, "MarketScreen") as MarketScreen
			var m: Market = PortService.market_of(st, "blackwater")
			var text: String = _labels(ms)
			_check(text.contains("%.1f" % m.buy_price("fish")), "market screen shows the market.gd buy price %.1f" % m.buy_price("fish"))
			_check(text.contains("%.1f" % m.sell_price("sugar")), "market screen shows the sugar sell price")
			_gold_before = st["gold"]
			ms._sell_good("fish", 10)
			_check(st["gold"] - _gold_before >= 70, "fish sold for about 76, got %d" % (st["gold"] - _gold_before))
			_check(st["tutorial"] == "hire_crew", "selling fish advances to hire_crew, got %s" % st["tutorial"])
			_close_screen(ms)
			_go(10, 3)
		10:
			_open_screen(TavernScreen.new())
			_go(11, 3)
		11:
			var tv: TavernScreen = _find(_world, "TavernScreen") as TavernScreen
			for i in 4:
				tv._hire("green")
			_check(st["crew"] == 4, "four deckhands hired, got %d" % st["crew"])
			_check(st["tutorial"] == "buy_food", "hiring advances to buy_food, got %s" % st["tutorial"])
			_close_screen(tv)
			_go(12, 3)
		12:
			_open_screen(MarketScreen.new())
			_go(13, 3)
		13:
			var ms2: MarketScreen = _find(_world, "MarketScreen") as MarketScreen
			var food_before: float = st["supplies"]["food"]
			ms2._buy_supply("food", 4)
			_check(st["supplies"]["food"] == food_before + 4.0, "bought four food")
			_check(st["tutorial"] == "quest_board", "buying food advances to quest_board, got %s" % st["tutorial"])
			_close_screen(ms2)
			_go(14, 3)
		14:
			_open_screen(QuestBoardScreen.new())
			_go(15, 3)
		15:
			var qb: QuestBoardScreen = _find(_world, "QuestBoardScreen") as QuestBoardScreen
			qb._accept("gallows_raid")
			_check(st["tutorial"] == "done", "taking a job finishes the tutorial, got %s" % st["tutorial"])
			_check(_world.prizes.targets.size() == 1 and _world.prizes.targets[0].get_meta("quest", "") == "gallows_raid", "the job's merchant sloop is at sea")
			_close_screen(qb)
			_go(16, 3)
		16:
			st["gold"] = 2000
			_open_screen(ShipyardScreen.new())
			_go(17, 3)
		17:
			var sy: ShipyardScreen = _find(_world, "ShipyardScreen") as ShipyardScreen
			sy._buy_ship("sloop")
			_check(st["gold"] == 600, "sloop with the cutter traded in costs 1,400, gold left %d" % st["gold"])
			_check(st["ship_class"] == "sloop", "now a sloop")
			_menu.close()
			_go(18, 3)
		18:
			_check(not SaveGame.read(Session.AUTOSAVE_SLOT).is_empty(), "leaving port autosaves")
			return _finish()
	return false


func _finish() -> bool:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	if _fails.is_empty():
		print("M12 PASS: port flow")
		quit(0)
	else:
		for f in _fails:
			print("M12 FAIL: ", f)
		quit(1)
	return true
