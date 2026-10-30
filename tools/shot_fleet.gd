extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_fleet.gd -- out_prefix
## The new ship variants and the giant ships: a line-up at sea beside a Man-o-War for scale, then a close look
## at each new class under full sail.

const LINE: Array = [
	["pinnace", "pirate"], ["xebec", "pirate"], ["corvette", "navy"], ["east_indiaman", "merchant"], ["man_o_war", "navy"],
	["treasure_galleon", "merchant"], ["dreadnought", "navy"], ["leviathan", "pirate"],
]
var _prefix: String = "user://fleet"
var _frames: int = 0
var _w: Node
var _ships: Array[Ship] = []
var _cam: Camera3D
var _shots: Array[Dictionary] = []


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_prefix = a[0]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _spawn() -> void:
	var x: float = 0.0
	for e: Array in LINE:
		var st: ShipStats = load("res://data/ships/%s.tres" % e[0])
		x += st.beam_m * 0.5 + 14.0
		var s := Ship.new()
		s.stats = st
		s.ocean = _w.ocean.model
		s.wind = _w.wind
		s.faction = e[1]
		s.position = Vector3(900.0 + x, 0.5, 2600.0 + st.length_m * 0.5)
		s.sail_level = 3
		s.freeze = true
		_w.add_child(s)
		_ships.append(s)
		x += st.beam_m * 0.5 + 14.0
	_w.day_night.apply_hour(10.5)
	for c in _w.get_children():
		if c is CanvasLayer:
			c.visible = false
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 6000.0
	_w.add_child(_cam)
	_cam.make_current()
	var mid := Vector3(900.0 + x * 0.5, 0.0, 2600.0)
	_shots.append({"name": "lineup", "pos": mid + Vector3(-x * 0.1, 45.0, -x * 0.62), "look": mid + Vector3(0, 6.0, 30.0)})
	_shots.append({"name": "giants", "pos": mid + Vector3(x * 0.55, 30.0, -x * 0.55), "look": mid + Vector3(x * 0.25, 12.0, 30.0)})
	for s in _ships:
		if s.stats.class_id == "man_o_war":
			continue
		var L: float = s.stats.length_m
		var c: Vector3 = s.position
		_shots.append({"name": s.stats.class_id, "pos": c + Vector3(-L * 0.9, L * 0.28, -L * 0.85), "look": c + Vector3(0, L * 0.15, 0)})


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		_spawn()
	for i in _shots.size():
		var at: int = 90 + i * 30
		if _frames == at - 6:
			_cam.global_position = _shots[i]["pos"]
			_cam.look_at(_shots[i]["look"], Vector3.UP)
		if _frames == at:
			root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, _shots[i]["name"]])
			print("saved ", _shots[i]["name"])
	if _frames > 3 and _frames == 100 + _shots.size() * 30:
		quit()
	return false
