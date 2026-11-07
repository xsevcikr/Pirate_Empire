extends SceneTree
## Screenshots of the Kenney-style HUD.
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_hud.gd -- <mode> out.png
## Modes: "sea" (ship card, quest banner, nameplates, floating numbers, a tip, a cannon volley with smoke and
## splashes), "dock" (the key-cap prompt next to the harbour), "crew" (the crew screen's cards), "menu" (pause menu
## on its wood panel).

var _frames: int = 0
var _mode: String = "sea"
var _out: String = "user://hud.png"
var _other: Ship
var _other2: Ship


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if args.size() > 1:
		_out = args[1]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1600, 900)
	var w: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene = w


func _spawn(w: Node, faction: String, cls: String, off: Vector3, label: String) -> Ship:
	var s := Ship.new()
	s.stats = load("res://data/ships/%s.tres" % cls)
	s.ocean = w.ocean.model
	s.wind = w.wind
	s.faction = faction
	s.display_label = label
	s.position = w.ship.global_position + off
	s.sail_level = 1
	w.add_child(s)
	return s


func _process(_d: float) -> bool:
	_frames += 1
	var w: Node = current_scene
	if _frames == 5:
		if _mode == "dock":
			var dock: Vector2 = PortData.PORTS[PortData.START_PORT]["dock"]
			w.ship.position = Vector3(dock.x + 30.0, 0.5, dock.y + 30.0)
		else:
			w.ship.position = Vector3(4000, 0.5, 4000)
			var tut: Node = w.get("tutorial")
			if tut != null:
				tut.queue_free()
			w.overlay.set_prompt("")
		w.ship.crew.count = 16
		Session.state["quests"] = ["gallows_raid"]
		Session.state["cargo"] = {"sugar": 12, "rum": 30, "spices": 4, "gems": 2}
		Session.state["crew"] = 16
		var types: Array[String] = ["bosun", "gunner", "swordsman", "green", "seasoned", "musketeer", "cook", "carpenter"]
		var names: Array[String] = ["Anne Bonny", "Calico Jack", "Peg-Leg Pete", "Tom Gull", "Mary Read", "Sam Bellamy", "Ned Low", "Old Finn"]
		var xps: Array[int] = [620, 300, 140, 20, 1100, 260, 90, 510]
		Session.state["roster"] = []
		for i in types.size():
			Session.state["roster"].append({"name": names[i], "type": types[i], "level": CrewTypes.level_for_xp(xps[i]), "xp": xps[i]})
	if _frames == 6 and _mode == "sea":
		_other = _spawn(w, "navy", "brigantine", Vector3(70, 0, -60), "")
		_other2 = _spawn(w, "player", "sloop", Vector3(-55, 0, -40), "Sea Dog")
	if _frames > 6 and _mode != "dock":
		w.ship.sail_level = 2
		w.ship.linear_velocity = Vector3.ZERO
		w.rig.set("_dragging", true)
		w.rig.set("_orbit_yaw", 0.35)
		w.rig.set("_orbit_pitch", 0.32)
	if _mode == "sea":
		var m: WorldMarkers = w.get_node_or_null("WorldMarkers")
		if _frames == 200:
			w.hud.set("_combat_left", 30.0)
			for i in w.ship.damage.section_count:
				w.ship.damage.section_hp[i] *= 0.62
		if _frames == 283 and is_instance_valid(_other):
			w.ship.broadside.set_elevation(2.0)
			w.ship.broadside.fire(Broadside.Side.STARBOARD)
		if _frames == 286 and m != null and is_instance_valid(_other):
			m.spawn(_other.global_position + Vector3(0, 12, 0), "-46", UiKit.FOE, "", 30)
			m.spawn(_other.global_position + Vector3(4, 16, 0), Loc.t("hud.float_crew") % 2, Color.WHITE, "characters/character-a", 20)
			Session.state["gold"] = int(Session.state["gold"]) + 50
	if _mode == "crew" and _frames == 60:
		var cs := CrewScreen.new()
		cs.world = w
		var layer := CanvasLayer.new()
		layer.layer = 20
		w.add_child(layer)
		layer.add_child(cs)
	if _mode == "menu" and _frames == 60:
		var pm := PauseMenu.new()
		var layer := CanvasLayer.new()
		layer.layer = 20
		w.add_child(layer)
		layer.add_child(pm)
	var at: int = 290 if _mode == "sea" else 200
	if _frames == at:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
