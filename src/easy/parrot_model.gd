class_name ParrotModel
extends Node3D
## The captain's parrot, built from a few primitives in Kenney's flat cartoon colours (no Kenney kit has a bird).
## It flies along with the ship, a little above the stern, flapping; when it spots hidden treasure it flies off to
## circle over the spot until the ship comes to collect. Its feathers change colour as the captain earns stars.

const SCALE: float = 1.6  ## cartoon size, so it reads from the chase camera
const FLY_SPEED: float = 26.0
const HOME_UP_M: float = 8.0  ## it flies off the starboard quarter, clear of the sails, where the chase camera sees it
const CIRCLE_R: float = 5.0
const CIRCLE_H: float = 7.0

var ship: Node3D
var ocean: WaveModel
var target_spot: Variant = null  ## Vector2 of the treasure it is circling, or null to stay with the ship
var colour_id: String = ""

var _wing_l: Node3D
var _wing_r: Node3D
var _head: Node3D
var _parts: Dictionary = {}  ## "body" / "wing" / "head" -> Array of MeshInstance3D
var _t: float = 0.0
var _squawk_t: float = 0.0


func _ready() -> void:
	if get_child_count() == 0:
		build()


func build() -> void:
	for c in get_children():
		c.queue_free()
	_parts = {"body": [], "wing": [], "head": []}
	var rig := Node3D.new()
	rig.scale = Vector3.ONE * SCALE
	add_child(rig)
	var dark := Color(0.12, 0.1, 0.14)
	var white := Color(1, 1, 1)
	# body: an egg, leaning forward (-Z is forward)
	var body := _part(rig, _sphere(0.32), Color.WHITE, Vector3(0, 0, 0), Vector3(-20, 0, 0), "body")
	body.scale = Vector3(0.85, 1.15, 0.9)
	_part(rig, _sphere(0.2), Color(1.0, 0.92, 0.55), Vector3(0, -0.06, -0.2), Vector3.ZERO, "").scale = Vector3(0.9, 1.2, 0.5)
	# tail feathers
	_part(rig, _box(Vector3(0.18, 0.05, 0.55)), Color.WHITE, Vector3(0, -0.2, 0.42), Vector3(-30, 0, 0), "wing")
	_part(rig, _box(Vector3(0.12, 0.04, 0.45)), Color.WHITE, Vector3(0, -0.15, 0.38), Vector3(-15, 0, 0), "body")
	# head
	_head = Node3D.new()
	_head.position = Vector3(0, 0.36, -0.1)
	rig.add_child(_head)
	_part(_head, _sphere(0.22), Color.WHITE, Vector3.ZERO, Vector3.ZERO, "head")
	var b := CylinderMesh.new()
	b.top_radius = 0.0
	b.bottom_radius = 0.11
	b.height = 0.26
	b.radial_segments = 8
	_part(_head, b, Color(0.22, 0.2, 0.24), Vector3(0, -0.06, -0.25), Vector3(-120, 0, 0), "")
	for sx in [-1.0, 1.0]:
		_part(_head, _sphere(0.07), white, Vector3(0.12 * sx, 0.05, -0.14), Vector3.ZERO, "")
		_part(_head, _sphere(0.035), dark, Vector3(0.14 * sx, 0.06, -0.19), Vector3.ZERO, "")
	# crest
	_part(_head, _box(Vector3(0.05, 0.18, 0.12)), Color.WHITE, Vector3(0, 0.22, 0.04), Vector3(-25, 0, 0), "wing")
	# wings on pivots at the shoulders
	_wing_l = Node3D.new()
	_wing_l.position = Vector3(-0.22, 0.08, 0)
	rig.add_child(_wing_l)
	_part(_wing_l, _box(Vector3(0.55, 0.05, 0.3)), Color.WHITE, Vector3(-0.27, 0, 0.05), Vector3(0, -12, 0), "wing")
	_part(_wing_l, _box(Vector3(0.25, 0.04, 0.22)), Color.WHITE, Vector3(-0.6, 0, 0.12), Vector3(0, -25, 0), "body")
	_wing_r = Node3D.new()
	_wing_r.position = Vector3(0.22, 0.08, 0)
	rig.add_child(_wing_r)
	_part(_wing_r, _box(Vector3(0.55, 0.05, 0.3)), Color.WHITE, Vector3(0.27, 0, 0.05), Vector3(0, 12, 0), "wing")
	_part(_wing_r, _box(Vector3(0.25, 0.04, 0.22)), Color.WHITE, Vector3(0.6, 0, 0.12), Vector3(0, 25, 0), "body")
	# feet
	for sx in [-1.0, 1.0]:
		_part(rig, _box(Vector3(0.05, 0.14, 0.05)), Color(0.4, 0.4, 0.45), Vector3(0.08 * sx, -0.38, 0), Vector3.ZERO, "")
	set_colours({})


## Feathers in a colour from GoalData.PARROT_COLOURS ({} picks the green one).
func set_colours(c: Dictionary) -> void:
	if c.is_empty():
		c = GoalData.PARROT_COLOURS[0]
	colour_id = str(c["id"])
	for k: String in ["body", "wing", "head"]:
		for mi: MeshInstance3D in _parts.get(k, []):
			mi.material_override = Kenney.flat(c[k], 0.0, true)


func squawk() -> void:
	_squawk_t = 0.8


func _process(delta: float) -> void:
	_t += delta
	_squawk_t = maxf(_squawk_t - delta, 0.0)
	var flap_speed: float = 14.0 if _squawk_t > 0.0 else 9.0
	var flap: float = sin(_t * flap_speed) * deg_to_rad(40.0)
	if _wing_l != null:
		_wing_l.rotation.z = flap
		_wing_r.rotation.z = -flap
		_head.rotation.y = sin(_t * 1.3) * 0.5 if _squawk_t <= 0.0 else sin(_t * 30.0) * 0.25
	if ship == null or not is_instance_valid(ship):
		return
	var goal: Vector3 = home_point()
	if target_spot is Vector2:
		var spot: Vector2 = target_spot
		var a: float = _t * 0.9
		var sea: float = ocean.height_at(spot.x, spot.y) if ocean != null else 0.0
		goal = Vector3(spot.x + cos(a) * CIRCLE_R, sea + CIRCLE_H, spot.y + sin(a) * CIRCLE_R)
	var to: Vector3 = goal - global_position
	var step: float = FLY_SPEED * delta
	var far: bool = to.length() > 120.0 and target_spot == null
	if far:  # left far behind (a teleport, a load): just be there
		global_position = goal
	elif to.length() > step:
		global_position += to.normalized() * maxf(step, to.length() * minf(delta * 3.0, 1.0))
	else:
		global_position = goal
	global_position.y += sin(_t * 2.0) * 0.02
	var flat := Vector3(to.x, 0.0, to.z)
	var face: Vector3 = flat if flat.length() > 0.5 else -ship.global_transform.basis.z
	if face.length() > 0.01:
		var want: float = atan2(-face.x, -face.z)
		rotation.y = lerp_angle(rotation.y, want, minf(delta * 5.0, 1.0))


func home_point() -> Vector3:
	var fwd: Vector3 = -ship.global_transform.basis.z
	var yaw: float = atan2(-fwd.x, -fwd.z)
	var beam: float = 6.0
	var length: float = 20.0
	if ship is Ship and (ship as Ship).stats != null:
		beam = (ship as Ship).stats.beam_m
		length = (ship as Ship).stats.length_m
	return ship.global_position + Basis(Vector3.UP, yaw) * Vector3(beam * 0.5 + 5.0, HOME_UP_M, length * 0.45 + 2.0)


func _part(parent: Node3D, mesh: Mesh, c: Color, at: Vector3, rot_deg: Vector3, group: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Kenney.flat(c, 0.0, true)
	mi.position = at
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	if group != "":
		_parts[group].append(mi)
	return mi


static func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _sphere(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m
