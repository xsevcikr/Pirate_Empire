class_name DebrisManager
extends Node3D
## Floating wreckage (planks, barrels, crates, hull pieces, spars) and falling rubble. Everything counts against one
## cap of MAX_DEBRIS bodies; when it is full the oldest goes. Floating pickups last three minutes.

const MAX_DEBRIS: int = DestructionData.MAX_DEBRIS
const PICKUP_LIFE_S: float = 180.0
const PICKUP_RANGE_M: float = 14.0
const FLOAT_LIFE_S: float = 90.0

signal picked_up(kind: String, payload: Dictionary)

var ocean: WaveModel
var player: Node3D
var pieces: Array[Node3D] = []  ## oldest first
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("debris")
	_rng.seed = 4242


func count() -> int:
	return pieces.size()


func _add(n: Node3D) -> void:
	add_child(n)
	pieces.append(n)
	while pieces.size() > MAX_DEBRIS:
		var old: Node3D = pieces.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _mesh_node(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = Kenney.flat(color)
	return mi


## A floating thing: bobs on the waves, drifts, and expires. `payload` makes it a pickup.
func spawn_floater(kind: String, pos: Vector3, vel: Vector3, size: Vector3, color: Color, payload: Dictionary = {}) -> Node3D:
	var n := Node3D.new()
	n.set_meta("kind", kind)
	n.set_meta("payload", payload)
	n.set_meta("age", 0.0)
	n.set_meta("vel", Vector3(vel.x, 0.0, vel.z))
	n.set_meta("life", PICKUP_LIFE_S if not payload.is_empty() else FLOAT_LIFE_S)
	n.add_child(_mesh_node(size, color))
	n.position = pos
	n.rotation = Vector3(_rng.randf() * 0.4, _rng.randf() * TAU, _rng.randf() * 0.4)
	_add(n)
	return n


func spawn_crate(pos: Vector3, cargo: Dictionary) -> Node3D:
	return spawn_floater("crate", pos, Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), Vector3(0.9, 0.9, 0.9), Color(0.5, 0.36, 0.2), {"cargo": cargo})


func spawn_barrel(pos: Vector3, supplies: Dictionary) -> Node3D:
	return spawn_floater("barrel", pos, Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-1.5, 1.5)), Vector3(0.6, 0.8, 0.6), Color(0.42, 0.28, 0.16), {"supplies": supplies})


func spawn_plank(pos: Vector3) -> Node3D:
	return spawn_floater("plank", pos, Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2)), Vector3(0.25, 0.08, _rng.randf_range(1.5, 3.5)), Color(0.4, 0.27, 0.15))


func spawn_spar(pos: Vector3, length: float) -> Node3D:
	return spawn_floater("spar", pos, Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), Vector3(0.35, 0.35, length), Color(0.36, 0.24, 0.14))


## A falling chunk of masonry or timber: a real rigid body that comes to rest and later sleeps.
func spawn_rubble(pos: Vector3, size: Vector3, color: Color, impulse: Vector3 = Vector3.ZERO) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = 8
	rb.collision_mask = 2 | 8
	rb.mass = 400.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	rb.add_child(shape)
	rb.add_child(_mesh_node(size, color))
	rb.position = pos
	rb.can_sleep = true
	_add(rb)
	rb.apply_central_impulse(impulse)
	return rb


## A sinking ship breaks into 3 to 6 hull pieces, with planks, barrels and (for ships carrying cargo) crates.
## `cargo` is what the ship had; 30% to 60% of it floats free. Returns what was spawned by kind.
func break_up(at: Vector3, stats: ShipStats, cargo: Dictionary) -> Dictionary:
	var made: Dictionary = {"piece": 0, "plank": 0, "barrel": 0, "crate": 0}
	var pieces_n: int = _rng.randi_range(3, 6)
	for i in pieces_n:
		var a: float = TAU * float(i) / float(pieces_n)
		var off := Vector3(cos(a), 0, sin(a)) * stats.length_m * 0.25
		spawn_floater("piece", at + off, off * 0.1, Vector3(stats.beam_m * 0.5, 0.9, stats.length_m * 0.18), Color(0.36, 0.21, 0.115))
		made["piece"] += 1
	for i in 8:
		spawn_plank(at + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * stats.length_m * 0.4)
		made["plank"] += 1
	for i in 4:
		spawn_barrel(at + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * stats.length_m * 0.3, {"water": 1.0 + float(i % 3)})
		made["barrel"] += 1
	var share: float = _rng.randf_range(0.3, 0.6)
	for g: String in cargo:
		var units: float = floorf(float(cargo[g]) * share)
		if units > 0.0:
			var crate_n: int = maxi(int(ceil(units / 10.0)), 1)
			for c in crate_n:
				spawn_crate(at + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * stats.length_m * 0.3, {g: units / float(crate_n)})
				made["crate"] += 1
	return made


func _physics_process(delta: float) -> void:
	var keep: Array[Node3D] = []
	for n in pieces:
		if not is_instance_valid(n):
			continue
		if n is RigidBody3D:
			keep.append(n)
			continue
		var age: float = float(n.get_meta("age")) + delta
		n.set_meta("age", age)
		if age > float(n.get_meta("life")):
			n.queue_free()
			continue
		var v: Vector3 = n.get_meta("vel")
		n.position += v * delta
		n.set_meta("vel", v * (1.0 - 0.2 * delta))
		var h: float = ocean.height_at(n.position.x, n.position.z) if ocean != null else 0.0
		var sink: float = clampf((age - float(n.get_meta("life")) * 0.8) / (float(n.get_meta("life")) * 0.2), 0.0, 1.0) * 1.0 if n.get_meta("payload").is_empty() else 0.0
		n.position.y = h + 0.05 - sink
		keep.append(n)
		if not n.get_meta("payload").is_empty() and player != null and is_instance_valid(player):
			if player.global_position.distance_to(n.global_position) <= PICKUP_RANGE_M:
				picked_up.emit(n.get_meta("kind"), n.get_meta("payload"))
				n.queue_free()
				keep.erase(n)
	pieces = keep
