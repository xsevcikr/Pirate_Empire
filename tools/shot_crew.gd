extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/shot_crew.gd -- out.png
## A lineup of crew close up: kinds and seeds, to judge faces, wounds, weapons and clothes.

var _out: String = "user://crew.png"
var _frames: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	root.size = Vector2i(1280, 720)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 10)
	floor_m.mesh = pm
	floor_m.material_override = DeckArt.wood(Color(0.55, 0.4, 0.25))
	root.add_child(floor_m)
	var kinds: Array[String] = ["captain", "brute", "sailor", "crew", "marine", "officer", "brute", "sailor"]
	var melee: Array[String] = ["cutlass", "boarding_axe", "dagger", "cutlass", "bayonet", "rapier", "club", "cutlass"]
	var n: int = kinds.size()
	for i in n:
		var f := FighterState.new()
		f.id = 3 + i * 5
		f.kind = kinds[i]
		f.melee = melee[i]
		f.ranged = "musket" if i % 3 == 0 else ("flintlock" if i % 3 == 1 else "")
		f.pos = Vector2(-4.4 + i * 1.25, 0.0)
		f.dir = Vector2(0.15, 1.0).normalized()
		var v := DeckFighterView.new()
		v.fighter = f
		v.show_label = false
		root.add_child(v)
	var cam := Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 1.5, 7.2)
	cam.look_at(Vector3(0.0, 1.1, 0.0), Vector3.UP)
	cam.make_current()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 12:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit()
	return false
