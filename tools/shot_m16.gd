extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m16.gd -- chart|district|harbour out.png
## chart: the parchment map after exploring; district: a walkable dock district; harbour: a faction harbour from the sea.

var _mode: String = "chart"
var _out: String = "user://m16.png"
var _frames: int = 0
var _w: Node
var _port: String = "albion"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	if args.size() > 1:
		_out = args[1]
	if args.size() > 2:
		_port = args[2]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	if _mode == "district":
		var d := DockDistrict.new()
		d.port_id = _port
		root.add_child(d)
	else:
		_w = load("res://scenes/world.tscn").instantiate()
		root.add_child(_w)
		current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _mode == "district" and _frames == 3:
		var d: DockDistrict = root.get_child(root.get_child_count() - 1) as DockDistrict
		if d != null and d.captain != null:
			d.captain.position = Vector3(2.0, 0.0, 22.0)
	if _mode == "chart" and _frames == 5:
		var disc := Discovery.new()
		for p in [Vector2(0, 0), Vector2(0, 2500), Vector2(-2500, 4500), Vector2(-5500, 5500), Vector2(2500, 5000), Vector2(5500, 4500), Vector2(-3500, 1200), Vector2(-5500, -2500), Vector2(-4800, -5800), Vector2(0, -3500)]:
			disc.reveal_around(p, 2600.0)
		Session.state["discovery"] = SaveGame.capture_discovery(disc)
		for s in OceanCurrent.STREAMS:
			Session.state["streams_known"].append(s["id"])
		_w.ship.global_position = Vector3(0, 0.5, 420)
		_w.ship.rotation_degrees.y = -90.0
		Session.state["course"] = [-3600.0, 5300.0]
		_w.open_map()
	if _mode == "harbour" and _frames == 5:
		var dock: Vector2 = PortData.PORTS[_port]["dock"]
		var isl: Vector2 = PortData.gen().islands[PortData.PORTS[_port]["island"]]["pos"]
		var out: Vector2 = (dock - isl).normalized()
		_w.streamer.load_all_near(dock)
		_w.ship.global_position = Vector3(dock.x + out.x * 60.0 + out.y * 50.0, 0.5, dock.y + out.y * 60.0 - out.x * 50.0)
		_w.ship.look_at(Vector3(dock.x - out.x * 130.0, 0.5, dock.y - out.y * 130.0), Vector3.UP)
		_w.ship.rotation.x = 0.0
		_w.ship.rotation.z = 0.0
	if _frames == 150:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
