class_name IslandCamp
extends RefCounted
## A small settlement on an island's beach: thatched huts and tents round a camp fire, a drying rack of fish,
## barrels and crates, a beached rowboat, a flag, and people who sit by the fire or tend the huts. Placed on flat
## ground close to the shore, from the island's seed; larger islands may have a bigger village.

const MIN_RADIUS_M: float = 110.0
const CHANCE: float = 0.55
const BEACH_MIN_M: float = 1.0
const BEACH_MAX_M: float = 6.0
const MAX_SLOPE: float = 0.9


static func _mat(c: Color, _rough: float = 0.9) -> ShaderMaterial:
	return Kenney.flat(c)


## A flat beach spot for the settlement, or (0,0,NaN) y-flag when none: returns {"ok", "pos": Vector2, "h": float}.
static func find_site(isl: Island, rng: RandomNumberGenerator) -> Dictionary:
	for t in 300:
		var ang: float = rng.randf() * TAU
		var rad: float = isl.radius_m * rng.randf_range(0.4, 1.1)
		var p: Vector2 = Vector2.from_angle(ang) * rad
		var h: float = isl.ground_y(p)
		if h < BEACH_MIN_M or h > BEACH_MAX_M or (isl.keep_clear.is_valid() and isl.keep_clear.call(p)):
			continue
		var flat: bool = true
		for d in [Vector2(9, 0), Vector2(-9, 0), Vector2(0, 9), Vector2(0, -9)]:
			if absf(isl.ground_y(p + d) - h) > MAX_SLOPE * 3.0:
				flat = false
		if flat:
			return {"ok": true, "pos": p, "h": h}
	return {"ok": false}


static func wants_camp(isl: Island, rng: RandomNumberGenerator) -> bool:
	return isl.radius_m >= MIN_RADIUS_M and isl.biome != "ice" and rng.randf() < CHANCE


static func build(isl: Island, rng: RandomNumberGenerator) -> Node3D:
	var plan: Dictionary = plan_camp(isl, rng)
	if plan.is_empty():
		return null
	for job in plan["jobs"]:
		(job as Callable).call()
	return plan["root"]


## The camp as a root node already in the island plus the jobs that fill it, in the order that keeps the island's
## random numbers the same however they are spread over frames. Empty when the island has no camp.
static func plan_camp(isl: Island, rng: RandomNumberGenerator) -> Dictionary:
	if not wants_camp(isl, rng):
		return {}
	var site: Dictionary = find_site(isl, rng)
	if not bool(site["ok"]):
		return {}
	var root := Node3D.new()
	root.name = "Camp"
	var at: Vector2 = site["pos"]
	root.position = Vector3(at.x, float(site["h"]), at.y)
	isl.add_child(root)
	var big: bool = isl.radius_m > 220.0
	var h0: float = float(site["h"])
	var jobs: Array = []
	jobs.append(func() -> void:
		root.add_child(CampFire.new(rng.randf() * 10.0))
		var huts: int = rng.randi_range(2, 3) + (3 if big else 0)
		for i in huts:
			var a: float = TAU * i / huts + rng.randf_range(-0.3, 0.3)
			var d: float = rng.randf_range(7.0, 10.0)
			var pos := Vector3(cos(a) * d, 0.0, sin(a) * d)
			pos.y = isl.ground_y(at + Vector2(pos.x, pos.z)) - h0
			if pos.y < -0.4:
				continue
			_hut(root, pos, -a * 180.0 / PI + 90.0, rng))
	jobs.append(func() -> void:
		for i in rng.randi_range(1, 2):
			var a2: float = rng.randf() * TAU
			var pos2 := Vector3(cos(a2) * 5.5, 0.0, sin(a2) * 5.5)
			pos2.y = isl.ground_y(at + Vector2(pos2.x, pos2.z)) - h0
			_tent(root, pos2, rng.randf() * 360.0)
		_rack(root, Vector3(3.2, 0.0, -3.6), rng)
		for i in rng.randi_range(3, 5):
			var a3: float = rng.randf() * TAU
			var q := Vector3(cos(a3) * rng.randf_range(4.5, 6.0), 0.0, sin(a3) * rng.randf_range(4.5, 6.0))
			q.y = isl.ground_y(at + Vector2(q.x, q.z)) - h0
			if rng.randf() < 0.5:
				_barrel(root, q)
			else:
				_crate(root, q, rng.randf() * 90.0)
		_flag(root, Vector3(-4.0, 0.0, 4.0), rng)
		for k in 6:
			var fa: float = rng.randf() * TAU
			var fp := Vector3(cos(fa) * rng.randf_range(6.0, 12.0), 0.0, sin(fa) * rng.randf_range(6.0, 12.0))
			fp.y = isl.ground_y(at + Vector2(fp.x, fp.z)) - h0
			if fp.y > -0.3:
				Kenney.place(root, "nature", ["log_stack", "mushroom_redGroup", "flower_redA", "grass_large", "stone_largeA", "log"][k], fp, rng.randf() * 360.0, 5.0)
		_boat(root, Vector3(-9.0, -0.3, -5.0), rng.randf() * 360.0))
	jobs.append(func() -> void: _people(root, rng, big))
	return {"root": root, "jobs": jobs}


static func _hut(root: Node3D, at: Vector3, yaw: float, rng: RandomNumberGenerator) -> void:
	var h := Node3D.new()
	h.name = "Hut"
	h.position = at
	h.rotation_degrees.y = yaw
	h.scale = Vector3.ONE * rng.randf_range(1.25, 1.55)
	root.add_child(h)
	Kenney.place(h, "pirate", "structure", Vector3.ZERO, 0.0, 1.0)
	var roof: Node3D = Kenney.place(h, "pirate", "structure-roof", Vector3.ZERO, 0.0, 1.0)
	roof.name = "Roof"
	Kenney.place(h, "pirate", "structure-platform", Vector3(0, -0.5, 0), 0.0, 1.0).scale = Vector3(1.0, 0.5, 1.0)


static func _tent(root: Node3D, at: Vector3, yaw: float) -> void:
	var t := Node3D.new()
	t.name = "Tent"
	t.position = at
	t.rotation_degrees.y = yaw
	root.add_child(t)
	Kenney.place(t, "forest", "tent", Vector3.ZERO, 0.0, 2.4)


static func _rack(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	var r := Node3D.new()
	r.name = "FishRack"
	r.position = at
	root.add_child(r)
	var wood: ShaderMaterial = _mat(Color(0.35, 0.23, 0.12))
	for x in [-1.1, 1.1]:
		DeckArt.add_mesh(r, DeckArt.cyl(0.05, 0.06, 1.6, 6), wood, Vector3(x, 0.8, 0), Vector3(0, 0, x * 4.0))
	DeckArt.add_mesh(r, DeckArt.cyl(0.04, 0.04, 2.4, 6), wood, Vector3(0, 1.5, 0), Vector3(0, 0, 90))
	var fish: ShaderMaterial = _mat(Color(0.65, 0.68, 0.7), 0.4)
	for i in 6:
		var f := DeckArt.add_mesh(r, _ellipsoid(0.07, 0.32), fish, Vector3(-0.95 + i * 0.38, 1.3, 0), Vector3(0, rng.randf_range(-20, 20), 0))
		f.scale = Vector3(0.6, 1.0, 1.0)


static func _ellipsoid(r: float, h: float) -> Mesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = 8
	s.rings = 4
	return s


static func _barrel(root: Node3D, at: Vector3) -> void:
	Kenney.place(root, "pirate", "barrel", at, at.x * 53.0, 0.6)


static func _crate(root: Node3D, at: Vector3, yaw: float) -> void:
	Kenney.place(root, "pirate", "crate", at, yaw, 0.75)


static func _flag(root: Node3D, at: Vector3, rng: RandomNumberGenerator) -> void:
	DeckArt.add_mesh(root, DeckArt.cyl(0.07, 0.1, 5.0, 6), _mat(Color(0.69, 0.38, 0.25)), at + Vector3(0, 2.5, 0))
	var models: Array[String] = ["flag-pirate", "flag", "flag-pennant"]
	var cloth: Node3D = Kenney.place(root, "pirate", models[rng.randi_range(0, 2)], at + Vector3(0, 3.2, 0), 0.0, 1.3)
	cloth.name = "Flag"


static func _boat(root: Node3D, at: Vector3, yaw: float) -> void:
	var b := Node3D.new()
	b.name = "Rowboat"
	b.position = at
	b.rotation_degrees = Vector3(0, yaw, 4)
	root.add_child(b)
	Kenney.place(b, "pirate", "boat-row-small", Vector3(0, 0.2, 0), 0.0, 1.0)


## A few villagers: some sit round the fire facing it, one stands near a hut. The same figures as the crew,
## in plain clothes and without weapons drawn.
static func _people(root: Node3D, rng: RandomNumberGenerator, big: bool) -> void:
	var n: int = rng.randi_range(3, 5) + (3 if big else 0)
	for i in n:
		var a: float = TAU * i / n + rng.randf_range(-0.2, 0.2)
		var d: float = rng.randf_range(2.2, 3.2) if i < n - 1 else rng.randf_range(5.0, 7.0)
		var f := FighterState.new()
		f.id = 90 + i * 13 + rng.randi_range(0, 50)
		f.kind = "sailor" if i % 2 == 0 else "crew"
		f.melee = "dagger"
		f.pos = Vector2.ZERO
		f.dir = Vector2(-cos(a), -sin(a))
		var v := DeckFighterView.new()
		v.fighter = f
		v.show_label = false
		v.pose_idle_only = true
		var holder := Node3D.new()
		holder.name = "Villager"
		holder.set_meta("kind", "villager")
		holder.position = Vector3(cos(a) * d, 0.0, sin(a) * d)
		holder.add_child(v)
		root.add_child(holder)
