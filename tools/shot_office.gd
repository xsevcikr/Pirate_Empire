extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_office.gd -- /tmp/office
## The harbour office of the lagoon: the building by the first pier, then its upgrades, lagoon and missions tabs.

var _prefix: String = "user://office"
var _frames: int = 0
var _w: Node
var _cam: Camera3D
var _office: CatalogueScreen


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


func _cove() -> void:
	var s: Dictionary = Session.state
	s["lagoon"] = Lagoon.new_lagoon()
	Lagoon.rank_up(s)
	for c in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(0, 1)]:
		Lagoon.place(s, "hut", c)
		Lagoon.upgrade(s, c)
	Lagoon.place(s, "tavern", Vector2i(0, -1))
	Lagoon.place(s, "shipyard", Vector2i(2, 0))
	Lagoon.place(s, "campfire", Vector2i(-2, 0))
	Lagoon.build_pier(s)
	Lagoon.expand_housing(s)
	s["fleet"].append({"class": "sloop", "name": "Prize", "crew": 0, "hull": 1.0})
	Lagoon.data(s)["pop"] = 34
	s["day"] = 3
	s["upgrades"] = {"hull": 2, "sails": 1, "cannons": 3}
	LagoonMissions.send(s, "fishing")
	s["day"] = 4
	LagoonMissions.daily(s, RandomNumberGenerator.new())
	var l: Dictionary = Lagoon.data(s)
	l["mission_log"].append({"id": "merchant_raid", "sent": 6, "alive": 5, "gold": 610, "day": 2})
	l["mission_log"].append({"id": "wreck_dive", "sent": 4, "alive": 0, "gold": 0, "day": 1})
	LagoonMissions.send(s, "treasure_hunt")
	s["gold"] = 18500


func _view_office() -> void:
	_cam = Camera3D.new()
	_cam.far = 5000.0
	_cam.fov = 50.0
	_w.add_child(_cam)
	var l: LagoonScene = _lagoon()
	var at: Vector3 = l.to_global(l.office_point())
	var f: Vector2 = LagoonData.harbour_dir()
	var r: Vector2 = LagoonData.cell_right()
	_cam.global_position = at + Vector3(f.x, 0, f.y) * 30.0 + Vector3(r.x, 0, r.y) * 12.0 + Vector3.UP * 13.0
	_cam.look_at(at + Vector3.UP * 3.0, Vector3.UP)
	_cam.make_current()


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
	print("shot ", name)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 30 or _lagoon() == null:
		return false
	match _frames - 30:
		1:
			_cove()
			_lagoon().sync()
			_lagoon().flush()
			_view_office()
		60:
			_shot("building")
			_w.open_lagoon()
		90:
			_shot("lagoon_screen")
			var scr: LagoonScreen = _w.get_node("PortLayer").get_child(0)
			scr.open_office()
		120:
			_office = _w.get_node("PortLayer").get_child(0)._child
			_shot("upgrades")
			_office.select("office.lagoon")
		150:
			_shot("lagoon")
			_office.select("office.missions")
		180:
			_shot("missions")
			quit(0)
			return true
	return false
