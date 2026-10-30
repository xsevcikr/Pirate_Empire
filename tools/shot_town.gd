extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_town.gd -- /tmp/town
## The walkable harbour town: the street from the captain's eye, the market square and the castle end.

var _prefix: String = "user://town"
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
	root.add_child(_d)


func _look(from: Vector3, to: Vector3, fov: float = 62.0) -> void:
	_d.active = false
	_d.camera.fov = fov
	_d.camera.global_position = _d.global_position + from
	_d.camera.look_at(_d.global_position + to, Vector3.UP)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 120:
		_look(Vector3(0, 3.2, 36), Vector3(0, 6, -20))
	if _frames == 130:
		root.get_texture().get_image().save_png(_prefix + "_street.png")
		print("saved street")
		_look(Vector3(7, 2.2, 14), Vector3(0, 1.6, 0), 58.0)
	if _frames == 140:
		root.get_texture().get_image().save_png(_prefix + "_square.png")
		print("saved square")
		_look(Vector3(-22, 16, 6), Vector3(0, 8, -42), 70.0)
	if _frames == 150:
		root.get_texture().get_image().save_png(_prefix + "_castle.png")
		print("saved castle")
		quit()
	return false
