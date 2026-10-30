class_name LagoonArt
extends RefCounted
## The look of everything the player builds in the lagoon, from the Kenney Pirate, Fantasy Town, Nature, Castle,
## Arena and Dungeon kits plus a few flat-coloured pieces. Each builder returns a node whose origin is the middle of
## the plot on the ground and whose front faces +z; higher levels are visibly bigger.

const PIRATE_SCALE: float = 2.3  ## the Pirate Kit's huts and props read right at this size next to the crew
const ROOFS: Array[Color] = [Color("cf534f"), Color("51b985"), Color("6794d9"), Color("b06041")]


static func building(type: String, level: int, seed_v: int, damaged: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = type.capitalize()
	root.set_meta("kind", "lagoon_building")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match type:
		"hut": _hut(root, level, rng)
		"tavern": _tavern(root, level, rng)
		"market": _market(root, level, rng)
		"warehouse": _warehouse(root, level, rng)
		"shipyard": _shipyard(root, level, rng)
		"tower": _tower(root, level)
		"battery": _battery(root, level)
		"farm": _farm(root, level, rng)
		"campfire": _campfire(root, rng)
		"flagpole": _flagpole(root)
		"lanterns": _lanterns(root)
		"palms": _palms(root, rng)
		"well": TownBuilder.well(root, Vector3.ZERO).scale = Vector3.ONE * 1.6
		"treasure": _treasure(root, rng)
		"statue": _statue(root)
	if damaged:
		_ruin(root, rng)
	return root


## The captain's hall in the middle of the lagoon: it grows with the lagoon's rank.
static func hall(rank: int, seed_v: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Hall"
	root.set_meta("kind", "lagoon_hall")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	match rank:
		0:
			Kenney.place(root, "nature", "tent_detailedOpen", Vector3(0, 0, -2.0), 0.0, 4.5)
			root.add_child(_fire_at(Vector3(0, 0, 4.0), 1.0))
			_flag(root, Vector3(4.5, 0, 0), 2.6)
		1:
			TownBuilder.house(root, Vector3(0, 0, -1.0), 0.0, 9.0, 9.0, 1, ROOFS[0], rng)
			_flag(root, Vector3(5.5, 0, 4.0), 3.0)
			_barrels(root, Vector3(-5.0, 0, 4.0), 3, rng)
		2:
			TownBuilder.house(root, Vector3(0, 0, -1.0), 0.0, 12.0, 9.0, 2, ROOFS[0], rng)
			_flag(root, Vector3(6.5, 0, 4.5), 3.4)
			_flag(root, Vector3(-6.5, 0, 4.5), 3.4)
			for x in [-3.0, 3.0]:
				Kenney.place(root, "town", "lantern", Vector3(x, 0, 5.0), 0.0, 2.4)
		_:
			TownBuilder.house(root, Vector3(0, 0, -1.5), 0.0, 12.0, 9.0, 3, ROOFS[0], rng)
			for x in [-7.5, 7.5]:
				Kenney.place(root, "pirate", "tower-complete-small", Vector3(x, 0, -1.5), 0.0, 1.9)
			Kenney.place(root, "pirate", "castle-gate", Vector3(0, 0, 5.5), 0.0, 1.8)
			_flag(root, Vector3(0, 13.0, -1.5), 3.6)
	return root


# ---- buildings ------------------------------------------------------------------------------

static func _hut(root: Node3D, level: int, rng: RandomNumberGenerator) -> void:
	match level:
		1:
			Kenney.place(root, "pirate", "structure", Vector3.ZERO, 0.0, PIRATE_SCALE)
			Kenney.place(root, "pirate", "structure-roof", Vector3.ZERO, 0.0, PIRATE_SCALE)
			Kenney.place(root, "pirate", "barrel", Vector3(3.6, 0, 2.6), 20.0, 1.0)
		2:
			TownBuilder.house(root, Vector3.ZERO, 0.0, 6.0, 6.0, 1, ROOFS[rng.randi_range(0, 3)], rng)
			Kenney.place(root, "pirate", "barrel", Vector3(4.0, 0, 3.0), 0.0, 1.0)
		_:
			TownBuilder.house(root, Vector3(0, 0, -0.5), 0.0, 9.0, 6.0, 2, ROOFS[rng.randi_range(0, 3)], rng)
			Kenney.place(root, "nature", "flower_redA", Vector3(-3.5, 0, 3.8), 0.0, 4.0)
			Kenney.place(root, "nature", "flower_yellowB", Vector3(3.5, 0, 3.8), 0.0, 4.0)


static func _tavern(root: Node3D, level: int, rng: RandomNumberGenerator) -> void:
	var sizes: Array = [[9.0, 6.0, 1], [9.0, 9.0, 2], [12.0, 9.0, 2]]
	var sz: Array = sizes[level - 1]
	TownBuilder.house(root, Vector3(0, 0, -1.5), 0.0, sz[0], sz[1], sz[2], ROOFS[1], rng)
	# a big hanging sign with a tankard on it
	TownBuilder.box(root, Vector3(2.2, 1.2, 0.12), Vector3(0, 3.4, sz[1] * 0.5 - 1.0), Color("b06041"))
	TownBuilder.box(root, Vector3(0.7, 0.8, 0.14), Vector3(0, 3.4, sz[1] * 0.5 - 0.9), Color("ffc044"))
	_barrels(root, Vector3(-sz[0] * 0.5, 0, sz[1] * 0.5 - 0.5), 2 + level, rng)
	Kenney.place(root, "town", "stall-bench", Vector3(2.5, 0, sz[1] * 0.5), 0.0, 2.6)
	if level >= 2:
		for x in [-2.0, 4.5]:
			Kenney.place(root, "town", "lantern", Vector3(x, 0, sz[1] * 0.5 + 0.2), 0.0, 2.2)
	if level >= 3:
		for x in [-3.5, 0.0, 3.5]:
			Kenney.place(root, "dungeon", "table", Vector3(x, 0, sz[1] * 0.5 + 3.0), 0.0, 1.6)
		Kenney.place(root, "town", "banner-red", Vector3(-sz[0] * 0.5 + 0.2, 4.0, 0), 0.0, 3.0)


static func _market(root: Node3D, level: int, rng: RandomNumberGenerator) -> void:
	var spots: Array = [[Vector3(0, 0, 0), 0.0], [Vector3(-4.0, 0, -2.5), 20.0], [Vector3(4.0, 0, -2.5), -20.0]]
	for i in level:
		TownBuilder.stall(root, spots[i][0] + (Vector3(0, 0, 2.5) if level > 1 and i == 0 else Vector3.ZERO), spots[i][1], rng)
	if level >= 2:
		Kenney.place(root, "town", "cart", Vector3(-4.5, 0, 3.5), 30.0, 2.4)
	if level >= 3:
		Kenney.place(root, "town", "banner-green", Vector3(0, 0, -5.0), 0.0, 3.0)
		Kenney.place(root, "pirate", "crate-bottles", Vector3(4.5, 0, 3.5), 0.0, 1.1)


static func _warehouse(root: Node3D, level: int, rng: RandomNumberGenerator) -> void:
	if level == 1:
		Kenney.place(root, "pirate", "structure-roof", Vector3.ZERO, 0.0, 3.0)
		_crates(root, Vector3(-1.5, 0, 0), 4, rng)
		_barrels(root, Vector3(1.5, 0, -1.0), 3, rng)
		return
	TownBuilder.house(root, Vector3(0, 0, -1.0), 0.0, 12.0, 9.0, level - 1, Color("868ba1"), rng)
	_crates(root, Vector3(-4.5, 0, 4.5), 3 + level, rng)
	_barrels(root, Vector3(4.0, 0, 4.5), 2 + level, rng)
	if level >= 3:
		Kenney.place(root, "pirate", "chest", Vector3(0, 0, 5.0), 0.0, 1.2)


static func _shipyard(root: Node3D, level: int, rng: RandomNumberGenerator) -> void:
	# the slipway: a ramp of planks running down towards the harbour
	var ramp := TownBuilder.box(root, Vector3(6.0, 0.4, 12.0), Vector3(0, 0.2, 0), Color("b06041"))
	ramp.material_override = Kenney.planks(Color("f1976c"), 0.5)
	for x in [-3.4, 3.4]:
		for z in [-5.0, 0.0, 5.0]:
			TownBuilder.cyl(root, 0.18, 0.2, 2.2, Vector3(x, 1.1, z), Color("b06041"), 6)
	Kenney.place(root, "nature", "log_stackLarge", Vector3(-5.5, 0, -3.0), 90.0, 4.0)
	Kenney.place(root, "pirate", "boat-row-large", Vector3(5.0, 0.0, 3.0), 30.0, 1.6)
	if level >= 2:
		# a hull on the stocks
		Kenney.place(root, "pirate", "ship-wreck", Vector3(0, -0.2, 0), 180.0, 1.1)
		Kenney.place(root, "nature", "log_stack", Vector3(5.0, 0, -4.0), 0.0, 5.0)
	if level >= 3:
		# a crane: a tall post, a jib and a hanging block
		TownBuilder.cyl(root, 0.3, 0.35, 12.0, Vector3(-4.5, 6.0, 4.5), Color("b06041"), 8)
		TownBuilder.box(root, Vector3(0.4, 0.4, 8.0), Vector3(-4.5, 11.6, 1.0), Color("b06041"))
		TownBuilder.box(root, Vector3(0.06, 6.0, 0.06), Vector3(-4.5, 8.6, -2.8), Color("38383d"))
		Kenney.place(root, "pirate", "crate", Vector3(-4.5, 5.0, -2.8), 0.0, 1.0)


static func _tower(root: Node3D, level: int) -> void:
	match level:
		1:
			Kenney.place(root, "pirate", "tower-watch", Vector3.ZERO, 0.0, 2.6)
		2:
			Kenney.place(root, "pirate", "tower-complete-small", Vector3.ZERO, 0.0, 2.1)
			Kenney.place(root, "pirate", "cannon", Vector3(0, 0, 4.8), 0.0, 1.2)
		_:
			Kenney.place(root, "pirate", "tower-complete-large", Vector3.ZERO, 0.0, 2.2)
			for x in [-3.0, 3.0]:
				Kenney.place(root, "pirate", "cannon-mobile", Vector3(x, 0, 5.0), 0.0, 1.3)


static func _battery(root: Node3D, level: int) -> void:
	var guns: int = 2 * level
	for i in guns:
		var x: float = (i - (guns - 1) * 0.5) * 2.8
		Kenney.place(root, "pirate", "cannon-mobile", Vector3(x, 0, 1.5), 0.0, 1.4)
	for x in [-1.0, 1.0]:
		Kenney.place(root, "pirate", "castle-wall", Vector3(x * 2.1 * level, 0, 3.8), 90.0, 0.55)
	Kenney.place(root, "pirate", "cannon-ball", Vector3(0, 0, -2.0), 0.0, 1.5)
	Kenney.place(root, "pirate", "barrel", Vector3(-4.5, 0, -2.5), 0.0, 1.0)
	if level >= 2:
		_flag(root, Vector3(5.0, 0, -3.0), 2.4)


static func _farm(root: Node3D, level: int, rng: RandomNumberGenerator) -> void:
	var rows: int = 3 + 2 * (level - 1)
	var crops: Array[String] = ["crops_cornStageD", "crop_pumpkin", "crops_wheatStageB", "crop_carrot", "crop_melon"]
	for r in rows:
		var z: float = -5.0 + r * (10.0 / float(rows - 1))
		for k in 5:
			var x: float = -4.0 + k * 2.0
			Kenney.place(root, "nature", "crops_dirtRow", Vector3(x, 0.02, z), 0.0, 3.2)
			Kenney.place(root, "nature", crops[(r + level) % crops.size()], Vector3(x, 0.0, z), rng.randf() * 360.0, 4.2)
	for x in [-6.0, 6.0]:
		for z in [-4.0, -1.0, 2.0, 5.0]:
			Kenney.place(root, "nature", "fence_simple", Vector3(x, 0, z), 90.0, 3.0)
	if level >= 2:
		Kenney.place(root, "nature", "tent_smallOpen", Vector3(4.0, 0, -6.0), 0.0, 3.0)


static func _campfire(root: Node3D, rng: RandomNumberGenerator) -> void:
	root.add_child(_fire_at(Vector3.ZERO, rng.randf() * 10.0))
	for i in 4:
		var a: float = TAU * i / 4.0 + 0.4
		Kenney.place(root, "nature", "log_large", Vector3(cos(a) * 3.0, 0, sin(a) * 3.0), -rad_to_deg(a) + 90.0, 2.6)
	Kenney.place(root, "pirate", "bottle-large", Vector3(1.6, 0, 1.2), 0.0, 1.0)


static func _flagpole(root: Node3D) -> void:
	_flag(root, Vector3.ZERO, 3.2)
	for i in 3:
		Kenney.place(root, "pirate", "cannon-ball", Vector3(1.2 + i * 0.7, 0, 1.0), 0.0, 1.4)


static func _lanterns(root: Node3D) -> void:
	for p in [Vector3(-4.5, 0, -4.5), Vector3(4.5, 0, -4.5), Vector3(-4.5, 0, 4.5), Vector3(4.5, 0, 4.5)]:
		Kenney.place(root, "town", "lantern", p, 0.0, 2.6)
	var path := TownBuilder.box(root, Vector3(10.0, 0.12, 10.0), Vector3(0, 0.06, 0), Color("f2bf99"))
	path.material_override = Kenney.planks(Color("f1976c"), 0.6)


static func _palms(root: Node3D, rng: RandomNumberGenerator) -> void:
	var models: Array[String] = ["palm-bend", "palm-straight", "palm-detailed-bend"]
	for i in 3:
		var a: float = TAU * i / 3.0 + rng.randf()
		Kenney.place(root, "pirate", models[i], Vector3(cos(a) * 3.0, 0, sin(a) * 3.0), rng.randf() * 360.0, rng.randf_range(2.0, 2.6))
	Kenney.place(root, "pirate", "patch-grass-foliage", Vector3.ZERO, 0.0, 3.0)


static func _treasure(root: Node3D, rng: RandomNumberGenerator) -> void:
	# a heap of gold with chests and spilled coins
	var heap := TownBuilder.cyl(root, 0.4, 3.0, 1.6, Vector3(0, 0.8, 0), Color("ffc044"), 10)
	heap.material_override = Kenney.flat(Color("ffc044"), 0.25)
	for i in 3:
		var a: float = TAU * i / 3.0
		Kenney.place(root, "pirate", "chest", Vector3(cos(a) * 3.4, 0, sin(a) * 3.4), -rad_to_deg(a), 1.4)
	for i in 10:
		var a2: float = rng.randf() * TAU
		Kenney.place(root, "dungeon", "coin", Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(2.0, 4.5), rng.randf() * 360.0, 2.0)
	Kenney.place(root, "pirate", "bottle-large", Vector3(-1.0, 1.6, 0.3), 0.0, 1.0)


static func _statue(root: Node3D) -> void:
	TownBuilder.box(root, Vector3(4.0, 1.6, 4.0), Vector3(0, 0.8, 0), Color("a0a8c9"))
	Kenney.place(root, "arena", "statue", Vector3(0, 1.6, 0), 0.0, 6.5)
	for p in [Vector3(-3.5, 0, 3.5), Vector3(3.5, 0, 3.5)]:
		Kenney.place(root, "town", "lantern", p, 0.0, 2.2)


## A raided building: scorched rubble and a fire still burning in it.
static func _ruin(root: Node3D, rng: RandomNumberGenerator) -> void:
	root.add_child(_fire_at(Vector3(1.5, 0.2, 3.5), rng.randf() * 5.0, 1.8))
	Kenney.place(root, "pirate", "crate", Vector3(-2.0, 0, 4.0), 35.0, 1.0)
	Kenney.place(root, "town", "fence-broken", Vector3(3.5, 0, 5.0), 10.0, 2.6)


# ---- small pieces ---------------------------------------------------------------------------

static func _fire_at(at: Vector3, seed_v: float, s: float = 1.6) -> Node3D:
	var f := CampFire.new(seed_v)
	f.position = at
	f.scale = Vector3.ONE * s
	return f


static func _flag(root: Node3D, at: Vector3, s: float) -> void:
	Kenney.place(root, "pirate", "flag-pirate-high", at, 0.0, s)


static func _barrels(root: Node3D, at: Vector3, n: int, rng: RandomNumberGenerator) -> void:
	for i in n:
		Kenney.place(root, "pirate", "barrel", at + Vector3((i % 3) * 1.3, 0, (i / 3) * 1.3), rng.randf() * 360.0, 0.9)


static func _crates(root: Node3D, at: Vector3, n: int, rng: RandomNumberGenerator) -> void:
	for i in n:
		var y: float = 0.0 if i < 3 else 0.8
		Kenney.place(root, "pirate", "crate", at + Vector3((i % 3) * 1.3, y, 0), rng.randf_range(-15, 15), 1.0)


# ---- the harbour -----------------------------------------------------------------------------

## A pier running out along +z from the beach: a plank deck on posts, bollards, a lantern at the head and barrels.
static func pier(level: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Pier"
	root.set_meta("kind", "lagoon_pier")
	var length: float = float(LagoonData.PIER["length_m"][level - 1])
	var width: float = 5.0 + level
	var deck := TownBuilder.box(root, Vector3(width, 0.5, length), Vector3(0, 1.6, length * 0.5), Color("f1976c"))
	deck.material_override = Kenney.planks(Color("f1976c"), 0.45, true)
	var posts: int = int(length / 8.0) + 1
	for i in posts:
		var z: float = i * (length / float(posts - 1))
		for x in [-width * 0.5 + 0.3, width * 0.5 - 0.3]:
			TownBuilder.cyl(root, 0.28, 0.32, 5.5, Vector3(x, -0.8, z), Color("b06041"), 6)
			TownBuilder.cyl(root, 0.22, 0.22, 0.7, Vector3(x, 2.2, z), Color("38383d"), 6)
	Kenney.place(root, "town", "lantern", Vector3(width * 0.5 - 0.6, 1.85, length - 0.6), 0.0, 2.0)
	Kenney.place(root, "pirate", "barrel", Vector3(-width * 0.5 + 0.9, 1.85, length * 0.4), 0.0, 0.8)
	Kenney.place(root, "pirate", "crate", Vector3(-width * 0.5 + 1.0, 1.85, length * 0.4 + 1.5), 15.0, 0.9)
	if level >= 2:
		Kenney.place(root, "pirate", "structure-platform-dock", Vector3(0, 0.2, length + 2.0), 0.0, 2.4)
	return root


## The harbour office by the foot of the first pier: a blue-roofed house with an anchor sign, a notice board of
## missions for the residents and a crate of ship fittings.
static func office() -> Node3D:
	var root := Node3D.new()
	root.name = "HarbourOffice"
	root.set_meta("kind", "lagoon_office")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	TownBuilder.house(root, Vector3(0, 0, -1.0), 0.0, 9.0, 7.0, 1, ROOFS[2], rng)
	# the anchor sign over the door
	TownBuilder.box(root, Vector3(2.4, 1.3, 0.12), Vector3(0, 3.6, 2.6), Color("6794d9"))
	TownBuilder.box(root, Vector3(0.22, 0.9, 0.14), Vector3(0, 3.65, 2.68), Color("ffc044"))
	TownBuilder.box(root, Vector3(0.9, 0.18, 0.14), Vector3(0, 3.3, 2.68), Color("ffc044"))
	# the mission board on two posts
	for x in [3.4, 5.6]:
		TownBuilder.cyl(root, 0.12, 0.12, 2.6, Vector3(x, 1.3, 4.0), Color("b06041"), 6)
	TownBuilder.box(root, Vector3(2.6, 1.5, 0.15), Vector3(4.5, 2.0, 4.0), Color("b06041"))
	for i in 4:
		TownBuilder.box(root, Vector3(0.5, 0.6, 0.05), Vector3(3.7 + i * 0.55, 2.0 + 0.15 * (i % 2), 4.1), Color("fff2c4"))
	_crates(root, Vector3(-4.0, 0, 3.5), 3, rng)
	Kenney.place(root, "town", "lantern", Vector3(-1.8, 0, 3.2), 0.0, 2.2)
	return root


## A ship of the fleet as a still model: the Kenney hull of its class, scaled to its length, sitting at its waterline.
static func moored_ship(class_id: String) -> Node3D:
	var stats: ShipStats = PortService.ship_stats(class_id if ResourceLoader.exists("res://data/ships/%s.tres" % class_id) else "sloop")
	var model: String = ShipModel.model_for(stats, "player")
	var root := Node3D.new()
	root.name = "Moored"
	root.set_meta("kind", "lagoon_ship")
	var hull: Node3D = Kenney.spawn("pirate", model)
	var model_len: float = Kenney.merged("pirate", model).get_aabb().size.z
	var s: float = stats.length_m / maxf(model_len, 0.1)
	hull.scale = Vector3.ONE * s
	hull.position.y = -ShipModel.WATER_Y * s
	root.add_child(hull)
	return root


## The signpost on the empty atoll before it is claimed, with a rowboat pulled up on the sand.
static func claim_sign() -> Node3D:
	var root := Node3D.new()
	root.name = "ClaimSign"
	root.set_meta("kind", "lagoon_sign")
	Kenney.place(root, "nature", "sign", Vector3.ZERO, 0.0, 5.0)
	Kenney.place(root, "pirate", "boat-row-small", Vector3(4.0, 0.0, 3.0), 40.0, 2.0)
	_flag(root, Vector3(-3.0, 0, 0), 2.4)
	return root
