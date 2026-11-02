class_name ShipLooks
extends RefCounted
## Visible ship upgrades bought with gold at any shipyard's "Ship looks" tab: smarter sails, bigger flags and finer
## cannons. They are for show (plus a crew cheer when bought), belong to the captain in state["looks"], and carry
## over to every ship the captain sails. Tier 0 is the starting look; each line has four more.

const LINES: Array[String] = ["sails", "flags", "cannons"]
const TIERS: int = 4
const COST: Dictionary = {
	"sails": [300, 900, 2000, 4500],
	"flags": [200, 700, 1600, 3800],
	"cannons": [400, 1100, 2500, 5500],
}
const ICONS: Dictionary = {"sails": "proc/sail", "flags": "pirate/flag-pirate", "cannons": "pirate/cannon"}
const CHEER_MORALE: float = 5.0  ## the crew cheers every new look

const GOLD: Color = Color(0.98, 0.78, 0.2)
const BRONZE: Color = Color(0.82, 0.52, 0.22)
const IRON: Color = Color(0.16, 0.16, 0.18)
const CARRIAGE_RED: Color = Color(0.62, 0.16, 0.12)
const CARRIAGE_WOOD: Color = Color(0.5, 0.32, 0.18)
const ROPE: Color = Color(0.32, 0.22, 0.14)
const STREAMERS: Array[Color] = [Color(0.85, 0.14, 0.12), Color(0.98, 0.78, 0.2)]
const BUNTING: Array[Color] = [
	Color(0.9, 0.18, 0.15), Color(0.98, 0.8, 0.2), Color(0.2, 0.45, 0.9), Color(0.25, 0.7, 0.3), Color(0.97, 0.96, 0.92),
]

## Sail tiers: canvas, sail-shader pattern (0 plain, 1 striped, 2 skull), mark ink and edging width.
const SAILS: Array[Dictionary] = [
	{},
	{"canvas": Color(0.98, 0.97, 0.93), "pattern": 0, "mark": Color(0.1, 0.1, 0.1), "trim": 0.05},
	{"canvas": Color(0.98, 0.97, 0.93), "pattern": 1, "mark": Color(0.82, 0.14, 0.12), "trim": 0.05},
	{"canvas": Color(0.09, 0.09, 0.1), "pattern": 2, "mark": Color(0.96, 0.95, 0.9), "trim": 0.06},
	{"canvas": Color(0.66, 0.08, 0.1), "pattern": 2, "mark": GOLD, "trim": 0.08},
]
const ENSIGN_SCALE: Array[float] = [1.0, 1.45, 1.5, 1.55, 1.9]


static func owned(state: Dictionary) -> Dictionary:
	if not (state.get("looks") is Dictionary):
		state["looks"] = {}
	var d: Dictionary = state["looks"]
	for line in LINES:
		d[line] = clampi(int(d.get(line, 0)), 0, TIERS)
	return d


static func tier(state: Dictionary, line: String) -> int:
	return int(owned(state).get(line, 0))


## Gold for the next tier of a line, or 0 when it is already at the top.
static func next_cost(state: Dictionary, line: String) -> int:
	var t: int = tier(state, line)
	return 0 if t >= TIERS else int(COST[line][t])


## Buys the next look of a line. False when it is maxed or the captain is short of gold.
static func buy(state: Dictionary, line: String) -> bool:
	if not COST.has(line):
		return false
	var t: int = tier(state, line)
	var price: int = next_cost(state, line)
	if t >= TIERS or int(state.get("gold", 0)) < price:
		return false
	state["gold"] = int(state["gold"]) - price
	state["looks"][line] = t + 1
	state["morale"] = minf(float(state.get("morale", 70.0)) + CHEER_MORALE, 100.0)
	return true


static func name_key(line: String, t: int) -> String:
	return "looks.%s.%d" % [line, clampi(t, 0, TIERS)]


# --- the look on the ship ------------------------------------------------------------------------------------------

## Puts the bought looks on a ship. Call after ShipCustom.apply: the captain's own sail colours from the customise
## screen win over a bought sail style, which then only adds its edging. Safe to call again.
static func apply(v: ShipVisuals, state: Dictionary) -> void:
	if v == null or v.root == null:
		return
	var looks: Dictionary = owned(state)
	var old: Node = v.root.get_node_or_null("Looks")
	if old != null:
		v.root.remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = "Looks"
	v.root.add_child(root)
	var custom: Dictionary = state.get("custom", {})
	var own_sails: bool = false
	if custom.get("sail") is Dictionary:
		own_sails = int(custom["sail"].get("color", 0)) != 0 or int(custom["sail"].get("pattern", 0)) != 0
	_sails(v, int(looks["sails"]), own_sails)
	_flags(v, root, int(looks["flags"]), custom)
	_cannons(v, root, int(looks["cannons"]))


static func _sails(v: ShipVisuals, t: int, own_sails: bool) -> void:
	if t <= 0:
		return
	var s: Dictionary = SAILS[t]
	for m: ShaderMaterial in v.sail_materials:
		m.set_shader_parameter("trim_color", Vector3(GOLD.r, GOLD.g, GOLD.b))
		m.set_shader_parameter("trim_width", float(s["trim"]))
		if own_sails:
			continue
		var c: Color = s["canvas"]
		var k: Color = s["mark"]
		m.set_shader_parameter("custom", true)
		m.set_shader_parameter("canvas_color", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("pattern", int(s["pattern"]))
		m.set_shader_parameter("mark_color", Vector3(k.r, k.g, k.b))


## Flags stack up: a bigger ensign, then streamers, then bunting, then gold.
static func _flags(v: ShipVisuals, root: Node3D, t: int, custom: Dictionary) -> void:
	var n: int = v.flag_nodes.size()
	if n == 0:
		return
	var ensign: MeshInstance3D = v.flag_nodes[n - 1]
	ensign.scale = Vector3.ONE * ENSIGN_SCALE[t]
	if t >= 2:
		for i in range(1, n - 1):  # the pennants on the other masts: red and gold
			var pc: Color = STREAMERS[i % 2]
			v.flag_materials[i].set_shader_parameter("base_color", Vector3(pc.r, pc.g, pc.b))
		for i in range(1, n):
			_streamer(v, root, v.flag_nodes[i], STREAMERS[i % 2])
	if t >= 3:
		_bunting(v, root)
	if t >= 4:
		var pixel_flag: bool = false
		if custom.get("flag") is Dictionary:
			pixel_flag = (custom["flag"].get("pixels", []) as Array).size() > 0
		if not pixel_flag:
			v.flag_materials[n - 1].set_shader_parameter("mark_color", Vector3(GOLD.r, GOLD.g, GOLD.b))
		for i in range(1, n):
			var tip := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22 * v._sw
			sm.height = 0.44 * v._sw
			tip.mesh = sm
			tip.material_override = Kenney.flat(GOLD, 0.35)
			tip.position = in_root(v, v.flag_nodes[i]) + Vector3(0, 1.05 * v._sw * v.flag_nodes[i].scale.y + 0.1, 0)
			tip.set_meta("kind", "finial")
			root.add_child(tip)


## Where a node sits in the ship's Visuals space, walking the parents (works before the ship is in the tree).
static func in_root(v: ShipVisuals, n: Node3D) -> Vector3:
	var p: Vector3 = n.position
	var up: Node = n.get_parent()
	while up != null and up != v.root and up is Node3D:
		p = (up as Node3D).transform * p
		up = up.get_parent()
	return p


## A long tapering streamer that flies under a masthead flag.
static func _streamer(v: ShipVisuals, root: Node3D, flag: MeshInstance3D, c: Color) -> void:
	var w: float = 3.2 * v._sw
	var h: float = 0.42 * v._sw
	var mi := MeshInstance3D.new()
	mi.mesh = v._quad_mesh(Vector3(0, 0, 0), Vector3(w, h * 0.42, 0), Vector3(0, h, 0), Vector3(w, h * 0.58, 0), 12, 2)
	var m := ShaderMaterial.new()
	m.shader = ShipVisuals.FLAG_SHADER
	m.set_shader_parameter("skull", 0.0)
	m.set_shader_parameter("base_color", Vector3(c.r, c.g, c.b))
	mi.material_override = m
	mi.position = in_root(v, flag) - Vector3(0, h * 1.6, 0)
	mi.set_meta("kind", "streamer")
	root.add_child(mi)


## Strings of little triangle flags from the bowsprit over every masthead down to the stern rail.
static func _bunting(v: ShipVisuals, root: Node3D) -> void:
	var pts: Array[Vector3] = []
	for f: MeshInstance3D in v.flag_nodes:
		pts.append(in_root(v, f))
	pts.append(Vector3(0, v.deck_y() + v.stats.freeboard_m * 0.9, v.stats.length_m * 0.46))
	var sc: float = clampf(v._sw, 0.8, 2.6)
	var spacing: float = 0.75 * sc
	var flags: Array[Transform3D] = []
	var ropes: Array[Transform3D] = []
	var down := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, PI)  # in the rope's plane, point down
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var dist: float = a.distance_to(b)
		var sag: float = dist * 0.1
		var count: int = maxi(int(dist / spacing), 2)
		var prev: Vector3 = a
		for k in range(1, count + 1):
			var u: float = float(k) / float(count)
			var p: Vector3 = a.lerp(b, u) - Vector3(0, sag * 4.0 * u * (1.0 - u), 0)
			var seg: Vector3 = p - prev
			if seg.length() > 0.01:
				var mid: Vector3 = (p + prev) * 0.5
				var basis := Basis.looking_at(seg.normalized(), Vector3.UP if absf(seg.normalized().y) < 0.95 else Vector3.BACK)
				ropes.append(Transform3D(basis.scaled(Vector3(1, 1, seg.length())), mid))
			if k < count:
				flags.append(Transform3D(down.scaled(Vector3.ONE * sc), p - Vector3(0, 0.22 * sc, 0)))
			prev = p
	var fm := MultiMesh.new()
	fm.transform_format = MultiMesh.TRANSFORM_3D
	fm.use_colors = true
	var prism := PrismMesh.new()
	prism.size = Vector3(0.42, 0.46, 0.03)
	fm.mesh = prism
	fm.instance_count = flags.size()
	for i in flags.size():
		fm.set_instance_transform(i, flags[i])
		fm.set_instance_color(i, BUNTING[i % BUNTING.size()])
	var fmi := MultiMeshInstance3D.new()
	fmi.multimesh = fm
	fmi.material_override = Kenney.vcol()
	fmi.set_meta("kind", "bunting")
	root.add_child(fmi)
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	var line := BoxMesh.new()
	line.size = Vector3(0.04, 0.04, 1.0)
	rm.mesh = line
	rm.instance_count = ropes.size()
	for i in ropes.size():
		rm.set_instance_transform(i, ropes[i])
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = rm
	rmi.material_override = Kenney.flat(ROPE)
	rmi.set_meta("kind", "bunting_rope")
	root.add_child(rmi)


## Upgraded cannons replace the Kenney guns at the same spots; the swivel and bow guns are extra.
static func _cannons(v: ShipVisuals, root: Node3D, t: int) -> void:
	for g: MeshInstance3D in v.gun_nodes:
		g.visible = t <= 0
	if t <= 0:
		return
	var barrel: Color = BRONZE if t <= 2 else (IRON if t == 3 else GOLD)
	var carriage: Color = CARRIAGE_RED if t != 3 else CARRIAGE_WOOD
	var length_mult: float = 1.3 if t >= 3 else 1.0
	for g: MeshInstance3D in v.gun_nodes:
		var c: Node3D = build_cannon(barrel, carriage, length_mult, t >= 3, t >= 4)
		c.transform = g.transform
		c.scale = g.scale
		c.set_meta("kind", "look_gun")
		root.add_child(c)
	if t >= 2:
		var s: ShipStats = v.stats
		var sc: float = clampf(s.beam_m / 7.0, 0.55, 1.5) * 0.6
		var rail: float = v.hull_half_width() * 0.6
		for z: float in [-s.length_m * 0.2]:  # the raised stern deck has no room on the waist-deck height
			for side: float in [-1.0, 1.0]:
				var sw: Node3D = build_swivel(barrel)
				sw.position = Vector3(side * rail, v.deck_y() + 0.75 * sc, z)
				sw.rotation_degrees.y = 90.0 * side
				sw.scale = Vector3.ONE * sc
				sw.set_meta("kind", "swivel")
				root.add_child(sw)
	if t >= 4 and not v.gun_nodes.is_empty():
		var s2: ShipStats = v.stats
		for side: float in [-0.12, 0.12]:
			var bow: Node3D = build_cannon(GOLD, CARRIAGE_RED, 1.3, true, true)
			bow.position = Vector3(side * s2.beam_m, v.deck_y(), -s2.length_m * 0.2)
			bow.rotation_degrees.y = 180.0  # muzzle (+Z) turned to face the bow (-Z)
			bow.scale = v.gun_nodes[0].scale
			bow.set_meta("kind", "bow_chaser")
			root.add_child(bow)


static func _part(parent: Node3D, mesh: Mesh, at: Vector3, c: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Kenney.flat(c, emit, true)
	mi.position = at
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	return cm


## A chunky Kenney-style cannon on a wheeled carriage, about the size of the kit's cannon, muzzle towards +Z.
static func build_cannon(barrel: Color, carriage: Color, length_mult: float, bands: bool, dragon: bool) -> Node3D:
	var gun := Node3D.new()
	var bed := BoxMesh.new()
	bed.size = Vector3(0.62, 0.26, 0.9)
	_part(gun, bed, Vector3(0, 0.27, -0.05), carriage)
	var wheel: CylinderMesh = _cyl(0.17, 0.17, 0.1)
	for x: float in [-0.36, 0.36]:
		for z: float in [-0.35, 0.3]:
			var w: MeshInstance3D = _part(gun, wheel, Vector3(x, 0.17, z), Color(0.25, 0.16, 0.1))
			w.rotation_degrees.z = 90.0
	var reach: float = 1.15 * length_mult
	var tube: MeshInstance3D = _part(gun, _cyl(0.13, 0.19, reach), Vector3(0, 0.55, reach * 0.5 - 0.35), barrel, 0.25 if dragon else 0.0)
	tube.rotation_degrees.x = 90.0  # cylinder axis (Y) along Z, narrow end at the muzzle
	var knob := SphereMesh.new()
	knob.radius = 0.12
	knob.height = 0.24
	_part(gun, knob, Vector3(0, 0.55, -0.42), barrel)
	var lip: MeshInstance3D = _part(gun, _cyl(0.17, 0.17, 0.1), Vector3(0, 0.55, reach - 0.38), GOLD if bands else barrel)
	lip.rotation_degrees.x = 90.0
	if bands:
		for f: float in [0.2, 0.55]:
			var band: MeshInstance3D = _part(gun, _cyl(0.19, 0.19, 0.06), Vector3(0, 0.55, reach * f - 0.35), GOLD)
			band.rotation_degrees.x = 90.0
	if dragon:
		# a dragon's head round the muzzle: snout, two horns and glowing eyes
		var head := SphereMesh.new()
		head.radius = 0.24
		head.height = 0.4
		var h: MeshInstance3D = _part(gun, head, Vector3(0, 0.6, reach - 0.42), GOLD, 0.2)
		h.scale = Vector3(1.0, 0.9, 1.3)
		for x: float in [-0.12, 0.12]:
			var horn: MeshInstance3D = _part(gun, _cyl(0.0, 0.05, 0.3), Vector3(x, 0.85, reach - 0.55), Color(0.95, 0.92, 0.8))
			horn.rotation_degrees.x = -40.0
			var eye := SphereMesh.new()
			eye.radius = 0.045
			eye.height = 0.09
			_part(gun, eye, Vector3(x * 0.9, 0.72, reach - 0.28), Color(1.0, 0.25, 0.1), 2.0)
	return gun


## A small swivel gun on a post, for the bow rails.
static func build_swivel(barrel: Color) -> Node3D:
	var gun := Node3D.new()
	_part(gun, _cyl(0.06, 0.08, 0.7), Vector3(0, -0.35, 0), Color(0.3, 0.2, 0.12))
	var tube: MeshInstance3D = _part(gun, _cyl(0.08, 0.12, 0.8), Vector3(0, 0.05, 0.15), barrel)
	tube.rotation_degrees.x = 90.0
	var lip: MeshInstance3D = _part(gun, _cyl(0.11, 0.11, 0.07), Vector3(0, 0.05, 0.55), GOLD)
	lip.rotation_degrees.x = 90.0
	return gun
