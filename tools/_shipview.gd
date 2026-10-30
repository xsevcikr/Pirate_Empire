extends SceneTree
## Scratch ship viewer.
var _frames: int = 0
var _w: Node
var _ship: Ship
var _cam: Camera3D
var _views: Array[Dictionary] = []
var _prefix: String
func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_prefix = a[0]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w
func _process(_d: float) -> bool:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_frames += 1
	if _frames == 3:
		var st: ShipStats = load("res://data/ships/%s.tres" % a[1])
		_ship = Ship.new()
		_ship.stats = st
		_ship.ocean = _w.ocean.model
		_ship.wind = _w.wind
		_ship.position = Vector3(900.0, 0.5, 2600.0)
		_ship.sail_level = int(a[3]) if a.size() > 3 else 3
		_ship.faction = a[2]
		_w.add_child(_ship)
		_w.day_night.apply_hour(11.0)
		_cam = Camera3D.new()
		_cam.fov = 58.0
		_w.add_child(_cam)
		_cam.make_current()
		var L: float = st.length_m
		if a.size() > 5:
			var cp: PackedStringArray = a[4].split(",")
			var lp: PackedStringArray = a[5].split(",")
			var one: Dictionary = {"pos": Vector3(float(cp[0]), float(cp[1]), float(cp[2])) * L, "look": Vector3(float(lp[0]), float(lp[1]), float(lp[2])) * L}
			_views = [one, one, one]
		else:
			_views = [
				{"pos": Vector3(L * 0.7, L * 0.18, -L * 0.8), "look": Vector3(0, L * 0.12, 0)},
				{"pos": Vector3(L * 1.1, L * 0.12, L * 0.0), "look": Vector3(0, L * 0.12, 0)},
				{"pos": Vector3(-L * 0.45, L * 0.3, L * 0.9), "look": Vector3(0, L * 0.1, -L * 0.1)},
			]
	for i in 3:
		var at: int = 90 + i * 40
		if _frames == at - 5:
			var v: Dictionary = _views[i]
			_cam.global_position = _ship.global_position + v["pos"]
			_cam.look_at(_ship.global_position + v["look"], Vector3.UP)
		if _frames == at:
			root.get_texture().get_image().save_png("%s_%d.png" % [_prefix, i])
	if _frames == 230:
		quit()
	return false
