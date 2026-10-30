extends SceneTree
## xvfb-run godot --path . --rendering-method gl_compatibility -s res://tools/render_title.gd -- [out.png]
## Renders the title-screen picture (assets/title/title_island.png): a little treasure island with a wrecked ship,
## palms, barrels and a dug-up chest, seen from above in bright cartoon water. The menu shows the saved picture.

const SIZE: Vector2i = Vector2i(1920, 1080)
const SAND: Color = Color(0.99, 0.85, 0.6)
const PROP: float = 1.35  ## props are drawn a little larger than life, like a toy diorama
const WET: Color = Color(0.86, 0.66, 0.44)

const WATER_CODE: String = """
shader_type spatial;
render_mode unshaded;
// Bright cartoon sea: a deep-to-light blue gradient with soft cell-edge ripples.
uniform vec3 deep : source_color = vec3(0.04, 0.36, 0.72);
uniform vec3 light : source_color = vec3(0.1, 0.58, 0.9);
uniform vec3 line : source_color = vec3(0.42, 0.8, 1.0);
varying vec3 w;
vec2 h2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float cells(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 r = o + h2(i + o) * 0.85 - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return sqrt(d2) - sqrt(d1);
}
void vertex() { w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float g = clamp(0.55 + w.z * 0.012 - length(w.xz) * 0.006, 0.0, 1.0);
	vec3 c = mix(deep, light, g);
	float e = cells(w.xz * vec2(0.22, 0.28) + vec2(sin(w.z * 0.3) * 0.25, 0.0));
	c = mix(c, line, (1.0 - smoothstep(0.015, 0.05, e)) * 0.4);
	float e2 = cells(w.xz * 0.6 + 13.0);
	c = mix(c, line, (1.0 - smoothstep(0.01, 0.03, e2)) * 0.12);
	ALBEDO = c;
}
"""

const GLOW_CODE: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
void fragment() { ALBEDO = COLOR.rgb; ALPHA = COLOR.a; }
"""

var _out: String = "res://assets/title/title_island.png"
var _frames: int = 0
var _rng := RandomNumberGenerator.new()
var _isle: Node3D


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_rng.seed = 1717
	root.size = SIZE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.55, 0.9)
	Look.apply_environment(env)
	env.ssao_enabled = false
	env.glow_enabled = false
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	Look.apply_sun(sun, 120.0)
	sun.light_energy = 1.0
	sun.shadow_opacity = 0.55
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(6.0, 48.0, 39.0), Vector3(6.0, 0.0, 5.5), Vector3.UP)
	cam.make_current()
	_isle = Node3D.new()
	root.add_child(_isle)
	_build()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 10:
		var img: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out).get_base_dir())
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false


## Island outline radius at angle `a`: a wide oval with a few lazy bumps, like a cartoon sandbank.
func _radius(a: float) -> Vector2:
	var k: float = 1.0 + 0.09 * sin(2.0 * a + 1.3) + 0.06 * sin(3.0 * a + 0.4) + 0.035 * sin(5.0 * a + 2.0)
	return Vector2(cos(a) * 17.5 * k, sin(a) * 11.0 * k)


func _build() -> void:
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	pm.subdivide_depth = 1
	water.mesh = pm
	water.material_override = _shader(WATER_CODE)
	_isle.add_child(water)
	_ring(1.0, 1.5, Color(0.3, 0.88, 0.92, 0.85), Color(0.2, 0.7, 0.95, 0.0), 0.04)
	_ring(1.0, 1.18, Color(0.5, 0.96, 0.92, 0.85), Color(0.4, 0.9, 0.95, 0.0), 0.06)
	_ring(1.04, 1.1, Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.85), 0.08)
	_ring(1.15, 1.18, Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.4), 0.08)
	_sand()
	_pool(Vector3(-7.5, 0.0, -4.0), Vector2(3.0, 1.8))
	_dress()


func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## A flat band around the island outline between two radius factors, coloured from inner to outer.
func _ring(f0: float, f1: float, c0: Color, c1: Color, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 160
	for i in n:
		var a0: float = TAU * i / n
		var a1: float = TAU * (i + 1) / n
		var r0: Vector2 = _radius(a0)
		var r1: Vector2 = _radius(a1)
		var w0: float = 1.0 + 0.012 * sin(a0 * 23.0)
		var w1: float = 1.0 + 0.012 * sin(a1 * 23.0)
		var p := [r0 * f0, r0 * f1 * w0, r1 * f1 * w1, r1 * f0]
		var cs := [c0, c1, c1, c0]
		for t in [0, 1, 2, 0, 2, 3]:
			st.set_color(cs[t])
			st.add_vertex(Vector3(p[t].x, y, p[t].y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _shader(GLOW_CODE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_isle.add_child(mi)


## The sand: a low dome with a damp darker rim sloping into the water.
func _sand() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 160
	var rings: Array = [[0.0, 0.95, SAND], [0.55, 0.85, SAND], [0.86, 0.6, SAND], [0.97, 0.32, SAND.lerp(WET, 0.4)], [1.04, -0.4, WET]]
	for i in n:
		var a0: float = TAU * i / n
		var a1: float = TAU * (i + 1) / n
		for j in rings.size() - 1:
			var ri: Array = rings[j]
			var ro: Array = rings[j + 1]
			var p := [
				_v(a0, ri[0], ri[1]), _v(a1, ri[0], ri[1]), _v(a1, ro[0], ro[1]), _v(a0, ro[0], ro[1]),
			]
			var cs := [ri[2], ri[2], ro[2], ro[2]]
			for t in [0, 2, 1, 0, 3, 2]:
				st.set_color(cs[t])
				st.add_vertex(p[t])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Kenney.vcol()
	_isle.add_child(mi)


func _v(a: float, f: float, y: float) -> Vector3:
	var r: Vector2 = _radius(a) * f
	return Vector3(r.x, y, r.y)


## A small tide pool in the sand: a turquoise blob with a pale rim.
func _pool(at: Vector3, size: Vector2) -> void:
	for layer in [[1.18, Color(0.98, 0.93, 0.78, 1.0), 0.9], [1.0, Color(0.35, 0.82, 0.95, 1.0), 0.93], [0.62, Color(0.2, 0.62, 0.9, 1.0), 0.95]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: int = 48
		for i in n:
			var a0: float = TAU * i / n
			var a1: float = TAU * (i + 1) / n
			var k0: float = layer[0] * (1.0 + 0.12 * sin(a0 * 3.0 + 0.7))
			var k1: float = layer[0] * (1.0 + 0.12 * sin(a1 * 3.0 + 0.7))
			st.set_color(layer[1])
			st.add_vertex(at + Vector3(0, layer[2], 0))
			st.add_vertex(at + Vector3(cos(a1) * size.x * k1, layer[2], sin(a1) * size.y * k1))
			st.add_vertex(at + Vector3(cos(a0) * size.x * k0, layer[2], sin(a0) * size.y * k0))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _shader(GLOW_CODE)
		_isle.add_child(mi)


## Height of the sand dome at a point, so props sit on it.
func _ground(x: float, z: float) -> float:
	var a: float = atan2(z / 11.0, x / 17.5)
	var r: Vector2 = _radius(a)
	var f: float = Vector2(x, z).length() / maxf(r.length(), 0.01)
	if f < 0.55:
		return lerpf(0.95, 0.85, f / 0.55)
	if f < 0.86:
		return lerpf(0.85, 0.6, (f - 0.55) / 0.31)
	return lerpf(0.6, 0.32, clampf((f - 0.86) / 0.11, 0.0, 1.0))


func _put(model: String, x: float, z: float, yaw: float, s: float = 1.0, tilt: Vector3 = Vector3.ZERO, sink: float = 0.0) -> Node3D:
	var n: Node3D = Kenney.place(_isle, "pirate", model, Vector3(x, _ground(x, z) - sink, z), yaw, s * PROP)
	n.rotation_degrees += tilt
	return n


func _dress() -> void:
	# the wreck, run aground and keeled over on the east beach
	var wreck: Node3D = Kenney.place(_isle, "pirate", "ship-wreck", Vector3(7.0, -0.8, -0.5), 62.0, 1.6)
	wreck.rotation_degrees.z = -14.0
	# palms around the edges
	_put("palm-detailed-bend", -13.0, -4.5, 200.0, 1.35)
	_put("palm-detailed-straight", 13.5, -7.0, 30.0, 1.25)
	_put("palm-detailed-bend", 11.0, 6.0, 120.0, 1.3)
	_put("palm-bend", -3.5, -9.0, 160.0, 1.1)
	_put("palm-detailed-straight", -14.5, 5.0, 75.0, 1.05)
	# undergrowth at the palm feet
	for g in [[-11.8, -3.0], [-13.8, -4.0], [14.5, -5.5], [10.0, 7.0], [-2.5, -8.0], [-13.5, 6.5], [6.0, 8.0]]:
		_put("grass-plant", g[0], g[1], _rng.randf_range(0, 360), 1.1)
	# the pirate camp: flag, barrels, crates, a cannon
	_put("flag-pirate-high", -12.0, 0.5, 15.0, 1.25)
	_put("barrel", -9.5, 2.5, 20.0, 1.2)
	_put("barrel", -8.2, 3.6, 70.0, 1.1)
	_put("barrel", -4.0, 6.0, 0.0, 1.15, Vector3(90, 0, 0), -0.6)
	_put("barrel", 3.5, 3.5, 40.0, 1.15)
	_put("barrel", 5.0, 5.0, 10.0, 1.1, Vector3(0, 0, 90), -0.6)
	_put("barrel", 12.5, 2.5, 0.0, 1.0)
	_put("crate", -10.5, 4.3, 25.0, 1.1)
	_put("crate-bottles", -6.5, -6.0, 60.0, 1.0)
	_put("cannon", -2.0, -4.5, 150.0, 1.1)
	_put("cannon-ball", -0.6, -3.6, 0.0, 1.0)
	_put("cannon-ball", -0.2, -4.4, 0.0, 1.0)
	# treasure: a dug pit, a shovel left standing and the chest pulled out
	_put("tool-shovel", 0.2, 1.8, 35.0, 1.1, Vector3(0, 0, -18), 0.2)
	_put("chest", 1.6, 3.4, -25.0, 1.3)
	_put("bottle-large", -7.0, 1.5, 0.0, 1.0, Vector3(80, 0, 0), -0.15)
	# broken planks washed up
	for p in [[-5.5, 0.5, 30.0], [-3.0, 8.0, 100.0], [10.0, 4.0, 160.0], [4.5, -6.5, 70.0], [-15.5, -1.5, 10.0], [7.5, 8.8, 45.0]]:
		_put("platform-planks", p[0], p[1], p[2], 0.75, Vector3.ZERO, 0.15)
	# rocks on the beach and in the shallows
	_put("rocks-sand-a", -16.5, -6.5, 30.0, 0.45)
	_put("rocks-sand-b", 17.5, 2.0, 200.0, 0.4)
	_put("rocks-sand-c", -2.0, 10.5, 90.0, 0.35)
	Kenney.place(_isle, "pirate", "rocks-a", Vector3(-21.5, -0.3, 6.0), 40.0, 0.55)
	Kenney.place(_isle, "pirate", "rocks-b", Vector3(20.5, -0.3, -10.0), 120.0, 0.5)
	Kenney.place(_isle, "pirate", "rocks-c", Vector3(4.0, -0.3, 15.5), 10.0, 0.45)
	# a rowing boat pulled up to the south beach and a sunken mast poking out of the sea
	var boat: Node3D = Kenney.place(_isle, "pirate", "boat-row-small", Vector3(-9.0, 0.0, 13.0), -30.0, 1.8)
	boat.rotation_degrees.z = 4.0
	var barrel: Node3D = Kenney.place(_isle, "pirate", "barrel", Vector3(24.0, -0.5, 9.0), 0.0, 1.1)
	barrel.rotation_degrees.x = 70.0
	# a pirate sloop riding at anchor off the north shore
	Kenney.place(_isle, "pirate", "ship-pirate-small", Vector3(25.0, -0.3, -13.0), 215.0, 1.1)
