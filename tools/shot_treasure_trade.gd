extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_treasure_trade.gd -- /tmp/tt
## Treasure maps and trade routes: the ship over an X with the dig hint, the tavern's map seller, the routes
## ledger with a fleet ship trading, and the chart with the X marks and the route.

var _prefix: String = "user://tt"
var _frames: int = 0
var _w: Node
var _screen: PortScreen


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	var s: Dictionary = Session.state
	s["gold"] = 4200
	s["tutorial"] = "done"
	s["ship_class"] = "brigantine"
	var r := RandomNumberGenerator.new()
	r.seed = 12
	for tier: String in ["common", "rich", "legendary"]:
		BuriedTreasure.add_map(s, BuriedTreasure.make_map(s, tier, r))
	var x: Vector2 = BuriedTreasure.spot(BuriedTreasure.maps(s)[0])
	s["pos"] = [x.x, x.y]
	# a few days of trading: uneven markets, and prices noted at five ports
	var skew: Dictionary = {"blackwater": {"rum": 2.6, "sugar": 0.3}, "meridian": {"sugar": 2.4, "silk": 2.0, "rum": 0.4}, "albion": {"rum": 0.2, "silk": 0.4, "tea": 0.4},
		"ironhold": {"tobacco": 0.3, "timber": 0.3}, "coral_landing": {"spices": 2.5, "tea": 2.2}}
	var day: int = 0
	for id: String in skew:
		var mk: Market = PortService.market_of(s, id)
		for g: String in skew[id]:
			mk.stock[g] = mk.target[g] * float(skew[id][g])
		PortService.store_market(s, id, mk)
		s["day"] = day
		TradeRoutes.record(s, id)
		day += 1
	s["fleet"] = [{"class": "schooner", "name": "Gull", "crew": 6, "hull": 0.9}, {"class": "sloop", "name": "Tern", "crew": 3, "hull": 1.0}]
	TradeRoutes.assign(s, 0, "meridian", "albion", "silk", 0.0)
	s["fleet"][0]["route"]["trips"] = 3
	s["fleet"][0]["route"]["earned"] = 4310
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _open(screen: PortScreen) -> void:
	var menu: PortMenu = _w.get_node("PortLayer").get_child(0)
	if _screen != null:
		_screen.close()
	_screen = screen
	menu._open(screen)


func _process(_d: float) -> bool:
	_frames += 1
	match _frames:
		90:
			_shot("dig_hint")
			_w.dig_treasure()
		100:
			_shot("dug")
			_w.open_port()
		110:
			_open(TavernScreen.new())
		140:
			var scroll: ScrollContainer = _screen.find_child("Scroll", true, false)
			if scroll != null:
				scroll.scroll_vertical = 220
		150:
			_shot("tavern_maps")
			_open(TradeRoutesScreen.new())
		180:
			_shot("routes_ledger")
			var scroll: ScrollContainer = _screen.find_child("Scroll", true, false)
			if scroll != null:
				scroll.scroll_vertical = 600
		200:
			_shot("routes_fleet")
			_screen.close()
			(_w.get_node("PortLayer").get_child(0) as PortMenu).close()
		210:
			var d: Discovery = Discovery.new()
			for cz in WorldMap.CHUNKS:
				for cx in WorldMap.CHUNKS:
					d.reveal(Vector2i(cx, cz))
			Session.state["discovery"] = SaveGame.capture_discovery(d)
			_w.open_map()
		240:
			_shot("chart")
			quit(0)
			return true
	return false


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
	print("shot ", name)
