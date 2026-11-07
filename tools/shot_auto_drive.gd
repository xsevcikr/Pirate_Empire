extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_auto_drive.gd -- /tmp/auto
## Auto drive: the ship sails herself to the chart mark while the captain walks the deck. Shots: the captain amidships
## from behind (<prefix>_walk.png), the captain up at the bow looking out to sea (<prefix>_bow.png), and the helm view with the
## small "K Auto drive" button before it is switched on (<prefix>_helm.png).

var _prefix: String = "user://auto"
var _frames: int = 0
var _w: Node
var _drive: AutoDrive


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["ship_class"] = "brigantine"
	Session.state["crew"] = 18
	Session.state["tutorial"] = "done"
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		var s: Ship = _w.ship
		s.global_position = Vector3(600.0, 0.3, 1400.0)
		s.rotation = Vector3.ZERO
		s.sail_level = 3
		_drive = _w.auto_drive
	if _frames == 60:
		root.get_texture().get_image().save_png(_prefix + "_helm.png")
		var s: Ship = _w.ship
		Session.state["course"] = [s.global_position.x + 900.0, s.global_position.z - 2600.0]
		_drive.engage()
		_drive.walker.use_keys = false
		_drive.walker.move_input = Vector2(0.0, 1.0)
	if _frames == 75:  # stroll forward along the waist, then stop amidships for the first picture
		_drive.walker.move_input = Vector2.ZERO
		_drive.walker.fighter.pos = _drive.walker.start_spot(Vector2(0.0, -6.0))
		_drive.walker.fighter.dir = Vector2(0.3, -1.0).normalized()
		_drive.rig._walk_yaw = -0.35
	if _frames == 120:
		root.get_texture().get_image().save_png(_prefix + "_walk.png")
		_drive.walker.fighter.pos = _drive.walker.start_spot(Vector2(0.0, -9.5))
		_drive.walker.fighter.dir = Vector2(0.0, -1.0)
		_drive.rig._walk_yaw = 0.5  # from over his shoulder, out past the bowsprit
		_drive.rig._walk_pitch = 0.6
	if _frames == 210:
		root.get_texture().get_image().save_png(_prefix + "_bow.png")
		print("auto drive shots saved, captain at %s, deck %.2f, walk z %.1f..%.1f" % [_drive.walker.fighter.pos, _drive.walker.deck_y, _drive.walker.bow_z, _drive.walker.stern_z])
		quit(0)
	return false
