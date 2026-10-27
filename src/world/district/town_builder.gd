class_name TownBuilder
extends RefCounted
## The pieces of a late-medieval harbour town, built from primitives and tuned to read as old: timber-framed houses on
## stone footings with the upper floor jettied out over the street, steep tiled roofs with chimneys, shuttered
## windows, hanging signs, market stalls with striped awnings and heaps of goods, a well, a church with a spire, a
## castle keep with crenellated walls, round towers and banners, cobbled streets and barrels and carts.

const PLASTER: Array[Color] = [Color(0.82, 0.76, 0.62), Color(0.78, 0.7, 0.56), Color(0.86, 0.82, 0.72), Color(0.7, 0.62, 0.5), Color(0.8, 0.72, 0.6)]
const TIMBER: Color = Color(0.2, 0.12, 0.07)
const STONE: Color = Color(0.52, 0.5, 0.47)
const STRIPES: Array[Color] = [Color(0.75, 0.15, 0.12), Color(0.9, 0.86, 0.75), Color(0.15, 0.35, 0.6), Color(0.85, 0.65, 0.15), Color(0.2, 0.5, 0.25)]
const FLOOR_H_M: float = 3.0
const JETTY_M: float = 0.55


static var _mats: Dictionary = {}
static var _boxes: Dictionary = {}


## Materials and box meshes are shared by colour and size: a harbour is hundreds of small timbers and streaming it
## in must not allocate a resource for each.
static func mat(c: Color, rough: float = 0.92) -> StandardMaterial3D:
	var key: String = "%s/%.2f" % [c.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key] as StandardMaterial3D


static func box(parent: Node3D, size: Vector3, at: Vector3, c: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key := Vector3(snappedf(size.x, 0.01), snappedf(size.y, 0.01), snappedf(size.z, 0.01))
	if not _boxes.has(key):
		_boxes[key] = DeckArt.box(size)
	return DeckArt.add_mesh(parent, _boxes[key] as Mesh, mat(c), at, rot_deg)


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, c: Color, segs: int = 12) -> MeshInstance3D:
	return DeckArt.add_mesh(parent, DeckArt.cyl(r_top, r_bot, h, segs), mat(c), at)


## A timber-framed house. `w` is across the street, `d` along it. Faces +z (the street side after rotating).
static func house(parent: Node3D, at: Vector3, yaw_deg: float, w: float, d: float, floors: int, roof: Color, rng: RandomNumberGenerator) -> Node3D:
	var h := Node3D.new()
	h.name = "House"
	h.position = at
	h.rotation_degrees.y = yaw_deg
	parent.add_child(h)
	var plaster: Color = PLASTER[rng.randi_range(0, PLASTER.size() - 1)]
	var stone_h: float = 0.9
	box(h, Vector3(w + 0.2, stone_h, d + 0.2), Vector3(0, stone_h * 0.5, 0), STONE.darkened(rng.randf() * 0.2))
	var y: float = stone_h
	for f in floors:
		var jet: float = JETTY_M * float(f)
		var fw: float = w + jet * 0.5
		var fd: float = d + jet
		box(h, Vector3(fw, FLOOR_H_M, fd), Vector3(0, y + FLOOR_H_M * 0.5, jet * 0.5), plaster)
		_frame(h, fw, fd, y, jet * 0.5, rng)
		_windows(h, fw, fd, y, jet * 0.5, f, rng)
		if f > 0:  # the jetty's underside beams
			for i in 4:
				box(h, Vector3(fw + 0.1, 0.18, 0.22), Vector3(0, y - 0.05, d * 0.5 + jet - 0.15 - i * 0.0), TIMBER)
				break
		y += FLOOR_H_M
	_roof(h, w + JETTY_M * float(floors - 1) * 0.5, d + JETTY_M * float(floors - 1), y, JETTY_M * float(floors - 1) * 0.5, roof, rng)
	# door with a stone arch and a step
	var top_z: float = d * 0.5 + 0.12
	box(h, Vector3(1.3, 2.2, 0.18), Vector3(-w * 0.25, stone_h + 1.1, top_z), Color(0.25, 0.15, 0.08))
	box(h, Vector3(1.7, 0.25, 0.3), Vector3(-w * 0.25, stone_h + 2.3, top_z), STONE)
	box(h, Vector3(0.12, 2.4, 0.3), Vector3(-w * 0.25 - 0.8, stone_h + 1.2, top_z), STONE)
	box(h, Vector3(0.12, 2.4, 0.3), Vector3(-w * 0.25 + 0.8, stone_h + 1.2, top_z), STONE)
	box(h, Vector3(1.8, 0.2, 0.7), Vector3(-w * 0.25, 0.1, top_z + 0.35), STONE.darkened(0.1))
	# a hanging sign on an iron bracket
	if rng.randf() < 0.7:
		var sx: float = w * 0.5 + 0.05
		box(h, Vector3(0.9, 0.06, 0.06), Vector3(sx + 0.4, stone_h + 2.6, top_z - 0.3), Color(0.1, 0.1, 0.12))
		box(h, Vector3(0.7, 0.55, 0.05), Vector3(sx + 0.55, stone_h + 2.25, top_z - 0.3), STRIPES[rng.randi_range(0, STRIPES.size() - 1)])
	return h


static func _frame(h: Node3D, fw: float, fd: float, y: float, zc: float, rng: RandomNumberGenerator) -> void:
	var z: float = zc + fd * 0.5 + 0.02
	box(h, Vector3(fw + 0.1, 0.2, 0.14), Vector3(0, y + 0.1, z), TIMBER)
	box(h, Vector3(fw + 0.1, 0.2, 0.14), Vector3(0, y + FLOOR_H_M - 0.1, z), TIMBER)
	var n: int = maxi(int(fw / 1.6), 2)
	for i in n + 1:
		var x: float = -fw * 0.5 + fw * float(i) / float(n)
		box(h, Vector3(0.2, FLOOR_H_M, 0.14), Vector3(x, y + FLOOR_H_M * 0.5, z), TIMBER)
		if i < n and rng.randf() < 0.6:
			var cx: float = x + fw / float(n) * 0.5
			box(h, Vector3(0.12, FLOOR_H_M * 1.15, 0.12), Vector3(cx, y + FLOOR_H_M * 0.5, z + 0.01), TIMBER, Vector3(0, 0, 38.0 * (1.0 if i % 2 == 0 else -1.0)))
	# the same on the gable end
	var xs: float = fw * 0.5 + 0.02
	var m: int = maxi(int(fd / 1.8), 2)
	for i in m + 1:
		var zz: float = zc - fd * 0.5 + fd * float(i) / float(m)
		box(h, Vector3(0.14, FLOOR_H_M, 0.2), Vector3(xs, y + FLOOR_H_M * 0.5, zz), TIMBER)
		box(h, Vector3(0.14, FLOOR_H_M, 0.2), Vector3(-xs, y + FLOOR_H_M * 0.5, zz), TIMBER)
	box(h, Vector3(0.14, 0.2, fd + 0.1), Vector3(xs, y + 0.1, zc), TIMBER)
	box(h, Vector3(0.14, 0.2, fd + 0.1), Vector3(-xs, y + 0.1, zc), TIMBER)


static func _windows(h: Node3D, fw: float, fd: float, y: float, zc: float, floor_i: int, rng: RandomNumberGenerator) -> void:
	var z: float = zc + fd * 0.5 + 0.1
	var n: int = maxi(int(fw / 2.6), 1)
	var glass: StandardMaterial3D = mat(Color(0.18, 0.24, 0.3), 0.2)
	glass.metallic = 0.4
	for i in n:
		var x: float = -fw * 0.5 + fw * (float(i) + 0.5) / float(n)
		if floor_i == 0 and absf(x - (-fw * 0.25)) < 1.3:
			continue
		var wy: float = y + 1.7
		box(h, Vector3(0.9, 1.1, 0.1), Vector3(x, wy, z), TIMBER)
		DeckArt.add_mesh(h, DeckArt.box(Vector3(0.74, 0.94, 0.06)), glass, Vector3(x, wy, z + 0.03))
		box(h, Vector3(0.06, 0.94, 0.08), Vector3(x, wy, z + 0.06), TIMBER)
		box(h, Vector3(0.74, 0.06, 0.08), Vector3(x, wy, z + 0.06), TIMBER)
		var open: bool = rng.randf() < 0.4
		for s in [-1.0, 1.0]:
			var shutter: Color = Color(0.15, 0.32, 0.22) if i % 2 == 0 else Color(0.5, 0.15, 0.12)
			box(h, Vector3(0.4, 1.05, 0.05), Vector3(x + s * (0.65 if open else 0.45), wy, z + (0.2 if open else 0.05)), shutter, Vector3(0, s * (70.0 if open else 0.0), 0))
		if floor_i >= 1 and rng.randf() < 0.55:  # window box with flowers
			box(h, Vector3(0.9, 0.22, 0.25), Vector3(x, wy - 0.7, z + 0.15), Color(0.35, 0.22, 0.12))
			for k in 5:
				DeckArt.add_mesh(h, _ball(0.07), mat([Color(0.85, 0.15, 0.2), Color(0.95, 0.8, 0.2), Color(0.9, 0.9, 0.95), Color(0.3, 0.6, 0.25)][k % 4]), Vector3(x - 0.34 + 0.17 * k, wy - 0.55, z + 0.18))
		if floor_i == 0 and rng.randf() < 0.5:
			DeckArt.add_mesh(h, DeckArt.cyl(0.0, 0.2, 0.45, 8), mat(Color(1.0, 0.8, 0.45), 0.4), Vector3(x + 0.7, wy + 0.1, z + 0.35)).visible = false


static func _ball(r: float) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 3
	return s


## A steep gable roof of tile rows with a ridge, a chimney and a dormer.
static func _roof(h: Node3D, w: float, d: float, y: float, zc: float, color: Color, rng: RandomNumberGenerator) -> void:
	var rise: float = w * 0.62
	var run: float = w * 0.5 + 0.5
	var slope: float = rad_to_deg(atan2(rise, run))
	var length: float = sqrt(rise * rise + run * run)
	var rows: int = int(length / 0.34)
	for side in [-1.0, 1.0]:
		var slab := box(h, Vector3(length + 0.3, 0.12, d + 1.0), Vector3(side * run * 0.5, y + rise * 0.5, zc), color.darkened(0.25), Vector3(0, 0, -side * slope))
		slab.name = "RoofSlab"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var tile := BoxMesh.new()
		tile.size = Vector3(0.36, 0.06, d + 0.95)
		mm.mesh = tile
		mm.instance_count = rows
		for r in rows:
			var t: float = (r + 0.5) / float(rows)
			var p := Vector3(side * run * (1.0 - t), y + rise * t + 0.1, zc)
			var b := Basis.from_euler(Vector3(0, 0, -side * slope * PI / 180.0))
			b = b.rotated(b * Vector3.RIGHT, 0.0)
			mm.set_instance_transform(r, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -side * deg_to_rad(slope) + side * 0.05)), p))
			mm.set_instance_color(r, color.lerp(Color(0.25, 0.1, 0.08), rng.randf() * 0.35).lightened(0.05 * float(r % 2)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var tm := StandardMaterial3D.new()
		tm.vertex_color_use_as_albedo = true
		tm.roughness = 0.8
		mi.material_override = tm
		h.add_child(mi)
	box(h, Vector3(0.3, 0.2, d + 1.1), Vector3(0, y + rise + 0.1, zc), color.darkened(0.35))
	# gable end fill (triangle as a prism)
	var gable := PrismMesh.new()
	gable.size = Vector3(w + 0.1, rise, 0.2)
	for s in [-1.0, 1.0]:
		DeckArt.add_mesh(h, gable, mat(PLASTER[0]), Vector3(0, y + rise * 0.5, zc + s * (d * 0.5 + 0.02)))
	# chimney
	var cx: float = w * 0.28
	box(h, Vector3(0.8, rise + 1.2, 0.8), Vector3(cx, y + (rise + 1.2) * 0.5 - 0.2, zc - d * 0.25), STONE.darkened(0.15))
	box(h, Vector3(1.0, 0.18, 1.0), Vector3(cx, y + rise + 1.0, zc - d * 0.25), STONE)
	if rng.randf() < 0.5:  # dormer
		box(h, Vector3(1.3, 1.2, 1.1), Vector3(-w * 0.2, y + rise * 0.35 + 0.6, zc + d * 0.5 - 0.3), PLASTER[1])
		var dm := PrismMesh.new()
		dm.size = Vector3(1.6, 0.8, 1.3)
		DeckArt.add_mesh(h, dm, mat(color.darkened(0.2)), Vector3(-w * 0.2, y + rise * 0.35 + 1.6, zc + d * 0.5 - 0.3))


## A market stall: four posts, a striped awning, a counter and heaps of goods.
static func stall(parent: Node3D, at: Vector3, yaw_deg: float, rng: RandomNumberGenerator) -> Node3D:
	var s := Node3D.new()
	s.name = "Stall"
	s.position = at
	s.rotation_degrees.y = yaw_deg
	parent.add_child(s)
	var wood: Color = Color(0.32, 0.2, 0.1)
	for x in [-1.3, 1.3]:
		for z in [-0.8, 0.8]:
			box(s, Vector3(0.12, 2.5 if z < 0 else 2.2, 0.12), Vector3(x, 1.2, z), wood)
	var a: Color = STRIPES[rng.randi_range(0, STRIPES.size() - 1)]
	var b: Color = Color(0.92, 0.88, 0.78)
	for i in 8:
		var strip := box(s, Vector3(0.34, 0.05, 2.1), Vector3(-1.25 + i * 0.36, 2.35, 0.0), a if i % 2 == 0 else b, Vector3(14, 0, 0))
		strip.name = "Awning"
	box(s, Vector3(2.8, 0.1, 0.7), Vector3(0, 0.95, 0.5), wood.lightened(0.1))
	box(s, Vector3(2.7, 0.9, 0.1), Vector3(0, 0.5, 0.82), wood)
	var goods: int = rng.randi_range(0, 3)
	for k in 6:
		var gx: float = -1.1 + k * 0.45
		match goods:
			0:  # fruit
				for j in 3:
					DeckArt.add_mesh(s, _ball(0.1), mat([Color(0.8, 0.15, 0.1), Color(0.9, 0.7, 0.1), Color(0.4, 0.6, 0.15)][(k + j) % 3], 0.5), Vector3(gx + j * 0.1 - 0.1, 1.08 + 0.06 * (j % 2), 0.5))
			1:  # fish
				var f := DeckArt.add_mesh(s, _ball(0.1), mat(Color(0.65, 0.68, 0.7), 0.4), Vector3(gx, 1.04, 0.5))
				f.scale = Vector3(0.6, 0.4, 2.4)
			2:  # cloth bolts
				DeckArt.add_mesh(s, DeckArt.cyl(0.1, 0.1, 0.6, 8), mat(STRIPES[k % STRIPES.size()], 0.9), Vector3(gx, 1.15, 0.5), Vector3(0, 0, 90))
			_:  # bread and loaves
				var l := DeckArt.add_mesh(s, _ball(0.13), mat(Color(0.7, 0.5, 0.25), 0.8), Vector3(gx, 1.08, 0.5))
				l.scale = Vector3(1.0, 0.7, 1.5)
	box(s, Vector3(0.6, 0.5, 0.5), Vector3(-1.9, 0.25, 0.4), wood.lightened(0.2))
	DeckArt.add_mesh(s, DeckArt.cyl(0.25, 0.25, 0.55, 10), mat(wood.lightened(0.25)), Vector3(2.0, 0.28, 0.4))
	return s


static func well(parent: Node3D, at: Vector3) -> Node3D:
	var w := Node3D.new()
	w.name = "Well"
	w.position = at
	parent.add_child(w)
	var ring := cyl(w, 1.1, 1.2, 1.0, Vector3(0, 0.5, 0), STONE.lightened(0.1), 14)
	ring.name = "WellRing"
	cyl(w, 0.85, 0.85, 0.05, Vector3(0, 1.0, 0), Color(0.05, 0.1, 0.15), 14)
	for s in [-1.0, 1.0]:
		box(w, Vector3(0.14, 2.4, 0.14), Vector3(s * 1.1, 2.0, 0), TIMBER)
	DeckArt.add_mesh(w, DeckArt.cyl(0.1, 0.1, 2.4, 8), mat(TIMBER), Vector3(0, 2.8, 0), Vector3(0, 0, 90))
	var rp := PrismMesh.new()
	rp.size = Vector3(3.0, 0.9, 1.8)
	DeckArt.add_mesh(w, rp, mat(Color(0.5, 0.2, 0.12)), Vector3(0, 3.5, 0))
	DeckArt.add_mesh(w, DeckArt.cyl(0.02, 0.02, 1.2, 5), mat(Color(0.6, 0.5, 0.3)), Vector3(0, 2.2, 0))
	DeckArt.add_mesh(w, DeckArt.cyl(0.18, 0.15, 0.3, 8), mat(Color(0.35, 0.22, 0.12)), Vector3(0, 1.5, 0))
	return w


## A church: nave, a tower with a belfry and a spire, a cross, buttresses and a rose window.
static func church(parent: Node3D, at: Vector3, yaw_deg: float) -> Node3D:
	var c := Node3D.new()
	c.name = "Church"
	c.position = at
	c.rotation_degrees.y = yaw_deg
	parent.add_child(c)
	var stone: Color = STONE.lightened(0.12)
	box(c, Vector3(10.0, 10.0, 22.0), Vector3(0, 5.0, 0), stone)
	var roof := PrismMesh.new()
	roof.size = Vector3(11.0, 5.0, 22.5)
	DeckArt.add_mesh(c, roof, mat(Color(0.3, 0.32, 0.36)), Vector3(0, 12.5, 0))
	for i in 5:
		var z: float = -8.0 + i * 4.0
		for s in [-1.0, 1.0]:
			box(c, Vector3(1.0, 8.0, 1.0), Vector3(s * 5.4, 4.0, z), stone.darkened(0.08))
			box(c, Vector3(0.1, 3.4, 1.6), Vector3(s * 5.06, 5.6, z + 2.0), Color(0.2, 0.3, 0.45))
			var arch := cyl(c, 0.8, 0.8, 0.1, Vector3(s * 5.06, 7.3, z + 2.0), Color(0.2, 0.3, 0.45), 10)
			arch.rotation_degrees = Vector3(0, 0, 90)
	box(c, Vector3(5.0, 22.0, 5.0), Vector3(0, 11.0, 13.5), stone.darkened(0.04))
	box(c, Vector3(5.4, 0.6, 5.4), Vector3(0, 22.2, 13.5), stone.darkened(0.15))
	for s in [-1.0, 1.0]:
		box(c, Vector3(1.2, 2.2, 0.15), Vector3(s * 1.2, 19.0, 11.0), Color(0.08, 0.06, 0.05))
		box(c, Vector3(0.15, 2.2, 1.2), Vector3(s * 2.55, 19.0, 13.5), Color(0.08, 0.06, 0.05))
	var spire := DeckArt.add_mesh(c, DeckArt.cyl(0.0, 3.4, 9.0, 4), mat(Color(0.28, 0.34, 0.3)), Vector3(0, 27.0, 13.5), Vector3(0, 45, 0))
	spire.name = "Spire"
	box(c, Vector3(0.18, 2.0, 0.18), Vector3(0, 32.4, 13.5), Color(0.8, 0.65, 0.2))
	box(c, Vector3(1.0, 0.18, 0.18), Vector3(0, 32.9, 13.5), Color(0.8, 0.65, 0.2))
	var rose := cyl(c, 1.6, 1.6, 0.2, Vector3(0, 8.0, -11.05), Color(0.35, 0.2, 0.45), 16)
	rose.rotation_degrees.x = 90.0
	var door_m := box(c, Vector3(2.6, 4.0, 0.3), Vector3(0, 2.0, 16.1), Color(0.22, 0.13, 0.07))
	door_m.name = "ChurchDoor"
	return c


## A crenellated wall run with a walkway, and optionally a round tower.
static func wall_run(parent: Node3D, from: Vector3, to: Vector3, height: float = 8.0) -> void:
	var dir: Vector3 = to - from
	var len: float = dir.length()
	var w := Node3D.new()
	w.name = "Wall"
	w.position = from
	w.rotation.y = atan2(dir.x, dir.z)
	parent.add_child(w)
	box(w, Vector3(3.0, height, len), Vector3(0, height * 0.5, len * 0.5), STONE.darkened(0.12))
	var n: int = int(len / 1.6)
	for i in n:
		if i % 2 == 0:
			for s in [-1.0, 1.0]:
				box(w, Vector3(0.5, 1.0, 0.9), Vector3(s * 1.25, height + 0.5, (i + 0.5) * len / float(n)), STONE)
	box(w, Vector3(2.2, 0.2, len), Vector3(0, height + 0.1, len * 0.5), Color(0.35, 0.28, 0.2))


static func round_tower(parent: Node3D, at: Vector3, radius: float, height: float, flag: Color) -> Node3D:
	var t := Node3D.new()
	t.name = "Tower"
	t.position = at
	parent.add_child(t)
	cyl(t, radius, radius * 1.08, height, Vector3(0, height * 0.5, 0), STONE.darkened(0.1), 16)
	cyl(t, radius * 1.15, radius * 1.15, 0.5, Vector3(0, height + 0.1, 0), STONE.darkened(0.2), 16)
	for i in 12:
		var a: float = TAU * i / 12.0
		box(t, Vector3(0.8, 1.1, 0.9), Vector3(cos(a) * radius * 1.12, height + 0.9, sin(a) * radius * 1.12), STONE, Vector3(0, -rad_to_deg(a), 0))
	var roof := DeckArt.add_mesh(t, DeckArt.cyl(0.0, radius * 1.05, radius * 1.4, 12), mat(Color(0.18, 0.2, 0.3)), Vector3(0, height + radius * 0.8 + 0.4, 0))
	roof.name = "TowerRoof"
	box(t, Vector3(0.1, 2.2, 0.1), Vector3(0, height + radius * 1.5 + 1.2, 0), TIMBER)
	var f := box(t, Vector3(0.05, 1.0, 1.6), Vector3(0, height + radius * 1.5 + 1.6, 0.9), flag)
	f.name = "Banner"
	for k in 3:
		box(t, Vector3(0.3, 0.8, 0.1), Vector3(cos(k * 2.1) * radius * 0.98, height * 0.7, sin(k * 2.1) * radius * 0.98), Color(0.05, 0.04, 0.04))
	return t


## The castle keep: a square keep with corner towers, a gatehouse, a banner and a lit window or two.
static func castle(parent: Node3D, at: Vector3, flag: Color) -> Node3D:
	var c := Node3D.new()
	c.name = "Castle"
	c.position = at
	parent.add_child(c)
	var stone: Color = STONE.darkened(0.08)
	box(c, Vector3(26.0, 18.0, 20.0), Vector3(0, 9.0, 0), stone)
	for i in 14:
		box(c, Vector3(1.6, 1.4, 1.4), Vector3(-12.0 + i * 1.85, 18.7, 9.4), stone.lightened(0.05))
		box(c, Vector3(1.6, 1.4, 1.4), Vector3(-12.0 + i * 1.85, 18.7, -9.4), stone.lightened(0.05))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			round_tower(c, Vector3(sx * 13.0, 0.0, sz * 10.0), 3.4, 23.0, flag)
	var gate := box(c, Vector3(5.0, 7.0, 1.0), Vector3(0, 3.5, 10.3), Color(0.12, 0.08, 0.05))
	gate.name = "CastleGate"
	for i in 6:
		box(c, Vector3(0.12, 7.0, 0.2), Vector3(-2.0 + i * 0.8, 3.5, 10.9), Color(0.06, 0.06, 0.07))
	for r in 5:
		box(c, Vector3(5.0, 0.12, 0.2), Vector3(0, 1.0 + r * 1.3, 10.95), Color(0.06, 0.06, 0.07))
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(1.0, 0.75, 0.35)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.65, 0.25)
	for i in 4:
		DeckArt.add_mesh(c, DeckArt.box(Vector3(0.9, 1.8, 0.15)), lit, Vector3(-7.5 + i * 5.0, 12.0, 10.15))
	box(c, Vector3(0.14, 8.0, 0.14), Vector3(0, 22.0, 0), TIMBER)
	var b := box(c, Vector3(0.06, 4.0, 6.0), Vector3(0, 24.0, 3.2), flag)
	b.name = "KeepBanner"
	return c


static func cobbles(parent: Node3D, half_w: float, half_l: float, rng: RandomNumberGenerator) -> void:
	var stone := BoxMesh.new()
	stone.size = Vector3(0.5, 0.1, 0.4)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = stone
	var cols: int = int(half_w * 2.0 / 0.52)
	var rows: int = int(half_l * 2.0 / 0.42)
	mm.instance_count = cols * rows
	var i: int = 0
	for r in rows:
		for c in cols:
			var x: float = -half_w + (c + 0.5 + (0.5 if r % 2 == 1 else 0.0)) * 0.52 + rng.randf_range(-0.03, 0.03)
			var z: float = -half_l + (r + 0.5) * 0.42
			mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(0, rng.randf_range(-0.12, 0.12), 0)), Vector3(clampf(x, -half_w, half_w), 0.04, z)))
			var g: float = rng.randf_range(0.2, 0.38)
			mm.set_instance_color(i, Color(g * 1.05, g * 0.97, g * 0.86))
			i += 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	mi.name = "Cobbles"
	parent.add_child(mi)


## Barrels, crates, a handcart and a few lanterns scattered along a street.
static func street_clutter(parent: Node3D, half_w: float, half_l: float, rng: RandomNumberGenerator) -> void:
	var wood: Color = Color(0.4, 0.27, 0.14)
	for i in 14:
		var x: float = (-1.0 if rng.randf() < 0.5 else 1.0) * (half_w - rng.randf_range(0.5, 1.4))
		var z: float = rng.randf_range(-half_l, half_l)
		if rng.randf() < 0.55:
			cyl(parent, 0.36, 0.36, 0.8, Vector3(x, 0.45, z), wood, 12)
			cyl(parent, 0.375, 0.375, 0.04, Vector3(x, 0.45, z), Color(0.2, 0.2, 0.22), 12)
		else:
			box(parent, Vector3(0.8, 0.7, 0.8), Vector3(x, 0.4, z), wood.lightened(0.15), Vector3(0, rng.randf() * 90.0, 0))
	for k in 2:
		var cz: float = rng.randf_range(-half_l * 0.6, half_l * 0.6)
		var cart := Node3D.new()
		cart.name = "Cart"
		cart.position = Vector3((-1.0 if k == 0 else 1.0) * (half_w - 2.0), 0.0, cz)
		cart.rotation_degrees.y = rng.randf_range(-15.0, 15.0)
		parent.add_child(cart)
		box(cart, Vector3(1.4, 0.4, 2.2), Vector3(0, 0.8, 0), wood)
		for s in [-1.0, 1.0]:
			var wh := cyl(cart, 0.5, 0.5, 0.1, Vector3(s * 0.8, 0.5, 0), wood.darkened(0.2), 14)
			wh.rotation_degrees.z = 90.0
		box(cart, Vector3(0.1, 0.1, 1.6), Vector3(0, 0.6, 2.0), wood.darkened(0.1))
		for j in 4:
			DeckArt.add_mesh(cart, _ball(0.18), mat(Color(0.75, 0.6, 0.3)), Vector3(-0.4 + 0.27 * j, 1.12, 0.3))


## Old-town detail for the harbour's destructible buildings. `body` is the box mesh (centred), so everything added
## here hides and falls with it when the building is destroyed.
static func dress_body(body: Node3D, kind: String, size: Vector3, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var hx: float = size.x * 0.5 + 0.03
	var hz: float = size.z * 0.5 + 0.03
	match kind:
		"house", "warehouse":
			var n: int = maxi(int(size.x / 1.7), 2)
			for i in n + 1:
				var x: float = -size.x * 0.5 + size.x * float(i) / float(n)
				for zs in [-1.0, 1.0]:
					box(body, Vector3(0.18, size.y, 0.1), Vector3(x, 0.0, zs * hz), TIMBER)
			for zs in [-1.0, 1.0]:
				box(body, Vector3(size.x + 0.1, 0.2, 0.12), Vector3(0, size.y * 0.5 - 0.15, zs * hz), TIMBER)
				box(body, Vector3(size.x + 0.1, 0.2, 0.12), Vector3(0, -size.y * 0.5 + 0.9, zs * hz), TIMBER)
				box(body, Vector3(size.x + 0.2, 0.9, 0.08), Vector3(0, -size.y * 0.5 + 0.45, zs * (hz - 0.02)), STONE)
				for i in n:
					var wx: float = -size.x * 0.5 + size.x * (float(i) + 0.5) / float(n)
					box(body, Vector3(0.7, 0.85, 0.08), Vector3(wx, 0.3, zs * (hz + 0.02)), Color(0.12, 0.17, 0.22))
					box(body, Vector3(0.3, 0.8, 0.05), Vector3(wx - 0.55, 0.3, zs * (hz + 0.05)), Color(0.15, 0.32, 0.22))
					box(body, Vector3(0.3, 0.8, 0.05), Vector3(wx + 0.55, 0.3, zs * (hz + 0.05)), Color(0.5, 0.15, 0.12))
			box(body, Vector3(0.9, 2.4, 0.2), Vector3(0, -size.y * 0.5 + 1.2, hz + 0.02), Color(0.22, 0.13, 0.07))
			box(body, Vector3(0.7, size.y * 0.5, 0.7), Vector3(size.x * 0.25, size.y * 0.5 + size.y * 0.3, 0.0), STONE.darkened(0.15))
		"wall", "gate":
			var n2: int = maxi(int(size.x / 1.4), 2)
			for i in n2:
				if i % 2 == 0:
					box(body, Vector3(0.7, 1.1, size.z + 0.2), Vector3(-size.x * 0.5 + (i + 0.5) * size.x / float(n2), size.y * 0.5 + 0.55, 0.0), STONE.lightened(0.04))
			for i in 3:  # arrow slits
				box(body, Vector3(0.12, 1.0, 0.1), Vector3(-size.x * 0.3 + i * size.x * 0.3, 0.6, hz), Color(0.05, 0.05, 0.05))
				box(body, Vector3(0.12, 1.0, 0.1), Vector3(-size.x * 0.3 + i * size.x * 0.3, 0.6, -hz), Color(0.05, 0.05, 0.05))
			if kind == "gate":
				box(body, Vector3(size.x * 0.4, size.y * 0.8, 0.3), Vector3(0, -size.y * 0.1, hz), Color(0.12, 0.08, 0.05))
		"tower":
			for i in 8:
				var a: float = TAU * i / 8.0
				box(body, Vector3(0.9, 1.2, 0.9), Vector3(cos(a) * size.x * 0.6, size.y * 0.5 + 0.6, sin(a) * size.z * 0.6), STONE)
			DeckArt.add_mesh(body, DeckArt.cyl(0.0, size.x * 0.62, size.x * 0.9, 4), mat(Color(0.18, 0.2, 0.3)), Vector3(0, size.y * 0.5 + size.x * 0.45 + 1.2, 0), Vector3(0, 45, 0))
			for zs in [-1.0, 1.0]:
				box(body, Vector3(0.14, 1.2, 0.1), Vector3(0, size.y * 0.15, zs * hz), Color(0.05, 0.05, 0.05))
		"lighthouse":
			for i in 3:
				box(body, Vector3(size.x + 0.15, 0.5, size.z + 0.15), Vector3(0, -size.y * 0.3 + i * size.y * 0.3, 0), Color(0.55, 0.15, 0.12))
			box(body, Vector3(size.x * 1.3, 0.5, size.z * 1.3), Vector3(0, size.y * 0.5 + 0.25, 0), STONE.darkened(0.2))
			var lamp := StandardMaterial3D.new()
			lamp.albedo_color = Color(1.0, 0.9, 0.5)
			lamp.emission_enabled = true
			lamp.emission = Color(1.0, 0.8, 0.3)
			lamp.emission_energy_multiplier = 2.0
			DeckArt.add_mesh(body, DeckArt.box(Vector3(size.x * 0.8, 1.4, size.z * 0.8)), lamp, Vector3(0, size.y * 0.5 + 1.2, 0))
		"dock":
			for i in int(size.z / 1.2):
				box(body, Vector3(size.x + 0.1, 0.05, 0.06), Vector3(0, size.y * 0.5 + 0.02, -size.z * 0.5 + i * 1.2), Color(0.18, 0.11, 0.06))
