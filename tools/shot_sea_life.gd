extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility --fixed-fps 30 -s res://tools/shot_sea_life.gd -- /tmp/sea
## Sea life and the walk on deck: dolphins on the bow wave, a whale blowing, flying fish and gulls, the captain on
## deck under autopilot, a bite on the fishing line and the catch on the planks.

var _prefix: String = "user://sea"
var _frames: int = 0
var _w: Node
var _ship: Ship
var _life: SeaLife
var _walk: DeckWalk
var _cam: Camera3D
var _plan: Array = []  ## [frame, callable]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["ship_class"] = "brigantine"
	Session.state["crew"] = 30
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, name])
	print("saved ", name)


func _side_cam(off: Vector3, look: Vector3, fov: float = 50.0) -> void:
	var b: Basis = _ship.global_transform.basis
	_cam.fov = fov
	_cam.global_position = _ship.global_position + b * off
	_cam.look_at(_ship.global_position + b * look, Vector3.UP)
	_cam.make_current()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_ship = _w.ship
		_life = _w.sea_life
		_walk = _w.deck_walk
		_ship.global_position = Vector3(600.0, 0.3, 1400.0)
		_ship.rotation = Vector3.ZERO
		_ship.sail_level = 3
		_life._pod_timer = 0.0
		_life._whale_timer = 9999.0
		_life._school_timer = 9999.0
		_cam = Camera3D.new()
		_w.add_child(_cam)
		var start: int = 450
		_plan = [
			[start - 1, func() -> void: print("pod: ", _life.pod_state)],
			[start, func() -> void: _side_cam(Vector3(10.0, 3.5, -26.0), Vector3(0.0, 0.5, -14.0), 55.0)],
			[start + 2, func() -> void: _save("dolphins")],
			[start + 10, func() -> void:
				_life._school_timer = 0.0
				_side_cam(Vector3(-4.0, 6.0, -40.0), Vector3(0.0, 4.0, -8.0), 60.0)],
			[start + 24, func() -> void: _save("flying_fish")],
			[start + 30, func() -> void:
				_life._pod_timer = 9999.0
				_life._whale_timer = 0.0],
			[start + 31, func() -> void:
				var b: Basis = _ship.global_transform.basis
				_life._whale.global_position = _ship.global_position + b * Vector3(55.0, 0.0, -30.0)
				_life._whale_dir = -b.z],
			[start + 52, func() -> void:
				var b: Basis = _ship.global_transform.basis
				var wp: Vector3 = _life._whale.global_position
				_cam.fov = 55.0
				_cam.global_position = wp + b.x * 20.0 + b.z * 17.0 + Vector3.UP * 8.0
				_cam.look_at(wp - b.x * 6.0 + Vector3.UP * 2.0, Vector3.UP)
				_cam.make_current()],
			[start + 60, func() -> void:
				print("whale ", _life.whale_state, " at ", _life._whale.global_position, " ship ", _ship.global_position, " cam ", _cam.global_position, " vis ", _life._whale.visible)
				_save("whale")],
			[start + 60, func() -> void:
				_life._whale_timer = 9999.0
				_walk.leave_helm()
				_walk.captain_pos = Vector2(0.6, 1.0)],
			[start + 61, func() -> void: _walk.captain_pos = Vector2(0.9, 0.2)],
			[start + 62, func() -> void: _walk.captain_pos = Vector2(1.1, -0.6)],
			[start + 78, func() -> void: _w.rig.camera.make_current()],
			[start + 82, func() -> void: _save("deck_walk")],
			[start + 84, func() -> void:
				_walk.captain_pos = Vector2(_walk.deck_half_width(-1.5), -1.5)
				_walk.use()
				_walk.fishing.tick(DeckFishing.WAIT_MAX_S + 0.1)
				_walk.fishing.timer = 99.0],
			[start + 100, func() -> void: _side_cam(Vector3(10.0, 4.5, 4.5), Vector3(2.0, 2.0, -2.5), 52.0)],
			[start + 104, func() -> void: _save("fishing_bite")],
			[start + 106, func() -> void: _walk.use()],
			[start + 110, func() -> void:
				_walk._show_t = 99.0
				_walk.fishing.timer = 99.0
				_side_cam(Vector3(5.5, 5.0, 3.5), Vector3(0.5, 2.2, -2.0), 55.0)],
			[start + 122, func() -> void: _save("catch")],
			[start + 125, func() -> void: quit()],
		]
	for step: Array in _plan:
		if int(step[0]) == _frames:
			(step[1] as Callable).call()
	if _frames > 2000:
		quit(1)
	return false
