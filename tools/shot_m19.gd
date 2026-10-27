extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m19.gd -- kraken.png ice.png
## The Kraken's whirlpool arena and the Ice Leviathan's floe field seen from the ship.

var _outs: Array[String] = ["user://m19_kraken.png", "user://m19_ice.png"]
var _frames: int = 0
var _w: Node


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	for i in mini(a.size(), 2):
		_outs[i] = a[i]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _view(boss: String) -> void:
	var v: ArenaView = ArenaView.make(boss)
	_w.add_child(v)
	_w.ship.global_position = Vector3(v.centre.x - v.radius * 0.8, 0.5, v.centre.y)
	_w.ship.rotation = Vector3(0, -PI / 2.0, 0)
	_w.ship.linear_velocity = Vector3.ZERO
	_w.streamer.load_all_near(v.centre)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_view("kraken")
	if _frames == 150:
		root.get_texture().get_image().save_png(_outs[0])
		_w.get_node("Arena_kraken").queue_free()
		_view("ice_leviathan")
	if _frames == 300:
		root.get_texture().get_image().save_png(_outs[1])
		quit()
	return false
