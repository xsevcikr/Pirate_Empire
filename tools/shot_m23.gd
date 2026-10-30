extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_m23.gd -- /tmp/m23
## Crash damage and crew repair: a sloop rams a navy brig on the beam (side view at the moment of impact), a close
## look at the hull with an open hole, an oakum plug, a fothered sail and a plank patch, and the damage control
## panel with the crew's orders while she sails on down by the head.

var _prefix: String = "user://m23"
var _frames: int = 0
var _w: Node
var _ship: Ship
var _brig: Ship
var _cam: Camera3D
var _hit_at: int = -1
var _contact := Vector3.ZERO


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 1, 7)
	Session.state["ship_class"] = "sloop"
	Session.state["ship_hull"] = 1.0
	Session.state["crew"] = 22
	Session.state["supplies"]["timber"] = 6.0
	Session.state["supplies"]["canvas"] = 3.0
	Session.state["supplies"]["tools"] = 1.0
	root.size = Vector2i(1280, 720)
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 5:
		_ship = _w.ship
		var at := Vector3(600.0, 0.3, 1400.0)
		_ship.global_position = at
		_ship.rotation = Vector3.ZERO
		_ship.sail_level = 2
		_brig = _w._make_ship(load("res://data/ships/brigantine.tres"), at + Vector3(0, 0, -42.0), 90.0, "navy")
		_brig.ai = ShipAI.new()
		_brig.sail_level = 0
		_cam = Camera3D.new()
		_cam.fov = 55.0
		_w.add_child(_cam)
		_cam.global_position = at + Vector3(34.0, 7.0, -4.0)
		_cam.look_at(at + Vector3(0, 2.0, -30.0), Vector3.UP)
		_cam.make_current()
	if _frames > 30 and _hit_at < 0:
		_ship.linear_velocity = Vector3(0, _ship.linear_velocity.y, -10.0 * 0.5144)
		if not _ship.damage.breaches.is_empty():
			_hit_at = _frames
			_contact = _ship.to_global(_ship.damage.breaches[0]["pos"])
	if _hit_at > 0 and _frames == _hit_at + 7:
		root.get_texture().get_image().save_png(_prefix + "_ram.png")
		print("ram: sloop holes %d, brig holes %d" % [_ship.damage.breaches.size(), _brig.damage.breaches.size()])
	if _hit_at > 0 and _frames == _hit_at + 120:
		# a close look along the starboard side: every kind of repair, and the open hole spouting
		_brig.queue_free()
		_ship.linear_velocity = Vector3.ZERO
		_ship.global_position = Vector3(700.0, 0.3, 1500.0)
		_ship.rotation = Vector3.ZERO
		_ship.sail_level = 0
		var d: DamageModel = _ship.damage
		var hb: float = _ship.stats.beam_m * 0.5
		d.open_breach(2, Vector3(hb, -0.3, -1.5), 3, CollisionModel.breach_leak(3))
		var b2: int = d.open_breach(2, Vector3(hb, -0.3, 2.5), 2, CollisionModel.breach_leak(2))
		d.set_breach_state(b2, "stuffed")
		var b3: int = d.open_breach(3, Vector3(hb * 0.85, -0.3, 6.0), 2, CollisionModel.breach_leak(2))
		d.set_breach_state(b3, "fothered")
		var b4: int = d.open_breach(0, Vector3(hb * 0.8, -0.3, -5.5), 1, CollisionModel.breach_leak(1))
		d.set_breach_state(b4, "patched")
		d.water_t[0] = 4.0
		d.water_t[2] = 6.0
		d.section_hp[2] = d.section_max * 0.35
		d.section_hp[0] = d.section_max * 0.55
		_ship.refresh_damage()
		_w.damage_panel.expanded = true
		_w.damage_panel._layout()
	if _hit_at > 0 and _frames > _hit_at + 120 and _frames < _hit_at + 300:
		var side: Vector3 = _ship.global_transform.basis.x
		_cam.global_position = _ship.global_position + side * 11.0 + Vector3(0, 2.6, 1.0)
		_cam.look_at(_ship.global_position + side * 2.0 + Vector3(0, 0.6, 0.6), Vector3.UP)
	if _hit_at > 0 and _frames == _hit_at + 200:
		root.get_texture().get_image().save_png(_prefix + "_hull.png")
	if _hit_at > 0 and _frames == _hit_at + 300:
		_ship.sail_level = 2
		for i in _ship.damage.section_count:
			_ship.damage.water_t[i] = 0.0
		_ship.damage.water_t[0] = 2.5
		_ship.damage.set_breach_state(_ship.damage.worst_breach(), "fothered")
		_ship.damage.ignite(1)
	if _hit_at > 0 and _frames > _hit_at + 300:  # astern and to windward, watching her sail on down by the head
		var b: Basis = _ship.global_transform.basis
		_cam.global_position = _ship.global_position + b.z * 24.0 + b.x * 12.0 + Vector3(0, 8.0, 0)
		_cam.look_at(_ship.global_position + Vector3(0, 1.5, 0), Vector3.UP)
	if _hit_at > 0 and _frames == _hit_at + 400:
		root.get_texture().get_image().save_png(_prefix + "_panel.png")
		print("saved ", _prefix)
		quit()
	if _frames > 3000:
		print("no collision happened")
		quit(1)
	return false
