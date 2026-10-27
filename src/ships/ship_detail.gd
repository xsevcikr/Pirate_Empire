class_name ShipDetail
extends RefCounted
## The small things that make a deck read as a deck in the reference pictures: raised rails with balusters,
## cannons on wooden carriages and wheels, a helm, barrels and crates, a gilded stern gallery with windows,
## lanterns and a carved figurehead. Repeated parts are MultiMeshes so a ship stays a handful of draw calls.

const BALUSTER_GAP_M: float = 0.8
const RAIL_H_M: float = 0.95


static func build(root: Node3D, stats: ShipStats) -> void:
	var wood := _std(Color(0.34, 0.2, 0.1), 0.85)
	var dark := _std(Color(0.2, 0.12, 0.06), 0.9)
	var gold := _std(Color(0.86, 0.66, 0.2), 0.35, 0.8)
	_rails(root, stats, wood)
	_gun_carriages(root, stats, dark)
	_helm(root, stats, wood, gold)
	_deck_props(root, stats, wood, dark)
	if stats.length_m > 30.0:
		_stern_gallery(root, stats, dark, gold)
	_figurehead(root, stats, gold, wood)


static func _std(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _multi(root: Node3D, mesh: Mesh, mat: Material, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	root.add_child(mi)


# ---- rails -------------------------------------------------------------------------------------------------

static func _rails(root: Node3D, stats: ShipStats, wood: Material) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.06
	post.height = RAIL_H_M
	post.radial_segments = 6
	var cap := BoxMesh.new()
	cap.size = Vector3(0.12, 0.1, BALUSTER_GAP_M * 1.02)
	var posts: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var count: int = int(stats.length_m * 0.74 / BALUSTER_GAP_M)
	for i in count + 1:
		var t: float = 0.14 + 0.74 * float(i) / float(count)
		var z: float = lerpf(-0.5, 0.5, t) * stats.length_m
		var t2: float = 0.14 + 0.74 * float(i + 1) / float(count)
		var w: float = ShipVisuals.half_width(stats, t) * 0.965
		var y: float = ShipVisuals.top_height(stats, t)
		var w2: float = ShipVisuals.half_width(stats, t2) * 0.965
		var y2: float = ShipVisuals.top_height(stats, t2)
		var z2: float = lerpf(-0.5, 0.5, t2) * stats.length_m
		for side in [-1.0, 1.0]:
			posts.append(Transform3D(Basis(), Vector3(side * w, y + RAIL_H_M * 0.5 - 0.05, z)))
			if i < count:
				var a := Vector3(side * w, y + RAIL_H_M, z)
				var b := Vector3(side * w2, y2 + RAIL_H_M, z2)
				var basis := Basis.looking_at((b - a).normalized(), Vector3.UP)
				caps.append(Transform3D(basis.scaled(Vector3(1, 1, a.distance_to(b) / BALUSTER_GAP_M)), (a + b) * 0.5))
	_multi(root, post, wood, posts)
	_multi(root, cap, wood, caps)


# ---- cannons on carriages ----------------------------------------------------------------------------------

static func _gun_carriages(root: Node3D, stats: ShipStats, dark: Material) -> void:
	var carriage := BoxMesh.new()
	carriage.size = Vector3(0.95, 0.32, 1.25)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.19
	wheel.bottom_radius = 0.19
	wheel.height = 0.1
	wheel.radial_segments = 10
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.1
	barrel.bottom_radius = 0.17
	barrel.height = 1.35
	barrel.radial_segments = 10
	var iron := _std(Color(0.06, 0.06, 0.07), 0.45, 0.7)
	var cars: Array[Transform3D] = []
	var wheels: Array[Transform3D] = []
	var barrels: Array[Transform3D] = []
	var n: int = stats.guns_per_side
	for side in 2:
		var sgn: float = 1.0 if side == 1 else -1.0
		for g in n:
			var z: float = lerpf(-0.3, 0.3, 0.5 if n == 1 else g / float(n - 1)) * stats.length_m
			var t: float = z / stats.length_m + 0.5
			var x: float = ShipVisuals.half_width(stats, t) * 0.8 * sgn
			var deck_y: float = ShipVisuals.top_height(stats, t) * 0.88
			cars.append(Transform3D(Basis(), Vector3(x, deck_y + 0.36, z)))
			for wz in [-0.45, 0.45]:
				for wx in [-0.5, 0.5]:
					wheels.append(Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(x + wx, deck_y + 0.19, z + wz)))
			barrels.append(Transform3D(Basis(Vector3(0, 0, 1), -sgn * PI / 2.0 + 0.04 * sgn), Vector3(x + sgn * 0.5, deck_y + 0.78, z)))
	_multi(root, carriage, dark, cars)
	_multi(root, wheel, dark, wheels)
	_multi(root, barrel, iron, barrels)


# ---- helm, props -------------------------------------------------------------------------------------------

static func _helm(root: Node3D, stats: ShipStats, wood: Material, gold: Material) -> void:
	var t: float = 0.86
	var z: float = lerpf(-0.5, 0.5, t) * stats.length_m
	var base_y: float = ShipVisuals.top_height(stats, t) * 0.88
	var helm := Node3D.new()
	helm.position = Vector3(0, base_y, z)
	root.add_child(helm)
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.12
	pm.bottom_radius = 0.16
	pm.height = 1.0
	post.mesh = pm
	post.material_override = wood
	post.position = Vector3(0, 0.5, 0)
	helm.add_child(post)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.6
	tm.rings = 18
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = wood
	ring.rotation_degrees = Vector3(0, 0, 90)
	ring.position = Vector3(0, 1.15, 0)
	helm.add_child(ring)
	var spoke := BoxMesh.new()
	spoke.size = Vector3(0.06, 0.06, 1.5)
	for k in 4:
		var sp := MeshInstance3D.new()
		sp.mesh = spoke
		sp.material_override = wood
		sp.rotation = Vector3(TAU * float(k) / 8.0, 0, 0)
		sp.position = Vector3(0, 1.15, 0)
		helm.add_child(sp)
	var hub := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.14
	hm.height = 0.28
	hub.mesh = hm
	hub.material_override = gold
	hub.position = Vector3(0, 1.15, 0)
	helm.add_child(hub)


static func _deck_props(root: Node3D, stats: ShipStats, wood: Material, dark: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stats.length_m * 100.0)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.34
	barrel.bottom_radius = 0.34
	barrel.height = 0.8
	barrel.radial_segments = 10
	var crate := BoxMesh.new()
	crate.size = Vector3(0.7, 0.6, 0.7)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.12
	coil.outer_radius = 0.34
	coil.rings = 14
	coil.ring_segments = 6
	var rope := _std(Color(0.62, 0.5, 0.3), 0.95)
	var barrels: Array[Transform3D] = []
	var crates: Array[Transform3D] = []
	var coils: Array[Transform3D] = []
	var n: int = clampi(int(stats.length_m / 6.0), 3, 10)
	for i in n:
		var t: float = rng.randf_range(0.2, 0.8)
		var z: float = lerpf(-0.5, 0.5, t) * stats.length_m
		var deck_y: float = ShipVisuals.top_height(stats, t) * 0.88
		var half: float = ShipVisuals.half_width(stats, t) * 0.4
		var x: float = rng.randf_range(-half, half)
		match i % 3:
			0:
				barrels.append(Transform3D(Basis(), Vector3(x, deck_y + 0.4, z)))
			1:
				crates.append(Transform3D(Basis(Vector3.UP, rng.randf() * 3.0), Vector3(x, deck_y + 0.3, z)))
			2:
				coils.append(Transform3D(Basis(), Vector3(x, deck_y + 0.12, z)))
	_multi(root, barrel, wood, barrels)
	_multi(root, crate, dark, crates)
	_multi(root, coil, rope, coils)


# ---- stern gallery and figurehead -------------------------------------------------------------------------

static func _stern_gallery(root: Node3D, stats: ShipStats, dark: Material, gold: Material) -> void:
	var F: float = stats.freeboard_m
	var z: float = stats.length_m * 0.5 + 0.06
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1.0, 0.82, 0.45)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.7, 0.3)
	glass.emission_energy_multiplier = 1.4
	var win := BoxMesh.new()
	win.size = Vector3(0.7, 0.9, 0.1)
	var frame := BoxMesh.new()
	frame.size = Vector3(0.9, 1.1, 0.08)
	var panes: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var cols: int = clampi(int(stats.beam_m * 0.7 / 1.3), 3, 8)
	for r in 2:
		for c in cols:
			var x: float = (c - (cols - 1) * 0.5) * 1.3
			var y: float = F * 1.05 + float(r) * 1.4
			panes.append(Transform3D(Basis(), Vector3(x, y, z + 0.03)))
			frames.append(Transform3D(Basis(), Vector3(x, y, z)))
	_multi(root, frame, gold, frames)
	_multi(root, win, glass, panes)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(stats.beam_m * 0.9, 0.22, 0.14)
	band.mesh = bm
	band.material_override = gold
	band.position = Vector3(0, F * 1.05 + 2.55, z)
	root.add_child(band)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.75, 0.3)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.65, 0.2)
	lamp_mat.emission_energy_multiplier = 3.0
	for sx in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.24
		lm.height = 0.5
		lamp.mesh = lm
		lamp.material_override = lamp_mat
		lamp.position = Vector3(sx * stats.beam_m * 0.42, F * 1.05 + 2.9, z + 0.2)
		root.add_child(lamp)


static func _figurehead(root: Node3D, stats: ShipStats, gold: Material, wood: Material) -> void:
	var F: float = stats.freeboard_m
	var z: float = -stats.length_m * 0.5 - 0.2
	var fig := Node3D.new()
	fig.position = Vector3(0, F * 0.95, z)
	root.add_child(fig)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.34
	cm.height = 1.5
	body.mesh = cm
	body.material_override = gold
	body.rotation_degrees = Vector3(-62, 0, 0)
	body.position = Vector3(0, -0.2, -0.5)
	fig.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	head.mesh = sm
	head.material_override = gold
	head.position = Vector3(0, 0.15, -1.15)
	fig.add_child(head)
	var scroll := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.3
	scroll.mesh = tm
	scroll.material_override = gold
	scroll.rotation_degrees = Vector3(0, 90, 0)
	scroll.position = Vector3(0, -0.45, -0.1)
	fig.add_child(scroll)
