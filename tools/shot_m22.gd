extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m22.gd -- /tmp/m22
## The settings page with its four volume sliders and the tavern with the shanty button and a bark subtitle.

var _prefix: String = "user://m22"
var _frames: int = 0
var _w: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["morale"] = 90.0
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	match _frames:
		10:
			var s := SettingsScreen.new()
			var layer := CanvasLayer.new()
			layer.name = "MapLayer"
			layer.layer = 52
			_w.add_child(layer)
			layer.add_child(s)
		40:
			root.get_texture().get_image().save_png(_prefix + "_settings.png")
			_w.get_node("MapLayer").queue_free()
			_w.open_port()
		50:
			var menu: Node = _w.get_node("PortLayer").get_child(0)
			menu._open(TavernScreen.new())
			Svc.node("Audio").bark("storm")
		90:
			root.get_texture().get_image().save_png(_prefix + "_tavern.png")
			quit(0)
			return true
	return false
