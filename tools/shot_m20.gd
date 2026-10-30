extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m20.gd -- rivals.png
## The rivals page after Molly is beaten and Saltjaw has taken the player's flag.

var _out: String = "user://m20_rivals.png"
var _frames: int = 0
var _w: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	var st: Dictionary = Session.state
	if _frames == 5:
		st["prizes_taken"] = 5
		st["bounty"]["navy"] = 60.0
		for i in 3:
			RivalState.record(st, "molly", true)
		RivalState.record(st, "saltjaw", false)
		RivalState.record(st, "saltjaw", false)
		RivalState.record(st, "vale", true)
		_w.open_rivals()
	if _frames == 40:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
