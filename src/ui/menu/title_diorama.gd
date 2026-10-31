class_name TitleDiorama
extends Node3D
## The title picture: a little sandy island in a turquoise sea, seen from above, with a wrecked ship run up on the
## beach, palms, barrels, a chest, the black flag and a rowing boat. tools/shot_title.gd renders it once to
## assets/ui/title_island.png, which the main menu shows behind the logo.

const R: float = 13.0          ## the island's mean radius
const TOP_Y: float = 1.0
const SAND := Color(0.92, 0.72, 0.4)
const SAND_WET := Color(0.78, 0.56, 0.32)

var camera: Camera3D


## Radius of the shoreline at angle `a` (radians): a lumpy circle, the same formula the water shader uses.
static func shore(a: float) -> float:
	return R * (1.0 + 0.13 * sin(2.0 * a + 1.0) + 0.07 * sin(3.0 * a + 2.2) + 0.04 * sin(5.0 * a + 0.4))


func _ready() -> void:
	_environment()
	add_child(_water())
	add_child(_island_mesh())
	add_child(_pond())
	_props()
	camera = Camera3D.new()
	camera.fov = 29.0
	camera.position = Vector3(0.0, 52.0, 47.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 8.5), Vector3.UP)
	camera.make_current()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.55, 0.75)
	Look.apply_environment(env)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	Look.apply_sun(sun, 120.0)
	sun.light_energy = 1.0
	add_child(sun)


func _water() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260.0, 260.0)
	pm.subdivide_width = 2
	pm.subdivide_depth = 2
	mi.mesh = pm
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("radius", R)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


const WATER_SHADER: String = """
shader_type spatial;
render_mode unshaded;
uniform float radius = 13.0;
float shore(float a) {
	return radius * (1.0 + 0.13 * sin(2.0 * a + 1.0) + 0.07 * sin(3.0 * a + 2.2) + 0.04 * sin(5.0 * a + 0.4));
}
float cell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = fract(sin(vec2(dot(i + g, vec2(127.1, 311.7)), dot(i + g, vec2(269.5, 183.3)))) * 43758.5453);
			d = min(d, length(g + o - f));
		}
	}
	return d;
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float d = length(p) - shore(atan(p.y, p.x));
	vec3 deep = vec3(0.02, 0.26, 0.5);
	vec3 mid = vec3(0.04, 0.45, 0.66);
	vec3 shallow = vec3(0.22, 0.72, 0.76);
	vec3 col = mix(shallow, mid, smoothstep(0.0, 9.0, d));
	col = mix(col, deep, smoothstep(10.0, 60.0, d));
	// sunlit caustic net, strongest in the shallows
	float c = cell(p * 0.22);
	float c2 = cell(p * 0.37 + vec2(3.1, 7.7));
	float net = smoothstep(0.08, 0.0, abs(c - 0.55) * 0.4) * 0.5 + smoothstep(0.06, 0.0, abs(c2 - 0.5) * 0.3) * 0.35;
	col += vec3(0.6, 0.85, 0.95) * net * mix(0.3, 0.08, smoothstep(0.0, 30.0, d));
	// white surf just off the sand, a second faint ring further out
	float surf = smoothstep(1.4, 0.2, d) * smoothstep(-0.6, 0.3, d);
	float ring = smoothstep(0.5, 0.0, abs(d - 2.6)) * 0.45;
	col = mix(col, vec3(1.0), clamp(surf + ring, 0.0, 1.0));
	ALBEDO = col;
}
"""


## The sand: a flat top ringed by a wet bevel that dips under the water.
func _island_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 96
	var rings: Array = [[0.0, TOP_Y + 0.25, SAND], [0.55, TOP_Y + 0.15, SAND], [0.9, TOP_Y, SAND], [1.0, 0.25, SAND_WET], [1.12, -1.2, SAND_WET]]
	var pts: Array = []
	for ring: Array in rings:
		var row: Array = []
		for i in n:
			var a: float = TAU * float(i) / float(n)
			var r: float = shore(a) * float(ring[0])
			row.append(Vector3(cos(a) * r, float(ring[1]), sin(a) * r))
		pts.append(row)
	for k in range(1, rings.size()):
		for i in n:
			var j: int = (i + 1) % n
			var a0: Vector3 = pts[k - 1][i]
			var a1: Vector3 = pts[k - 1][j]
			var b0: Vector3 = pts[k][i]
			var b1: Vector3 = pts[k][j]
			for v in [a0, b1, b0, a0, a1, b1]:
				st.set_color(rings[k][2] if v.y < TOP_Y - 0.01 else SAND)
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## A little rock pool on the sand, like the island has a spring.
func _pond() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.4
	cm.bottom_radius = 2.4
	cm.height = 0.05
	cm.radial_segments = 32
	mi.mesh = cm
	mi.scale = Vector3(1.0, 1.0, 0.65)
	mi.position = Vector3(-3.5, TOP_Y + 0.28, -7.2)
	mi.material_override = Kenney.flat(Color(0.3, 0.8, 0.92))
	return mi


func _put(model: String, pos: Vector3, yaw_deg: float, scale_k: float = 1.0, tilt: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = Kenney.spawn("pirate", model)
	n.position = pos
	n.rotation_degrees = Vector3(tilt.x, yaw_deg, tilt.z)
	n.scale = Vector3.ONE * scale_k
	add_child(n)
	return n


func _props() -> void:
	var y: float = TOP_Y + 0.2
	# the wreck, beached on its side across the east of the island
	_put("ship-wreck", Vector3(4.5, y - 0.6, -1.0), 65.0, 1.0, Vector3(0.0, 0.0, 9.0))
	# palms round the edge
	_put("palm-detailed-bend", Vector3(-9.0, y, -6.0), 30.0, 1.25)
	_put("palm-detailed-straight", Vector3(7.5, y, -7.0), -20.0, 1.3)
	_put("palm-detailed-bend", Vector3(8.0, y, 7.0), 200.0, 1.15)
	_put("palm-detailed-straight", Vector3(-6.0, y, 7.5), 90.0, 1.0)
	# barrels, a chest, crates and planks on the sand
	_put("barrel", Vector3(-7.5, y, 1.0), 10.0, 1.4)
	_put("barrel", Vector3(-5.8, y, 2.4), 40.0, 1.3)
	_put("barrel", Vector3(1.5, y + 0.6, 6.5), 0.0, 1.3, Vector3(90.0, 0.0, 0.0))
	_put("barrel", Vector3(10.0, y, 2.5), 70.0, 1.4)
	_put("chest", Vector3(-2.0, y, 1.5), -25.0, 1.6)
	_put("crate", Vector3(-4.0, y, 3.4), 15.0, 1.4)
	_put("platform-planks", Vector3(-1.0, y - 0.15, -3.5), 40.0)
	_put("platform-planks", Vector3(-4.5, y - 0.15, 4.8), -60.0, 0.8)
	_put("tool-shovel", Vector3(-0.5, y + 0.2, 3.8), 30.0, 1.4, Vector3(0.0, 0.0, 80.0))
	_put("bottle-large", Vector3(2.7, y, 4.5), 0.0, 1.2, Vector3(80.0, 30.0, 0.0))
	# the black flag on the west point
	_put("flag-pirate", Vector3(-10.5, y, -1.0), 20.0, 2.2)
	# grass tufts and rocks
	for g: Vector3 in [Vector3(-8.0, y, -3.2), Vector3(-4.5, y, -9.5), Vector3(6.5, y, -9.0), Vector3(9.0, y, 5.0), Vector3(-7.0, y, 5.5), Vector3(0.5, y, -8.0)]:
		_put("grass-plant", g, g.x * 20.0, 1.6)
	_put("rocks-sand-a", Vector3(-12.5, 0.1, 6.5), 30.0, 0.7)
	_put("rocks-sand-b", Vector3(12.8, 0.1, -5.5), 120.0, 0.6)
	# a rowing boat pulled up on the south beach, a broken mast in the shallows
	_put("boat-row-small", Vector3(3.0, 0.15, 13.0), -30.0, 1.3, Vector3(0.0, 0.0, 6.0))
	_put("mast", Vector3(-14.5, -1.0, 12.0), 50.0, 0.9, Vector3(0.0, 0.0, 28.0))
	# a ship's hull far out on the sea, top of the picture
	_put("ship-pirate-small", Vector3(5.0, -0.6, -27.0), 110.0, 0.9)
	_put("rocks-a", Vector3(-24.0, -0.5, -18.0), 0.0, 1.0)
	# life rings tossed on the sand
	for at: Vector3 in [Vector3(6.0, y + 0.15, 4.5), Vector3(-9.5, y + 0.15, 4.0)]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.55
		tm.outer_radius = 1.05
		ring.mesh = tm
		ring.position = at
		ring.material_override = Kenney.flat(Color(0.95, 0.25, 0.2), 0.0, true)
		add_child(ring)
		for k in 4:  # the white bands
			var band := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.62, 0.55, 0.36)
			band.mesh = bm
			var a: float = TAU * float(k) / 4.0 + 0.4
			band.position = at + Vector3(cos(a), 0.0, sin(a)) * 0.8
			band.rotation.y = -a
			band.material_override = Kenney.flat(Color(1.0, 0.98, 0.94))
			add_child(band)
