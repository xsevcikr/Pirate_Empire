extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_bosses.gd -- /tmp/boss
## One picture per boss model, seen from the front and a little above.

var _prefix: String = "user://boss"
var _frames: int = 0
var _cam: Camera3D
var _cur: BossModel
var _idx: int = 0
const DIST: Dictionary = {"kraken": 120.0, "sea_serpent": 110.0, "shell_king": 28.0, "ghost_admiral": 110.0, "brass_colossus": 60.0, "ice_leviathan": 85.0}


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_prefix = args[0]
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.38)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.4, 0.5)
	env.fog_density = 0.0015
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 140, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.03, 0.14, 0.2)
	wm.roughness = 0.15
	water.material_override = wm
	root.add_child(water)
	_cam = Camera3D.new()
	_cam.far = 3000.0
	root.add_child(_cam)
	_cam.current = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames % 8 != 0:
		return false
	if _cur == null:
		if _idx >= BossModel.KINDS.size():
			quit()
			return true
		_cur = BossModel.make(BossModel.KINDS[_idx])
		root.add_child(_cur)
		var d: float = float(DIST[_cur.kind])
		_cam.position = Vector3(d * 0.35, d * 0.38, d)
		_cam.look_at(Vector3(0, d * 0.22, 0))
		return false
	root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_prefix, _cur.kind])
	_cur.queue_free()
	_cur = null
	_idx += 1
	return false
