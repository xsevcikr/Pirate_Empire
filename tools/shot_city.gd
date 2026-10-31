extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_city.gd -- /tmp/city [port...]
## Harbour towns from the sea and from the air for each port given (default: a capital, a city and a village),
## then the walkable dock district: the chandler's front, a townsperson talking, and the whole walled town.

var _prefix: String = "user://city"
var _ports: Array[String] = []
var _frames: int = 0
var _w: Node
var _cam: Camera3D
var _i: int = 0
var _t0: int = 0
var _d: DockDistrict


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	for k in range(1, args.size()):
		_ports.append(args[k])
	if _ports.is_empty():
		_ports = _pick_ports()
	GameInput.register()
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _pick_ports() -> Array[String]:
	var out: Array[String] = []
	for tier in ["capital", "city", "village"]:
		for id: String in PortData.PORTS:
			if PortData.PORTS[id]["tier"] == tier and not out.has(id):
				out.append(id)
				break
	return out


func _shoot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
	print("saved ", name)


func _process(_d2: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	if _i < _ports.size():
		var id: String = _ports[_i]
		var f: int = _frames - _t0
		if f == 1 or _t0 == 0:
			_t0 = _frames
			var dock: Vector2 = PortData.PORTS[id]["dock"]
			_w.ship.global_position = Vector3(dock.x, 0.5, dock.y)
			_w.streamer.load_all_near(dock)
			return false
		if f == 200:
			var ps: PortScene = _w.streamer.ports[id]
			if _cam == null:
				_cam = Camera3D.new()
				_cam.far = 4000.0
				root.add_child(_cam)
			_cam.make_current()
			var centre: Vector3 = ps.to_global(ps.town_point(0, 0))
			var sea: Vector3 = ps.global_transform.basis.z
			var side: Vector3 = ps.global_transform.basis.x
			_cam.global_position = centre + sea * 150.0 + side * 70.0 + Vector3(0, 55, 0)
			_cam.look_at(centre, Vector3.UP)
			_cam.fov = 55.0
		if f == 210:
			_shoot(_ports[_i] + "_sea")
			var ps2: PortScene = _w.streamer.ports[id]
			var c2: Vector3 = ps2.to_global(ps2.town_point(0, 0))
			_cam.global_position = c2 + ps2.global_transform.basis.z * 30.0 + Vector3(0, 120, 0)
			_cam.look_at(c2, Vector3.UP)
		if f == 220:
			_shoot(_ports[_i] + "_air")
			var ps3: PortScene = _w.streamer.ports[id]
			var c3: Vector3 = ps3.to_global(ps3.town_point(0, 0))
			_cam.global_position = c3 + ps3.global_transform.basis.z * 14.0 + ps3.global_transform.basis.x * 10.0 + Vector3(0, 9, 0)
			_cam.look_at(c3 + Vector3(0, 2, 0), Vector3.UP)
		if f == 230:
			_shoot(_ports[_i] + "_street")
			_i += 1
			_t0 = 0
		return false
	if _d == null:
		_d = DockDistrict.new()
		root.add_child(_d)
		_t0 = _frames
		return false
	var g: int = _frames - _t0
	if g == 120:
		_d.active = false
		var door: Vector3 = Vector3.ZERO
		for dd in _d.doors:
			if dd["kind"] == "supplies":
				door = dd["pos"]
		_d.camera.fov = 60.0
		_d.camera.global_position = _d.global_position + door + Vector3(-sign(door.x) * 6.0, 3.0, 7.0)
		_d.camera.look_at(_d.global_position + door + Vector3(sign(door.x) * 3.0, 2.0, 0.0), Vector3.UP)
		_d.captain.position = door
	if g == 130:
		_shoot("dock_chandler")
		var w: TownWalker = _d.walkers[0]
		_d.captain.position = w.pos3() + Vector3(1.5, 0, 0.5)
		_d.talk_nearest()
		var at: Vector3 = _d.global_position + w.pos3()
		_d.camera.global_position = at + Vector3(4.0, 2.6, 5.0)
		_d.camera.look_at(at + Vector3(0, 1.6, 0), Vector3.UP)
	if g == 140:
		_shoot("dock_talk")
		_d.camera.fov = 70.0
		_d.camera.global_position = _d.global_position + Vector3(70, 75, 60)
		_d.camera.look_at(_d.global_position + Vector3(0, 0, -20), Vector3.UP)
	if g == 150:
		_shoot("dock_air")
		quit()
	return false
