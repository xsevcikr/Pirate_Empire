class_name StormFx
extends RefCounted
## The storm's one-shot effects: St Elmo's fire crackling on a masthead before a strike, and the bolt itself.

const BOLT_COLOR: Color = Color(0.85, 0.92, 1.0)
const ELMO_COLOR: Color = Color(0.45, 0.75, 1.0)
const BOLT_HEIGHT_M: float = 420.0
const BOLT_SEGMENTS: int = 9


static func _glow_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 4.0
	m.disable_fog = true
	return m


## A pale blue glow that flickers on `ship` at world position `top` until it is freed.
static func st_elmo(ship: Node3D, top: Vector3) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", "st_elmo")
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	ball.mesh = sm
	ball.material_override = _glow_mat(ELMO_COLOR)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = ELMO_COLOR
	light.light_energy = 3.0
	light.omni_range = 18.0
	root.add_child(light)
	ship.add_child(root)
	root.global_position = top
	if root.is_inside_tree():
		var tw: Tween = root.create_tween().set_loops()
		tw.tween_property(ball, "scale", Vector3.ONE * 1.6, 0.12)
		tw.tween_property(ball, "scale", Vector3.ONE * 0.8, 0.09)
	return root


## A jagged bolt from the clouds down to `top`, with a blinding light, gone in a third of a second.
static func bolt(parent: Node, top: Vector3) -> Node3D:
	var root := Node3D.new()
	root.set_meta("kind", "bolt")
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(top.x * 13.0 + top.z * 7.0)
	var mat: StandardMaterial3D = _glow_mat(BOLT_COLOR)
	var start: Vector3 = top + Vector3(rng.randf_range(-60, 60), BOLT_HEIGHT_M, rng.randf_range(-60, 60))
	var prev: Vector3 = start
	for i in BOLT_SEGMENTS:
		var t: float = float(i + 1) / BOLT_SEGMENTS
		var jag: float = 22.0 * (1.0 - t)
		var next: Vector3 = start.lerp(top, t) + Vector3(rng.randf_range(-jag, jag), 0.0, rng.randf_range(-jag, jag))
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = prev.distance_to(next)
		cyl.radial_segments = 4
		cyl.rings = 1
		seg.mesh = cyl
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(seg)
		var mid: Vector3 = (prev + next) * 0.5
		var axis: Vector3 = (next - prev).normalized()
		var side: Vector3 = axis.cross(Vector3.FORWARD).normalized() if absf(axis.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		seg.global_transform = Transform3D(Basis(side, axis, side.cross(axis)), mid)
		prev = next
	var light := OmniLight3D.new()
	light.light_color = BOLT_COLOR
	light.light_energy = 12.0
	light.omni_range = 160.0
	root.add_child(light)
	light.global_position = top + Vector3.UP * 20.0
	if root.is_inside_tree():
		root.get_tree().create_timer(0.35).timeout.connect(root.queue_free)
	return root
