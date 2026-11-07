extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_looks.gd -- out_prefix
## Visible ship upgrades: five brigantines side by side, from the starting look (left) to every line maxed (right),
## close looks at the middle and top tiers, then the shipyard's "Ship looks" tab.

const CLASS: String = "brigantine"
var _prefix: String = "user://looks"
var _frames: int = 0
var _w: Node
var _ships: Array[Ship] = []
var _cam: Camera3D
var _shots: Array[Dictionary] = []
var _screen: CatalogueScreen


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
	var st: ShipStats = load("res://data/ships/%s.tres" % CLASS)
	var gap: float = st.beam_m + 16.0
	for t in ShipLooks.TIERS + 1:
		var s := Ship.new()
		s.stats = st
		s.ocean = _w.ocean.model
		s.wind = _w.wind
		s.faction = "player"
		s.position = Vector3(900.0 + gap * t, 0.5, 2600.0)
		s.sail_level = 3
		s.freeze = true
		_w.add_child(s)
		_ships.append(s)
	_w.day_night.apply_hour(10.5)
	for c in _w.get_children():
		if c is CanvasLayer:
			c.visible = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 6000.0
	_w.add_child(_cam)
	_cam.make_current()
	var L: float = st.length_m
	var mid := Vector3(900.0 + gap * 2.0, 0.0, 2600.0)
	_shots.append({"name": "lineup", "pos": mid + Vector3(-gap * 0.4, L * 0.9, -L * 2.9), "look": mid + Vector3(0, L * 0.25, 0)})
	for t in [4, 2, 3]:
		var c: Vector3 = Vector3(900.0 + gap * t, 0.0, 2600.0)
		_shots.append({"name": "tier%d" % t, "pos": c + Vector3(-L * 0.85, L * 0.45, -L * 0.75), "look": c + Vector3(0, L * 0.22, 0)})
	var top := Vector3(900.0 + gap * 4, 0.0, 2600.0)
	_shots.append({"name": "guns", "pos": top + Vector3(-st.beam_m * 1.4, L * 0.32, L * 0.05), "look": top + Vector3(0, L * 0.12, -L * 0.02)})


func _dress() -> void:
	for t in _ships.size():
		var s: Dictionary = {"looks": {"sails": t, "flags": t, "cannons": t}, "custom": {}}
		ShipLooks.apply(_ships[t].visuals, s)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		_spawn()
	if _frames == 8:
		_dress()
	for i in _shots.size():
		var at: int = 90 + i * 30
		if _frames == at - 6:
			_cam.global_position = _shots[i]["pos"]
			_cam.look_at(_shots[i]["look"], Vector3.UP)
		if _frames == at:
			root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, _shots[i]["name"]])
			print("saved ", _shots[i]["name"])
	var shop: int = 100 + _shots.size() * 30
	if _frames == shop:
		_cam.queue_free()
		for c in _w.get_children():
			if c is CanvasLayer:
				c.visible = true
		var st: Dictionary = Session.state
		st["gold"] = 4200
		ShipLooks.buy(st, "flags")
		ShipLooks.buy(st, "flags")
		ShipLooks.buy(st, "cannons")
		st["gold"] = 4200
		_w.open_port()
	if _frames == shop + 10:
		var menu: PortMenu = _w.get_node("PortLayer").get_child(0)
		_screen = ShipyardScreen.new()
		menu._open(_screen)
	if _frames == shop + 25:
		_screen.select("cat.looks")
	if _frames == shop + 45:
		root.get_texture().get_image().save_png("%s_shop.png" % _prefix)
		print("saved shop")
		quit()
	return false
