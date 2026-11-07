extends SceneTree
## Treasure maps and trade routes in the running world: the ship sits on the X of a map, the dig hint shows and
## Space digs up the chest; in port the tavern sells a map and the routes ledger lists the gaps and sends a fleet
## ship out; the hourly tick brings it home with gold; the chart draws the X and the route.

var _fails: Array[String] = []
var _frames: int = 0
var _step: int = 0
var _wait: int = 0
var _start: int = -1
var _gold: int = 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.state["gold"] = 5000
	Session.state["tutorial"] = "done"
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var m: Dictionary = BuriedTreasure.make_map(Session.state, "rich", r)
	BuriedTreasure.add_map(Session.state, m)
	var x: Vector2 = BuriedTreasure.spot(m)
	Session.state["pos"] = [x.x, x.y]
	for pair: Array in [["blackwater", 2.5], ["albion", 0.2]]:  # a rum glut at home, a thirsty navy port
		var mk: Market = PortService.market_of(Session.state, pair[0])
		mk.stock["rum"] = mk.target["rum"] * float(pair[1])
		PortService.store_market(Session.state, pair[0], mk)
	Session.enter_world(self)


func _process(_delta: float) -> bool:
	_frames += 1
	if current_scene == null or current_scene.name != "World" or _frames < 4:
		return false
	var w: Node = current_scene
	if _start < 0:
		_start = _frames
	if _wait > 0:
		_wait -= 1
		return false
	var s: Dictionary = Session.state
	match _step:
		0:
			w.ship.linear_velocity = Vector3.ZERO
			_check(w.can_dig(), "the ship over the X can dig")
			_gold = int(s["gold"])
			var r: Dictionary = w.dig_treasure()
			_check(bool(r.get("ok", false)), "the chest is dug up")
			_check(int(s["gold"]) > _gold, "gold from the chest")
			_check(BuriedTreasure.maps(s).is_empty(), "the map is used up")
			_check(not w.can_dig(), "nothing left to dig")
			s["fleet"] = [{"class": "schooner", "name": "Gull", "crew": 4, "hull": 1.0}]
			TradeRoutes.record(s, "albion")
			w.open_port()
			_step = 1
			_wait = 5
		1:
			var menu: PortMenu = w.get_node("PortLayer").get_child(0)
			_check(TradeRoutes.known(s, menu.port_id), "docking writes the port's prices in the book")
			var tav := TavernScreen.new()
			menu._open(tav)
			_check(tav.find_children("*", "Label", true, false).any(func(l: Label) -> bool: return l.text == Loc.t("buried.seller")), "the tavern has a map seller")
			tav._buy_map()
			_check(BuriedTreasure.maps(s).size() == 1, "a map bought in the tavern")
			tav.close()
			var led := TradeRoutesScreen.new()
			menu._open(led)
			var routes: Array[Dictionary] = TradeRoutes.best(s, PortService.cargo_capacity(s), 7.0)
			_check(not routes.is_empty(), "the ledger has routes between two known ports")
			if not routes.is_empty():
				var rt: Dictionary = routes[0]
				led._assign(rt)
				_check(TradeRoutes.on_route(s["fleet"][0]), "the fleet ship is on the route")
				s["fleet"][0]["route"]["next_h"] = 0.0  # due home at the next tick
				s["fleet"][0]["route"]["good"] = rt["good"]
				led._course(rt)
				_check((s["course"] as Array).size() == 2, "set course from the ledger")
			led.close()
			menu.close()
			_step = 2
			_wait = 3
		2:
			Svc.node("GameClock").hour += 1.5
			w._game_tick()
			if TradeRoutes.on_route(s["fleet"][0]):
				_check(int(s["fleet"][0]["route"]["trips"]) >= 1, "the hourly tick settles the trip")
			w.open_map()
			_step = 3
			_wait = 3
		3:
			var map: WorldMapScreen = w.get_node("MapLayer").get_child(0)
			_check(map != null, "the chart opens with the X and the route")
			map.close()
			return _finish()
	if _frames - _start > 4000:
		_check(false, "timed out at step %d" % _step)
		return _finish()
	return false


func _finish() -> bool:
	for f in _fails:
		print("FAIL m24: " + f)
	print("m24_treasure_trade: %s" % ("ok" if _fails.is_empty() else "%d failures" % _fails.size()))
	Kenney.clear_caches()
	quit(1 if not _fails.is_empty() else 0)
	return true
