extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_minimap.gd -- /tmp/minimap
## The top-left sea chart and status panel: by Haven Rock with ships of several flags around and a course set;
## then far from home, zoomed out, with low supplies (yellow and red bars); then the big chart.

var _prefix: String = "user://minimap"
var _frames: int = 0
var _w: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["course"] = [1400.0, -900.0]
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		var d := Discovery.new()
		d.reveal_around(Vector2.ZERO, 9000.0)
		_w.discovery = d
		var at: Vector2 = Vector2(_w.ship.global_position.x, _w.ship.global_position.z)
		var spots: Array = [[Vector2(700, -300), "navy", 30.0], [Vector2(-600, 500), "merchant", 200.0],
			[Vector2(900, 700), "pirate", 300.0], [Vector2(-1100, -700), "iron_dominion", 120.0], [Vector2(300, 1100), "black_sails", 10.0]]
		for s in spots:
			var p: Vector2 = at + s[0]
			_w._make_ship(load("res://data/ships/sloop.tres"), Vector3(p.x, 0.5, p.y), s[2], s[1])
	if _frames == 90:
		root.get_texture().get_image().save_png(_prefix + "_near.png")
	if _frames == 95:
		_w.ship.global_position = Vector3(5200.0, 0.5, 5200.0)
		_w.minimap.range_index = MinimapMath.RANGES_M.size() - 1
		Session.state["captain_hp"] = 60.0
		Session.state["supplies"]["food"] = 0.6
		Session.state["supplies"]["water"] = 2.0
		Session.state["supplies"]["rum"] = 0.04
		for k in _w.ship.damage.section_hp.size():
			_w.ship.damage.section_hp[k] *= 0.4
	if _frames == 180:
		root.get_texture().get_image().save_png(_prefix + "_far.png")
		print("home at ", MinimapMath.home_pos())
		_w.ship.global_position = Vector3(-200.0, 0.5, 900.0)
		_w.minimap.range_index = 1
		_w.open_map()
	if _frames == 260:
		root.get_texture().get_image().save_png(_prefix + "_chart.png")
		return true
	return false
