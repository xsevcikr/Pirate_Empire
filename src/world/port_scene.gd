class_name PortScene
extends Node3D
## The harbour of a city: a pier running from the dock point to the shore, and on the shore a walled town on level
## ground: a sea wall with a gate and cannon towers, a harbour road of warehouses, a main street up from the gate to a
## market square, cross streets lined with houses in the faction's style (more streets in bigger cities), a church,
## stalls and a well, and townsfolk walking the streets. The town stands on its own stone-rimmed ground, so nothing
## stands over the water. Every building is destructible; what the save says was destroyed stays a ruin until it is
## rebuilt.

signal building_destroyed(building: DestructibleBuilding, by_player: bool)

const PIER_WIDTH_M: float = 6.0
const PIER_HEIGHT_M: float = 1.4
const WOOD := Color(0.36, 0.24, 0.14)
const SEGMENT_W_M: Array[float] = [12.0, 11.0, 10.0]
const TOWN_HALF_BY_TIER: Dictionary = {"village": 28.0, "town": 34.0, "city": 40.0, "capital": 48.0}
const TOWN_H_M: float = 1.6  ## top of the town ground, level with the pier deck
const STREET_HALF_M: float = 3.5
const HOUSE_DEPTH_M: float = 7.5
const HOUSE_RUN_M: float = 8.5  ## a house front is about this long; a street side is shared out evenly
const SQUARE_HALF_M: float = 9.0
const FOLK_BY_TIER: Dictionary = {"village": 6, "town": 9, "city": 12, "capital": 16}
const BUILD_PER_STEP: int = 8  ## houses put up per streamed frame
const GROUND_COL := Color(0.78, 0.72, 0.56)
const STREET_COL := Color(0.62, 0.6, 0.64)

var port_id: String = PortData.START_PORT
var world: Node
var buildings: Array[DestructibleBuilding] = []
var fort_level: int = 1
var staged: bool = false
var _fort_built: bool = false
var _style: Dictionary = {}
var _town: Dictionary = {}  ## see town_frame(); plus "z": local z of the town centre
var _jobs: Array[Callable] = []
var _plan: Array[Dictionary] = []
var walkers: Array[TownWalker] = []


## Fort level of a port: capitals of the great powers 3, other capitals 2, everyone else 1.
static func fort_level_of(port: Dictionary) -> int:
	if port["tier"] == "capital":
		return 3 if port["faction"] in ["navy", "iron_dominion"] else 2
	if port["tier"] == "city" and port["faction"] in ["navy", "iron_dominion"]:
		return 2
	return 1


## Where the town of a port stands, worked out from the island's real coastline: "coast" is how far from the dock
## along the pier the ground first rises out of the sea, "half" the half-size of the square town ground, "centre"
## the town centre in island-local metres. Without an island it falls back on the island's radius.
static func town_frame(id: String, isl: Island) -> Dictionary:
	var port: Dictionary = PortData.PORTS[id]
	var dock: Vector2 = port["dock"]
	var info: Dictionary = PortData.gen().islands[port["island"]]
	var centre: Vector2 = info["pos"]
	var to: Vector2 = centre - dock
	var dist: float = to.length()
	var dir: Vector2 = to / maxf(dist, 0.001)
	var half: float = float(TOWN_HALF_BY_TIER.get(port["tier"], 32.0))
	var coast: float = maxf(dist - float(info["radius"]) * 0.85, 40.0)
	if isl != null:
		var t: float = 20.0
		while t < dist and isl.ground_y(dock + dir * t - centre) < Island.SHORE_H:
			t += 2.0
		coast = clampf(t, 40.0, dist - half * 1.2)
	return {"coast": coast, "half": half, "centre": dock + dir * (coast - 2.0 + half) - centre}


## Levels the ground the town will stand on before the island builds its mesh: hills inside the town are cut down to
## the town's height, the sea floor is left alone, and no trees or camp grow there.
static func shape_island(isl: Island, id: String) -> void:
	var f: Dictionary = town_frame(id, isl)
	isl.set_meta("town_frame", f)
	var c: Vector2 = f["centre"]
	var half: float = f["half"]
	isl.pad_center = c
	isl.pad_radius = half * 1.45
	isl.pad_blend = 30.0
	isl.pad_h = TOWN_H_M
	isl.pad_cut_only = true
	isl.keep_clear = func(local: Vector2) -> bool: return local.distance_to(c) < half * 1.6


func _ready() -> void:
	var port: Dictionary = PortData.PORTS[port_id]
	var dock: Vector2 = port["dock"]
	var isl: Dictionary = PortData.gen().islands[port["island"]]
	var to_island: Vector2 = (isl["pos"] as Vector2) - dock
	position = Vector3(dock.x, 0.0, dock.y)
	rotation.y = atan2(-to_island.x, -to_island.y)  # local -z points at the island
	_style = IslandData.style(port["faction"])
	fort_level = fort_level_of(port)
	var node: Island = _island_node()
	_town = node.get_meta("town_frame") if node != null and node.has_meta("town_frame") else town_frame(port_id, node)
	var coast: float = _town["coast"]
	_town["z"] = -(coast - 2.0 + float(_town["half"]))
	# the pier runs from the dock to the town's sea wall
	var length: float = coast - 4.0
	_make("dock", 0, Vector3(0, PIER_HEIGHT_M - 0.2, -length * 0.5 - 6.0), Vector3(PIER_WIDTH_M, 0.4, length), WOOD, WOOD)
	for i in 8:
		var z: float = -6.0 - float(i) * length / 7.0
		_post(Vector3(PIER_WIDTH_M * 0.5 - 0.3, PIER_HEIGHT_M - 1.2, z))
		_post(Vector3(-PIER_WIDTH_M * 0.5 + 0.3, PIER_HEIGHT_M - 1.2, z))
	var crane_at := Vector3(PIER_WIDTH_M * 0.5 + 2.5, PIER_HEIGHT_M, -length * 0.25)
	_footing(crane_at, Vector2(3.0, 3.0))
	_make("crane", 0, crane_at, Vector3(1.6, 12.0, 1.6), WOOD.darkened(0.2), WOOD)
	_flag(_style["flag"], Vector3(PIER_WIDTH_M * 0.5, PIER_HEIGHT_M, -length * 0.5))
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0, PIER_HEIGHT_M + 4.0, -8.0)
	lantern.light_color = Color(1.0, 0.75, 0.4)
	lantern.omni_range = 40.0
	add_child(lantern)
	_post(Vector3(0, PIER_HEIGHT_M + 2.0, -8.0), Vector3(0.4, 4.0, 0.4))
	_build_ground()
	_plan = plan_town(port_id, float(_town["half"]), port["tier"])
	_jobs.append(build_fort)
	for k in range(0, _plan.size(), BUILD_PER_STEP):
		_jobs.append(_build_houses.bind(k, mini(k + BUILD_PER_STEP, _plan.size())))
	_jobs.append(_build_square)
	_jobs.append(_spawn_folk)
	if not staged:
		while build_next():
			pass


## One more slice of the harbour; false once it is all up. The streamer calls this once a frame.
func build_next() -> bool:
	if _jobs.is_empty():
		return false
	(_jobs.pop_front() as Callable).call()
	return not _jobs.is_empty()


## The fort goes up on its own frame when the streamer builds the harbour, so a port never costs one long frame.
func build_fort() -> void:
	if _fort_built:
		return
	_fort_built = true
	_build_fort()


func _island_node() -> Island:
	var parent: Node = get_parent()
	if parent == null:
		return null
	var isl: Island = parent.get_node_or_null("Island_%d" % int(PortData.PORTS[port_id]["island"])) as Island
	if isl == null or not isl.is_inside_tree():
		return null
	return isl


func _island_ground(local: Vector3) -> float:
	var isl: Island = _island_node()
	if isl == null:
		return 0.0
	var world_p: Vector3 = to_global(local)
	return maxf(isl.ground_y(Vector2(world_p.x - isl.global_position.x, world_p.z - isl.global_position.z)), 0.0)


## Local position of a point given in town coordinates: u across, v towards the sea from the town centre.
func town_point(u: float, v: float, y: float = TOWN_H_M) -> Vector3:
	return Vector3(u, y, float(_town["z"]) + v)


func on_town_ground(local: Vector3) -> bool:
	var half: float = _town["half"]
	return absf(local.x) <= half and absf(local.z - float(_town["z"])) <= half


## Ground under a local point: the town's level ground on it, the island (or the sea floor at 0) off it.
func ground_at(local: Vector3) -> float:
	return TOWN_H_M if on_town_ground(local) else _island_ground(local)


## A stone block under something that stands off the town ground, down into the sea floor, so it never floats.
func _footing(at: Vector3, size: Vector2) -> void:
	if on_town_ground(at):
		return
	var depth: float = at.y + 5.0
	_box(Vector3(size.x, depth, size.y), Vector3(at.x, at.y - depth * 0.5, at.z), TownBuilder.STONE.darkened(0.1))


## The town's level ground: a stone-rimmed platform from the sea floor up to the town's height, earth on top,
## cobbled streets and the market square.
func _build_ground() -> void:
	var half: float = _town["half"]
	_box(Vector3(half * 2.0, TOWN_H_M + 6.0, half * 2.0), town_point(0, 0, TOWN_H_M - (TOWN_H_M + 6.0) * 0.5 - 0.02), TownBuilder.STONE).name = "TownGround"
	_box(Vector3(half * 2.0 - 1.6, 0.1, half * 2.0 - 1.6), town_point(0, 0, TOWN_H_M + 0.01), GROUND_COL)
	var st: Dictionary = streets(port_id, half, PortData.PORTS[port_id]["tier"])
	for u: float in st["u"]:
		_box(Vector3(STREET_HALF_M * 2.0, 0.08, half * 2.0 - 1.6), town_point(u, 0, TOWN_H_M + 0.05), STREET_COL)
	for v: float in st["v"]:
		_box(Vector3(half * 2.0 - 1.6, 0.08, STREET_HALF_M * 2.0), town_point(0, v, TOWN_H_M + 0.05), STREET_COL)
	_box(Vector3(SQUARE_HALF_M * 2.0, 0.08, SQUARE_HALF_M * 2.0), town_point(0, 0, TOWN_H_M + 0.06), STREET_COL.lightened(0.12))


## The streets of a town: "u" the across-positions of streets running inland, "v" the positions of cross streets.
## Every town has a main street from the gate and a harbour road behind the sea wall and a cross street through the
## square; cities and capitals get two more streets inland and another cross street.
static func streets(_id: String, half: float, tier: String) -> Dictionary:
	var us: Array[float] = [0.0]
	if tier in ["city", "capital"]:
		us = [-half * 0.55, 0.0, half * 0.55]
	var vs: Array[float] = [0.0, half - 9.0]
	if tier in ["city", "capital"]:
		vs = [-half * 0.5, 0.0, half - 9.0]
	return {"u": us, "v": vs}


## Every house of the town as {kind, u, v, w, d, h, yaw}: the blocks between the streets are lined with houses facing
## the streets (warehouses on the harbour road), leaving the market square open. Pure, so tests can check it.
static func plan_town(id: String, half: float, tier: String) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = id.hash() * 13 + 5
	var st: Dictionary = streets(id, half, tier)
	var us: Array[float] = st["u"]
	var vs: Array[float] = st["v"]
	var wall_v: float = half - 5.5  # the sea wall's inner face
	var harbour_v: float = vs[vs.size() - 1]
	var out: Array[Dictionary] = []
	for i in us.size() + 1:
		var u0: float = -half + 1.0 if i == 0 else us[i - 1] + STREET_HALF_M
		var u1: float = half - 1.0 if i == us.size() else us[i] - STREET_HALF_M
		for j in vs.size() + 1:
			var v0: float = -half + 1.0 if j == 0 else vs[j - 1] + STREET_HALF_M
			var v1: float = wall_v if j == vs.size() else vs[j] - STREET_HALF_M
			if u1 - u0 < 6.0 or v1 - v0 < 6.0:
				continue
			var on_harbour: bool = j < vs.size() and is_equal_approx(vs[j], harbour_v)
			_fill_block(out, rng, u0, u1, v0, v1, true, true, true, j < vs.size(), on_harbour)
	return out


## Lines one block with houses along its sides, fronts outwards (-u, +u, -v, +v as `left`/`right`/`back`/`front`
## allow): onto a street, or at the town's edge onto the fields. The side against the sea wall stays a yard.
static func _fill_block(out: Array[Dictionary], rng: RandomNumberGenerator, u0: float, u1: float, v0: float, v1: float,
		left: bool, right: bool, back: bool, front: bool, harbour: bool) -> void:
	var d: float = minf(HOUSE_DEPTH_M, (v1 - v0) * 0.5) if front and back else minf(HOUSE_DEPTH_M, v1 - v0)
	var rows: Array = []  # [axis "u"/"v", from, to, fixed coordinate, yaw]
	if front:
		rows.append(["u", u0, u1, v1 - d * 0.5, 0.0])
	if back:
		rows.append(["u", u0, u1, v0 + d * 0.5, 180.0])
	var sv0: float = v0 + (d if back else 0.0)
	var sv1: float = v1 - (d if front else 0.0)
	if u1 - u0 >= HOUSE_DEPTH_M * 2.0:
		if left:
			rows.append(["v", sv0, sv1, u0 + HOUSE_DEPTH_M * 0.5, -90.0])
		if right:
			rows.append(["v", sv0, sv1, u1 - HOUSE_DEPTH_M * 0.5, 90.0])
	for r: Array in rows:
		var run: float = float(r[2]) - float(r[1])
		if run < 6.0:
			continue
		var n: int = maxi(int(round(run / HOUSE_RUN_M)), 1)
		var w: float = run / float(n)
		for k in n:
			var c: float = float(r[1]) + (k + 0.5) * w
			var u: float = c if r[0] == "u" else float(r[3])
			var v: float = float(r[3]) if r[0] == "u" else c
			var depth: float = d if r[0] == "u" else HOUSE_DEPTH_M
			if absf(u) < SQUARE_HALF_M + w * 0.5 and absf(v) < SQUARE_HALF_M + depth * 0.5:
				continue  # the market square
			var wh: bool = harbour and r[0] == "u" and float(r[4]) == 0.0
			out.append({"kind": "warehouse" if wh else "house", "u": u, "v": v, "w": w - 0.8, "d": depth - 0.6,
				"h": rng.randf_range(6.0, 7.0) if wh else rng.randf_range(4.2, 6.5), "yaw": float(r[4])})


func _build_houses(from: int, to: int) -> void:
	var counts: Dictionary = {"house": 0, "warehouse": 0}
	for k in from:
		counts[_plan[k]["kind"]] = int(counts[_plan[k]["kind"]]) + 1
	for k in range(from, to):
		var h: Dictionary = _plan[k]
		var kind: String = h["kind"]
		var b: DestructibleBuilding = _make(kind, int(counts[kind]), town_point(float(h["u"]), float(h["v"])), Vector3(float(h["w"]), float(h["h"]), float(h["d"])),
			(_style["wall"] as Color).lightened(0.05 * float(k % 4)).darkened(0.22 if kind == "warehouse" else 0.08), _style["roof"], 1, true)
		b.rotation_degrees.y = float(h["yaw"])
		counts[kind] = int(counts[kind]) + 1


## The square: a well, market stalls, lanterns, and in cities a church on the inland side.
func _build_square() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = port_id.hash() + 41
	var sq := Node3D.new()
	sq.name = "Square"
	sq.position = town_point(0, 0)
	add_child(sq)
	TownBuilder.well(sq, Vector3.ZERO)
	for i in 4:
		var a: float = TAU * (float(i) + 0.5) / 4.0
		TownBuilder.stall(sq, Vector3(cos(a) * 6.0, 0.0, sin(a) * 6.0), -rad_to_deg(a) - 90.0, rng)
	for i in 4:
		var a2: float = TAU * float(i) / 4.0 + PI * 0.25
		Kenney.place(sq, "town", "lantern", Vector3(cos(a2) * 8.4, 0.0, sin(a2) * 8.4), 0.0, 2.0)
	var port: Dictionary = PortData.PORTS[port_id]
	if port["tier"] in ["city", "capital"] or fort_level >= 2:
		var tower_v: float = -float(_town["half"]) + 4.0
		var spire := Node3D.new()
		spire.name = "ChurchSpire"
		spire.position = town_point(0, tower_v)
		add_child(spire)
		TownBuilder.round_tower(spire, Vector3.ZERO, 3.0, 14.0, _style["flag"])
	if port["tier"] in ["capital", "city"]:
		var half: float = _town["half"]
		var span: float = float(DestructionData.WALL_SEGMENTS[fort_level - 1] / 2 + 1) * SEGMENT_W_M[fort_level - 1]
		var lh: Vector3 = town_point(-(span + 12.0), half - 3.5, 0.0)
		lh.y = ground_at(lh)
		_footing(lh, Vector2(7.0, 7.0))
		_make("lighthouse", 0, lh, Vector3(5.0, 22.0, 5.0), Color(0.86, 0.84, 0.78), Color(0.6, 0.2, 0.15))


## Townsfolk who walk between the square and the two streets through it, so nobody walks through a house.
func _spawn_folk() -> void:
	var port: Dictionary = PortData.PORTS[port_id]
	var half: float = _town["half"]
	var folk := Node3D.new()
	folk.name = "Folk"
	folk.position = town_point(0, 0)
	add_child(folk)
	var spots: Array[Vector3] = []
	for k in 5:
		var t: float = -half + 4.0 + float(k) * (half * 2.0 - 14.0) / 4.0
		spots.append(Vector3(rng_jitter(k), 0.0, t))
		spots.append(Vector3(t, 0.0, rng_jitter(k + 7)))
	var n: int = int(FOLK_BY_TIER.get(port["tier"], 8))
	for i in n:
		var w := TownWalker.new()
		w.setup(DockDistrict.PEOPLE[i % DockDistrict.PEOPLE.size()], 300 + i * 13, spots, port_id.hash() + i * 53)
		w.hub_routing = true
		w.hub = Vector3.ZERO
		w.set_meta("kind", "townsfolk")
		folk.add_child(w)
		walkers.append(w)


## A small across-street offset so walkers keep to either side of the street, not its centre line.
static func rng_jitter(k: int) -> float:
	return (1.6 if k % 2 == 0 else -1.6)


## A sea wall of segments along the town's waterfront, the gate where the pier lands, cannon towers at each end.
## Wall pieces past the town ground stand on stone footings on the beach or in the shallows.
func _build_fort() -> void:
	var n: int = DestructionData.WALL_SEGMENTS[fort_level - 1]
	var w: float = SEGMENT_W_M[fort_level - 1]
	var v: float = float(_town["half"]) - 3.5
	var wall_col: Color = (_style["wall"] as Color).darkened(0.3)
	for i in n:
		var x: float = float(i - n / 2) * w  # the gate stands across the main street where the pier lands
		var gate: bool = i == n / 2
		var at: Vector3 = town_point(x, v, 0.0)
		at.y = ground_at(at)
		_footing(at, Vector2(w, 3.0))
		_make("gate" if gate else "wall", i, at, Vector3(w, 7.0 if gate else 6.0, 3.0), wall_col, wall_col, fort_level)
	var left: float = -(float(n / 2) + 0.5) * w - 3.0
	var right: float = (float(n - n / 2) - 0.5) * w + 3.0
	var towers: Array[float] = [left, right]
	if fort_level >= 2:
		towers.append_array([left * 0.5, right * 0.5])
	for i in towers.size():
		var at2: Vector3 = town_point(towers[i], v, 0.0)
		at2.y = ground_at(at2)
		_footing(at2, Vector2(7.0, 7.0))
		_make("tower", i, at2, Vector3(6.0, 11.0, 6.0), wall_col.darkened(0.1), wall_col)


func _make(kind: String, idx: int, at: Vector3, size: Vector3, wall: Color, roof: Color, level: int = 1, light: bool = false) -> DestructibleBuilding:
	var b: DestructibleBuilding = CannonTower.new() if kind == "tower" else DestructibleBuilding.new()
	var id: String = "%s:%s:%d" % [port_id, kind, idx]
	b.setup(kind, level, id, port_id, size, wall, roof)
	b.light_dress = light
	b.position = at
	if Session.has_state() and Session.state.get("destroyed", {}).has(id):
		b.is_ruin = true
	if b is CannonTower:
		(b as CannonTower).world = world
	add_child(b)
	buildings.append(b)
	b.destroyed.connect(func(bb: DestructibleBuilding, by_player: bool) -> void:
		if Session.has_state():
			Session.state["destroyed"][bb.building_id] = int(Session.state["day"])
		building_destroyed.emit(bb, by_player))
	return b


## Bring back buildings whose three days are up.
func rebuild_due() -> int:
	var n: int = 0
	for b in buildings:
		if b.is_ruin and not (Session.state.get("destroyed", {}).has(b.building_id)):
			b.rebuild()
			n += 1
	return n


func _post(pos: Vector3, sz: Vector3 = Vector3(0.5, 3.0, 0.5)) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = sz
	mi.mesh = mesh
	mi.material_override = _mat(WOOD)
	mi.position = pos
	add_child(mi)


func _flag(color: Color, base: Vector3) -> void:
	_post(base + Vector3(0, 5.5, 0), Vector3(0.3, 11.0, 0.3))
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 2.2, 3.4)
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = base + Vector3(0, 9.6, 1.8)
	add_child(mi)


func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = DeckArt.box(size)
	mi.material_override = _mat(color)
	mi.position = at
	add_child(mi)
	return mi


func _mat(color: Color) -> ShaderMaterial:
	return Kenney.flat(Look.cartoon(color))
