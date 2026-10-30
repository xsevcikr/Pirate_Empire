class_name BreachVisuals
extends Node3D
## The holes on a ship's hull, as the damage model lists them: a dark torn hole with splintered planks sticking
## out while it is open (and foam where the sea pours in), a bundle of oakum when stuffed, a sheet of canvas when
## fothered and a nailed plank patch once the carpenters have closed it.

const HOLE_M: Array[float] = [0.0, 0.7, 1.1, 1.7]
const SPRAY_EVERY_S: float = 0.45
const SPRAY_NEAR_M: float = 220.0
const COLOR_HOLE := Color(0.07, 0.05, 0.04)
const COLOR_SPLINTER := Color(0.78, 0.6, 0.38)
const COLOR_PLANK := Color(0.74, 0.54, 0.31)
const COLOR_NAIL := Color(0.25, 0.23, 0.22)
const COLOR_CANVAS := Color(0.93, 0.89, 0.77)
const COLOR_OAKUM := Color(0.46, 0.42, 0.36)

var ship: Ship
var _spray_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func setup(owner_ship: Ship) -> void:
	ship = owner_ship
	name = "Breaches"
	ship.damage.breach_opened.connect(func(_i: int) -> void: rebuild())
	ship.damage.breach_changed.connect(func(_i: int) -> void: rebuild())


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if ship == null or ship.damage == null:
		return
	for b in ship.damage.breaches.size():
		add_child(_marker(ship.damage.breaches[b], b))


## Where on the drawn hull a breach sits, and which way that patch of hull faces.
func surface(br: Dictionary) -> Dictionary:
	var p: Vector3 = br["pos"]
	var hb: float = ship.stats.beam_m * 0.5
	var hl: float = ship.stats.length_m * 0.5
	var width: float = ship.visuals.hull_half_width() if ship.visuals != null else hb
	var at := Vector3(p.x * width / hb, 0.1, p.z * 0.86)
	var along: float = absf(p.z) / hl
	if along > 0.45:  # the drawn hull curves in toward the stem and stern faster than the collision box
		at.x *= lerpf(1.0, 0.35, clampf((along - 0.45) / 0.55, 0.0, 1.0))
	var n := Vector3(p.x / hb, 0.0, p.z / hl * 0.6)
	if n.length() < 0.01:
		n = Vector3(0, 0, -1)
	return {"pos": at + n.normalized() * 0.06, "normal": n.normalized()}


func _marker(br: Dictionary, index: int) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", "breach")
	root.set_meta("state", br["state"])
	var s: Dictionary = surface(br)
	var n: Vector3 = s["normal"]
	root.position = s["pos"]
	root.basis = Basis.looking_at(n, Vector3.UP)  # local -Z points out of the hull, +Z into it
	var size: float = HOLE_M[clampi(int(br["size"]), 1, 3)]
	_rng.seed = index * 7919 + int(br["size"])
	match str(br["state"]):
		"open":
			_box(root, Vector3(size, size * 0.75, 0.08), Vector3.ZERO, Vector3.ZERO, COLOR_HOLE)
			for k in 5 + int(br["size"]) * 2:
				var ang: float = _rng.randf() * TAU
				var r: float = size * 0.45
				var at := Vector3(cos(ang) * r, sin(ang) * r * 0.75, -0.08)
				var rot := Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.6, 0.6), ang)
				_box(root, Vector3(size * _rng.randf_range(0.25, 0.5), 0.07, 0.05), at, rot, COLOR_SPLINTER)
		"stuffed":
			_box(root, Vector3(size, size * 0.75, 0.08), Vector3.ZERO, Vector3.ZERO, COLOR_HOLE)
			_box(root, Vector3(size * 0.8, size * 0.55, 0.22), Vector3(0, 0, -0.08), Vector3(0, 0, 0.2), COLOR_OAKUM)
		"fothered":
			_box(root, Vector3(size * 1.8, size * 1.4, 0.04), Vector3(0, -size * 0.2, -0.04), Vector3(0, 0, 0.05), COLOR_CANVAS)
		_:
			for k in 3:
				var y: float = (k - 1) * size * 0.3
				_box(root, Vector3(size * 1.35, size * 0.27, 0.07), Vector3(0, y, -0.04), Vector3(0, 0, _rng.randf_range(-0.08, 0.08)), COLOR_PLANK)
				for side in [-1.0, 1.0]:
					_box(root, Vector3(0.06, 0.06, 0.04), Vector3(side * size * 0.58, y, -0.09), Vector3.ZERO, COLOR_NAIL)
	return root


func _box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Kenney.flat(color)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _process(delta: float) -> void:
	if ship == null or ship.damage == null or ship.damage.sunk:
		return
	_spray_t += delta
	if _spray_t < SPRAY_EVERY_S:
		return
	_spray_t = 0.0
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(ship.global_position) > SPRAY_NEAR_M:
		return
	for c in get_children():
		if c.get_meta("state", "") == "open" or c.get_meta("state", "") == "stuffed":
			var out: Vector3 = -(c as Node3D).global_transform.basis.z
			var amount: int = 18 if c.get_meta("state") == "open" else 6
			Vfx.burst(ship.get_parent(), (c as Node3D).global_position + out * 0.2, Color(0.93, 0.98, 1.0, 0.9), amount, 3.5, 0.8, 0.2, -9.8, 35.0, (out + Vector3.UP * 0.6).normalized())
