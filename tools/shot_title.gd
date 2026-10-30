extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_title.gd -- out.png
## The main menu as the player first sees it.

var _out: String = "user://title.png"
var _frames: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	root.size = Vector2i(1920, 1080)
	change_scene_to_file(Session.MENU_SCENE)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 30:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
