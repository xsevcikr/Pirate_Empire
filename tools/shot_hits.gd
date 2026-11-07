extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_hits.gd -- /tmp/hits
## Sound and hit effects: a brig's broadside striking our sloop (sparks, flashes and splinters on the hull, from
## close by), then our own broadside going off (muzzle flashes) with the balls throwing sparks off the brig and a
## near-miss splash beside us. Prints what the effects did so a headless run can check them too.

var _prefix: String = "user://hits"
var _frames: int = 0
var _w: Node
var _ship: Ship
var _brig: Ship
var _cam: Camera3D


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["ship_class"] = "sloop"
	Session.state["crew"] = 22
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _count(kind: String) -> int:
	var n: int = 0
	for c in _w.get_children():
		if c.get_meta("kind", "") == kind:
			n += 1
	return n


func _hull_hits(target: Ship, side: float, count: int) -> void:
	var b: Basis = target.global_transform.basis
	var hb: float = target.stats.beam_m * 0.5
	for k in count:
		var z: float = lerpf(-target.stats.length_m * 0.3, target.stats.length_m * 0.3, float(k) / maxf(count - 1, 1))
		var local := Vector3(hb * side, 0.9 + 0.5 * (k % 2), z)
		var world: Vector3 = target.to_global(local)
		var normal: Vector3 = b.x * side
		target.receive_cannonball(world, normal, -normal, "12pdr", "round", 60.0, _brig if target == _ship else _ship)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_ship = _w.ship
		var at := Vector3(600.0, 0.3, 1400.0)
		_ship.global_position = at
		_ship.rotation = Vector3.ZERO
		_ship.sail_level = 0
		_brig = _w._make_ship(load("res://data/ships/brigantine.tres"), at + Vector3(-70.0, 0, -6.0), 0.0, "navy")
		_brig.ai = ShipAI.new()
		_brig.sail_level = 0
		_cam = Camera3D.new()
		_cam.fov = 50.0
		_w.add_child(_cam)
	if _frames >= 5 and _frames < 200:  # close by on our port quarter, looking along the struck side
		var b: Basis = _ship.global_transform.basis
		_cam.global_position = _ship.global_position - b.x * 14.0 + b.z * 9.0 + Vector3(0, 3.5, 0)
		_cam.look_at(_ship.global_position - b.x * 1.5 + Vector3(0, 1.4, -1.0), Vector3.UP)
		_cam.make_current()
	if _frames == 58:
		Engine.time_scale = 0.3  # slow motion so the half-second sparks are still flying at the capture
	if _frames == 60:
		_hull_hits(_ship, -1.0, 4)
		print("hit: sparks %d flashes %d" % [_count("sparks"), _count("hit_flash")])
	if _frames == 70:
		root.get_texture().get_image().save_png(_prefix + "_struck.png")
		Engine.time_scale = 1.0
	if _frames == 200:  # back to the chase camera, our broadside going off at the brig
		_w.rig.camera.make_current()
		_cam.queue_free()
	if _frames == 228:
		Engine.time_scale = 0.3
	if _frames == 230:
		var shots: int = _ship.broadside.fire(0)
		shots += _ship.broadside.fire(1)
		print("broadside: %d guns" % shots)
		_hull_hits(_brig, 1.0, 5)
		_hull_hits(_ship, -1.0, 1)  # one back at us while the chase camera follows her: thud and shake
		var me: Vector3 = _ship.global_position
		_w.projectiles.fire(me + Vector3(-12.0, 6.0, 4.0), Vector3(0, -20.0, 0), "12pdr", "round", _brig)
	if _frames == 240:
		root.get_texture().get_image().save_png(_prefix + "_broadside.png")
		Engine.time_scale = 1.0
		print("near misses %d" % _w.projectiles.near_misses)
	if _frames == 260:
		var audio: Node = root.get_node_or_null("Audio")
		if audio != null:
			print("played: ", {"hit_thud": audio.played.get("hit_thud", 0), "splash_near": audio.played.get("splash_near", 0),
				"wave_slap": audio.played.get("wave_slap", 0), "cannon": audio.played.get("cannon_12pdr", 0) + audio.played.get("cannon_6pdr", 0)})
		print("sea state %.1f, %.1f s of game time" % [_w.wind.sea_state(), Time.get_ticks_msec() / 1000.0])
		print("saved ", _prefix)
		quit()
	return false
