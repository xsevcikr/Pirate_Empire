extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_landings.gd -- out_prefix
## Each island without a harbour and its beach landing, seen from the anchorage.

var _prefix: String = "user://landing"
var _frames: int = 0
var _cam: Camera3D
var _list: Array[int] = []
var _at: int = -1
var _isle: Island
var _site: Node3D


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
	water.material_override = Kenney.flat(Color(0.3, 0.75, 0.9))
	root.add_child(water)
	_cam = Camera3D.new()
	_cam.fov = 55.0
	root.add_child(_cam)
	_cam.make_current()
	_list = Landings.islands(PortData.gen())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 1:
		_at += 1
		if _at >= _list.size():
			quit()
			return false
		if _isle != null:
			_isle.free()
		var g: WorldGen = PortData.gen()
		var i: int = _list[_at]
		var info: Dictionary = g.islands[i]
		_isle = Island.make(info["radius"], 100 + i, info["biome"])
		root.add_child(_isle)
		_site = LandingSite.build(_isle, g, i)
	if _frames == 6:
		var s: Vector3 = _site.global_position
		var out: Vector3 = Vector3(s.x, 0.0, s.z).normalized()
		_cam.global_position = s + out * 55.0 + out.cross(Vector3.UP) * 22.0 + Vector3(0, 16.0, 0)
		_cam.look_at(s + Vector3(0, 3.0, 0) - out * 10.0, Vector3.UP)
	if _frames == 12:
		var nm: String = str(PortData.gen().islands[_list[_at]]["name"]).to_lower().replace(" ", "_").replace("'", "")
		root.get_texture().get_image().save_png("%s_%s.png" % [_prefix, nm])
		print("saved ", nm)
		_frames = 0
	return false
