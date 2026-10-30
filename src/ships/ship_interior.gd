class_name ShipInterior
extends RefCounted
## The inside of the player's ship as a cutaway you can look into: every deck plank and rib, each gun on its
## carriage with its shot and powder, the hold with the barrels, crates and sacks the ship really carries, and the
## captain's cabin with one treasure chest for every 1,500 gold aboard, lids open on coins, gems and goblets.
## The near wall is left off so the camera can see in. Everything is built from the ship's stats and the save.

const PLANK_W_M: float = 0.28
const DECK_H_M: float = 2.1
const HOLD_DROP_M: float = 2.4
const CHEST_GOLD: int = 1500
const MAX_CHESTS: int = 10
const SHOT_PER_GUN: int = 6

const WOOD_TONES: Array[Color] = [Color(0.45, 0.3, 0.17), Color(0.4, 0.27, 0.15), Color(0.5, 0.35, 0.2), Color(0.36, 0.24, 0.13), Color(0.47, 0.33, 0.2)]


## How many chests the gold fills.
static func chest_count(gold: int) -> int:
	return clampi(ceili(float(maxi(gold, 0)) / float(CHEST_GOLD)), 1, MAX_CHESTS)


## Barrels, crates and sacks for a cargo of `units` of goods, weighed against the hold.
static func cargo_pieces(cargo: Dictionary) -> int:
	var n: int = 0
	for g: String in cargo:
		n += clampi(ceili(float(cargo[g]) / 4.0), 0, 12)
	return n


static func _std(c: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return DeckArt.add_mesh(parent, mesh, mat, at, rot_deg)


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func build(stats: ShipStats, state: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "ShipInterior"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.get("seed", 1)) * 101 + stats.class_id.hash()
	var half_l: float = stats.length_m * 0.42
	var half_w: float = maxf(stats.beam_m * 0.5 - 0.15, 1.2)
	_deck(root, half_l, half_w, 0.0, rng, true)
	_deck(root, half_l, half_w, -HOLD_DROP_M - DECK_H_M, rng, false)
	_ribs(root, half_l, half_w, rng)
	_guns(root, stats, half_l, half_w)
	_hold(root, state, half_l, half_w, rng)
	_cabin(root, state, half_l, half_w, rng)
	_lanterns(root, half_l, half_w)
	return root


## Floor planks one by one, each with its own tone, and the beams carrying them.
static func _deck(root: Node3D, half_l: float, half_w: float, y: float, rng: RandomNumberGenerator, with_ceiling: bool) -> void:
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(PLANK_W_M - 0.02, 0.07, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = plank_mesh
	var cols: int = int(floor(half_w * 2.0 / PLANK_W_M))
	var seg_len: float = 3.2
	var rows: int = int(ceil(half_l * 2.0 / seg_len))
	mm.instance_count = cols * rows
	var i: int = 0
	for c in cols:
		var shift: float = rng.randf() * seg_len
		for r in rows:
			var z: float = -half_l + shift + (r + 0.5) * seg_len - seg_len * 0.5
			var t := Transform3D(Basis().scaled(Vector3(1, 1, seg_len - 0.04)), Vector3(-half_w + (c + 0.5) * PLANK_W_M, y, clampf(z, -half_l, half_l)))
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, WOOD_TONES[rng.randi_range(0, WOOD_TONES.size() - 1)].lerp(Color(0.2, 0.12, 0.07), rng.randf() * 0.35))
			i += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.name = "Planks"
	root.add_child(mi)
	var beam_mat: StandardMaterial3D = _std(Color(0.28, 0.17, 0.09), 0.9)
	var z2: float = -half_l
	while z2 <= half_l:
		_mesh(root, DeckArt.box(Vector3(half_w * 2.0, 0.16, 0.2)), beam_mat, Vector3(0, y - 0.12, z2))
		if with_ceiling:  # only the far half of each beam: the near half is cut away so the camera can see in
			_mesh(root, DeckArt.box(Vector3(half_w, 0.18, 0.22)), beam_mat, Vector3(-half_w * 0.5, y + DECK_H_M, z2))
		z2 += 1.6


## Ribs and the outer planking on the far side, a keel and the posts that hold the deck up.
static func _ribs(root: Node3D, half_l: float, half_w: float, rng: RandomNumberGenerator) -> void:
	var rib_mat: StandardMaterial3D = _std(Color(0.3, 0.19, 0.1), 0.9)
	var top: float = DECK_H_M
	var low: float = -HOLD_DROP_M - DECK_H_M
	var z: float = -half_l
	while z <= half_l:
		var pinch: float = 1.0 - 0.45 * pow(absf(z) / half_l, 3.0)
		_mesh(root, DeckArt.box(Vector3(0.22, top - low + 0.4, 0.24)), rib_mat, Vector3(-half_w * pinch - 0.1, (top + low) * 0.5, z), Vector3(0, 0, -6.0))
		z += 1.2
	var skin := BoxMesh.new()
	skin.size = Vector3(0.08, 1.0, 1.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = skin
	var rows: int = int(ceil((top - low) / 0.3))
	var segs: int = int(ceil(half_l * 2.0 / 3.0))
	mm.instance_count = rows * segs
	var i: int = 0
	for r in rows:
		for s in segs:
			var zc: float = -half_l + (s + 0.5) * 3.0 + rng.randf_range(-0.6, 0.6)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, 0.28, 2.96)), Vector3(-half_w - 0.02, low + r * 0.3, clampf(zc, -half_l, half_l))))
			mm.set_instance_color(i, WOOD_TONES[rng.randi_range(0, WOOD_TONES.size() - 1)].darkened(0.15))
			i += 1
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.name = "Planking"
	root.add_child(mi)
	_mesh(root, DeckArt.box(Vector3(0.3, 0.3, half_l * 2.0)), rib_mat, Vector3(0, -HOLD_DROP_M - DECK_H_M - 0.3, 0))
	for k in 3:
		_mesh(root, DeckArt.cyl(0.18, 0.18, DECK_H_M, 10), rib_mat, Vector3(0, DECK_H_M * 0.5, -half_l * 0.55 + k * half_l * 0.55))


## Each gun on a carriage with its trucks, breeching rope, rammer, a pile of shot and a powder keg.
static func _guns(root: Node3D, stats: ShipStats, half_l: float, half_w: float) -> void:
	var dark: StandardMaterial3D = _std(Color(0.22, 0.22, 0.25), 0.5, 0.3)
	var wood: StandardMaterial3D = _std(Color(0.33, 0.2, 0.1), 0.8)
	var rope: StandardMaterial3D = _std(Color(0.62, 0.52, 0.34), 0.95)
	var brass: StandardMaterial3D = _std(Color(0.8, 0.62, 0.2), 0.3, 0.9)
	var n: int = maxi(stats.guns_per_side, 1)
	var span: float = half_l * 1.5
	for side in [-1.0, 1.0]:
		for g in n:
			var z: float = -span * 0.5 + (span / float(maxi(n - 1, 1))) * float(g) if n > 1 else 0.0
			var gun := Node3D.new()
			gun.name = "Gun"
			gun.set_meta("kind", "gun")
			gun.position = Vector3(side * (half_w - 0.9), 0.1, z)
			gun.rotation_degrees.y = 90.0 * side
			root.add_child(gun)
			_mesh(gun, DeckArt.cyl(0.19, 0.12, 1.9, 12), dark, Vector3(0, 0.62, 0.1), Vector3(90, 0, 0))
			_mesh(gun, DeckArt.cyl(0.2, 0.2, 0.1, 12), dark, Vector3(0, 0.62, -0.8), Vector3(90, 0, 0))
			_mesh(gun, _sphere(0.1), dark, Vector3(0, 0.62, -0.92))
			_mesh(gun, DeckArt.cyl(0.14, 0.14, 0.05, 12), dark, Vector3(0, 0.62, 1.07), Vector3(90, 0, 0))
			_mesh(gun, DeckArt.cyl(0.05, 0.05, 0.9, 8), brass, Vector3(0, 0.66, 0.0), Vector3(0, 0, 90))
			for s in [-1.0, 1.0]:
				_mesh(gun, DeckArt.box(Vector3(0.09, 0.4, 1.5)), wood, Vector3(s * 0.4, 0.34, 0.05), Vector3(4, 0, 0))
				_mesh(gun, DeckArt.cyl(0.18, 0.18, 0.12, 10), wood, Vector3(s * 0.4, 0.16, 0.7), Vector3(0, 0, 90))
				_mesh(gun, DeckArt.cyl(0.12, 0.12, 0.12, 10), wood, Vector3(s * 0.4, 0.12, -0.45), Vector3(0, 0, 90))
			_mesh(gun, DeckArt.box(Vector3(0.8, 0.08, 0.1)), wood, Vector3(0, 0.55, 0.3))
			_mesh(gun, DeckArt.cyl(0.03, 0.03, 1.4, 6), rope, Vector3(0.0, 0.5, -1.05), Vector3(0, 90, 0))
			_mesh(gun, DeckArt.cyl(0.025, 0.025, 2.3, 6), wood, Vector3(0.62, 0.12, 0.2), Vector3(90, 0, 0))
			_mesh(gun, _sphere(0.07), dark, Vector3(0.62, 0.12, 1.4))
			# shot pyramid and a powder keg
			var base: Vector3 = Vector3(-0.8, 0.0, 0.8)
			for layer in 3:
				for a in 3 - layer:
					for b in 3 - layer:
						_mesh(gun, _sphere(0.075), dark, base + Vector3(0.15 * a + 0.075 * layer, 0.08 + 0.12 * layer, 0.15 * b + 0.075 * layer))
			_mesh(gun, DeckArt.cyl(0.2, 0.2, 0.34, 12), wood, Vector3(-0.85, 0.17, -0.5))
			_mesh(gun, DeckArt.cyl(0.205, 0.205, 0.03, 12), dark, Vector3(-0.85, 0.12, -0.5))
			_mesh(gun, DeckArt.cyl(0.205, 0.205, 0.03, 12), dark, Vector3(-0.85, 0.28, -0.5))
			# the gun port in the side
			if side < 0.0:
				_mesh(root, DeckArt.box(Vector3(0.05, 0.62, 0.7)), _std(Color(0.05, 0.04, 0.04), 1.0), Vector3(side * (half_w + 0.02), 1.0, z))


## Barrels, crates and sacks for the cargo, water casks and ballast, stacked in the hold.
static func _hold(root: Node3D, state: Dictionary, half_l: float, half_w: float, rng: RandomNumberGenerator) -> void:
	var floor_y: float = -HOLD_DROP_M - DECK_H_M
	var wood: StandardMaterial3D = _std(Color(0.4, 0.26, 0.14), 0.85)
	var hoop: StandardMaterial3D = _std(Color(0.2, 0.2, 0.22), 0.5, 0.7)
	var sack: StandardMaterial3D = _std(Color(0.72, 0.62, 0.44), 1.0)
	var pieces: int = cargo_pieces(state.get("cargo", {})) + 8
	var slots: int = 0
	var cols: int = maxi(int(half_w / 0.7), 2)
	for p in pieces:
		var col: int = slots % cols
		var row: int = slots / cols
		var x: float = -half_w + 0.6 + col * 0.72 + rng.randf_range(-0.05, 0.05)
		var z: float = -half_l * 0.9 + row * 0.8
		if z > half_l * 0.4:
			break
		slots += 1
		var kind: int = rng.randi_range(0, 2)
		var y: float = floor_y + 0.05
		for layer in rng.randi_range(1, 2):
			var at := Vector3(x, y + layer * 0.78 + 0.35, z)
			match kind:
				0:
					_mesh(root, DeckArt.cyl(0.3, 0.3, 0.7, 14), wood, at).scale = Vector3(1, 1, 1)
					for h in [-0.22, 0.0, 0.22]:
						_mesh(root, DeckArt.cyl(0.31, 0.31, 0.035, 14), hoop, at + Vector3(0, h, 0))
				1:
					_mesh(root, DeckArt.box(Vector3(0.62, 0.62, 0.62)), wood, at)
					_mesh(root, DeckArt.box(Vector3(0.64, 0.05, 0.64)), hoop, at + Vector3(0, 0.15, 0))
					_mesh(root, DeckArt.box(Vector3(0.64, 0.05, 0.64)), hoop, at + Vector3(0, -0.15, 0))
				_:
					var s := _mesh(root, _sphere(0.32), sack, at + Vector3(0, -0.05, 0))
					s.scale = Vector3(1.0, 0.8, 0.7)
					_mesh(root, DeckArt.cyl(0.06, 0.1, 0.12, 8), sack, at + Vector3(0, 0.22, 0))
	# ballast stones along the keel
	var stone: StandardMaterial3D = _std(Color(0.4, 0.4, 0.42), 0.95)
	for k in 26:
		var st := _mesh(root, _sphere(rng.randf_range(0.14, 0.26)), stone, Vector3(rng.randf_range(-0.4, 0.4), floor_y + 0.1, rng.randf_range(-half_l, half_l)))
		st.scale = Vector3(1.0, 0.6, 1.0)
	# the ship's bell, hung at the foot of the ladder
	_mesh(root, DeckArt.cyl(0.0, 0.2, 0.32, 12), _std(Color(0.8, 0.62, 0.2), 0.3, 0.9), Vector3(0, floor_y + 1.4, half_l * 0.35))


## Captain's cabin at the stern: a table with a chart, a bunk, a chair and the treasure chests.
static func _cabin(root: Node3D, state: Dictionary, half_l: float, half_w: float, rng: RandomNumberGenerator) -> void:
	var wood: StandardMaterial3D = _std(Color(0.3, 0.19, 0.1), 0.7)
	var gold: StandardMaterial3D = _std(Color(0.95, 0.76, 0.2), 0.25, 0.9)
	var brass: StandardMaterial3D = _std(Color(0.8, 0.62, 0.2), 0.3, 0.9)
	var z0: float = half_l * 0.62
	# table, chart, goblets, candle
	var table := Node3D.new()
	table.position = Vector3(-0.2, 0.0, z0 + 0.6)
	root.add_child(table)
	_mesh(table, DeckArt.box(Vector3(1.6, 0.08, 0.9)), wood, Vector3(0, 0.8, 0))
	for lx in [-0.7, 0.7]:
		for lz in [-0.38, 0.38]:
			_mesh(table, DeckArt.box(Vector3(0.08, 0.8, 0.08)), wood, Vector3(lx, 0.4, lz))
	_mesh(table, DeckArt.box(Vector3(1.0, 0.012, 0.65)), _std(Color(0.85, 0.76, 0.55), 1.0), Vector3(-0.1, 0.85, 0.0), Vector3(0, 8, 0))
	for k in 2:
		_mesh(table, DeckArt.cyl(0.05, 0.03, 0.12, 10), gold, Vector3(0.5, 0.9, -0.2 + 0.25 * k))
	var candle := _mesh(table, DeckArt.cyl(0.02, 0.02, 0.14, 8), _std(Color(0.95, 0.9, 0.75)), Vector3(0.45, 0.92, 0.25))
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.7, 0.35)
	flame.omni_range = 4.0
	flame.light_energy = 1.4
	flame.position = Vector3(0, 0.15, 0)
	candle.add_child(flame)
	# bunk with a blanket, a chair
	_mesh(root, DeckArt.box(Vector3(1.0, 0.25, 2.0)), wood, Vector3(half_w - 0.8, 0.45, z0 + 0.4))
	_mesh(root, DeckArt.box(Vector3(0.92, 0.12, 1.9)), _std(Color(0.6, 0.15, 0.12), 1.0), Vector3(half_w - 0.8, 0.64, z0 + 0.4))
	_mesh(root, DeckArt.box(Vector3(0.4, 0.1, 0.4)), wood, Vector3(-0.6, 0.45, z0 - 0.3))
	_mesh(root, DeckArt.box(Vector3(0.4, 0.5, 0.06)), wood, Vector3(-0.6, 0.75, z0 - 0.48))
	# treasure chests
	var n: int = chest_count(int(state.get("gold", 0)))
	var gold_left: int = int(state.get("gold", 0))
	for i in n:
		var cx: float = -half_w + 0.8 + (i % 5) * 1.0
		var cz: float = z0 + 1.7 + (i / 5) * 0.9
		if i >= 5:
			cz = z0 - 1.2 - (i - 5) * 0.8
		var share: int = mini(gold_left, CHEST_GOLD)
		gold_left -= share
		_chest(root, Vector3(cx, 0.0, cz), float(share) / float(CHEST_GOLD), wood, gold, brass, rng)


## One iron-bound chest, lid thrown back, heaped with coins, gems, a goblet and a string of pearls.
static func _chest(root: Node3D, at: Vector3, fill: float, wood: Material, gold: Material, brass: Material, rng: RandomNumberGenerator) -> void:
	var c := Node3D.new()
	c.name = "Chest"
	c.set_meta("kind", "chest")
	c.position = at
	c.rotation_degrees.y = rng.randf_range(-25.0, 25.0)
	root.add_child(c)
	_mesh(c, DeckArt.box(Vector3(0.8, 0.4, 0.5)), wood, Vector3(0, 0.2, 0))
	var iron: StandardMaterial3D = _std(Color(0.18, 0.18, 0.2), 0.4, 0.8)
	for x in [-0.3, 0.3]:
		_mesh(c, DeckArt.box(Vector3(0.05, 0.42, 0.52)), iron, Vector3(x, 0.2, 0))
	_mesh(c, DeckArt.box(Vector3(0.06, 0.1, 0.02)), brass, Vector3(0, 0.34, 0.26))
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.4, -0.25)
	lid.rotation_degrees.x = -105.0
	c.add_child(lid)
	_mesh(lid, DeckArt.box(Vector3(0.8, 0.06, 0.5)), wood, Vector3(0, 0.0, 0.25))
	for x in [-0.3, 0.3]:
		_mesh(lid, DeckArt.box(Vector3(0.05, 0.08, 0.52)), iron, Vector3(x, 0.0, 0.25))
	var coins: int = clampi(int(fill * 90.0) + 10, 10, 100)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = DeckArt.cyl(0.05, 0.05, 0.012, 10)
	mm.instance_count = coins
	for i in coins:
		var a: float = rng.randf() * TAU
		var r: float = sqrt(rng.randf()) * 0.3
		var h: float = 0.4 + 0.12 * (1.0 - r / 0.3) * fill + rng.randf() * 0.03
		mm.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))), Vector3(cos(a) * r * 1.2, h, sin(a) * r * 0.7)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = gold
	mi.name = "Coins"
	c.add_child(mi)
	for k in 5:
		var gem := _mesh(c, _sphere(0.035), _std([Color(0.8, 0.1, 0.15), Color(0.1, 0.6, 0.3), Color(0.15, 0.3, 0.85), Color(0.9, 0.9, 1.0), Color(0.6, 0.2, 0.7)][k], 0.15, 0.1), Vector3(rng.randf_range(-0.25, 0.25), 0.5 + 0.1 * fill, rng.randf_range(-0.12, 0.12)))
		gem.name = "Gem"
	if fill > 0.5:
		_mesh(c, DeckArt.cyl(0.04, 0.025, 0.1, 10), gold, Vector3(0.22, 0.53, 0.1))
		for p in 8:
			_mesh(c, _sphere(0.018), _std(Color(0.95, 0.94, 0.9), 0.2), Vector3(-0.2 + 0.035 * p, 0.46 + 0.01 * sin(p), 0.18))


static func _lanterns(root: Node3D, half_l: float, half_w: float) -> void:
	var brass: StandardMaterial3D = _std(Color(0.8, 0.62, 0.2), 0.3, 0.9)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.8, 0.45)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.3)
	glow.emission_energy_multiplier = 2.0
	for y in [DECK_H_M - 0.35, -HOLD_DROP_M - 0.4]:
		var z: float = -half_l * 0.8
		while z <= half_l * 0.8:
			var l := Node3D.new()
			l.name = "Lantern"
			l.position = Vector3(-half_w * 0.8, y, z)
			root.add_child(l)
			_mesh(l, DeckArt.cyl(0.015, 0.015, 0.3, 6), brass, Vector3(0, 0.3, 0))
			_mesh(l, DeckArt.cyl(0.1, 0.12, 0.26, 8), glow, Vector3.ZERO)
			_mesh(l, DeckArt.cyl(0.0, 0.13, 0.08, 8), brass, Vector3(0, 0.17, 0))
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.72, 0.4)
			light.omni_range = 6.5
			light.light_energy = 1.1
			l.add_child(light)
			z += half_l * 0.55
