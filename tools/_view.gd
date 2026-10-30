extends SceneTree
## Scratch viewer: xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/_view.gd -- out.png "kit/model,kit/model" [spacing] [cam_dist] [cam_h]
var _frames := 0
func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var names: PackedStringArray = a[1].split(",")
	var sp: float = float(a[2]) if a.size() > 2 else 6.0
	var x: float = 0.0
	for nm in names:
		var kv: PackedStringArray = nm.split("/")
		var n: Node3D = Kenney.spawn(kv[0], kv[1])
		n.position = Vector3(x, 0, 0)
		root.add_child(n)
		x += sp
	var cam := Camera3D.new()
	root.add_child(cam)
	var cp: PackedStringArray = (a[3] if a.size() > 3 else "0,6,14").split(",")
	var lp: PackedStringArray = (a[4] if a.size() > 4 else "0,2,0").split(",")
	var mid: float = x * 0.5 - sp * 0.5
	cam.look_at_from_position(Vector3(mid + float(cp[0]), float(cp[1]), float(cp[2])), Vector3(mid + float(lp[0]), float(lp[1]), float(lp[2])))
	cam.fov = 50.0
func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 8:
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		quit()
	return false
