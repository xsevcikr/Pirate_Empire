extends SceneTree
## Our ship and a navy brig side by side, seen from high on the quarter, to show the people on deck.
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_deck_crew.gd -- out.png [yaw] [pitch]

var _frames: int = 0
var _out: String = "user://deck_crew.png"
var _yaw: float = 0.9
var _pitch: float = 0.55
var _other: Ship


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 2:
		_yaw = float(args[1])
		_pitch = float(args[2])
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	var w: Node = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	current_scene = w


func _process(_d: float) -> bool:
	_frames += 1
	var w: Node = current_scene
	if _frames == 5:
		w.ship.position = Vector3(4000, 0.5, 4000)
		w.ship.crew.count = 16
		var tut: Node = w.get("tutorial")
		if tut != null:
			tut.queue_free()
	if _frames == 6:
		_other = Ship.new()
		_other.stats = load("res://data/ships/%s.tres" % OS.get_environment("SHOT_SHIP") if OS.get_environment("SHOT_SHIP") != "" else "res://data/ships/brigantine.tres")
		_other.ocean = w.ocean.model
		_other.wind = w.wind
		_other.faction = "navy"
		_other.position = Vector3(4000 + 30, 0.5, 4000 + 4)
		_other.sail_level = 1
		w.add_child(_other)
	if _frames > 6:
		w.ship.sail_level = 1
		w.ship.linear_velocity = Vector3.ZERO
		if is_instance_valid(_other):
			_other.linear_velocity = Vector3.ZERO
			_other.global_position.x = w.ship.global_position.x + 30
			_other.global_position.z = w.ship.global_position.z + 4
			_other.rotation = w.ship.rotation
		w.rig.set("_dragging", true)
		w.rig.set("_orbit_yaw", _yaw)
		w.rig.set("_orbit_pitch", _pitch)
	if _frames == 320:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
