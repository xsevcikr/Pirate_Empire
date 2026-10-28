class_name LandingSite
extends RefCounted
## The beach landing of an island without a harbour: a short plank jetty at the waterline, a rowboat pulled up on
## the sand, a sign, a lantern post and props that say what kind of place it is (a prison tower, temple ruins,
## a wreck on the beach, ice, a hot spring's steaming rocks). Built facing the island's anchorage.

const JETTY_SCALE: float = 3.2
const JETTY_PIECE_M: float = 2.5  ## model length of one Kenney dock piece


const MODELS: Array = [
	["pirate", "structure-platform-dock-small"], ["pirate", "structure-platform-dock"], ["pirate", "boat-row-small"], ["nature", "sign"],
	["castle", "tower-square-base"], ["castle", "tower-square-mid-windows"], ["castle", "tower-square-mid"], ["castle", "tower-square-top-roof"],
	["castle", "tower-square-mid-door"], ["castle", "tower-square-top-roof-high"], ["castle", "wall"], ["castle", "wall-half"], ["castle", "rocks-large"],
	["nature", "statue_column"], ["nature", "statue_columnDamaged"], ["nature", "statue_head"], ["nature", "statue_obelisk"], ["nature", "tent_smallClosed"],
	["pirate", "ship-wreck"], ["pirate", "barrel"], ["pirate", "crate"], ["pirate", "chest"], ["pirate", "palm-bend"], ["pirate", "palm-straight"],
]


## Loads every model a landing uses while the world loads, so a landing streaming in never stalls a frame.
static func prewarm() -> void:
	for m: Array in MODELS:
		Kenney.scene(m[0], m[1])


## Builds the landing on `isl` (an Island already in the tree) for island `index` at once; returns its root or null.
static func build(isl: Island, g: WorldGen, index: int) -> Node3D:
	var plan: Dictionary = plan_site(isl, g, index)
	if plan.is_empty():
		return null
	for job: Callable in plan["jobs"]:
		job.call()
	return plan["root"]


## The landing's root, already on the island, and the jobs that fill it: the streamer runs one job a frame.
static func plan_site(isl: Island, g: WorldGen, index: int) -> Dictionary:
	var info: Dictionary = g.islands[index]
	if not Landings.has_landing(info):
		return {}
	var dir: Vector2 = Vector2.from_angle(Landings.angle(g, index))
	# walk in from the sea to the first dry sand
	var rad: float = isl.radius_m * 1.25
	while rad > 4.0 and isl.ground_y(dir * rad) < Island.SHORE_H:
		rad -= 2.0
	var shore: Vector2 = dir * rad
	var root := Node3D.new()
	root.name = "Landing"
	root.set_meta("kind", "landing")
	root.set_meta("landing", Landings.kind_of(info))
	root.position = Vector3(shore.x, 0.0, shore.y)
	root.rotation.y = atan2(dir.x, dir.y)  # local +z points out to sea
	isl.add_child(root)
	var ground: Callable = func(local: Vector3) -> float:
		var w: Vector3 = root.transform * local
		return maxf(isl.ground_y(Vector2(w.x, w.z)), 0.0)
	var jobs: Array[Callable] = [_jetty.bind(root, ground), _props.bind(root, ground, Landings.kind_of(info))]
	return {"root": root, "jobs": jobs}


## The jetty from the sand out over the water, the rowboat, the sign and the lantern.
static func _jetty(root: Node3D, ground: Callable) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():  # the island streamed out first
		return
	for i in 4:
		var at := Vector3(0, 0.35, -4.0 + float(i) * JETTY_PIECE_M * JETTY_SCALE)
		var plank: Node3D = Kenney.place(root, "pirate", "structure-platform-dock-small" if i < 3 else "structure-platform-dock", at, 0.0, JETTY_SCALE)
		plank.set_meta("kind", "jetty")
	var boat: Node3D = Kenney.place(root, "pirate", "boat-row-small", Vector3(8.0, ground.call(Vector3(8.0, 0, -3.0)) + 0.1, -3.0), 70.0, 2.4)
	boat.rotation_degrees.z = 6.0
	boat.set_meta("kind", "rowboat")
	var sign_at := Vector3(-6.0, 0.0, -7.0)
	sign_at.y = ground.call(sign_at)
	Kenney.place(root, "nature", "sign", sign_at, 200.0, 7.0)
	_lantern(root, Vector3(-2.6, 0.35 + 1.3 * JETTY_SCALE * 0.5, -4.0 + JETTY_PIECE_M * JETTY_SCALE * 3.4))


## What kind of place it is.
static func _props(root: Node3D, ground: Callable, kind: String) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():  # the island streamed out first
		return
	match kind:
		"prison":
			_stack(root, ground, Vector3(-14.0, 0, -18.0), ["tower-square-base", "tower-square-mid-windows", "tower-square-mid", "tower-square-top-roof"], 6.0)
			_row(root, ground, "castle", "wall", Vector3(-8.0, 0, -18.0), 3, Vector3(6.0, 0, 0), 6.0)
		"ruins":
			for p in [Vector3(-12, 0, -14), Vector3(-5, 0, -19), Vector3(5, 0, -17), Vector3(12, 0, -13)]:
				_piece(root, ground, "nature", "statue_columnDamaged" if int(p.x) % 2 == 0 else "statue_column", p, 8.0, p.x * 9.0)
			_piece(root, ground, "nature", "statue_head", Vector3(0, 0, -12), 7.0, 160.0)
		"chapel":
			_stack(root, ground, Vector3(-10.0, 0, -16.0), ["tower-square-base", "tower-square-mid-door", "tower-square-top-roof-high"], 5.5)
			_piece(root, ground, "castle", "wall-half", Vector3(-3.0, 0, -16.0), 5.5, 0.0)
			_piece(root, ground, "nature", "statue_obelisk", Vector3(7.0, 0, -12.0), 7.0, 0.0)
		"volcano":
			for p in [Vector3(-9, 0, -9), Vector3(-5, 0, -13), Vector3(7, 0, -10)]:
				_piece(root, ground, "castle", "rocks-large", p, 7.0, p.z * 20.0)
			root.add_child(CampFire.new(1.0))
			root.get_child(root.get_child_count() - 1).position = Vector3(0, ground.call(Vector3(0, 0, -9)), -9)
		"wreck":
			var w: Node3D = _piece(root, ground, "pirate", "ship-wreck", Vector3(-14.0, 0, -6.0), 2.0, 40.0)
			w.rotation_degrees.z = 12.0
			_piece(root, ground, "pirate", "barrel", Vector3(-6.0, 0, -6.0), 1.4, 30.0)
			_piece(root, ground, "pirate", "crate", Vector3(-8.0, 0, -8.5), 1.6, 10.0)
		"ice":
			for p in [Vector3(-8, 0, -10), Vector3(8, 0, -12), Vector3(0, 0, -16)]:
				var r: Node3D = _piece(root, ground, "castle", "rocks-large", p, 8.0, p.x * 11.0)
				r.set_meta("ice", true)
			_piece(root, ground, "nature", "tent_smallClosed", Vector3(-4.0, 0, -10.0), 6.0, 20.0)
		"atoll":
			_piece(root, ground, "pirate", "palm-bend", Vector3(-8.0, 0, -8.0), 2.0, 20.0)
			_piece(root, ground, "pirate", "palm-straight", Vector3(8.0, 0, -10.0), 2.2, 80.0)
			_piece(root, ground, "pirate", "ship-wreck", Vector3(14.0, 0, -4.0), 1.4, -60.0)
			_piece(root, ground, "pirate", "chest", Vector3(-3.0, 0, -9.0), 1.6, 15.0)


static func _piece(root: Node3D, ground: Callable, kit: String, model: String, at: Vector3, s: float, yaw: float) -> Node3D:
	at.y = ground.call(at)
	var n: Node3D = Kenney.place(root, kit, model, at, yaw, s)
	n.set_meta("kind", "landing_prop")
	return n


static func _stack(root: Node3D, ground: Callable, at: Vector3, models: Array, s: float) -> void:
	var y: float = ground.call(at)
	for i in models.size():
		var n: Node3D = Kenney.place(root, "castle", str(models[i]), Vector3(at.x, y + float(i) * s, at.z), 0.0, s)
		n.set_meta("kind", "landing_prop")


static func _row(root: Node3D, ground: Callable, kit: String, model: String, at: Vector3, n: int, step: Vector3, s: float) -> void:
	for i in n:
		_piece(root, ground, kit, model, at + step * float(i), s, 0.0)


static func _lantern(root: Node3D, at: Vector3) -> void:
	DeckArt.add_mesh(root, DeckArt.cyl(0.08, 0.1, 3.2, 6), Kenney.flat(Color(0.36, 0.24, 0.14)), at + Vector3(0, 1.6, 0))
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	lamp.mesh = sm
	lamp.material_override = Kenney.flat(Color(1.0, 0.78, 0.35), 2.0)
	lamp.position = at + Vector3(0, 3.3, 0)
	root.add_child(lamp)
