extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m23.gd -- <mode> out.png
## M23 rival pirate crews. Modes: page (the crews page after a month of crew life), chart (their waters, claims
## and lagoons on the chart), warband (a crew warband in its colours closing on the player), lagoon (a crew's
## lagoon with its flagship), deck (the player's deck boarded by the Sea Wolves).

var _mode: String = "page"
var _out: String = "user://m23.png"
var _frames: int = 0
var _w: Node
var _deck: DeckFightScene
var _focus: Vector3 = Vector3.ZERO


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if args.size() > 1:
		_out = args[1]
	root.size = Vector2i(1280, 720)
	if _mode == "deck":
		GameInput.register()
		var s: Dictionary = SaveGame.new_state()
		for i in 12:
			s["roster"].append({"name": "Hand", "type": ["green", "seasoned", "swordsman", "gunner"][i % 4], "level": 1, "xp": 0})
		var c: DeckCombat = DeckBridge.build(13, 1.0, 70.0, CrewData.faction_of("sea_wolves"), 14, 1.3, 85.0, s, 9)
		_deck = DeckFightScene.new()
		root.add_child(_deck)
		_deck.start(c)
		return
	Session.begin_new("Rob", 1, 7)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _month(st: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 21
	for d in 30:
		st["day"] = d
		PirateCrews.day_tick(st, r)
	PirateCrews.ship_beaten(st, "red_hand", "merchants_reach")
	PirateCrews.ship_beaten(st, "red_hand", "merchants_reach")
	PirateCrews.ship_beaten(st, "black_gulls", "dead_reach")
	PirateCrews.root(st)["player_renown"] = 90


func _process(_d: float) -> bool:
	_frames += 1
	if _mode == "deck":
		return _deck_frame()
	var st: Dictionary = Session.state
	if _frames == 5:
		_month(st)
		match _mode:
			"page":
				_w.open_rivals()
			"chart":
				_w.discovery = Discovery.new()
				for cz in WorldMap.CHUNKS:
					for cx in WorldMap.CHUNKS:
						_w.discovery.reveal(Vector2i(cx, cz))
				st["discovery"] = SaveGame.capture_discovery(_w.discovery)
				_w.open_map()
			"warband":
				_w.ship.position = Vector3(0, 0.5, 2600)
				_w.ship.rotation_degrees.y = 180.0
				_w.ship.crew.count = 12
			"lagoon":
				var p: Vector2 = CrewData.lagoon_pos("red_hand")
				_w.ship.position = Vector3(p.x - 330.0, 0.5, p.y + 180.0)
				_w.ship.crew.count = 12
				_focus = Vector3(p.x, 0.0, p.y)
	if _frames == 8 and _mode == "page":
		var layer: Node = _w.get_node_or_null("MapLayer")
		if layer != null and layer.get_child_count() > 0:
			(layer.get_child(0) as MenuScreen).open_child(CrewsScreen.new())
	if _frames == 30 and _mode == "warband":
		var band: Array[Ship] = _w.crews.send_warband("sea_wolves")
		var here: Vector3 = _w.ship.global_position
		for i in band.size():
			band[i].global_position = here + Vector3(-90.0 + 70.0 * i, 0.5, 150.0 + 60.0 * i)
			band[i].rotation_degrees.y = 200.0 + 15.0 * i
			band[i].sail_level = 2
		_w.ship.sail_level = 0
	if _frames == 30 and _mode == "lagoon":
		var ships: Array[Ship] = _w.crews.defend_lagoon("red_hand")
		for s in ships:
			s.sail_level = 0
		_w.ship.sail_level = 0
	if _frames > 30 and _mode in ["warband", "lagoon"]:
		_w.ship.linear_velocity = Vector3.ZERO
		if _mode == "lagoon":
			_w.ship.look_at(_focus, Vector3.UP)
			_w.ship.rotation.x = 0.0
			_w.ship.rotation.z = 0.0
	var at: int = 40 if _mode in ["page", "chart"] else 260
	if _frames == at:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false


func _deck_frame() -> bool:
	if _frames == 1 or not is_instance_valid(_deck):
		return false
	DeckBridge.autopilot(_deck.combat, 1.0 / 60.0)
	if _frames == 50:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out, " mine=", _deck.combat.standing_on_screen(0), " theirs=", _deck.combat.standing_on_screen(1))
		quit()
	return false
