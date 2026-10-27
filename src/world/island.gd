class_name Island
extends StaticBody3D
## A procedural island: noise heightmap with sand, grass and rock vertex colours, plus a solid core ships can ground on.

const SAND := Color(0.80, 0.72, 0.52)
const GRASS := Color(0.22, 0.42, 0.16)
const FOREST := Color(0.12, 0.30, 0.12)
const ROCK := Color(0.38, 0.35, 0.32)

var radius_m: float = 200.0
var seed_value: int = 1
var peak_m: float = 40.0


static func make(radius: float, seed_v: int) -> Island:
	var isl := Island.new()
	isl.radius_m = radius
	isl.seed_value = seed_v
	isl.peak_m = clampf(radius * 0.22, 18.0, 70.0)
	return isl


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	set_meta("island", true)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius_m * 0.92
	cyl.height = 12.0
	cs.shape = cyl
	cs.position.y = -2.0
	add_child(cs)


func height_at(local: Vector2, noise: FastNoiseLite) -> float:
	var d: float = local.length() / radius_m
	var fall: float = clampf(1.0 - d * d, 0.0, 1.0)
	var n: float = 0.55 + 0.45 * noise.get_noise_2d(local.x, local.y)
	return (fall * peak_m * n) - 3.0 * (1.0 - fall) - 1.5 + (4.0 if fall > 0.0 else 0.0) * fall


func _build_mesh() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.6 / radius_m
	noise.fractal_octaves = 4
	var rings: int = 28
	var segs: int = 56
	var outer: float = radius_m * 1.25
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	for r in rings + 1:
		for s in segs:
			var ang: float = TAU * s / segs
			var rad: float = outer * float(r) / rings
			var p := Vector2.from_angle(ang) * rad
			# warp the coastline so it is not a circle
			var warp: float = 1.0 + 0.25 * noise.get_noise_2d(p.x * 1.7 + 311.0, p.y * 1.7)
			var h: float = height_at(p / warp, noise)
			verts.append(Vector3(p.x, h, p.y))
			cols.append(_color_for(h, noise.get_noise_2d(p.x * 3.0, p.y * 3.0)))
	for r in rings:
		for s in segs:
			var a: int = r * segs + s
			var b: int = r * segs + (s + 1) % segs
			var c: int = (r + 1) * segs + s
			var d: int = (r + 1) * segs + (s + 1) % segs
			for idx in [a, c, b, b, c, d]:
				st.set_color(cols[idx])
				st.add_vertex(verts[idx])
	st.generate_normals()
	return st.commit()


func _color_for(h: float, n: float) -> Color:
	if h < 0.8:
		return SAND.darkened(0.25)
	if h < 3.0:
		return SAND
	if h < peak_m * 0.55:
		return GRASS.lerp(FOREST, clampf(0.5 + n, 0.0, 1.0))
	return ROCK.lerp(GRASS, clampf(0.3 - n, 0.0, 0.6))
