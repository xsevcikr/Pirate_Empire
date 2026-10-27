class_name Vfx
extends RefCounted
## Fire-and-forget particle bursts built from CPUParticles3D (cheap, headless-safe).


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
	mesh.radial_segments = 6
	mesh.rings = 3
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


static func muzzle(parent: Node, pos: Vector3, dir: Vector3) -> void:
	burst(parent, pos, Color(1.0, 0.7, 0.3, 0.9), 14, 9.0, 0.15, 0.25, 0.0, 25.0, dir)
	burst(parent, pos + dir * 1.0, Color(0.85, 0.85, 0.85, 0.7), 24, 5.0, 4.0, 0.9, 0.5, 35.0, dir)


static func splash(parent: Node, pos: Vector3, size: float = 1.0) -> void:
	burst(parent, pos, Color(0.9, 0.97, 1.0, 0.85), 40, 9.0 * size, 1.6, 0.25 * size, -9.8, 25.0)


static func splinters(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(0.5, 0.33, 0.18), 18, 6.0, 1.5, 0.12, -9.8, 90.0)
	burst(parent, pos, Color(0.4, 0.4, 0.4, 0.6), 8, 2.0, 2.0, 0.4, 0.5, 90.0)


static func flames(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1.0, 0.5, 0.1, 0.9), 12, 2.5, 0.9, 0.3, 3.0, 25.0)
	burst(parent, pos + Vector3.UP, Color(0.2, 0.2, 0.2, 0.6), 6, 2.0, 3.0, 0.7, 2.0, 20.0)


static func explosion(parent: Node, pos: Vector3) -> void:
	burst(parent, pos, Color(1.0, 0.55, 0.15, 0.95), 80, 18.0, 1.2, 1.1, -3.0, 180.0)
	burst(parent, pos, Color(0.25, 0.25, 0.25, 0.8), 40, 8.0, 5.0, 2.0, 1.0, 180.0)
