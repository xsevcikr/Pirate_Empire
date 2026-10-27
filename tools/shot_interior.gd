extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_interior.gd -- /tmp/int galleon
## Below decks: the gun deck, the hold and the cabin of a ship, one picture each.

var _prefix: String = "user://interior"
var _class_id: String = "galleon"
var _frames: int = 0
var _screen: InteriorScreen


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	if args.size() > 1:
		_class_id = args[1]
	Session.begin_new("Rob", 1, 7)
	Session.state["gold"] = 9200
	Session.state["cargo"] = {"sugar": 20.0, "rum": 16.0, "spices": 8.0, "iron": 12.0, "timber": 10.0}
	root.size = Vector2i(1280, 720)
	_screen = InteriorScreen.new()
	_screen.stats = load("res://data/ships/%s.tres" % _class_id)
	root.add_child(_screen)


func _process(_d: float) -> bool:
	_frames += 1
	var views: Array[String] = ["gun_deck", "hold", "cabin"]
	for i in 3:
		if _frames == 10 + i * 25:
			_screen._pick(views[i])
		if _frames == 10 + i * 25 + 12:
			root.get_texture().get_image().save_png("%s_%d.png" % [_prefix, i])
			print("saved ", i)
	if _frames > 100:
		quit()
	return false
