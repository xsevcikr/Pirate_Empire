extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_convoy.gd -- out.png [frames]
## A sugar convoy with an escort sailing past the player, then (if a second path is given) the inspection screen.

var _frames: int = 0
var _out: String = "user://convoy.png"
var _out2: String = ""
var _at: int = 260
var _w: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_out2 = args[1]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	var clock: Node = root.get_node("GameClock")
	var now_h: float = float(clock.day) * 24.0 + float(clock.hour)
	if _frames == 5:
		_w.ship.position = Vector3(0, 0.5, 700)
		_w.ship.rotation_degrees.y = 180.0
		Session.state["convoys"].append({"id": 5, "good": "sugar", "from": "meridian", "to": "blackwater", "ships": 4, "ships_start": 4,
			"escorts": 1, "units": 100.0, "depart_h": now_h - 9.9, "eta_h": now_h + 0.1, "status": 0})
	if _frames == 30:
		_w.ship.crew.count = 12
	if _frames == 100:
		var ships: Array = _w.convoys.live_ships(5)
		if not ships.is_empty():
			var lead: Ship = ships[0]
			var side: Vector3 = lead.global_transform.basis.x
			_w.ship.global_position = lead.global_position + side * 110.0 + Vector3(0, 0, 30)
			_w.ship.look_at(lead.global_position, Vector3.UP)
			_w.ship.rotation.x = 0.0
			_w.ship.rotation.z = 0.0
			_w.ship.sail_level = 0
			_w.ship.linear_velocity = Vector3.ZERO
	if _frames == _at:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		if _out2 == "":
			quit()
		Session.state["cargo"] = {"gunpowder": 20.0}
		var layer := CanvasLayer.new()
		layer.layer = 90
		_w.add_child(layer)
		var s := InspectionScreen.new()
		s.port_id = "albion"
		layer.add_child(s)
	if _out2 != "" and _frames == _at + 20:
		root.get_texture().get_image().save_png(_out2)
		print("saved ", _out2)
		quit()
	return false
