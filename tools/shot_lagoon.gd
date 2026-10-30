extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_lagoon.gd -- /tmp/lagoon
## The lagoon on Skull Atoll: unclaimed, a young hideout, a grown pirate capital with its fleet at the piers,
## build mode with a see-through hut on the grid, and the lagoon and harbour screens.

var _prefix: String = "user://lagoon"
var _frames: int = 0
var _w: Node
var _cam: Camera3D
var _mode: LagoonBuildMode


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["gold"] = 400000
	Session.state["fame"] = 99999
	var dock: Vector2 = LagoonData.dock_point()
	Session.state["pos"] = [dock.x, dock.y]
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _lagoon() -> LagoonScene:
	return _w.streamer.lagoon


## A camera over the lagoon: `back` metres out towards the harbour, `up` metres high, `side` metres to the right.
func _view(back: float, up: float, side: float = 0.0, look_inland: float = 10.0) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.far = 5000.0
		_cam.fov = 55.0
		_w.add_child(_cam)
	var l: LagoonScene = _lagoon()
	var c: Vector2 = LagoonData.pad_center()
	var f: Vector2 = LagoonData.harbour_dir()
	var r: Vector2 = LagoonData.cell_right()
	var centre: Vector3 = l.to_global(Vector3(c.x, LagoonData.PAD_H_M, c.y))
	_cam.global_position = centre + Vector3(f.x, 0, f.y) * back + Vector3(r.x, 0, r.y) * side + Vector3.UP * up
	_cam.look_at(centre - Vector3(f.x, 0, f.y) * look_inland, Vector3.UP)
	_cam.make_current()


func _grow_capital() -> void:
	var s: Dictionary = Session.state
	s["lagoon"] = Lagoon.new_lagoon()
	for i in 3:
		Lagoon.rank_up(s)
	var plan: Array = [
		["tavern", 0, -1, 3], ["market", 1, -1, 3], ["market", -1, -1, 2], ["warehouse", 2, 0, 3], ["shipyard", -2, 0, 3],
		["hut", 1, 1, 3], ["hut", -1, 1, 3], ["hut", 2, 1, 2], ["hut", -2, 1, 2], ["hut", 0, 2, 3], ["hut", 1, 2, 1], ["hut", -1, 2, 1],
		["hut", 2, 2, 2], ["hut", -2, 2, 1], ["farm", 3, 2, 2], ["farm", -3, 2, 2], ["tower", 4, -1, 3], ["tower", -4, -1, 3],
		["battery", 3, -2, 2], ["battery", -3, -2, 2], ["campfire", 1, 0, 1], ["flagpole", -1, 0, 1], ["lanterns", 0, -2, 1],
		["palms", 2, -2, 1], ["palms", -2, -2, 1], ["well", 3, 0, 1], ["treasure", -3, 0, 1], ["statue", 0, 3, 1],
		["hut", 3, 1, 3], ["hut", -3, 1, 3], ["warehouse", 4, 1, 2], ["tower", 0, 4, 2], ["palms", 3, 3, 1], ["palms", -3, 3, 1],
	]
	for p in plan:
		var c := Vector2i(p[1], p[2])
		Lagoon.place(s, p[0], c)
		for k in int(p[3]) - 1:
			Lagoon.upgrade(s, c)
	for i in 6:
		Lagoon.build_pier(s)
		Lagoon.upgrade_pier(s, i)
		if i < 3:
			Lagoon.upgrade_pier(s, i)
	for cls in ["galleon", "frigate", "brigantine", "schooner", "sloop", "man_o_war", "frigate", "brigantine", "sloop", "schooner", "cutter", "galleon"]:
		s["fleet"].append({"class": cls, "name": cls.capitalize(), "crew": 0, "hull": 1.0})
	Lagoon.data(s)["pop"] = Lagoon.beds(s)


func _hideout() -> void:
	var s: Dictionary = Session.state
	s["lagoon"] = Lagoon.new_lagoon()
	Lagoon.place(s, "hut", Vector2i(1, 0))
	Lagoon.place(s, "hut", Vector2i(-1, 0))
	Lagoon.place(s, "campfire", Vector2i(0, -1))
	Lagoon.place(s, "farm", Vector2i(1, 1))
	Lagoon.build_pier(s)
	s["fleet"].append({"class": "sloop", "name": "Prize", "crew": 0, "hull": 1.0})
	Lagoon.data(s)["pop"] = 6


func _sync() -> void:
	_lagoon().sync()
	_lagoon().flush()


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
	print("shot ", name)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 30 or _lagoon() == null:
		return false
	var f: int = _frames - 30
	match f:
		1:
			_view(170.0, 70.0, 40.0)
			_sync()
		40:
			_shot("unclaimed")
			_hideout()
			_sync()
			_view(70.0, 35.0, 10.0, 0.0)
		90:
			_shot("hideout")
			_grow_capital()
			_sync()
			_view(260.0, 150.0, 60.0, 0.0)
		160:
			_shot("capital")
			_view(110.0, 45.0, -30.0, 25.0)
		200:
			_shot("capital_close")
			_view(-40.0, 30.0, 0.0, -60.0)
		240:
			_shot("capital_harbour")
			_mode = LagoonBuildMode.new()
			_mode.lagoon = _lagoon()
			_w.add_child(_mode)
		250:
			Lagoon.demolish(Session.state, Vector2i(2, 2))
			_mode.refresh()
			_mode.pick("tavern")
			_mode.move_cursor(Vector2i(2, 2))
		290:
			_shot("build_mode")
			_mode.finish()
			_w.open_lagoon()
		330:
			_shot("lagoon_screen")
			var scr: LagoonScreen = _w.get_node("PortLayer").get_child(0)
			scr.open_child(LagoonHarbourScreen.new())
		370:
			_shot("harbour_screen")
			quit(0)
			return true
	return false
