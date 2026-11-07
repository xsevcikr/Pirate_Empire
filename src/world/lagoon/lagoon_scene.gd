class_name LagoonScene
extends Node3D
## The lagoon on Skull Atoll as the save state describes it: the captain's hall, a model on every built plot, the
## piers with the fleet lying alongside, the ships waiting at anchor, a boardwalk to the beach and the pirates who
## live there walking about. sync() compares the state with what stands and only builds what changed, a few pieces
## a frame, so placing a hut in build mode never rebuilds the whole lagoon.

const BUILD_BUDGET_US: int = 3500
const ANCHOR_SLOTS: int = 8

var island: Island
var state: Dictionary = {}
var _nodes: Dictionary = {}  ## key -> Node3D
var _sigs: Dictionary = {}  ## key -> signature of what the node shows
var _jobs: Array[Array] = []  ## [key, sig, Callable returning the node]
var _walkers: Array[TownWalker] = []
var _walker_root: Node3D
var _t: float = 0.0


func _ready() -> void:
	name = "Lagoon"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_walker_root = Node3D.new()
	_walker_root.name = "Villagers"
	add_child(_walker_root)
	sync()


## Island-local ground point of a plot.
func cell_pos(c: Vector2i) -> Vector3:
	var p: Vector2 = LagoonData.cell_local(c)
	return Vector3(p.x, island.ground_y(p) if island != null else LagoonData.PAD_H_M, p.y)


## Bring the models in line with the state. Cheap when nothing changed.
func sync() -> void:
	var want: Dictionary = _wanted()
	for key: String in _nodes.keys():
		if not want.has(key) or want[key][0] != _sigs[key]:
			_nodes[key].queue_free()
			_nodes.erase(key)
			_sigs.erase(key)
	_jobs = _jobs.filter(func(j: Array) -> bool: return want.has(j[0]) and want[j[0]][0] == j[1])
	var queued: Dictionary = {}
	for j in _jobs:
		queued[j[0]] = true
	for key: String in want:
		if not _nodes.has(key) and not queued.has(key):
			_jobs.append([key, want[key][0], want[key][1]])
	_sync_walkers()


## key -> [signature, Callable that builds the node].
func _wanted() -> Dictionary:
	var out: Dictionary = {}
	if not Lagoon.claimed(state):
		out["sign"] = ["sign", func() -> Node3D: return _put(LagoonArt.claim_sign(), _landing_point(), LagoonData.facing_yaw())]
		return out
	var l: Dictionary = Lagoon.data(state)
	var rank: int = int(l["rank"])
	out["plaza"] = ["plaza%d" % rank, func() -> Node3D: return _make_plaza(rank)]
	out["hall"] = ["hall%d" % rank, func() -> Node3D: return _put(LagoonArt.hall(rank, 7), cell_pos(Vector2i.ZERO), LagoonData.facing_yaw())]
	for b: Dictionary in l["buildings"]:
		var c := Vector2i(int(b["x"]), int(b["y"]))
		var t: String = b["t"]
		var lv: int = int(b["lv"])
		var dmg: bool = bool(b["dmg"])
		var yaw: float = LagoonData.facing_yaw() + 90.0 * int(b["rot"])
		out["b%d,%d" % [c.x, c.y]] = ["%s/%d/%d/%s" % [t, lv, int(b["rot"]), dmg], func() -> Node3D:
			return _put(LagoonArt.building(t, lv, c.x * 31 + c.y * 7 + 3, dmg), cell_pos(c), yaw)]
	var piers: Array = l["piers"]
	for i in piers.size():
		var lv2: int = int(piers[i])
		out["p%d" % i] = ["%d" % lv2, func() -> Node3D: return _make_pier(i, lv2)]
	out["office"] = ["office", func() -> Node3D: return _put(LagoonArt.office(), office_point(), LagoonData.facing_yaw())]
	out["walk"] = ["%d" % piers.size(), func() -> Node3D: return _make_walk(piers.size())]
	var berths: Array[Vector3] = _berths()
	var fleet: Array = state["fleet"]
	var anchored: int = 0
	for i in fleet.size():
		var cls: String = Lagoon.class_of(fleet[i])
		if i < berths.size():
			var at: Vector3 = berths[i]
			out["s%d" % i] = ["%s/%s/%.0f,%.0f" % [cls, fleet[i].get("name", ""), at.x, at.z], func() -> Node3D:
				return _put(LagoonArt.moored_ship(cls), Vector3(at.x, 0.0, at.z), at.y)]
		elif anchored < ANCHOR_SLOTS:
			var ap: Vector3 = _anchor_point(anchored)
			anchored += 1
			out["s%d" % i] = ["%s/%s/a%d" % [cls, fleet[i].get("name", ""), anchored], func() -> Node3D:
				return _put(LagoonArt.moored_ship(cls), Vector3(ap.x, 0.0, ap.z), ap.y)]
	return out


func _put(n: Node3D, at: Vector3, yaw_deg: float) -> Node3D:
	n.position = at
	n.rotation_degrees.y = yaw_deg
	return n


func _process(delta: float) -> void:
	_t += delta
	var start: int = Time.get_ticks_usec()
	while not _jobs.is_empty() and Time.get_ticks_usec() - start < BUILD_BUDGET_US:
		_run_job(_jobs.pop_front())
	for key: String in _nodes:
		if key.begins_with("s"):
			var n: Node3D = _nodes[key]
			n.position.y = 0.25 * sin(_t * 0.8 + float(key.hash() % 100))
			n.rotation_degrees.z = 1.2 * sin(_t * 0.6 + float(key.hash() % 37))
	if not _walkers.is_empty():
		TownWalker.pair_up(_walkers)


func _run_job(j: Array) -> void:
	var n: Node3D = (j[2] as Callable).call()
	n.set_meta("lagoon_key", j[0])
	add_child(n)
	_nodes[j[0]] = n
	_sigs[j[0]] = j[1]


## Build everything still waiting, at once (tests, screenshots, the first load).
func flush() -> void:
	while not _jobs.is_empty():
		_run_job(_jobs.pop_front())


func pending() -> int:
	return _jobs.size()


func node_for(key: String) -> Node3D:
	return _nodes.get(key, null)


# ---- the harbour ------------------------------------------------------------------------------

## Island-local point on the beach where a pier starts.
func pier_root(slot: int) -> Vector2:
	var dir: Vector2 = Vector2.from_angle(LagoonData.pier_angle(slot))
	var r: float = float(LagoonData.island()["radius"]) * 1.25
	while r > 10.0 and (island == null or island.ground_y(dir * r) < Island.SHORE_H + 0.4):
		r -= 3.0
	return dir * r


func _landing_point() -> Vector3:
	var p: Vector2 = pier_root(0) - Vector2.from_angle(LagoonData.pier_angle(0)) * 10.0
	return Vector3(p.x, island.ground_y(p) if island != null else 1.0, p.y)


## Island-local ground point of the harbour office: on the beach beside the foot of the first pier, where the
## captain steps ashore. The office (HarbourOfficeCatalogue) opens from here.
func office_point() -> Vector3:
	var dir: Vector2 = Vector2.from_angle(LagoonData.pier_angle(0))
	var p: Vector2 = pier_root(0) - dir * 16.0 + Vector2(-dir.y, dir.x) * 14.0
	return Vector3(p.x, island.ground_y(p) if island != null else LagoonData.PAD_H_M, p.y)


func _make_pier(slot: int, level: int) -> Node3D:
	var root: Vector2 = pier_root(slot)
	var dir: Vector2 = Vector2.from_angle(LagoonData.pier_angle(slot))
	return _put(LagoonArt.pier(level), Vector3(root.x, 0.0, root.y), rad_to_deg(atan2(dir.x, dir.y)))


## Berth positions for every pier, in fleet order: x, z and the ship's yaw (degrees) packed in y.
func _berths() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var piers: Array = Lagoon.data(state)["piers"]
	for i in piers.size():
		var lv: int = int(piers[i])
		var length: float = float(LagoonData.PIER["length_m"][lv - 1])
		var dir: Vector2 = Vector2.from_angle(LagoonData.pier_angle(i))
		var side: Vector2 = Vector2(-dir.y, dir.x)
		var root: Vector2 = pier_root(i)
		var yaw: float = rad_to_deg(atan2(-dir.x, -dir.y))  # bow out to sea
		for k in int(LagoonData.PIER["berths"][lv - 1]):
			var p: Vector2
			match k:
				0: p = root + dir * (length * 0.6) + side * 13.0
				1: p = root + dir * (length * 0.6) - side * 13.0
				_: p = root + dir * (length + 32.0)
			out.append(Vector3(p.x, yaw, p.y))
	return out


func _anchor_point(k: int) -> Vector3:
	var fwd: Vector2 = LagoonData.harbour_dir()
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var r: float = float(LagoonData.island()["radius"])
	var p: Vector2 = fwd * (r + 170.0 + 40.0 * (k % 2)) + side * ((k - 3.5) * 55.0)
	return Vector3(p.x, rad_to_deg(atan2(-side.x, -side.y)) + 15.0 * (k % 3), p.y)


## Trodden sand under the plots open at this rank, so the lagoon's ground grows with it.
func _make_plaza(rank: int) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "Plaza"
	mi.set_meta("kind", "lagoon_plaza")
	var m := CylinderMesh.new()
	var r: float = (float(LagoonData.rank(rank)["extent"]) + 0.7) * LagoonData.CELL_M
	m.top_radius = r
	m.bottom_radius = r + 1.0
	m.height = 0.3
	m.radial_segments = 40
	m.rings = 1
	mi.mesh = m
	mi.material_override = Kenney.flat(Color("c49a68"))
	var c: Vector2 = LagoonData.pad_center()
	mi.position = Vector3(c.x, LagoonData.PAD_H_M - 0.1, c.y)
	return mi


## A plank boardwalk from the hall's square down to the foot of every pier, laid on the ground.
func _make_walk(piers: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Boardwalk"
	root.set_meta("kind", "lagoon_walk")
	var start: Vector2 = LagoonData.pad_center() + LagoonData.harbour_dir() * (LagoonData.PAD_RADIUS_M * 0.5)
	var ends: Array[Vector2] = [pier_root(0)]
	for i in range(1, piers):
		ends.append(pier_root(i))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in ends:
		var steps: int = maxi(int(start.distance_to(e) / 5.0), 2)
		var dir: Vector2 = (e - start).normalized()
		var side: Vector2 = Vector2(-dir.y, dir.x) * 2.6
		for i in steps:
			var a: Vector2 = start.lerp(e, float(i) / steps)
			var b: Vector2 = start.lerp(e, float(i + 1) / steps)
			var ha: float = (island.ground_y(a) if island != null else 1.0) + 0.25
			var hb: float = (island.ground_y(b) if island != null else 1.0) + 0.25
			ha = maxf(ha, 1.85)
			hb = maxf(hb, 1.85)
			var q: Array[Vector3] = [Vector3(a.x + side.x, ha, a.y + side.y), Vector3(a.x - side.x, ha, a.y - side.y), Vector3(b.x + side.x, hb, b.y + side.y), Vector3(b.x - side.x, hb, b.y - side.y)]
			for idx in [0, 2, 1, 1, 2, 3]:
				st.set_uv(Vector2(q[idx].x, q[idx].z))
				st.add_vertex(q[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Kenney.flat(Color("f1976c"))
	root.add_child(mi)
	return root


# ---- the people ------------------------------------------------------------------------------

func _sync_walkers() -> void:
	var want: int = 0
	if Lagoon.claimed(state):
		want = mini(int(Lagoon.data(state)["pop"]), LagoonData.MAX_VILLAGERS)
	var spots: Array[Vector3] = _spots()
	while _walkers.size() > want:
		_walkers.pop_back().queue_free()
	while _walkers.size() < want:
		var w := TownWalker.new()
		var id: int = _walkers.size()
		w.setup("sailor" if id % 3 != 2 else "crew", 300 + id * 17, spots, 911 + id * 13)
		w.set_meta("kind", "lagoon_villager")
		_walker_root.add_child(w)
		_walkers.append(w)
	for w in _walkers:
		w.places = spots
	_walker_root.position = Vector3(0.0, LagoonData.PAD_H_M, 0.0)


## Places people walk between: just in front of every building and the hall, on the levelled ground.
func _spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var fwd: Vector2 = LagoonData.harbour_dir()
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	if Lagoon.claimed(state):
		for b: Dictionary in Lagoon.data(state)["buildings"]:
			cells.append(Vector2i(int(b["x"]), int(b["y"])))
	for c in cells:
		var p: Vector2 = LagoonData.cell_local(c) + fwd * (LagoonData.CELL_M * 0.5)
		out.append(Vector3(p.x, 0.0, p.y))
	return out


func villager_count() -> int:
	return _walkers.size()
