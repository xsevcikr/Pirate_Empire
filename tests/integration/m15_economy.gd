extends SceneTree
## Economy depth in the running world: a convoy appears as real ships, sinking them stops the delivery and
## lifts the destination's price, the blockade clock runs, and a sunk player is washed up by Finance.defeat.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _price_before: float = 0.0
var _live: Array = []


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


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	_frames += 1
	var st: Dictionary = Session.state
	var clock: Node = root.get_node("GameClock")
	var now_h: float = float(clock.day) * 24.0 + float(clock.hour)
	match _step:
		0:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_ship = _world.get("ship")
			_check(_world.convoys != null, "world has a convoy manager")
			_price_before = PortService.market_of(st, "blackwater").mid_price("sugar")
			st["convoys"].append({"id": 900, "good": "sugar", "from": "meridian", "to": "blackwater", "ships": 3, "ships_start": 3,
				"escorts": 1, "units": 75.0, "depart_h": now_h - 9.9, "eta_h": now_h + 0.1, "status": TradeNetwork.Status.SAILING})
			_go(1, 70)
		1:
			_live = _world.convoys.live_ships(900)
			_check(_live.size() == 4, "3 merchants and 1 escort on the sea, got %d" % _live.size())
			var merchants: int = 0
			for s: Ship in _live:
				if s.faction == "merchant":
					merchants += 1
					s.damage.sunk = true
					s.damage.sank.emit()
			_check(merchants == 3, "three merchant ships")
			_go(2, 5)
		2:
			_check(TradeNetwork.find(st, 900).is_empty() or int(TradeNetwork.find(st, 900)["ships"]) == 0, "convoy struck off")
			_check(int(st["convoys_lost"]) == 1, "one convoy lost, got %d" % int(st["convoys_lost"]))
			TradeNetwork.advance(st, now_h + 5.0)
			PortService.advance_markets(st, 1.0)
			var price: float = PortService.market_of(st, "blackwater").mid_price("sugar")
			_check(price >= _price_before * 0.99, "price does not fall without the delivery (%f vs %f)" % [price, _price_before])
			st["gold"] = 400
			st["difficulty"] = 2  # Hard: the full defeat rules (Easy and Normal get a second chance, see m25)
			_ship.damage.sunk = true
			_ship.damage.sank.emit()
			_go(3, 5)
		3:
			var d: DefeatScreen = _find(_world, "DefeatScreen") as DefeatScreen
			_check(d != null, "defeat screen shown")
			if d != null:
				d.continued.emit()
			_go(4, 5)
		4:
			_check(st["ship_class"] == "cutter", "back in a cutter")
			_check(int(st["gold"]) == 200, "half the gold lost, got %d" % int(st["gold"]))
			_check(not paused, "game resumes")
			return _finish()
	if _frames > 4000:
		_fails.append("timed out in step %d" % _step)
		return _finish()
	return false


func _finish() -> bool:
	if _fails.is_empty():
		print("M15 ECONOMY: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
	return true
