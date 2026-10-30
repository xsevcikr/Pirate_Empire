extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_isle.gd -- /tmp/isle
## An island with palms and its camp, seen from the beach and from the sea. The first seed with a camp is used.

var _prefix: String = "user://isle"
var _frames: int = 0
var _isle: Island
var _cam: Camera3D
var _camp: Node3D
var _seed: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.75, 0.9)
	Look.apply_environment(env)
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.82, 0.9)
	env.fog_density = 0.0008
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	Look.apply_sun(sun, 400.0)
	root.add_child(sun)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	water.mesh = pm
	var wm: ShaderMaterial = Kenney.flat(Color(0.3, 0.75, 0.9))
	water.material_override = wm
	root.add_child(water)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	root.add_child(_cam)
	_cam.make_current()


func _process(_d: float) -> bool:
	if _camp == null:
		if _isle != null:
			_camp = _isle.get_node_or_null("Camp")
			if _camp != null:
				print("seed ", _seed)
				_frames = 0
				return false
			_isle.queue_free()
		_seed += 1
		if _seed > 40:
			quit()
			return false
		_isle = Island.make(260.0, _seed, "tropical")
		root.add_child(_isle)
		return false
	_frames += 1
	var cp: Vector3 = _camp.global_position
	if _frames == 8:
		_cam.global_position = cp + Vector3(14.0, 4.5, 14.0)
		_cam.look_at(cp + Vector3(0.0, 1.4, 0.0), Vector3.UP)
	if _frames == 16:
		root.get_texture().get_image().save_png(_prefix + "_camp.png")
		print("saved camp")
		var out: Vector3 = Vector3(cp.x, 0.0, cp.z).normalized()
		_cam.global_position = out * (_isle.radius_m * 1.9) + Vector3(0.0, 9.0, 0.0)
		_cam.look_at(Vector3(cp.x * 0.5, 8.0, cp.z * 0.5), Vector3.UP)
	if _frames == 24:
		root.get_texture().get_image().save_png(_prefix + "_sea.png")
		print("saved sea")
		quit()
	return false
