class_name ShipVisuals
extends RefCounted
## Procedural ship look: lofted hull, masts, yards, billowing sails, flags, gun ports and wakes.

const SAIL_SHADER: Shader = preload("res://shaders/sail.gdshader")
const FLAG_SHADER: Shader = preload("res://shaders/flag.gdshader")

var ship: Ship
var stats: ShipStats
var root: Node3D
var hull_material: ShaderMaterial
var mast_groups: Array[Node3D] = []
var sail_materials: Array[ShaderMaterial] = []
var flag_materials: Array[ShaderMaterial] = []
var _tiers: Array[Dictionary] = []  # {node, material, rig, tier, mast, square}
var _wake: CPUParticles3D
var _spray_l: CPUParticles3D
var _spray_r: CPUParticles3D
var _time: float = 0.0
var _rig_yaw: PackedFloat32Array = PackedFloat32Array()
var deck_crew: DeckCrew
var _model: Node3D
var _model_name: String = ""
var _parts: Dictionary = {}
var _sx: float = 1.0  ## model-to-ship scale across the beam
var _sy: float = 1.0  ## ... in height
var _sz: float = 1.0  ## ... along the length
var _sw: float = 1.0  ## ... for sails and masts, which keep their own proportions


func build(owner_ship: Ship) -> void:
	ship = owner_ship
	stats = ship.stats
	root = Node3D.new()
	root.name = "Visuals"
	ship.add_child(root)
	_fit()
	_build_hull()
	_build_rig()
	_build_guns()
	_build_wake()
	_build_crew()
	ShipLivery.apply(self)


## Scale factors from the Kenney hull (model units) to this ship class. Beam and length follow the stats; height
## follows the freeboard, damped so the big ships keep chunky proportions instead of towering.
func _fit() -> void:
	_model_name = ShipModel.model_for(stats, ship.faction)
	_parts = ShipModel.parts(_model_name)
	_sz = stats.length_m / float(_parts["length"])
	_sx = stats.beam_m / 4.8
	_sy = clampf(stats.freeboard_m * 0.62 / (ShipModel.DECK_Y - ShipModel.WATER_Y), 0.7, 3.2)
	_sw = maxf(_sx, 0.85 * _sy)  # sails and masts keep their proportions


func deck_y() -> float:
	return (ShipModel.DECK_Y - ShipModel.WATER_Y) * _sy


func hull_half_width() -> float:
	return 2.0 * _sx


func _build_hull() -> void:
	var src_mat: ShaderMaterial = (_parts["hull"] as Mesh).surface_get_material(0) as ShaderMaterial
	hull_material = src_mat.duplicate() as ShaderMaterial
	_model = Node3D.new()
	_model.name = "Model"
	_model.rotation.y = PI
	_model.scale = Vector3(_sx, _sy, _sz)
	_model.position.y = -ShipModel.WATER_Y * _sy
	root.add_child(_model)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _parts["hull"] as Mesh
	hull.material_override = hull_material
	_model.add_child(hull)
	# a ring of surf round the waterline
	var ring := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(stats.beam_m * 1.7, stats.length_m * 1.25)
	rq.orientation = PlaneMesh.FACE_Y
	ring.mesh = rq
	var rm := ShaderMaterial.new()
	rm.shader = preload("res://shaders/foam_ring.gdshader")
	ring.material_override = rm
	ring.position = Vector3(0, 0.12, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	# stern lantern
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	lamp.mesh = sm
	var lm: ShaderMaterial = Kenney.flat(Color(1.0, 0.75, 0.3), 0.35)
	lamp.material_override = lm
	lamp.position = Vector3(0, 4.7 * _sy - ShipModel.WATER_Y * _sy, stats.length_m * 0.5 - 0.3)
	root.add_child(lamp)


func _sail_material(src: Mesh, size: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SAIL_SHADER
	var tex: Texture2D = (src.surface_get_material(0) as BaseMaterial3D).albedo_texture
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("sail_size", Vector2(size.x, size.y))
	m.set_shader_parameter("bulge_depth", 1.0)
	m.set_shader_parameter("time_offset", randf() * 10.0)
	sail_materials.append(m)
	return m


func _quad_mesh(a: Vector3, b: Vector3, c: Vector3, d: Vector3, nu: int = 10, nv: int = 10) -> ArrayMesh:
	# Bilinear patch with corners a (u0v0), b (u1v0), c (u0v1), d (u1v1).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv:
		for i in nu:
			var uv := [Vector2(i, j), Vector2(i + 1, j), Vector2(i, j + 1), Vector2(i + 1, j + 1)]
			var pts: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for q: Vector2 in uv:
				var u: float = q.x / nu
				var v: float = q.y / nv
				pts.append(a.lerp(b, u).lerp(c.lerp(d, u), v))
				uvs.append(Vector2(u, v))
			for tri in [[0, 1, 2], [1, 3, 2]]:
				for k: int in tri:
					st.set_uv(uvs[k])
					st.add_vertex(pts[k])
	st.generate_normals()
	return st.commit()


## The list of masts for this class, bow first: the model's own plus a third mast borrowed from the Kenney mast piece,
## set between the two, when the class carries three.
func _mast_defs() -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for m: Dictionary in _parts["masts"]:
		defs.append(m)
	# each extra mast goes into the widest gap between two masts, so a four-master spaces them evenly
	while stats.mast_count > defs.size() and defs.size() >= 2:
		var at: int = 1
		for i in range(1, defs.size()):
			if absf(float(defs[i - 1]["z"]) - float(defs[i]["z"])) > absf(float(defs[at - 1]["z"]) - float(defs[at]["z"])):
				at = i
		var extra: Dictionary = ShipModel.mast_piece().duplicate()
		extra["z"] = (float(defs[at - 1]["z"]) + float(defs[at]["z"])) * 0.5
		extra["extra"] = true
		defs.insert(at, extra)
	while defs.size() > stats.mast_count and defs.size() > 1:
		defs.pop_back()
	return defs


func _build_rig() -> void:
	var defs: Array[Dictionary] = _mast_defs()
	var wy: float = -ShipModel.WATER_Y * _sy
	var n: int = defs.size()
	# a jack on the bowsprit first, then a pennant per mast bow to stern: the last flag is the aftmost mast's
	_add_flag(root, Vector3(0, 5.5 * _sy + wy, -float((_parts["ensign"] as Vector3).z) * _sz), 0.7, false)
	for m in n:
		var d: Dictionary = defs[m]
		var group := Node3D.new()
		group.name = "Mast%d" % m
		group.position = Vector3(0, wy, -float(d["z"]) * _sz)
		root.add_child(group)
		mast_groups.append(group)
		var shrink: float = 0.85 if d.has("extra") else 1.0
		if d["mesh"] != null:
			var pole := MeshInstance3D.new()
			pole.mesh = d["mesh"] as Mesh
			pole.material_override = hull_material
			pole.rotation.y = PI
			pole.scale = Vector3(_sw, _sy, _sw) * shrink
			pole.position.y = float(d.get("pole_y", 0.0)) * _sy * shrink
			group.add_child(pole)
		var rig := Node3D.new()
		rig.name = "Rig"
		group.add_child(rig)
		_rig_yaw.append(0.0)
		var holder := Node3D.new()
		holder.rotation.y = PI
		holder.scale = Vector3(_sw, _sy, _sw) * shrink
		holder.position = Vector3(0, ((d["sail_pos"] as Vector3).y + float(d.get("pole_y", 0.0))) * _sy * shrink, 0)
		rig.add_child(holder)
		var sail := MeshInstance3D.new()
		sail.mesh = d["sail"] as Mesh
		var mat: ShaderMaterial = _sail_material(d["sail"] as Mesh, d["sail_size"] as Vector3)
		sail.material_override = mat
		holder.add_child(sail)
		_tiers.append({"node": sail, "yard": null, "material": mat, "rig": rig, "tier": mini(m, 2), "mast": m, "square": stats.square_rig})
		_add_flag(group, Vector3(0, (float(d["top_y"]) + float(d.get("pole_y", 0.0))) * _sy * shrink, 0), 1.0, m == n - 1)


func _add_flag(parent: Node3D, at: Vector3, size: float, ensign: bool) -> void:
	var flag := MeshInstance3D.new()
	var w: float = 1.7 * size * _sw
	var h: float = 1.0 * size * _sw
	flag.mesh = _quad_mesh(Vector3(0, 0, 0), Vector3(w, 0, 0), Vector3(0, h, 0), Vector3(w, h * 0.9, 0), 8, 4)
	var fmat := ShaderMaterial.new()
	fmat.shader = FLAG_SHADER
	flag_materials.append(fmat)
	fmat.set_shader_parameter("skull", 1.0 if ensign else 0.0)
	fmat.set_shader_parameter("base_color", Vector3(0.05, 0.05, 0.06) if ensign else Vector3(0.85, 0.15, 0.12))
	flag.material_override = fmat
	flag.position = at
	parent.add_child(flag)


## Real cannons along both rails: up to six a side stand on the waist deck, muzzles out.
func _build_guns() -> void:
	var n: int = mini(stats.guns_per_side, 6)
	if n <= 0:
		return
	var cmat: Mesh = Kenney.mesh("pirate", "cannon")
	var y: float = deck_y()
	for side in 2:
		for g in n:
			var frac: float = 0.5 if n == 1 else g / float(n - 1)
			var z: float = lerpf(-0.12, 0.2, frac) * stats.length_m
			var c := MeshInstance3D.new()
			c.mesh = cmat
			c.scale = Vector3.ONE * clampf(stats.beam_m / 7.0, 0.55, 1.5)
			var sgn: float = 1.0 if side == 1 else -1.0
			c.position = Vector3(sgn * (hull_half_width() * 0.62), y, z)
			c.rotation_degrees.y = 90.0 * sgn
			c.name = "Gun"
			root.add_child(c)


func _foam_particles(amount: int, life: float, size: float, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2.0, 0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.85))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = true
	plane.material = mat
	p.mesh = plane
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var alpha := Gradient.new()
	alpha.set_color(0, Color(1, 1, 1, 1))
	alpha.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = alpha
	return p


func _build_wake() -> void:
	_wake = _foam_particles(90, 7.0, stats.beam_m * 1.1, 0.4)
	_wake.position = Vector3(0, 0.15, stats.length_m * 0.42)
	root.add_child(_wake)
	_spray_l = _foam_particles(26, 1.6, stats.beam_m * 0.45, 1.5)
	_spray_l.position = Vector3(-stats.beam_m * 0.3, 0.2, -stats.length_m * 0.38)
	root.add_child(_spray_l)
	_spray_r = _foam_particles(26, 1.6, stats.beam_m * 0.45, 1.5)
	_spray_r.position = Vector3(stats.beam_m * 0.3, 0.2, -stats.length_m * 0.38)
	root.add_child(_spray_r)


func set_mast_visible(index: int, vis: bool) -> void:
	if index < mast_groups.size():
		mast_groups[index].visible = vis


## The captain and crew on deck (DeckCrew): every ship carries them; other ships only near the camera.
func _build_crew() -> void:
	deck_crew = DeckCrew.new()
	deck_crew.setup(ship, deck_y(), hull_half_width())
	ship.add_child(deck_crew)


## Per-frame: sail trim, billow, tears, wake strength.
func update(delta: float) -> void:
	_time += delta
	var wind: WindModel = ship.wind
	if wind == null or ship.damage == null:
		return
	var fwd := Vector3(0, 0, -1)
	var w_local: Vector3 = fwd  # sailing ignores the wind: the sails always fill from astern
	var level: float = SailModel.LEVELS[clampi(ship.sail_level, 0, 3)]
	var factor: float = 1.0
	var wind_ratio: float = 1.0
	var billow: float = clampf(factor * 1.1, 0.0, 1.0) * clampf(wind_ratio, 0.3, 1.0) * clampf(level * 1.4, 0.0, 1.0)
	var luff: float = 1.0 - clampf(factor * 3.0, 0.0, 1.0)
	for t: Dictionary in _tiers:
		var mast: int = t["mast"]
		var node: MeshInstance3D = t["node"]
		var tier: int = t["tier"]
		var mat: ShaderMaterial = t["material"]
		var show: bool = not ship.damage.mast_down[mast] and level > 0.0
		show = show and (tier == 0 or (tier == 1 and level >= 0.5) or (tier == 2 and level >= 0.99))
		node.visible = show
		mat.set_shader_parameter("billow", billow * (0.8 if tier == 2 else 1.0))
		mat.set_shader_parameter("flutter", luff * 0.8)
		mat.set_shader_parameter("damage", 1.0 - clampf(ship.damage.sail_hp[mast] / ship.damage.sail_max, 0.0, 1.0))
	# Trim: square yards brace toward the bisector of heading and wind; booms swing downwind.
	for m in mast_groups.size():
		var rig: Node3D = mast_groups[m].get_node("Rig")
		var target: float = 0.0
		if stats.square_rig:
			var n: Vector3 = w_local + fwd
			if n.length() > 0.25:
				n = n.normalized()
				target = clampf(atan2(-n.x, -n.z), deg_to_rad(-55.0), deg_to_rad(55.0))
		else:
			target = 0.0
		_rig_yaw[m] = lerp_angle(_rig_yaw[m], target, 1.0 - exp(-1.2 * delta))
		rig.rotation.y = _rig_yaw[m]
	# Wake
	var speed: float = absf(ship.speed_forward_ms)
	var wet: bool = ship.submerged_fraction > 0.3 and not ship.damage.sunk
	_wake.emitting = wet and speed > 1.0
	_wake.amount = maxi(int(40 + speed * 6.0), 10) if _wake.amount != 0 else 90
	_spray_l.emitting = wet and speed > 2.5
	_spray_r.emitting = wet and speed > 2.5
