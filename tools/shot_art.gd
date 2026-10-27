extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_art.gd -- out_prefix [class] [hour]
## Art pass check: a ship under full sail seen from three camera positions (quarter view, deck level, stern).

var _prefix: String = "user://art"
var _cls: String = "galleon"
var _hour: float = 11.0
var _frames: int = 0
var _w: Node
var _ship: Ship
var _cam: Camera3D
var _views: Array[Dictionary] = []


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_prefix = a[0]
	if a.size() > 1:
		_cls = a[1]
	if a.size() > 2:
		_hour = float(a[2])
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		var st: ShipStats = load("res://data/ships/%s.tres" % _cls)
		_ship = Ship.new()
		_ship.stats = st
		_ship.ocean = _w.ocean.model
		_ship.wind = _w.wind
		_ship.position = Vector3(900.0, 0.5, 2600.0)
		_ship.rotation_degrees.y = 0.0
		_ship.sail_level = 3
		_ship.faction = "navy"
		_w.add_child(_ship)
		_w.day_night.apply_hour(_hour)
		_cam = Camera3D.new()
		_cam.fov = 58.0
		_w.add_child(_cam)
		_cam.make_current()
		var L: float = st.length_m
		_views = [
			{"pos": Vector3(L * 0.6, L * 0.1, -L * 0.75), "look": Vector3(0, L * 0.18, -L * 0.05)},
			{"pos": Vector3(1.4, st.freeboard_m + 3.6, L * 0.2), "look": Vector3(0, st.freeboard_m + 1.0, -L * 0.3)},
			{"pos": Vector3(-L * 0.35, L * 0.22, L * 0.9), "look": Vector3(0, L * 0.18, L * 0.1)},
		]
	if _frames >= 3 and _frames % 40 == 0 and _frames / 40 <= 3 and _frames > 40:
		var i: int = _frames / 40 - 2
		if i >= 0 and i < 3:
			pass
	for i in 3:
		var at: int = 100 + i * 60
		if _frames == at - 5:
			var v: Dictionary = _views[i]
			_cam.global_position = _ship.global_position + v["pos"]
			_cam.look_at(_ship.global_position + v["look"], Vector3.UP)
		if _frames == at:
			root.get_texture().get_image().save_png("%s_%d.png" % [_prefix, i])
			print("saved ", i)
	if _frames == 300:
		quit()
	return false
