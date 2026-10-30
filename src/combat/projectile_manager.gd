class_name ProjectileManager
extends Node3D
## Simulates up to MAX_ACTIVE cannonballs with gravity, drag, water impact and ship raycasts.

const MAX_ACTIVE: int = 400
const MAX_AGE_S: float = 12.0
const SELF_HIT_GRACE_S: float = 0.3

var ocean: WaveModel
var active: Array[Dictionary] = []
var hits: int = 0
var misses: int = 0
var _pool: Array[MeshInstance3D] = []
var _mesh: SphereMesh
var _material: ShaderMaterial


func _ready() -> void:
	_mesh = SphereMesh.new()
	_mesh.radius = 0.14
	_mesh.height = 0.28
	_mesh.radial_segments = 8
	_mesh.rings = 4
	_material = Kenney.flat(Color(0.31, 0.32, 0.38))
	_mesh.material = _material


func active_count() -> int:
	return active.size()


func fire(origin: Vector3, velocity: Vector3, gun_id: String, ammo_id: String, source: Node) -> bool:
	if active.size() >= MAX_ACTIVE:
		return false
	var node: MeshInstance3D
	if _pool.is_empty():
		node = MeshInstance3D.new()
		node.mesh = _mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	else:
		node = _pool.pop_back()
	node.visible = true
	node.global_position = origin
	active.append({
		"pos": origin, "vel": velocity, "origin": origin, "gun": gun_id, "ammo": ammo_id,
		"gravity": GunData.shot_gravity(gun_id), "source": source, "age": 0.0, "node": node,
	})
	return true


func _physics_process(delta: float) -> void:
	if active.is_empty():
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var i: int = active.size() - 1
	while i >= 0:
		var p: Dictionary = active[i]
		var prev: Vector3 = p["pos"]
		var out: Array = Ballistics.step(prev, p["vel"], p["gravity"], delta)
		p["pos"] = out[0]
		p["vel"] = out[1]
		p["age"] += delta
		var done: bool = false
		var q := PhysicsRayQueryParameters3D.create(prev, p["pos"], 2 | 4)
		if p["age"] < SELF_HIT_GRACE_S and p["source"] is CollisionObject3D:
			q.exclude = [(p["source"] as CollisionObject3D).get_rid()]
		var res: Dictionary = space.intersect_ray(q)
		if not res.is_empty() and res["collider"] is Ship:
			var dir: Vector3 = (p["pos"] - prev).normalized()
			var dist: float = (res["position"] as Vector3).distance_to(p["origin"])
			(res["collider"] as Ship).receive_cannonball(res["position"], res["normal"], dir, p["gun"], p["ammo"], dist, p["source"])
			hits += 1
			done = true
		elif not res.is_empty() and (res["collider"] as Object).has_method("take_shot"):
			var dir2: Vector3 = (p["pos"] - prev).normalized()
			var dist2: float = (res["position"] as Vector3).distance_to(p["origin"])
			res["collider"].take_shot(res["position"], res["normal"], dir2, p["gun"], p["ammo"], dist2, p["source"])
			hits += 1
			done = true
		elif not res.is_empty():
			Vfx.splash(self, res["position"])
			Sfx.play("splash", res["position"])
			misses += 1
			done = true
		elif ocean and p["pos"].y < ocean.height_at(p["pos"].x, p["pos"].z):
			Vfx.splash(self, Vector3(p["pos"].x, ocean.height_at(p["pos"].x, p["pos"].z), p["pos"].z))
			Sfx.play("splash", p["pos"])
			misses += 1
			done = true
		elif p["age"] > MAX_AGE_S or p["pos"].y < -60.0:
			done = true
		if done:
			_release(p)
			active.remove_at(i)
		else:
			(p["node"] as MeshInstance3D).global_position = p["pos"]
		i -= 1


func _release(p: Dictionary) -> void:
	var n: MeshInstance3D = p["node"]
	n.visible = false
	_pool.append(n)
