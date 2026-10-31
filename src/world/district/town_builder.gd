class_name TownBuilder
extends RefCounted
## The pieces of a late-medieval harbour town, built from primitives and tuned to read as old: timber-framed houses on
## stone footings with the upper floor jettied out over the street, steep tiled roofs with chimneys, shuttered
## windows, hanging signs, market stalls with striped awnings and heaps of goods, a well, a church with a spire, a
## castle keep with crenellated walls, round towers and banners, cobbled streets and barrels and carts.

const PLASTER: Array[Color] = [Color(0.99, 0.89, 0.78), Color(0.95, 0.75, 0.6), Color(0.99, 0.92, 0.7), Color(0.78, 0.8, 0.92), Color(0.97, 0.82, 0.68)]
const TIMBER: Color = Color(0.45, 0.28, 0.2)
const STONE: Color = Color(0.66, 0.68, 0.79)
const STRIPES: Array[Color] = [Color(0.81, 0.33, 0.31), Color(0.99, 0.89, 0.78), Color(0.4, 0.58, 0.85), Color(1.0, 0.75, 0.27), Color(0.38, 0.8, 0.55)]
const FLOOR_H_M: float = 3.0
const JETTY_M: float = 0.55
const CELL_M: float = 3.0  ## one Fantasy Town wall panel is one cell: a metre in the kit is three here


static var _boxes: Dictionary = {}


## Shared flat toon materials by colour: a harbour is hundreds of small pieces and streaming it in must not allocate a
## resource for each.
static func mat(c: Color, _rough: float = 0.92) -> ShaderMaterial:
	return Kenney.flat(c)


static func box(parent: Node3D, size: Vector3, at: Vector3, c: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var key := Vector3(snappedf(size.x, 0.01), snappedf(size.y, 0.01), snappedf(size.z, 0.01))
	if not _boxes.has(key):
		_boxes[key] = DeckArt.box(size)
	return DeckArt.add_mesh(parent, _boxes[key] as Mesh, mat(c), at, rot_deg)


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, c: Color, segs: int = 12) -> MeshInstance3D:
	return DeckArt.add_mesh(parent, DeckArt.cyl(r_top, r_bot, h, segs), mat(c), at)


## One Kenney piece at a position, yaw and (possibly stretched) scale.
static func piece(parent: Node3D, kit: String, model: String, at: Vector3, yaw_deg: float = 0.0, scl: Vector3 = Vector3.ONE) -> Node3D:
	var n: Node3D = Kenney.spawn(kit, model, not model.begins_with("stall") and not model.begins_with("roof"))
	n.position = at
	n.rotation_degrees.y = yaw_deg
	n.scale = scl
	parent.add_child(n)
	return n


## A house from Fantasy Town panels: `w` across the street, `d` along it, `floors` storeys, a gabled roof, a chimney.
## Faces +z (the street side after rotating).
static func house(parent: Node3D, at: Vector3, yaw_deg: float, w: float, d: float, floors: int, roof: Color, rng: RandomNumberGenerator) -> Node3D:
	var h := Node3D.new()
	h.name = "House"
	h.position = at
	h.rotation_degrees.y = yaw_deg
	parent.add_child(h)
	var nx: int = maxi(int(round(w / CELL_M)), 2)
	var nz: int = maxi(int(round(d / CELL_M)), 2)
	var ww: float = nx * CELL_M
	var dd: float = nz * CELL_M
	var sc := Vector3.ONE * CELL_M
	var timber: bool = rng.randf() < 0.5
	var door_i: int = nx / 2
	for f in floors:
		var y: float = f * CELL_M
		# sides: [yaw of the outward normal, cells, centre offset of the edge, direction of the run]
		for side in 4:
			var cells: int = nx if side % 2 == 0 else nz
			for i in cells:
				var model: String = "wall-wood" if (timber or f > 0) else "wall"
				var kind: int = rng.randi_range(0, 4)
				if kind <= 1:
					model += "-window-shutters"
				elif kind == 2 and f > 0:
					model += "-window-small"
				if side == 0 and f == 0 and i == door_i:
					model = "wall-wood-door" if timber else "wall-door"
				var run: float = (i + 0.5) * CELL_M - (ww if side % 2 == 0 else dd) * 0.5
				var pos: Vector3
				var yaw: float
				match side:
					0: pos = Vector3(run, y, dd * 0.5 - 0.5 * CELL_M * 0.0); yaw = -90.0   # front, +z
					1: pos = Vector3(ww * 0.5, y, -run); yaw = 0.0                              # right, +x
					2: pos = Vector3(-run, y, -dd * 0.5); yaw = 90.0                            # back, -z
					_: pos = Vector3(-ww * 0.5, y, run); yaw = 180.0                            # left, -x
				piece(h, "town", model, pos, yaw, sc)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			piece(h, "town", "pillar-wood", Vector3(cx * ww * 0.5, 0.0, cz * dd * 0.5), 0.0, Vector3(sc.x, sc.y * floors, sc.z))
	var top: float = floors * CELL_M
	# roof: gable ridge runs along z
	var rf: Node3D = piece(h, "town", "roof-gable", Vector3(0, top, 0), 0.0, Vector3((ww + 0.8) / 1.1, (ww * 0.42) / 0.57, (dd + 0.8) / 1.07))
	rf.name = "RoofSlab"
	piece(h, "town", "chimney", Vector3(ww * 0.28, top + 0.6, -dd * 0.25), 0.0, Vector3(sc.x, sc.y * 0.9, sc.z))
	# a lit doorstep and a hanging sign
	if rng.randf() < 0.7:
		box(h, Vector3(0.7, 0.55, 0.06), Vector3(ww * 0.5 - 0.6, 2.3, dd * 0.5 + 0.5), STRIPES[rng.randi_range(0, STRIPES.size() - 1)])
		box(h, Vector3(0.9, 0.08, 0.08), Vector3(ww * 0.5 - 0.5, 2.7, dd * 0.5 + 0.2), TIMBER)
	return h


static func _ball(r: float) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 3
	return s


## A market stall: a Fantasy Town stall with heaps of goods on the counter.
static func stall(parent: Node3D, at: Vector3, yaw_deg: float, rng: RandomNumberGenerator) -> Node3D:
	var s := Node3D.new()
	s.name = "Stall"
	s.position = at
	s.rotation_degrees.y = yaw_deg
	parent.add_child(s)
	var body: Node3D = piece(s, "town", "stall-red" if rng.randf() < 0.5 else "stall-green", Vector3.ZERO, 0.0, Vector3(2.8, 2.8, 2.8))
	body.name = "Awning"
	var goods: int = rng.randi_range(0, 3)
	for k in 5:
		var gx: float = -1.0 + k * 0.5
		match goods:
			0:  # fruit
				for j in 3:
					DeckArt.add_mesh(s, _ball(0.12), mat([Color(0.81, 0.33, 0.31), Color(1.0, 0.75, 0.27), Color(0.38, 0.8, 0.55)][(k + j) % 3]), Vector3(gx + j * 0.1 - 0.1, 1.05 + 0.07 * (j % 2), 0.1))
			1:  # fish
				var f := DeckArt.add_mesh(s, _ball(0.12), mat(Color(0.63, 0.66, 0.79)), Vector3(gx, 1.02, 0.1))
				f.scale = Vector3(0.6, 0.4, 2.4)
			2:  # cloth bolts
				DeckArt.add_mesh(s, DeckArt.cyl(0.12, 0.12, 0.6, 8), mat(STRIPES[k % STRIPES.size()]), Vector3(gx, 1.1, 0.1), Vector3(0, 0, 90))
			_:  # bread
				var l := DeckArt.add_mesh(s, _ball(0.15), mat(Color(0.95, 0.75, 0.6)), Vector3(gx, 1.05, 0.1))
				l.scale = Vector3(1.0, 0.7, 1.5)
	Kenney.place(s, "pirate", "barrel", Vector3(-2.0, 0.0, 0.5), 0.0, 0.5)
	Kenney.place(s, "pirate", "crate", Vector3(2.0, 0.0, 0.5), 20.0, 0.6)
	return s


static func well(parent: Node3D, at: Vector3) -> Node3D:
	var w := Node3D.new()
	w.name = "Well"
	w.position = at
	parent.add_child(w)
	var ring: Node3D = piece(w, "town", "fountain-round-detail", Vector3.ZERO, 0.0, Vector3.ONE * 1.5)
	ring.name = "WellRing"
	return w


## A church: a nave of Fantasy Town walls under a steep roof, a square tower with a belfry and a spire.
static func church(parent: Node3D, at: Vector3, yaw_deg: float) -> Node3D:
	var c := Node3D.new()
	c.name = "Church"
	c.position = at
	c.rotation_degrees.y = yaw_deg
	parent.add_child(c)
	var cell: float = 4.0
	var nx: int = 3
	var nz: int = 5
	var ww: float = nx * cell
	var dd: float = nz * cell
	var sc := Vector3.ONE * cell
	for f in 2:
		for side in 4:
			var cells: int = nx if side % 2 == 0 else nz
			for i in cells:
				var run: float = (i + 0.5) * cell - (ww if side % 2 == 0 else dd) * 0.5
				var model: String = "wall-window-stone" if (i % 2 == 1 and side % 2 == 1) else "wall"
				var pos: Vector3
				var yaw: float
				match side:
					0: pos = Vector3(run, f * cell, dd * 0.5); yaw = -90.0
					1: pos = Vector3(ww * 0.5, f * cell, -run); yaw = 0.0
					2: pos = Vector3(-run, f * cell, -dd * 0.5); yaw = 90.0
					_: pos = Vector3(-ww * 0.5, f * cell, run); yaw = 180.0
				piece(c, "town", model, pos, yaw, sc)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			piece(c, "town", "pillar-stone", Vector3(cx * ww * 0.5, 0.0, cz * dd * 0.5), 0.0, Vector3(cell, cell * 2.0, cell))
	piece(c, "town", "roof-high-gable", Vector3(0, 2.0 * cell, 0), 0.0, Vector3((ww + 1.0) / 1.1, (ww * 0.5) / 1.16, (dd + 1.0) / 1.13))
	# tower at the street end
	var tz: float = dd * 0.5 + 2.5
	var ts: float = 5.5
	piece(c, "castle", "tower-square-base", Vector3(0, 0, tz), 0.0, Vector3.ONE * ts)
	piece(c, "castle", "tower-square-mid", Vector3(0, ts, tz), 0.0, Vector3.ONE * ts)
	piece(c, "castle", "tower-square-mid-windows", Vector3(0, ts * 2.0, tz), 0.0, Vector3.ONE * ts)
	piece(c, "castle", "tower-square-top", Vector3(0, ts * 3.0, tz), 0.0, Vector3.ONE * ts)
	var spire: Node3D = piece(c, "castle", "tower-square-roof", Vector3(0, ts * 3.3, tz), 0.0, Vector3.ONE * ts)
	spire.name = "Spire"
	box(c, Vector3(0.2, 2.0, 0.2), Vector3(0, ts * 3.3 + ts * 2.0 + 1.0, tz), Color(1.0, 0.75, 0.27))
	box(c, Vector3(1.0, 0.2, 0.2), Vector3(0, ts * 3.3 + ts * 2.0 + 1.6, tz), Color(1.0, 0.75, 0.27))
	var door_m := box(c, Vector3(2.6, 4.0, 0.3), Vector3(0, 2.0, tz + ts * 0.5 + 0.05), Color(0.69, 0.38, 0.25))
	door_m.name = "ChurchDoor"
	return c


## A crenellated wall run: Castle Kit wall pieces end to end, two high.
static func wall_run(parent: Node3D, from: Vector3, to: Vector3, height: float = 8.0) -> void:
	var dir: Vector3 = to - from
	var len: float = dir.length()
	var w := Node3D.new()
	w.name = "Wall"
	w.position = from
	w.rotation.y = atan2(dir.x, dir.z)
	parent.add_child(w)
	var cells: int = maxi(int(round(len / 3.0)), 1)
	var step: float = len / float(cells)
	var layers: int = maxi(int(round(height / 4.0)), 1)
	for i in cells:
		for l in layers:
			var model: String = "wall" if l == 0 else "wall-half"
			piece(w, "castle", model, Vector3(0, l * 3.9, (i + 0.5) * step), 0.0, Vector3(3.0, 3.0, step))


static func round_tower(parent: Node3D, at: Vector3, radius: float, height: float, flag: Color) -> Node3D:
	var t := Node3D.new()
	t.name = "Tower"
	t.position = at
	parent.add_child(t)
	var sc: float = radius * 2.0 / 0.9
	var layer_h: float = 1.31 * sc
	var layers: int = maxi(int(round(height / layer_h)), 1)
	for l in layers:
		piece(t, "castle", "tower-hexagon-base", Vector3(0, l * layer_h, 0), 0.0, Vector3.ONE * sc)
	var y: float = layers * layer_h
	piece(t, "castle", "tower-hexagon-top", Vector3(0, y, 0), 0.0, Vector3.ONE * sc)
	var roof: Node3D = piece(t, "castle", "tower-hexagon-roof", Vector3(0, y + 0.13 * sc, 0), 0.0, Vector3.ONE * sc)
	roof.name = "TowerRoof"
	var f: Node3D = piece(t, "castle", "flag-wide", Vector3(0, y + 0.13 * sc + 0.83 * sc, 0), 0.0, Vector3.ONE * sc * 0.8)
	f.name = "Banner"
	return t


## The castle keep: a square keep of Castle Kit walls with corner towers, a gatehouse and banners.
static func castle(parent: Node3D, at: Vector3, flag: Color) -> Node3D:
	var c := Node3D.new()
	c.name = "Castle"
	c.position = at
	parent.add_child(c)
	var cell: float = 4.0
	var nx: int = 6
	var nz: int = 5
	var ww: float = nx * cell
	var dd: float = nz * cell
	for l in 3:
		for side in 4:
			var cells: int = nx if side % 2 == 0 else nz
			for i in cells:
				var run: float = (i + 0.5) * cell - (ww if side % 2 == 0 else dd) * 0.5
				var model: String = "wall"
				if side == 0 and i == nx / 2 and l == 0:
					model = "wall-doorway"
				var pos: Vector3
				var yaw: float
				match side:
					0: pos = Vector3(run, l * cell * 1.3, dd * 0.5); yaw = 90.0
					1: pos = Vector3(ww * 0.5, l * cell * 1.3, -run); yaw = 0.0
					2: pos = Vector3(-run, l * cell * 1.3, -dd * 0.5); yaw = 90.0
					_: pos = Vector3(-ww * 0.5, l * cell * 1.3, run); yaw = 0.0
				piece(c, "castle", model, pos, yaw, Vector3(cell, cell, cell))
	# fill the keep so it reads as a solid block from every side
	box(c, Vector3(ww - 2.0, 3.0 * cell * 1.3, dd - 2.0), Vector3(0, 3.0 * cell * 1.3 * 0.5, 0), STONE.darkened(0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var tp := Vector3(sx * ww * 0.5, 0.0, sz * dd * 0.5)
			var ts: float = 6.0
			piece(c, "castle", "tower-square-base", tp, 0.0, Vector3.ONE * ts)
			piece(c, "castle", "tower-square-mid-windows", tp + Vector3(0, ts, 0), 0.0, Vector3.ONE * ts)
			piece(c, "castle", "tower-square-mid", tp + Vector3(0, ts * 2.0, 0), 0.0, Vector3.ONE * ts)
			piece(c, "castle", "tower-square-mid", tp + Vector3(0, ts * 3.0, 0), 0.0, Vector3.ONE * ts)
			piece(c, "castle", "tower-square-top-roof-high", tp + Vector3(0, ts * 4.0, 0), 0.0, Vector3.ONE * ts)
	var gate := box(c, Vector3(5.0, 7.0, 0.4), Vector3(0, 3.5, dd * 0.5 + 0.3), Color(0.45, 0.28, 0.2))
	gate.name = "CastleGate"
	var b: Node3D = piece(c, "castle", "flag-banner-long", Vector3(0, 3.0 * cell * 1.3, 0), 0.0, Vector3.ONE * 5.0)
	b.name = "KeepBanner"
	return c


## Cobbled street: the Fantasy Town road tile laid over the whole street.
static func cobbles(parent: Node3D, half_w: float, half_l: float, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Kenney.merged("town", "road", false)
	var tile: float = 2.0
	var cols: int = int(ceil(half_w * 2.0 / tile))
	var rows: int = int(ceil(half_l * 2.0 / tile))
	mm.instance_count = cols * rows
	var i: int = 0
	for r in rows:
		for c in cols:
			var t := Transform3D(Basis.from_euler(Vector3(0, PI * 0.5 * float(rng.randi_range(0, 3)), 0)).scaled(Vector3(tile, 1.0, tile)), Vector3(-half_w + (c + 0.5) * tile, 0.03, -half_l + (r + 0.5) * tile))
			mm.set_instance_transform(i, t)
			i += 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.name = "Cobbles"
	parent.add_child(mi)


## Barrels, crates, handcarts and a few lanterns scattered along a street.
static func street_clutter(parent: Node3D, half_w: float, half_l: float, rng: RandomNumberGenerator) -> void:
	for i in 14:
		var x: float = (-1.0 if rng.randf() < 0.5 else 1.0) * (half_w - rng.randf_range(0.5, 1.4))
		var z: float = rng.randf_range(-half_l, half_l)
		if rng.randf() < 0.55:
			Kenney.place(parent, "pirate", "barrel", Vector3(x, 0.0, z), rng.randf() * 360.0, 0.6)
		else:
			Kenney.place(parent, "pirate", "crate", Vector3(x, 0.0, z), rng.randf() * 90.0, 0.75)
	for k in 2:
		var cz: float = rng.randf_range(-half_l * 0.6, half_l * 0.6)
		var cart: Node3D = Kenney.place(parent, "town", "cart-high" if k == 0 else "cart", Vector3((-1.0 if k == 0 else 1.0) * (half_w - 2.0), 0.0, cz), rng.randf_range(-15.0, 15.0) + 90.0, 2.4)
		cart.name = "Cart"
	for k in 8:  # hedges, banners and flowers along the house fronts
		var hz: float = -half_l + (k + 0.5) * half_l * 2.0 / 8.0
		var left: bool = k % 2 == 0
		piece(parent, "town", "hedge", Vector3((-half_w - 0.4) if left else (half_w + 0.4), 0.0, hz), 0.0 if left else 180.0, Vector3.ONE * 2.5)
		if k % 3 == 0:
			piece(parent, "town", "banner-green" if left else "banner-red", Vector3((-half_w - 0.2) if left else (half_w + 0.2), 3.0, hz + 1.2), 0.0 if left else 180.0, Vector3.ONE * 2.5)
		Kenney.place(parent, "nature", ["flower_redA", "flower_yellowB", "flower_purpleA"][k % 3], Vector3((-half_w + 1.2) if left else (half_w - 1.2), 0.0, hz + 2.0), rng.randf() * 360.0, 5.0)
	for k in 3:
		var lz: float = -half_l + (k + 0.5) * half_l * 2.0 / 3.0
		Kenney.place(parent, "town", "lantern", Vector3(-half_w + 0.4, 0.0, lz), 0.0, 2.0)
		Kenney.place(parent, "town", "lantern", Vector3(half_w - 0.4, 0.0, lz + 3.0), 0.0, 2.0)


## Old-town detail for the harbour's destructible buildings. `body` is the box mesh (centred), so everything added
## here hides and falls with it when the building is destroyed.
## `light` keeps a house to a door, front windows, corner posts, a beam and a chimney: what reads from the sea.
static func dress_body(body: Node3D, kind: String, size: Vector3, seed_v: int, light: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var hx: float = size.x * 0.5 + 0.03
	var hz: float = size.z * 0.5 + 0.03
	if light and kind in ["house", "warehouse"]:
		for xs in [-1.0, 1.0]:
			box(body, Vector3(0.22, size.y, 0.22), Vector3(xs * (size.x * 0.5), 0.0, hz), TIMBER)
		box(body, Vector3(size.x + 0.1, 0.22, 0.12), Vector3(0, size.y * 0.5 - 0.6, hz), TIMBER)
		var nw: int = maxi(int(size.x / 2.6), 1)
		for i in nw:
			var wx: float = -size.x * 0.5 + size.x * (float(i) + 0.5) / float(nw)
			if absf(wx) > 0.9:
				box(body, Vector3(0.8, 0.9, 0.08), Vector3(wx, size.y * 0.15, hz + 0.02), Color(0.12, 0.17, 0.22))
		box(body, Vector3(1.0, 2.2, 0.12), Vector3(0, -size.y * 0.5 + 1.1, hz + 0.02), Color(0.22, 0.13, 0.07))
		box(body, Vector3(0.7, size.y * 0.5, 0.7), Vector3(size.x * 0.25, size.y * 0.5 + size.y * 0.3, 0.0), STONE.darkened(0.15))
		return
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
			var lamp: ShaderMaterial = Kenney.flat(Color(1.0, 0.85, 0.4), 0.5)
			DeckArt.add_mesh(body, DeckArt.box(Vector3(size.x * 0.8, 1.4, size.z * 0.8)), lamp, Vector3(0, size.y * 0.5 + 1.2, 0))
		"dock":
			for i in int(size.z / 1.2):
				box(body, Vector3(size.x + 0.1, 0.05, 0.06), Vector3(0, size.y * 0.5 + 0.02, -size.z * 0.5 + i * 1.2), Color(0.18, 0.11, 0.06))

static func clear_cache() -> void:
	_boxes.clear()
