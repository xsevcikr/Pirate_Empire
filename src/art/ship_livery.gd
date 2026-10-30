class_name ShipLivery
extends RefCounted
## The look that tells the ship variants apart on the same Kenney hulls: hull paint, sail canvas and pattern, pennant
## colour, and code-built extras the kit has no part for (gun-deck stripes with their ports, a raised stern castle,
## a gilded figurehead, treasure on deck, big stern lanterns). The captain's own customisation is laid over this.

## class -> {paint, mix, sail, pattern, pennant, extras}. Sail patterns follow the sail shader: 0 plain, 1 striped,
## 2 skull, 3 torn, 4 black. Classes not listed keep the plain Kenney colours.
const LIVERIES: Dictionary = {
	"pinnace": {"paint": Color(0.18, 0.36, 0.58), "mix": 0.55, "sail": Color(0.95, 0.94, 0.88), "pattern": 1, "pennant": Color(0.2, 0.45, 0.85), "extras": []},
	"xebec": {"paint": Color(0.62, 0.32, 0.16), "mix": 0.6, "sail": Color(0.96, 0.86, 0.62), "pattern": 1, "pennant": Color(0.85, 0.55, 0.1), "extras": ["figurehead_gold"]},
	"corvette": {"paint": Color(0.12, 0.22, 0.2), "mix": 0.55, "sail": Color(0.92, 0.9, 0.84), "pattern": 0, "pennant": Color(0.1, 0.55, 0.45), "extras": ["gun_decks"]},
	"east_indiaman": {"paint": Color(0.55, 0.42, 0.24), "mix": 0.5, "sail": Color(0.88, 0.8, 0.66), "pattern": 0, "pennant": Color(0.9, 0.7, 0.15), "extras": ["stern_castle", "cargo"]},
	"treasure_galleon": {"paint": Color(0.5, 0.16, 0.12), "mix": 0.7, "sail": Color(0.97, 0.9, 0.7), "pattern": 1, "pennant": Color(0.95, 0.78, 0.2),
		"extras": ["gun_decks", "stern_castle", "figurehead_gold", "treasure", "lanterns"]},
	"dreadnought": {"paint": Color(0.1, 0.12, 0.16), "mix": 0.75, "sail": Color(0.95, 0.95, 0.92), "pattern": 0, "pennant": Color(0.15, 0.3, 0.75),
		"extras": ["gun_decks", "stern_castle", "figurehead_gold", "lanterns"]},
	"leviathan": {"paint": Color(0.08, 0.06, 0.06), "mix": 0.85, "sail": Color(0.12, 0.1, 0.1), "pattern": 2, "pennant": Color(0.75, 0.08, 0.06),
		"extras": ["gun_decks", "stern_castle", "figurehead_gold", "lanterns", "treasure"]},
}
const STRIPE: Color = Color(0.86, 0.66, 0.2)
const PORT: Color = Color(0.06, 0.05, 0.05)
const GOLD: Color = Color(0.95, 0.76, 0.2)
const MAX_PORTS_PER_DECK: int = 16


static func has_livery(class_id: String) -> bool:
	return LIVERIES.has(class_id)


## How many rows of gun ports a class shows: one per 16 guns a side, at most three.
static func gun_decks(stats: ShipStats) -> int:
	return clampi(ceili(float(stats.guns_per_side) / float(MAX_PORTS_PER_DECK)), 1, 3)


static func apply(v: ShipVisuals) -> void:
	var l: Dictionary = LIVERIES.get(v.stats.class_id, {})
	if l.is_empty():
		return
	paint(v)
	var old: Node = v.root.get_node_or_null("Livery")
	if old != null:
		return
	var root := Node3D.new()
	root.name = "Livery"
	v.root.add_child(root)
	for e: String in l["extras"]:
		match e:
			"gun_decks":
				_gun_decks(v, root)
			"stern_castle":
				_stern_castle(v, root)
			"figurehead_gold":
				_figurehead(v, root)
			"treasure":
				_deck_goods(v, root, ["chest", "chest", "barrel", "crate"])
			"cargo":
				_deck_goods(v, root, ["crate", "crate", "barrel", "crate-bottles"])
			"lanterns":
				_lanterns(v, root)


## Hull paint, sail canvas and the mast pennants; the ensign on the tallest mast keeps its skull.
static func paint(v: ShipVisuals) -> void:
	var l: Dictionary = LIVERIES.get(v.stats.class_id, {})
	if l.is_empty():
		return
	var p: Color = l["paint"]
	if v.hull_material != null:
		v.hull_material.set_shader_parameter("paint", Vector3(p.r, p.g, p.b))
		v.hull_material.set_shader_parameter("paint_mix", float(l["mix"]))
	var c: Color = l["sail"]
	var ink: Color = Color(0.08, 0.08, 0.08) if c.get_luminance() > 0.35 else Color(0.9, 0.9, 0.85)
	for m: ShaderMaterial in v.sail_materials:
		m.set_shader_parameter("custom", true)
		m.set_shader_parameter("canvas_color", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("pattern", int(l["pattern"]))
		m.set_shader_parameter("mark_color", Vector3(ink.r, ink.g, ink.b))
	var pc: Color = l["pennant"]
	for i in v.flag_materials.size() - 1:
		v.flag_materials[i].set_shader_parameter("base_color", Vector3(pc.r, pc.g, pc.b))


static func _box(parent: Node3D, size: Vector3, at: Vector3, c: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Kenney.flat(c, emit)
	mi.position = at
	parent.add_child(mi)
	return mi


## A gold wale and a row of black gun ports per gun deck along both sides, through the straight middle of the hull.
static func _gun_decks(v: ShipVisuals, root: Node3D) -> void:
	var s: ShipStats = v.stats
	var decks: int = gun_decks(s)
	var half_w: float = s.beam_m * 0.5 * 0.97
	var run: float = s.length_m * 0.56
	var top: float = v.deck_y() * 0.92
	var per: int = mini(ceili(float(s.guns_per_side) / float(decks)), MAX_PORTS_PER_DECK)
	var port_size := Vector3(0.12, s.freeboard_m * 0.09, s.length_m * 0.016)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := BoxMesh.new()
	pm.size = port_size
	mm.mesh = pm
	mm.instance_count = decks * per * 2
	var n: int = 0
	for d in decks:
		var y: float = top - (float(d) + 0.6) * (top * 0.8 / float(decks))
		for side in [-1.0, 1.0]:
			var stripe := _box(root, Vector3(0.1, port_size.y * 0.45, run), Vector3(side * half_w, y + port_size.y * 0.85, s.length_m * 0.03), STRIPE)
			stripe.set_meta("kind", "wale")
			for g in per:
				var z: float = lerpf(-run * 0.45, run * 0.45, 0.5 if per == 1 else float(g) / float(per - 1)) + s.length_m * 0.03
				mm.set_instance_transform(n, Transform3D(Basis(), Vector3(side * (half_w + 0.02), y, z)))
				n += 1
	var ports := MultiMeshInstance3D.new()
	ports.multimesh = mm
	ports.material_override = Kenney.flat(PORT)
	ports.set_meta("kind", "gun_ports")
	root.add_child(ports)


## A raised poop deck over the stern with a row of lit windows across its back.
static func _stern_castle(v: ShipVisuals, root: Node3D) -> void:
	var s: ShipStats = v.stats
	var p: Color = LIVERIES[s.class_id]["paint"]
	var h: float = s.freeboard_m * 0.55
	var depth: float = s.length_m * 0.13
	var w: float = s.beam_m * 0.74
	var z: float = s.length_m * 0.5 - depth * 0.5 - s.length_m * 0.06
	var castle := _box(root, Vector3(w, h, depth), Vector3(0, v.deck_y() + h * 0.5, z), p.lightened(0.15))
	castle.set_meta("kind", "stern_castle")
	_box(root, Vector3(w * 1.06, h * 0.12, depth * 1.04), Vector3(0, v.deck_y() + h, z), GOLD)
	var windows: int = 5 if s.giant else 3
	for i in windows:
		var x: float = lerpf(-w * 0.36, w * 0.36, float(i) / float(windows - 1))
		_box(root, Vector3(w * 0.1, h * 0.32, 0.08), Vector3(x, v.deck_y() + h * 0.5, z + depth * 0.5 + 0.03), Color(1.0, 0.8, 0.4), 1.5)


static func _figurehead(v: ShipVisuals, root: Node3D) -> void:
	var s: ShipStats = v.stats
	var size: float = clampf(s.beam_m / 9.0, 0.6, 1.6)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.4 * size
	sm.height = 0.8 * size
	head.mesh = sm
	head.material_override = Kenney.flat(GOLD, 0.3)
	head.position = Vector3(0, v.deck_y() * 0.85, -s.length_m * 0.41)  # on the stem, under the bowsprit
	head.set_meta("kind", "figurehead")
	root.add_child(head)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2 * size
	cm.bottom_radius = 0.32 * size
	cm.height = 1.2 * size
	body.mesh = cm
	body.material_override = head.material_override
	body.position = head.position + Vector3(0, -0.7 * size, 0.15 * size)
	body.rotation_degrees.x = 25.0
	root.add_child(body)


## Kenney chests, barrels and crates stacked on the waist deck.
static func _deck_goods(v: ShipVisuals, root: Node3D, models: Array) -> void:
	var s: ShipStats = v.stats
	var sc: float = clampf(s.beam_m / 6.0, 1.0, 2.6)
	for i in models.size():
		var mi := MeshInstance3D.new()
		mi.mesh = Kenney.mesh("pirate", str(models[i]))
		mi.scale = Vector3.ONE * sc
		var side: float = -1.0 if i % 2 == 0 else 1.0
		mi.position = Vector3(side * s.beam_m * 0.16, v.deck_y(), s.length_m * (0.05 + 0.04 * float(i)))
		mi.rotation_degrees.y = 25.0 * float(i)
		mi.set_meta("kind", "deck_goods")
		root.add_child(mi)


## Three big lanterns across the taffrail.
static func _lanterns(v: ShipVisuals, root: Node3D) -> void:
	var s: ShipStats = v.stats
	var r: float = clampf(s.beam_m / 30.0, 0.3, 0.7)
	for x in [-0.3, 0.0, 0.3]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh = sm
		mi.material_override = Kenney.flat(Color(1.0, 0.78, 0.35), 2.0)
		mi.position = Vector3(float(x) * s.beam_m, v.deck_y() + s.freeboard_m * 0.85, s.length_m * 0.44)
		mi.set_meta("kind", "lantern")
		root.add_child(mi)
