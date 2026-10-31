extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_easy_play.gd -- /tmp/easy
## Easy play: a close look at the parrot flying with the ship, the parrot circling a hidden treasure it spotted (the
## sailing view with the goals card), the goals list, and the collection book's shell, flag and ship pages.

var _prefix: String = "user://easy"
var _frames: int = 0
var _w: Node
var _cam: Camera3D
var _spot: Dictionary = {}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	Session.begin_new("Rob", 0, 7)
	var s: Dictionary = Session.state
	s["tutorial"] = "done"
	s["crew"] = 8
	s["ship_class"] = "sloop"
	s["ship_hull"] = 1.0
	s["hour"] = 11.0
	Achievements.record(s, "distance_km", 3.0)
	Achievements.record(s, "islands_found", 2.0)
	for id in ["shell_scallop", "shell_scallop", "shell_spiral", "shell_conch", "shell_starfish"]:
		EasyPlay.collect(s, id)
	for f in ["navy", "merchant"]:
		EasyPlay.add_faction_flag(s, f)
	EasyPlay.collect(s, "flag_rainbow")
	for c in ["cutter", "sloop", "schooner", "brigantine", "dreadnought"]:
		EasyPlay.add_ship_card(s, c)
	EasyPlay.check(s)
	_spot = HiddenLoot.spots()[2]
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	current_scene = _w


func _far_from_treasure() -> Vector2:
	for x in range(-6, 7):
		var p := Vector2(x * 700.0, 2600.0)
		if HiddenLoot.near(Session.state, p, HiddenLoot.SPOT_M * 1.5).is_empty():
			return p
	return Vector2(0, 2600)


func _process(_d: float) -> bool:
	_frames += 1
	var ship: Ship = _w.ship if _w != null else null
	if _frames == 5:
		var p: Vector2 = _far_from_treasure()
		ship.global_position = Vector3(p.x, 0.3, p.y)
		ship.rotation = Vector3.ZERO
		ship.sail_level = 2
		_cam = Camera3D.new()
		_cam.fov = 50.0
		_w.add_child(_cam)
	if _frames > 5 and _frames < 140:
		var par: ParrotModel = _w.easy_play.parrot
		var side: Vector3 = ship.global_transform.basis.x
		_cam.global_position = par.global_position + side * 4.5 + Vector3(0, 0.4, -2.5)
		_cam.look_at(par.global_position + Vector3(0, -0.6, 0), Vector3.UP)
		_cam.make_current()
	if _frames == 140:
		root.get_texture().get_image().save_png(_prefix + "_parrot.png")
		print("parrot close-up")
		# out to sea 120 m from a treasure spot, bow pointing at it
		var isl_pos: Vector2 = Vector2.ZERO
		for isl: Dictionary in PortData.gen().islands:
			if isl["name"] == _spot["island"]:
				isl_pos = isl["pos"]
		var sp: Vector2 = _spot["pos"]
		var away: Vector2 = (sp - isl_pos).normalized()
		var at: Vector2 = sp + away.rotated(0.25) * 120.0
		var d: Vector2 = (sp - at).normalized()
		ship.global_position = Vector3(at.x, 0.3, at.y)
		ship.rotation = Vector3(0, atan2(-d.x, -d.y), 0)
		ship.linear_velocity = Vector3.ZERO
		_w.easy_play.parrot.global_position = _w.easy_play.parrot.home_point()
		_cam.clear_current()
		_w.rig.get_viewport().get_camera_3d()
		for c in _w.find_children("*", "Camera3D", true, false):
			if c != _cam:
				(c as Camera3D).make_current()
				break
		ship.sail_level = 0
	if _frames == 420:
		root.get_texture().get_image().save_png(_prefix + "_treasure.png")
		print("treasure spotted: markers %d" % _w.easy_play.markers.size())
		_w.open_goals()
	if _frames == 450:
		root.get_texture().get_image().save_png(_prefix + "_goals.png")
		(_w.get_node("MapLayer").get_child(0) as MenuScreen).close()
	if _frames == 460:
		_w.open_collection()
	if _frames == 490:
		root.get_texture().get_image().save_png(_prefix + "_book_shells.png")
		var b: CollectionScreen = _w.get_node("MapLayer").get_child(0)
		b._set_page("flags")
	if _frames == 510:
		root.get_texture().get_image().save_png(_prefix + "_book_flags.png")
		var b: CollectionScreen = _w.get_node("MapLayer").get_child(0)
		b._set_page("ships")
	if _frames == 530:
		root.get_texture().get_image().save_png(_prefix + "_book_ships.png")
		Kenney.clear_caches()
		quit(0)
	return false
