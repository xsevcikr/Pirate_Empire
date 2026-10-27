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
var _hands: Array[DeckFighterView] = []
var _hands_root: Node3D
const MAX_VISIBLE_HANDS: int = 9


static func half_width(stats: ShipStats, t: float) -> float:
	var b: float = stats.beam_m * 0.5
	if t < 0.32:
		return b * pow(maxf(t / 0.32, 0.0), 0.65)
	if t > 0.84:
		return b * (1.0 - 0.28 * (t - 0.84) / 0.16)
	return b


static func keel_depth(stats: ShipStats, t: float) -> float:
	return stats.draft_m * (1.0 - 0.7 * pow(1.0 - t, 3.0) - 0.15 * pow(t, 4.0))


static func top_height(stats: ShipStats, t: float) -> float:
	return stats.freeboard_m * (1.0 + 0.35 * pow(absf(2.0 * t - 1.0), 2.4) * (1.0 if t < 0.5 else 0.75))


func build(owner_ship: Ship) -> void:
	ship = owner_ship
	stats = ship.stats
	root = Node3D.new()
	root.name = "Visuals"
	ship.add_child(root)
	_build_hull()
	_build_details()
	ShipDetail.build(root, stats)
	_build_rig()
	_build_wake()


func _build_hull() -> void:
	var sections: int = 28
	var profile: int = 7
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var F: float = stats.freeboard_m
	for i in sections + 1:
		var t: float = i / float(sections)
		var z: float = lerpf(-0.5, 0.5, t) * stats.length_m
		var w: float = half_width(stats, t)
		var d: float = keel_depth(stats, t)
		var top: float = top_height(stats, t)
		for side in 2:
			for k in profile + 1:
				var u: float = k / float(profile)
				var x: float = w * sin(u * PI * 0.5) * (1.0 - 0.07 * pow(u, 3.0))
				var y: float = -d + (top + d) * pow(u, 1.25)
				var sx: float = x * (1.0 if side == 1 else -1.0)
				verts.append(Vector3(sx, y, z))
				cols.append(_hull_color(y, F))
	var per_side: int = profile + 1
	var per_section: int = per_side * 2
	for i in sections:
		for side in 2:
			for k in profile:
				var a: int = i * per_section + side * per_side + k
				var b: int = a + 1
				var c: int = (i + 1) * per_section + side * per_side + k
				var d2: int = c + 1
				idx.append_array([a, b, c, b, d2, c])
	# Transom (stern wall)
	var base: int = verts.size()
	var t_end: float = 1.0
	var sw: float = half_width(stats, t_end)
	var sd: float = keel_depth(stats, t_end)
	var stop: float = top_height(stats, t_end)
	var zc: float = stats.length_m * 0.5
	verts.append(Vector3(-sw, -sd, zc))
	verts.append(Vector3(sw, -sd, zc))
	verts.append(Vector3(sw * 0.93, stop, zc))
	verts.append(Vector3(-sw * 0.93, stop, zc))
	for v in 4:
		cols.append(Color(0.5, 0.3, 0.16))
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	# Deck
	var deck_y: float = F * 0.78
	var db: int = verts.size()
	for i in sections + 1:
		var t2: float = i / float(sections)
		var z2: float = lerpf(-0.5, 0.5, t2) * stats.length_m
		var w2: float = half_width(stats, t2) * 0.9
		var dy: float = top_height(stats, t2) * 0.88
		verts.append(Vector3(-w2, dy, z2))
		verts.append(Vector3(w2, dy, z2))
		cols.append(Color(0.52, 0.38, 0.22))
		cols.append(Color(0.52, 0.38, 0.22))
	for i in sections:
		var a2: int = db + i * 2
		idx.append_array([a2, a2 + 1, a2 + 2, a2 + 1, a2 + 3, a2 + 2])
	var mesh := _mesh_from(verts, cols, idx)
	var planks := ShaderMaterial.new()
	hull_material = planks
	planks.shader = load("res://shaders/wood.gdshader")
	planks.set_shader_parameter("use_vertex_color", true)
	planks.set_shader_parameter("plank_width", 0.28)
	planks.set_shader_parameter("plank_len", 3.5)
	planks.set_shader_parameter("wear", 0.7)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = planks
	root.add_child(mi)


## Plank-textured wood for castles, masts and spars.
func plank_material(tint: Color, width: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/wood.gdshader")
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("plank_width", width)
	m.set_shader_parameter("plank_len", 2.2)
	m.set_shader_parameter("wear", 0.5)
	return m


func _hull_color(y: float, F: float) -> Color:
	if y < -0.05:
		return Color(0.30, 0.10, 0.06)  # copper-red below the waterline
	if y > F - 1.05 and y < F - 0.35:
		return Color(0.78, 0.58, 0.16)  # gun-row stripe
	return Color(0.36, 0.21, 0.115)


## Builds an ArrayMesh with outward-facing, consistent normals (winding is fixed per triangle).
func _mesh_from(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var fixed := PackedInt32Array()
	var ymid: float = 0.0
	for t in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[t]]
		var b: Vector3 = verts[idx[t + 1]]
		var c: Vector3 = verts[idx[t + 2]]
		var n: Vector3 = (b - a).cross(c - a)
		var centroid: Vector3 = (a + b + c) / 3.0
		var out: Vector3 = Vector3(centroid.x, centroid.y - ymid, 0.0)
		var tt: float = clampf(centroid.z / stats.length_m + 0.5, 0.0, 1.0)
		if absf(centroid.y - top_height(stats, tt) * 0.88) < 0.06 and absf(centroid.x) < half_width(stats, tt) * 0.95:
			out = Vector3.UP  # the deck faces up; hull flanks near the bow keep facing outward
		if absf(centroid.z) > stats.length_m * 0.499:
			out = Vector3(0, 0, signf(centroid.z))
		if n.dot(out) < 0.0:
			fixed.append_array([idx[t], idx[t + 2], idx[t + 1]])
		else:
			fixed.append_array([idx[t], idx[t + 1], idx[t + 2]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in fixed:
		st.set_color(cols[i])
		st.add_vertex(verts[i])
	st.generate_normals()
	return st.commit()


func _build_details() -> void:
	var F: float = stats.freeboard_m
	var port_mat := StandardMaterial3D.new()
	port_mat.albedo_color = Color(0.02, 0.02, 0.02)
	var gun_mat := StandardMaterial3D.new()
	gun_mat.albedo_color = Color(0.05, 0.05, 0.06)
	gun_mat.metallic = 0.7
	gun_mat.roughness = 0.4
	for side in 2:
		for g in stats.guns_per_side:
			var n: int = stats.guns_per_side
			var z: float = lerpf(-0.3, 0.3, 0.5 if n == 1 else g / float(n - 1)) * stats.length_m
			var t: float = z / stats.length_m + 0.5
			var x: float = half_width(stats, t) * (1.0 if side == 1 else -1.0)
			var port := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(0.12, 0.55, 0.62)
			port.mesh = pb
			port.material_override = port_mat
			port.position = Vector3(x * 0.995, F - 0.65, z)
			root.add_child(port)
	# Castles
	var wood: Material = plank_material(Color(1.0, 0.82, 0.62), 0.22)
	var big: bool = stats.length_m > 30.0
	if big:
		var stern := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(stats.beam_m * 0.82, F * 0.55, stats.length_m * 0.24)
		stern.mesh = sb
		stern.material_override = wood
		stern.position = Vector3(0, F * 1.35, stats.length_m * 0.37)
		root.add_child(stern)
		var fore := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(stats.beam_m * 0.6, F * 0.35, stats.length_m * 0.12)
		fore.mesh = fb
		fore.material_override = wood
		fore.position = Vector3(0, F * 1.2, -stats.length_m * 0.36)
		root.add_child(fore)
	# Bowsprit
	var spar := MeshInstance3D.new()
	var spm := CylinderMesh.new()
	spm.top_radius = 0.08
	spm.bottom_radius = 0.16
	spm.height = stats.length_m * 0.3
	spar.mesh = spm
	spar.material_override = wood
	spar.rotation_degrees = Vector3(-72, 0, 0)
	spar.position = Vector3(0, F * 1.25, -stats.length_m * 0.52)
	root.add_child(spar)
	# Stern lantern
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	lamp.mesh = sm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.75, 0.3)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.65, 0.2)
	lm.emission_energy_multiplier = 3.0
	lamp.material_override = lm
	lamp.position = Vector3(0, F * (2.0 if big else 1.5), stats.length_m * 0.5)
	root.add_child(lamp)


func _sail_material(bulge_dir: Vector3, depth: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SAIL_SHADER
	m.set_shader_parameter("bulge_dir", bulge_dir)
	m.set_shader_parameter("bulge_depth", depth)
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


func _build_rig() -> void:
	var L: float = stats.length_m
	var B: float = stats.beam_m
	var F: float = stats.freeboard_m
	var wood: Material = plank_material(Color(0.85, 0.7, 0.55), 0.8)
	var n: int = stats.mast_count
	for m in n:
		var group := Node3D.new()
		var frac: float = 0.5 if n == 1 else m / float(n - 1)
		var mz: float = (lerpf(-0.24, 0.26, frac) if stats.square_rig else lerpf(-0.12, 0.18, frac)) * L
		if n == 1:
			mz = -0.05 * L
		var height: float = (0.98 if m == n - 1 and n == 3 else 1.0) * L * (0.95 if stats.square_rig else 0.85)
		if n == 3 and m == 0:
			height *= 0.9
		if n == 3 and m == 2:
			height *= 0.72
		if n == 2 and m == 0:
			height *= 0.9
		group.position = Vector3(0, F * 0.8, mz)
		root.add_child(group)
		mast_groups.append(group)
		var mast := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.1
		cm.bottom_radius = 0.22 + L * 0.004
		cm.height = height
		mast.mesh = cm
		mast.material_override = wood
		mast.position = Vector3(0, height * 0.5, 0)
		group.add_child(mast)
		# Crow's nest
		if stats.square_rig:
			var nest := MeshInstance3D.new()
			var nm := CylinderMesh.new()
			nm.top_radius = 0.9
			nm.bottom_radius = 0.7
			nm.height = 0.4
			nest.mesh = nm
			nest.material_override = wood
			nest.position = Vector3(0, height * 0.62, 0)
			group.add_child(nest)
		var rig := Node3D.new()
		rig.name = "Rig"
		group.add_child(rig)
		_rig_yaw.append(0.0)
		if stats.square_rig:
			_build_square_sails(rig, m, height, B, wood)
		else:
			_build_fore_and_aft(rig, m, height, L, B, wood)
		# Pennant
		var flag := MeshInstance3D.new()
		var fm := _quad_mesh(Vector3(0, 0, 0), Vector3(2.4, 0, 0), Vector3(0, 0.9, 0), Vector3(2.4, 0.45, 0), 8, 4)
		flag.mesh = fm
		var fmat := ShaderMaterial.new()
		fmat.shader = FLAG_SHADER
		flag_materials.append(fmat)
		fmat.set_shader_parameter("skull", 1.0 if m == n - 1 else 0.0)
		fmat.set_shader_parameter("base_color", Vector3(0.05, 0.05, 0.06) if m == n - 1 else Vector3(0.7, 0.1, 0.1))
		flag.material_override = fmat
		flag.position = Vector3(0, height, 0)
		group.add_child(flag)
	_build_shrouds(wood)


func _build_square_sails(rig: Node3D, mast_index: int, height: float, B: float, wood: Material) -> void:
	var tiers: int = 3
	if stats.length_m < 36.0:
		tiers = 2
	var y: float = height * 0.12
	var widths: Array[float] = [1.5 * B, 1.2 * B, 0.85 * B]
	var heights: Array[float] = [0.28 * height, 0.24 * height, 0.18 * height]
	if mast_index == stats.mast_count - 1 and stats.mast_count == 3:
		widths = [1.1 * B, 0.9 * B, 0.65 * B]
	for t in tiers:
		var w: float = widths[t]
		var h: float = heights[t]
		var yard := MeshInstance3D.new()
		var ym := CylinderMesh.new()
		ym.top_radius = 0.07
		ym.bottom_radius = 0.1
		ym.height = w * 1.04
		yard.mesh = ym
		yard.material_override = wood
		yard.rotation_degrees = Vector3(0, 0, 90)
		yard.position = Vector3(0, y + h, 0)
		rig.add_child(yard)
		var sail := MeshInstance3D.new()
		# top edge slightly wider than the bottom, like a real square sail
		sail.mesh = _quad_mesh(Vector3(-w * 0.46, 0, 0), Vector3(w * 0.46, 0, 0), Vector3(-w * 0.5, h, 0), Vector3(w * 0.5, h, 0), 12, 12)
		sail.material_override = _sail_material(Vector3(0, 0, -1), maxf(1.2, w * 0.16))
		sail.position = Vector3(0, y, 0)
		rig.add_child(sail)
		_tiers.append({"node": sail, "yard": yard, "material": sail.material_override, "rig": rig, "tier": t, "mast": mast_index, "square": true})
		y += h + 0.15 * h


func _build_fore_and_aft(rig: Node3D, mast_index: int, height: float, L: float, B: float, wood: Material) -> void:
	# Gaff mainsail: boom runs aft from the mast, sail is a trapezoid in the centre plane.
	var boom_len: float = L * 0.42
	var sail_h: float = height * 0.78
	var boom_y: float = height * 0.1
	var boom := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.07
	bm.bottom_radius = 0.09
	bm.height = boom_len
	boom.mesh = bm
	boom.material_override = wood
	boom.rotation_degrees = Vector3(90, 0, 0)
	boom.position = Vector3(0, boom_y, boom_len * 0.5)
	rig.add_child(boom)
	var sail := MeshInstance3D.new()
	# corners: tack at mast bottom, clew at boom end, head at mast top, peak aft along the gaff
	sail.mesh = _quad_mesh(Vector3(0, boom_y, 0), Vector3(0, boom_y, boom_len), Vector3(0, boom_y + sail_h, 0), Vector3(0, boom_y + sail_h * 0.95, boom_len * 0.45), 12, 12)
	sail.material_override = _sail_material(Vector3(1, 0, 0), maxf(1.0, boom_len * 0.1))
	rig.add_child(sail)
	_tiers.append({"node": sail, "yard": boom, "material": sail.material_override, "rig": rig, "tier": 0, "mast": mast_index, "square": false})
	if mast_index == 0:
		# Jib from the bowsprit to the mast head
		var jib := MeshInstance3D.new()
		var hx: float = -L * 0.5 + L * 0.02
		jib.mesh = _quad_mesh(Vector3(0, F_JIB, -L * 0.26), Vector3(0, F_JIB + 0.4, hx - L * 0.12), Vector3(0, height * 0.88, -0.1), Vector3(0, height * 0.88, -0.1), 10, 10)
		jib.material_override = _sail_material(Vector3(1, 0, 0), 1.2)
		jib.position = Vector3(0, 0, 0)
		rig.add_child(jib)
		_tiers.append({"node": jib, "yard": null, "material": jib.material_override, "rig": rig, "tier": 1, "mast": mast_index, "square": false})


const F_JIB: float = 2.2


func _build_shrouds(wood: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var F: float = stats.freeboard_m
	for m in mast_groups.size():
		var base: Vector3 = mast_groups[m].position
		var top: Vector3 = base + Vector3(0, stats.length_m * 0.55, 0)
		for side in [-1.0, 1.0]:
			for k in 4:
				var off: float = (k - 1.5) * 0.9
				st.add_vertex(Vector3(side * stats.beam_m * 0.42, F * 0.9, base.z + off))
				st.add_vertex(top + Vector3(0, 0, off * 0.05))
		# ratlines: rope rungs between neighbouring shrouds, climbing the lower 60% of the mast
		for side2 in [-1.0, 1.0]:
			for r in range(1, 12):
				var f: float = float(r) / 12.0 * 0.6
				for k2 in 3:
					var o1: float = (k2 - 1.5) * 0.9
					var o2: float = (k2 + 1 - 1.5) * 0.9
					var p1: Vector3 = Vector3(side2 * stats.beam_m * 0.42, F * 0.9, base.z + o1).lerp(top + Vector3(0, 0, o1 * 0.05), f)
					var p2: Vector3 = Vector3(side2 * stats.beam_m * 0.42, F * 0.9, base.z + o2).lerp(top + Vector3(0, 0, o2 * 0.05), f)
					st.add_vertex(p1)
					st.add_vertex(p2)
		st.add_vertex(top)
		st.add_vertex(Vector3(0, F * 1.2, -stats.length_m * 0.5))
		st.add_vertex(top)
		st.add_vertex(Vector3(0, F * 1.2, stats.length_m * 0.48))
	var lines := MeshInstance3D.new()
	lines.mesh = st.commit()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.1, 0.08, 0.06)
	lines.material_override = lm
	root.add_child(lines)


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


## Sailors on deck: figures stand at fixed stations along the deck, one per two hands up to a cap. Only the
## player's ship carries them, to keep eight-ship battles inside the frame budget.
func _sync_hands() -> void:
	if ship.ai != null or ship.crew == null:
		return
	var want: int = mini(ceili(float(ship.crew.count) / 2.0), MAX_VISIBLE_HANDS)
	if want == _hands.size():
		return
	if _hands_root == null:
		_hands_root = Node3D.new()
		_hands_root.name = "Hands"
		ship.add_child(_hands_root)
	while _hands.size() > want:
		var gone: DeckFighterView = _hands.pop_back()
		gone.queue_free()
	var types: Array[String] = ["seasoned", "green", "swordsman", "gunner", "green", "seasoned", "bosun", "green", "musketeer"]
	while _hands.size() < want:
		var i: int = _hands.size()
		var f: FighterState = FighterState.make_crew(types[i % types.size()])
		f.id = 100 + i * 3
		f.melee = "cutlass"
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var z: float = lerpf(-0.22, 0.4, float(i) / float(maxi(MAX_VISIBLE_HANDS - 1, 1))) * stats.length_m
		var t: float = z / stats.length_m + 0.5
		f.pos = Vector2(side * (half_width(stats, t) * 0.55 + 0.1 * float(i % 3)), z)
		f.dir = Vector2(side * 0.3, -1.0 if i % 3 == 0 else 0.4).normalized()
		var v := DeckFighterView.new()
		v.fighter = f
		v.show_label = false
		v.scale = Vector3.ONE * clampf(stats.beam_m / 7.0, 0.8, 1.0)
		var holder := Node3D.new()
		holder.position = Vector3(0, stats.freeboard_m * 0.78 * 0.88, 0)
		holder.add_child(v)
		_hands_root.add_child(holder)
		_hands.append(v)


## Per-frame: sail trim, billow, tears, wake strength.
func update(delta: float) -> void:
	_time += delta
	_sync_hands()
	var wind: WindModel = ship.wind
	if wind == null or ship.damage == null:
		return
	var inv: Basis = ship.global_transform.basis.inverse()
	var w_local: Vector3 = inv * Vector3(wind.direction.x, 0.0, wind.direction.y)
	w_local.y = 0.0
	var fwd := Vector3(0, 0, -1)
	var level: float = SailModel.LEVELS[clampi(ship.sail_level, 0, 3)]
	var factor: float = SailModel.speed_factor(ship.angle_off_wind, stats.square_rig)
	var wind_ratio: float = clampf(wind.speed_ms() / 10.29, 0.15, 1.4)
	var billow: float = clampf(factor * 1.1, 0.0, 1.0) * clampf(wind_ratio, 0.3, 1.0) * clampf(level * 1.4, 0.0, 1.0)
	var luff: float = 1.0 - clampf(factor * 3.0, 0.0, 1.0)
	var side_sign: float = signf(-w_local.x) if absf(w_local.x) > 0.01 else 1.0  # +1: wind from starboard
	for t: Dictionary in _tiers:
		var mast: int = t["mast"]
		var node: MeshInstance3D = t["node"]
		var tier: int = t["tier"]
		var mat: ShaderMaterial = t["material"]
		var show: bool = not ship.damage.mast_down[mast]
		if t["square"]:
			show = show and level > 0.0 and (tier == 0 or (tier == 1 and level >= 0.5) or (tier == 2 and level >= 0.99))
			if level < 0.99 and tier == 2:
				show = false
		else:
			show = show and level > 0.0
		node.visible = show
		if t["yard"]:
			(t["yard"] as Node3D).visible = not ship.damage.mast_down[mast]
		mat.set_shader_parameter("billow", billow * (0.8 if tier == 2 else 1.0))
		mat.set_shader_parameter("flutter", luff * 0.8)
		mat.set_shader_parameter("damage", 1.0 - clampf(ship.damage.sail_hp[mast] / ship.damage.sail_max, 0.0, 1.0))
		if not t["square"]:
			mat.set_shader_parameter("bulge_dir", Vector3(-side_sign, 0, 0))
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
			target = -side_sign * deg_to_rad(clampf(ship.angle_off_wind * 0.45 - 8.0, 0.0, 70.0))
		_rig_yaw[m] = lerp_angle(_rig_yaw[m], target, 1.0 - exp(-1.2 * delta))
		rig.rotation.y = _rig_yaw[m]
	# Wake
	var speed: float = absf(ship.speed_forward_ms)
	var wet: bool = ship.submerged_fraction > 0.3 and not ship.damage.sunk
	_wake.emitting = wet and speed > 1.0
	_wake.amount = maxi(int(40 + speed * 6.0), 10) if _wake.amount != 0 else 90
	_spray_l.emitting = wet and speed > 2.5
	_spray_r.emitting = wet and speed > 2.5
