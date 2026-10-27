extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m17.gd -- out.png [port]
## A fort wall after a bombardment: cracked segments, a breach, rubble, fires and floating wreckage.

var _out: String = "user://m17.png"
var _port_id: String = "albion"
var _frames: int = 0
var _w: Node
var _ps: PortScene


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_port_id = args[1]
	Session.begin_new("Rob", 1, 7)
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		var dock: Vector2 = PortData.PORTS[_port_id]["dock"]
		_w.streamer.load_all_near(dock)
		_w.ship.global_position = Vector3(dock.x, 0.5, dock.y + 400.0)
	if _frames == 20:
		_ps = _w.streamer.ports[_port_id]
		var walls: Array[DestructibleBuilding] = []
		var towers: Array[DestructibleBuilding] = []
		for b in _ps.buildings:
			if b.kind == "wall":
				walls.append(b)
			elif b.kind == "tower":
				towers.append(b)
		var mid: int = walls.size() / 2
		for i in walls.size():
			var d: int = absi(i - mid)
			if d <= 1:
				walls[i].hurt(walls[i].max_hp * 2.0, true)
			elif d <= 3:
				walls[i].hurt(walls[i].max_hp * 0.72, true)
			elif d <= 5:
				walls[i].hurt(walls[i].max_hp * 0.4, true)
		towers[0].hurt(towers[0].max_hp * 0.5, true)
		var focus: Vector3 = walls[mid].global_position
		var back: Vector3 = _ps.global_transform.basis.z
		_w.ship.global_position = focus + back * 85.0 + _ps.global_transform.basis.x * 28.0 + Vector3(0, 0.5, 0)
		_w.ship.look_at(focus + Vector3(0, 0.5, 0), Vector3.UP)
		_w.ship.rotation.x = 0.0
		_w.ship.rotation.z = 0.0
		_w.ship.sail_level = 0
		var target: Ship = _w._make_ship(load("res://data/ships/sloop.tres"), focus + back * 120.0 + _ps.global_transform.basis.x * -25.0, 0.0, "navy")
		target.damage.sunk = true
		target.damage.sank.emit()
	if _frames == 150:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
