class_name Vfx
extends RefCounted
## Fire-and-forget particle bursts built from CPUParticles3D (cheap, headless-safe). Smoke, spray and sparks use
## the cartoon sprites from tools/gen_ui_skin.py (Kenney particle-pack style): round puffs that swell and fade,
## water drops and a foam ring that spreads on the sea where a shot lands.

const FX_DIR: String = "res://assets/ui/"

static var _sprite_mats: Dictionary = {}
static var _ring_mat: StandardMaterial3D


## A billboard material for one of the fx sprites ("fx_puff", "fx_drop", "fx_spark"), shared by key.
static func sprite_material(sprite: String, additive: bool = false) -> StandardMaterial3D:
	var key: String = sprite + ("+" if additive else "")
	if _sprite_mats.has(key):
		return _sprite_mats[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var p: String = FX_DIR + sprite + ".png"
	if ResourceLoader.exists(p):
		mat.albedo_texture = load(p)
	_sprite_mats[key] = mat
	return mat


## Sprite particles: they swell from `size` to `size * grow` and fade out over their life.
static func sprites(parent: Node, pos: Vector3, sprite: String, color: Color, amount: int, speed: float, lifetime: float,
		size: float, grow: float = 2.0, gravity: float = 0.0, spread_deg: float = 180.0, dir: Vector3 = Vector3.UP,
		additive: bool = false) -> CPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.25
	p.damping_max = speed * 0.5
	p.gravity = Vector3(0, gravity, 0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.max_value = maxf(grow, 1.0)
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(1.0, grow))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.add_point(0.6, Color(color, color.a * 0.8))
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = sprite_material(sprite, additive)
	p.mesh = quad
	p.emitting = true
	parent.add_child(p)
	p.global_position = pos
	parent.get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
	return p


## A white ring of foam that spreads flat on the water and fades, where a shot or a hull meets the sea.
static func foam_ring(parent: Node, pos: Vector3, size: float = 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var p: String = FX_DIR + "fx_ring.png"
		if ResourceLoader.exists(p):
			_ring_mat.albedo_texture = load(p)
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.0, 4.0) * size
	plane.material = _ring_mat
	ring.mesh = plane
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.15
	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 1.4).from(Vector3(0.4, 1.0, 0.4)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "transparency", 1.0, 1.4).from(0.0).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)


static func burst(parent: Node, pos: Vector3, color: Color, amount: int, speed: float, lifetime: float,
		size: float, gravity: float = -9.8, spread_deg: float = 180.0, dir: Vector3 = Vector3.UP) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = dir
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 5
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	p.mesh = mesh
	p.emitting = true
	parent.add_child(p)
	p.global_position = pos
	parent.get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)


## A cannon going off: a bright flash and sparks, then big round cartoon smoke puffs that roll out and swell.
static func muzzle(parent: Node, pos: Vector3, dir: Vector3) -> void:
	sprites(parent, pos, "fx_spark", Color(1.0, 0.85, 0.4, 1.0), 6, 10.0, 0.18, 1.6, 1.4, 0.0, 20.0, dir, true)
	sprites(parent, pos + dir * 0.8, "fx_puff", Color(1.0, 0.6, 0.25, 0.95), 4, 6.0, 0.25, 1.6, 1.8, 0.0, 15.0, dir)
	sprites(parent, pos + dir * 1.2, "fx_puff", Color(0.96, 0.96, 0.98, 0.9), 14, 7.0, 3.2, 2.0, 3.2, 0.6, 30.0, dir)


## A shot hitting the sea: a column of spray drops, a white puff and a ring of foam spreading on the water.
static func splash(parent: Node, pos: Vector3, size: float = 1.0) -> void:
	sprites(parent, pos, "fx_drop", Color(0.92, 0.98, 1.0, 1.0), 26, 11.0 * size, 1.3, 0.7 * size, 0.6, -14.0, 18.0)
	sprites(parent, pos + Vector3.UP * 0.5, "fx_puff", Color(1.0, 1.0, 1.0, 0.85), 6, 2.5 * size, 1.1, 1.6 * size, 2.2, -1.0, 40.0)
	foam_ring(parent, pos, size)


static func splinters(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.5, 0.33, 0.18), 18, 6.0, 1.5, 0.12, -9.8, 90.0)
	burst(parent, pos, Color(0.4, 0.4, 0.4, 0.6), 8, 2.0, 2.0, 0.4, 0.5, 90.0)


static func flames(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1.0, 0.5, 0.1, 0.9), 12, 2.5, 0.9, 0.3, 3.0, 25.0)
	burst(parent, pos + Vector3.UP, Color(0.2, 0.2, 0.2, 0.6), 6, 2.0, 3.0, 0.7, 2.0, 20.0)


static func explosion(parent: Node, pos: Vector3) -> void:
	sprites(parent, pos, "fx_spark", Color(1.0, 0.8, 0.3, 1.0), 24, 20.0, 0.6, 1.8, 1.2, -6.0, 180.0, Vector3.UP, true)
	sprites(parent, pos, "fx_puff", Color(1.0, 0.55, 0.15, 0.95), 18, 12.0, 0.9, 3.0, 2.0, 0.0, 180.0)
	sprites(parent, pos, "fx_puff", Color(0.32, 0.3, 0.34, 0.85), 22, 7.0, 4.5, 3.4, 2.6, 1.2, 180.0)
