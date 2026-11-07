class_name HitFx
extends RefCounted
## Hit feedback on top of the particles: a short rattle of the chase camera, sparks and a flash where iron meets
## wood or iron. Kept subtle on purpose. The camera shake slider scales every rattle (0 turns it off) and the
## "Hit sparks and flashes" switch turns the sparks and flashes off.

const SHAKE_FIRE: float = 0.08        ## each of our own guns going off
const SHAKE_HIT_MIN: float = 0.2      ## a ball striking our hull
const SHAKE_HIT_MAX: float = 0.5
const SHAKE_NEAR_MISS: float = 0.1    ## a ball landing close alongside
const SHAKE_EXPLOSION: float = 0.6    ## a magazine going up next to us
const NEAR_MISS_M: float = 30.0
const FALLOFF_M: float = 120.0        ## rattles from other ships fade out over this distance
const EXPLOSION_FALLOFF_M: float = 350.0
const FLASH_S: float = 0.12


static func enabled() -> bool:
	var st: Node = Svc.node("Settings")
	if st == null or st.get("accessibility") == null:
		return true
	return bool(st.accessibility.hit_effects)


## How much of a rattle reaches a camera `dist` metres away (1 at the camera, 0 at `falloff` and beyond).
static func falloff(dist: float, radius: float = FALLOFF_M) -> float:
	return clampf(1.0 - dist / maxf(radius, 0.001), 0.0, 1.0)


## The shake for a hit on our own hull: bigger balls and weaker hulls rattle more, within the min/max.
static func hit_shake(damage: float, hull_hp: float) -> float:
	return clampf(SHAKE_HIT_MIN + damage / maxf(hull_hp, 1.0) * 4.0, SHAKE_HIT_MIN, SHAKE_HIT_MAX)


static func _rig(node: Node) -> CameraRig:
	if node == null or not node.is_inside_tree():
		return null
	var cam: Camera3D = node.get_viewport().get_camera_3d()
	return cam.get_parent() as CameraRig if cam != null else null


## The ship (or whatever) the chase camera follows, or null when there is no chase camera.
static func focus(node: Node) -> Node3D:
	var rig: CameraRig = _rig(node)
	return rig.target if rig != null else null


## Rattle the chase camera by `amount`, weakened by the distance from `world_pos` to what it follows.
static func shake(node: Node, amount: float, world_pos: Variant = null, radius: float = FALLOFF_M) -> void:
	var rig: CameraRig = _rig(node)
	if rig == null:
		return
	if world_pos is Vector3 and rig.target != null:
		amount *= falloff((world_pos as Vector3).distance_to(rig.target.global_position), radius)
	if amount > 0.005:
		rig.shake(amount)


## Hot sparks thrown off a hit along the surface normal, with a quick orange flash.
static func sparks(parent: Node, pos: Vector3, normal: Vector3 = Vector3.UP, amount: int = 22) -> void:
	if not enabled() or parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.45
	p.direction = normal if normal.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 7.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, -14.0, 0)
	p.particle_flag_align_y = true  # streaks point the way they fly
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.07, 0.6, 0.07)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.78, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	mat.emission_energy_multiplier = 3.0
	mesh.material = mat
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = true
	parent.add_child(p)
	p.global_position = pos
	p.set_meta("kind", "sparks")
	parent.get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)
	flash(parent, pos + p.direction * 0.4)


## A short-lived point light, gone in a blink.
static func flash(parent: Node, pos: Vector3, energy: float = 3.0, radius: float = 9.0) -> void:
	if not enabled() or parent == null or not parent.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	light.set_meta("kind", "hit_flash")
	parent.add_child(light)
	light.global_position = pos
	var tw: Tween = light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, FLASH_S)
	tw.tween_callback(light.queue_free)
