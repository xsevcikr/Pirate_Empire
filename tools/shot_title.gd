extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_title.gd -- [out.png]
## Renders the title island (TitleDiorama) to assets/ui/title_island.png, the picture behind the main menu.
## With `-- menu out.png` it shoots the finished main menu instead.

var _out: String = "res://assets/ui/title_island.png"
var _frames: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	if args.size() > 1 and args[0] == "menu":
		_out = args[1]
		change_scene_to_file("res://scenes/main_menu.tscn")
		return
	if args.size() > 0:
		_out = args[0]
	root.add_child(TitleDiorama.new())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 30:
		return false
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var path: String = ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("saved ", path)
	quit()
	return true
