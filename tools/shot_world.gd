extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_world.gd -- out.png [frames]

var _frames: int = 0
var _out: String = "user://world.png"
var _at: int = 200
var _pos: Vector3 = Vector3.INF


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_at = int(args[1])
	if args.size() > 3:
		_pos = Vector3(float(args[2]), 0.5, float(args[3]))
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	var w: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene = w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5 and _pos != Vector3.INF:
		current_scene.ship.position = _pos
	if _frames == 6 and OS.get_environment("SHOT_SHIP") != "":
		var st: ShipStats = load("res://data/ships/%s.tres" % OS.get_environment("SHOT_SHIP"))
		var o: Ship = Ship.new()
		o.stats = st
		o.ocean = current_scene.ocean.model
		o.wind = current_scene.wind
		o.position = _pos + Vector3(75, 0, -26)
		o.rotation_degrees.y = -90.0
		o.sail_level = 3
		o.faction = "navy"
		current_scene.add_child(o)
	if _frames == 30 and current_scene.get("ship") != null:
		current_scene.ship.sail_level = 3
		current_scene.ship.crew.count = 12
	if _frames == _at:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
