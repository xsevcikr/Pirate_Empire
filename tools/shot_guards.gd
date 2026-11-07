extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_guards.gd -- out.png [port]
## The city watch putting out from a harbour the player has just fired on.

var _out: String = "user://guards.png"
var _port_id: String = "albion"
var _frames: int = 0
var _w: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_port_id = args[1]
	Session.begin_new("Rob", 1, 7)
	Session.state["tutorial"] = "done"
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		var dock: Vector2 = PortData.PORTS[_port_id]["dock"]
		_w.streamer.load_all_near(dock)
		var isl: Vector2 = PortData.gen().islands[int(PortData.PORTS[_port_id]["island"])]["pos"]
		var out: Vector2 = (dock - isl).normalized()
		var at: Vector2 = dock + out * 330.0
		_w.ship.global_position = Vector3(at.x, 0.5, at.y)
		_w.ship.look_at(Vector3(dock.x, 0.5, dock.y), Vector3.UP)
		_w.ship.rotation.x = 0.0
		_w.ship.rotation.z = 0.0
		_w.ship.sail_level = 0
	if _frames == 20:
		CannonTower.raise_alert(_port_id)
	if _frames == 260:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out, " guards: ", (_w.guards.active.get(_port_id, []) as Array).size())
		quit()
	return false
