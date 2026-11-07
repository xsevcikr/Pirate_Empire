class_name DeckWalker
extends Node3D
## The captain on foot on his own deck while the ship sails itself. Lives as a child of the ship, so he rolls and
## pitches with her; his position is kept in ship-local metres (x across the beam, z along it, bow is -z). The steer
## and sail keys walk him, relative to the camera.
## Where he may stand comes from the hull model itself: a grid of deck heights read off its level, upward-facing
## faces, so he keeps to the planking, walks round the open hold, stays off the rails and the bowsprit, and only
## steps up or down where the change in level is a step, not a wall.

const WALK_MS: float = 2.4
const RUN_MS: float = 4.6
const MAST_R: float = 0.45
const STEP_EVERY_M: float = 1.1
const CELL_X: float = 0.25  ## grid cell across the beam
const SLICES: int = 64  ## grid stations along the hull
const MAX_STEP_M: float = 1.1  ## the most he climbs or drops in one stride (a ladder or companion step)
const MIN_FLOOR_W: float = 0.35  ## level faces narrower than this (rail caps) are not floor

var ship: Ship
var camera: Camera3D
var fighter: FighterState
var view: DeckFighterView
var anchor: Node3D  ## the camera's target: at chest height above the captain
var deck_y: float = 2.0
var half_beam: float = 2.0
var bow_z: float = -8.0
var stern_z: float = 5.0
var mast_z: PackedFloat32Array = PackedFloat32Array()
var profile_z0: float = -9.0  ## the stations the grid covers (the whole hull, stem to stern)
var profile_z1: float = 9.0
var grid_nx: int = 0
var grid: PackedFloat32Array = PackedFloat32Array()  ## deck height per cell (x fastest), INF where there is no deck
var row_lo: PackedFloat32Array = PackedFloat32Array()  ## per station: the deck's port and starboard edges, for a
var row_hi: PackedFloat32Array = PackedFloat32Array()  ## smooth slide along a tapering rail instead of grid stairs
## Things on deck he walks round: the guns (the hands at their stations step aside for him). {pos: Vector2, r: float}
var obstacles: Array[Dictionary] = []
var move_input: Vector2 = Vector2.ZERO  ## x right, y forward, relative to the camera; set by tests to drive him
var use_keys: bool = true
var _step_acc: float = 0.0
var _feet: Node3D
var _feet_y: float = 0.0
var _obstacle_t: float = 0.0


func setup(owner_ship: Ship) -> void:
	ship = owner_ship
	name = "DeckWalker"
	var L: float = ship.stats.length_m
	if ship.visuals != null:
		deck_y = ship.visuals.deck_y()
		half_beam = ship.visuals.hull_half_width()
		for g: Node3D in ship.visuals.mast_groups:
			mast_z.append(g.position.z)
	else:
		deck_y = ship.stats.freeboard_m
		half_beam = ship.stats.beam_m * 0.4
	bow_z = -0.36 * L
	stern_z = 0.3 * L
	profile_z0 = -0.5 * L
	profile_z1 = 0.5 * L
	if ship.visuals != null:
		_sample_deck(ship.visuals.root.get_node_or_null("Model") as Node3D)
	refresh_obstacles()
	fighter = FighterState.make_player(1, "cutlass", "", 0)
	fighter.id = 1
	fighter.pos = start_spot(Vector2(0.0, 0.08 * L))  # in the waist, just aft of amidships
	fighter.dir = Vector2(0, -1)
	view = DeckFighterView.new()
	view.fighter = fighter
	view.show_label = false
	view.pose_idle_only = true
	view.scale = Vector3.ONE * clampf(ship.stats.beam_m / 7.0, 0.85, 1.0)
	var holder := Node3D.new()
	holder.name = "Feet"
	holder.add_child(view)
	add_child(holder)
	_feet = holder
	anchor = Node3D.new()
	anchor.name = "CamAnchor"
	holder.add_child(anchor)
	_feet_y = height_at(fighter.pos)
	_sync_anchor()


# --- the deck grid -------------------------------------------------------------------------------------------------

## Reads the deck off the hull mesh: cross-sections of every level face at every station, joined where planks touch;
## the lowest such floor under a cell is the deck there (crate tops stand on it, so they are higher; the bottom of
## the hull faces down). The result is shrunk by a shoulder's width from every edge and hole.
func _sample_deck(model: Node3D) -> void:
	if model == null:
		return
	var hull: MeshInstance3D = model.get_node_or_null("Hull") as MeshInstance3D
	if hull == null or hull.mesh == null:
		return
	var xf: Transform3D = model.transform * hull.transform
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for surf in hull.mesh.get_surface_count():  # every surface: the planking can be its own material
		var arrays: Array = hull.mesh.surface_get_arrays(surf)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var base: int = verts.size()
		verts.append_array(v)
		if ix.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ix:
				idx.append(base + i)
	var floor_y: float = deck_y * 0.6
	var spans: Array = []  # per station: Vector3(y, x_min, x_max)
	spans.resize(SLICES)
	for k in SLICES:
		spans[k] = []
	for t in idx.size() / 3:
		var tri: Array[Vector3] = [xf * verts[idx[t * 3]], xf * verts[idx[t * 3 + 1]], xf * verts[idx[t * 3 + 2]]]
		var n: Vector3 = (tri[2] - tri[0]).cross(tri[1] - tri[0])  # Godot meshes wind clockwise seen from the front
		if n.length() < 1e-6 or n.normalized().y < 0.9:
			continue
		var y: float = (tri[0].y + tri[1].y + tri[2].y) / 3.0
		if y < floor_y:
			continue
		var z0: float = minf(tri[0].z, minf(tri[1].z, tri[2].z))
		var z1: float = maxf(tri[0].z, maxf(tri[1].z, tri[2].z))
		var k0: int = clampi(int(floor((z0 - profile_z0) / _dz())), 0, SLICES - 1)
		var k1: int = clampi(int(ceil((z1 - profile_z0) / _dz())), 0, SLICES - 1)
		for k in range(k0, k1 + 1):
			var zc: float = _station(k)
			if zc < z0 or zc > z1:
				continue
			var xs: Array[float] = []
			for e in 3:
				var p: Vector3 = tri[e]
				var q: Vector3 = tri[(e + 1) % 3]
				if (p.z - zc) * (q.z - zc) <= 0.0 and absf(q.z - p.z) > 1e-6:
					xs.append(lerpf(p.x, q.x, (zc - p.z) / (q.z - p.z)))
			if xs.size() >= 2:
				(spans[k] as Array).append(Vector3(y, xs.min(), xs.max()))
	grid_nx = int(ceil(half_beam * 2.0 / CELL_X))
	var raw := PackedFloat32Array()
	raw.resize(grid_nx * SLICES)
	raw.fill(INF)
	var cells: int = 0
	for k in SLICES:
		var floors: Array = _merge_spans(spans[k])
		for i in grid_nx:
			var x: float = _cell_x(i)
			for sp: Vector3 in floors:
				if sp.z - sp.y >= MIN_FLOOR_W and x >= sp.y - 0.01 and x <= sp.z + 0.01 and sp.x < raw[k * grid_nx + i]:
					raw[k * grid_nx + i] = sp.x
	# shrink by a cell from every edge, hole and wall-high change of level (his shoulders need the room)
	grid = raw.duplicate()
	for k in SLICES:
		for i in grid_nx:
			var h: float = raw[k * grid_nx + i]
			if h == INF:
				continue
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var ii: int = i + d.x
				var kk: int = k + d.y
				if ii < 0 or ii >= grid_nx or kk < 0 or kk >= SLICES or absf(raw[kk * grid_nx + ii] - h) > MAX_STEP_M:
					grid[k * grid_nx + i] = INF
					break
			if grid[k * grid_nx + i] < INF:
				cells += 1
	if cells < 12:  # nothing usable (an odd model): fall back to the plain outline
		grid = PackedFloat32Array()
		return
	var first: int = SLICES
	var last: int = -1
	for k in SLICES:
		for i in grid_nx:
			if grid[k * grid_nx + i] < INF:
				first = mini(first, k)
				last = maxi(last, k)
	bow_z = _station(first) - _dz() * 0.5
	stern_z = _station(last) + _dz() * 0.5
	row_lo.resize(SLICES)
	row_hi.resize(SLICES)
	for k in SLICES:
		row_lo[k] = INF
		row_hi[k] = -INF
		for i in grid_nx:
			if grid[k * grid_nx + i] < INF:
				row_lo[k] = minf(row_lo[k], _cell_x(i) - CELL_X * 0.45)
				row_hi[k] = maxf(row_hi[k], _cell_x(i) + CELL_X * 0.45)


## Joins level spans at the same height that touch, so a deck laid in narrow planks reads as one floor.
static func _merge_spans(list: Array) -> Array:
	list.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var ya: float = snappedf(a.x, 0.05)
		var yb: float = snappedf(b.x, 0.05)
		return ya < yb or (ya == yb and a.y < b.y))
	var out: Array = []
	for sp: Vector3 in list:
		if not out.is_empty():
			var last: Vector3 = out[out.size() - 1]
			if snappedf(last.x, 0.05) == snappedf(sp.x, 0.05) and sp.y <= last.z + 0.06:
				out[out.size() - 1] = Vector3(last.x, last.y, maxf(last.z, sp.z))
				continue
		out.append(sp)
	return out


func _dz() -> float:
	return (profile_z1 - profile_z0) / float(SLICES)


func _station(k: int) -> float:
	return profile_z0 + (float(k) + 0.5) * _dz()


func _cell_x(i: int) -> float:
	return -half_beam + (float(i) + 0.5) * CELL_X


## Deck height under a deck position, or INF where there is no deck to stand on.
func cell_height(p: Vector2) -> float:
	if grid.is_empty():
		return deck_y if _in_outline(p) else INF
	var i: int = int(floor((p.x + half_beam) / CELL_X))
	var k: int = int(floor((p.y - profile_z0) / _dz()))
	if i < 0 or i >= grid_nx or k < 0 or k >= SLICES:
		return INF
	return grid[k * grid_nx + i]


func height_at(p: Vector2) -> float:
	var h: float = cell_height(p)
	return h if h < INF else deck_y


func walkable(p: Vector2) -> bool:
	if cell_height(p) == INF:
		return false
	for z in mast_z:
		if Vector2(p.x, p.y - z).length() < MAST_R:
			return false
	for o: Dictionary in obstacles:
		if p.distance_to(o["pos"]) < float(o["r"]):
			return false
	return true


## Centre of the round obstacle (mast or gun) that `p` stands in, or INF.
func _nearest_round(p: Vector2) -> Vector2:
	for z in mast_z:
		if Vector2(p.x, p.y - z).length() < MAST_R:
			return Vector2(0.0, z)
	for o: Dictionary in obstacles:
		if p.distance_to(o["pos"]) < float(o["r"]):
			return o["pos"]
	return Vector2.INF


## Re-reads the guns on deck (a refit can change them).
func refresh_obstacles() -> void:
	obstacles.clear()
	if ship == null or ship.visuals == null or ship.visuals.root == null:
		return
	var gun_r: float = 0.55 * clampf(ship.stats.beam_m / 7.0, 0.55, 1.5)
	for c in ship.visuals.root.get_children():
		if c is MeshInstance3D and str(c.name).begins_with("Gun"):
			var g: Vector3 = (c as MeshInstance3D).position
			obstacles.append({"pos": Vector2(g.x, g.z), "r": gun_r})


## Without a grid: the beam narrowing toward the bow and a little toward the stern.
func _in_outline(p: Vector2) -> bool:
	if p.y < bow_z or p.y > stern_z:
		return false
	var w: float = half_beam * 0.78
	if p.y < 0.0:
		var f: float = clampf((p.y - bow_z * 0.45) / (bow_z * 0.55), 0.0, 1.0)
		w *= lerpf(1.0, 0.25, f * f)
	else:
		w *= lerpf(1.0, 0.8, clampf(p.y / stern_z, 0.0, 1.0))
	return absf(p.x) <= maxf(w, 0.35)


## The walkable spot nearest `want` on the main deck (the lowest level close by), for where he first appears.
func start_spot(want: Vector2) -> Vector2:
	var best: Vector2 = want
	var best_d: float = INF
	for r in 80:
		for a in 16:
			var p: Vector2 = want + Vector2.from_angle(TAU * float(a) / 16.0) * float(r) * 0.2
			if walkable(p):
				var d: float = p.distance_to(want) + (height_at(p) - deck_y) * 4.0
				if d < best_d:
					best_d = d
					best = p
		if best_d < INF and float(r) * 0.2 > best_d:
			break
	return best


## Pulls a point across the beam inside the deck's edges at its station, read between stations so a tapering bow
## is a smooth line he slides along.
func clamp_x(p: Vector2) -> Vector2:
	if row_lo.is_empty():
		return p
	var f: float = (p.y - profile_z0) / _dz()
	var k: int = clampi(int(floor(f)), 0, SLICES - 1)
	if row_lo[k] == INF:
		return p
	var t: float = f - float(k)  # 0..1 through this row of cells
	var nb: int = clampi(k - 1 if t < 0.5 else k + 1, 0, SLICES - 1)
	var w: float = absf(t - 0.5) * 2.0  # 0 at the row's middle, 1 at its edge, where it meets the next row
	var lo: float = row_lo[k]
	var hi: float = row_hi[k]
	if row_lo[nb] != INF:
		lo = lerpf(lo, maxf(lo, row_lo[nb]), w)
		hi = lerpf(hi, minf(hi, row_hi[nb]), w)
	return Vector2(clampf(p.x, lo, hi), p.y)


## Moves from `from` toward `to`, sliding along a rail, a tapering bow or a hatch coaming instead of stopping dead:
## if the straight step is barred it tries the step turned a little to either side, then the two axis slides.
func step_to(from: Vector2, to: Vector2) -> Vector2:
	var h0: float = height_at(from)
	var d: Vector2 = to - from
	var tries: Array[Vector2] = [clamp_x(to)]
	for deg in [25.0, -25.0, 50.0, -50.0]:
		tries.append(from + d.rotated(deg_to_rad(deg)) * cos(deg_to_rad(deg)))
	tries.append(Vector2(to.x, from.y))
	tries.append(Vector2(from.x, to.y))
	for deg in [75.0, -75.0, 90.0, -90.0]:  # along a tapering rail: sidle off it to find the way on
		tries.append(from + d.rotated(deg_to_rad(deg)) * 0.6)
	var l: float = d.length() * 0.6
	var c: Vector2 = _nearest_round(to)  # a mast or a gun in the way: walk round it
	if c != Vector2.INF:
		var radial: Vector2 = (from - c).normalized()
		var tangent := Vector2(-radial.y, radial.x)
		if tangent.dot(d) < 0.0:
			tangent = -tangent
		tries.append(from + (tangent * 0.9 + radial * 0.25).normalized() * d.length())
		tries.append(from + (-tangent * 0.9 + radial * 0.25).normalized() * l)
	for side: Vector2 in [Vector2(-signf(from.x), 0.0), Vector2(signf(from.x), 0.0)]:  # inboard first
		tries.append(from + side * l)
	var boxed_in: bool = not walkable(from)  # a hand stepped onto his spot: let him walk out through anything
	for p: Vector2 in tries:
		if p.distance_squared_to(from) < 1e-8:  # an axis slide with nothing to slide along
			continue
		var ok: bool = walkable(p) or (boxed_in and cell_height(p) < INF)
		if ok and absf(cell_height(p) - h0) <= MAX_STEP_M:
			return p
	return from


# --- walking -------------------------------------------------------------------------------------------------------

func _read_keys() -> Vector2:
	if not use_keys:
		return move_input
	return Vector2(Input.get_axis("steer_left", "steer_right"), Input.get_axis("sail_down", "sail_up"))


## One walking step: input is turned from camera space into deck space, then kept on the deck.
func walk(delta: float, input: Vector2, running: bool) -> void:
	if fighter == null:
		return
	if input.length() > 1.0:
		input = input.normalized()
	if input.length() > 0.05:
		var fwd := Vector2(0, -1)
		var right := Vector2(1, 0)
		if camera != null and is_inside_tree():
			var inv: Basis = ship.global_transform.basis.inverse()
			var cf: Vector3 = inv * (-camera.global_transform.basis.z)
			var cr: Vector3 = inv * camera.global_transform.basis.x
			if Vector2(cf.x, cf.z).length() > 0.05:
				fwd = Vector2(cf.x, cf.z).normalized()
				right = Vector2(cr.x, cr.z).normalized()
		var move: Vector2 = (right * input.x + fwd * input.y)
		var speed: float = RUN_MS if running else WALK_MS
		var before: Vector2 = fighter.pos
		fighter.pos = step_to(fighter.pos, fighter.pos + move * speed * delta)
		fighter.dir = fighter.dir.slerp(move.normalized(), clampf(delta * 12.0, 0.0, 1.0)).normalized()
		_step_acc += before.distance_to(fighter.pos)
		if _step_acc > STEP_EVERY_M:
			_step_acc = 0.0
			Sfx.play("step_wood")
	_sync_anchor(delta)


func _sync_anchor(delta: float = 0.0) -> void:
	if fighter == null or _feet == null:
		return
	var want: float = height_at(fighter.pos)
	_feet_y = want if delta <= 0.0 else lerpf(_feet_y, want, clampf(delta * 14.0, 0.0, 1.0))  # up the steps, not a jump
	_feet.position = Vector3(0, _feet_y, 0)
	anchor.position = Vector3(fighter.pos.x, 1.4, fighter.pos.y)


func _physics_process(delta: float) -> void:
	_obstacle_t -= delta
	if _obstacle_t <= 0.0:
		_obstacle_t = 2.0
		refresh_obstacles()
	walk(delta, _read_keys(), use_keys and Input.is_key_pressed(KEY_SHIFT))
