extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_ashore.gd -- /tmp/ashore
## Ashore with F: the ship tied up at the pier, the captain stepping into the street with his crew behind him.

var _prefix: String = "user://ashore"
var _frames: int = 0
var _d: DockDistrict


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	GameInput.register()
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_d = DockDistrict.new()
	_d.ship_class = "brigantine"
	_d.shore_party = ["gunner", "swordsman", "seasoned", "musketeer", "bosun", "green"]
	root.add_child(_d)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 100:
		_d.active = false
		_d.camera.fov = 60.0
		_d.camera.global_position = _d.global_position + Vector3(-9, 6, 24)
		_d.camera.look_at(_d.global_position + Vector3(4, 1.5, 44), Vector3.UP)
	if _frames == 112:
		root.get_texture().get_image().save_png(_prefix + "_pier.png")
		print("saved pier")
		_d.active = true
	if _frames > 112 and _frames < 190:
		_d.step(Vector2(0.25, -1), 1.0 / 60.0)
		_d.follow(1.0 / 60.0)
		_d._place_camera(1.0 / 60.0)
	if _frames == 200:
		root.get_texture().get_image().save_png(_prefix + "_street.png")
		print("saved street")
		quit()
	return false
