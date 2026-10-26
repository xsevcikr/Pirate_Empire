class_name Ship
extends RigidBody3D
## A sailing ship: buoyancy sampled on the Gerstner surface, wind sail thrust,
## quadratic hull drag, rudder yaw and wind heel. Forward is -Z, starboard is +X.

const RHO_REF_WIND_MS: float = 10.29  # 20 knots
const WATER_LATERAL_DAMP: float = 3.0
const ROLL_DAMP: float = 0.9
const PITCH_DAMP: float = 1.2
const RUDDER_TIME_S: float = 1.2
const HEEL_COEFF: float = 0.25
const POINT_COLUMNS: int = 4
const POINT_ROWS: int = 4

@export var stats: ShipStats

var ocean: WaveModel
var wind: WindModel

## Player or AI inputs.
var rudder_input: float = 0.0
var sail_level: int = 3

var rudder_actual: float = 0.0
var submerged_fraction: float = 0.0
var angle_off_wind: float = 90.0
var speed_forward_ms: float = 0.0

var _points: PackedVector3Array = PackedVector3Array()
var _k_point: float = 0.0
var _c_point: float = 0.0
var _k_drag: float = 0.0
var _f_ref: float = 0.0


func _ready() -> void:
	if stats == null:
		stats = load("res://data/ships/sloop.tres")
	mass = stats.mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.3, 0)
	# Replace the project-wide default damping; drag is modelled explicitly below.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = false
	can_sleep = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(stats.beam_m, stats.draft_m + stats.freeboard_m, stats.length_m)
	shape.shape = box
	shape.position = Vector3(0, (stats.freeboard_m - stats.draft_m) * 0.5, 0)
	add_child(shape)
	_build_points()
	_build_visuals()
	var vmax: float = MathUtils.knots_to_ms(stats.max_speed_kn)
	_k_drag = stats.mass_kg / (stats.accel_tau_s * vmax)
	_f_ref = _k_drag * vmax * vmax


func _build_points() -> void:
	_points.clear()
	for r in POINT_ROWS:
		for c in POINT_COLUMNS:
			var x: float = lerpf(-0.5, 0.5, c / float(POINT_COLUMNS - 1)) * stats.beam_m * 0.9
			var z: float = lerpf(-0.5, 0.5, r / float(POINT_ROWS - 1)) * stats.length_m * 0.9
			_points.append(Vector3(x, -stats.draft_m, z))
	var n: float = float(_points.size())
	_k_point = stats.mass_kg * 9.81 / (n * stats.draft_m)
	var omega: float = sqrt(9.81 / stats.draft_m)
	_c_point = 2.0 * 0.6 * stats.mass_kg * omega / n


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if ocean == null or wind == null:
		return
	var dt: float = state.step
	var xf: Transform3D = state.transform
	var forward: Vector3 = -xf.basis.z
	var right: Vector3 = xf.basis.x
	var flat_fwd := Vector2(forward.x, forward.z)
	if flat_fwd.length() < 0.001:
		return
	var vel: Vector3 = state.linear_velocity

	# Buoyancy
	var wet: int = 0
	var max_depth: float = stats.draft_m * 2.0
	for p in _points:
		var offset: Vector3 = xf.basis * p
		var world: Vector3 = xf.origin + offset
		var h: float = ocean.height_at(world.x, world.z)
		var depth: float = h - world.y
		if depth > 0.0:
			wet += 1
			var pv: Vector3 = state.get_velocity_at_local_position(offset)
			var f: float = _k_point * minf(depth, max_depth) - _c_point * pv.y
			state.apply_force(Vector3.UP * maxf(f, 0.0), offset)
	submerged_fraction = float(wet) / float(_points.size())
	var in_water: bool = submerged_fraction > 0.25

	# Forward and lateral speeds
	var flat_vel := Vector3(vel.x, 0.0, vel.z)
	speed_forward_ms = flat_vel.dot(forward)
	var lateral: float = flat_vel.dot(right)

	if in_water:
		# Sail thrust: terminal speed = max_speed * wind_ratio * point-of-sail factor * sqrt(level).
		angle_off_wind = wind.angle_off_wind_deg(flat_fwd)
		var factor: float = SailModel.speed_factor(angle_off_wind, stats.square_rig)
		var level: float = SailModel.LEVELS[clampi(sail_level, 0, 3)]
		var ratio: float = minf(wind.speed_ms() / RHO_REF_WIND_MS, 1.5)
		var thrust: float = _f_ref * ratio * ratio * factor * factor * level
		state.apply_central_force(forward * thrust)
		# Hull drag
		state.apply_central_force(-forward * _k_drag * speed_forward_ms * absf(speed_forward_ms))
		state.apply_central_force(-right * stats.mass_kg * WATER_LATERAL_DAMP * lateral)
		# Heel away from the wind
		var side: float = wind.direction.x * right.x + wind.direction.y * right.z
		var heel: float = HEEL_COEFF * _f_ref * ratio * ratio * level * side
		state.apply_torque(forward * heel * stats.length_m * 0.25)
		# Rudder
		rudder_actual = move_toward(rudder_actual, rudder_input, dt / RUDDER_TIME_S)
		var vmax: float = MathUtils.knots_to_ms(stats.max_speed_kn)
		var authority: float = clampf(absf(speed_forward_ms) / (0.35 * vmax), 0.0, 1.0)
		var desired: float = -rudder_actual * deg_to_rad(stats.turn_rate_deg_s) * authority
		var av: Vector3 = state.angular_velocity
		av.y = lerpf(av.y, desired, 1.0 - exp(-3.0 * dt))
		state.angular_velocity = av

	# Roll and pitch damping (local axes)
	var local_av: Vector3 = xf.basis.inverse() * state.angular_velocity
	local_av.x *= exp(-PITCH_DAMP * dt)
	local_av.z *= exp(-ROLL_DAMP * dt)
	state.angular_velocity = xf.basis * local_av


## Heading as a flat unit vector (x, z).
func heading() -> Vector2:
	var f: Vector3 = -global_transform.basis.z
	return Vector2(f.x, f.z).normalized()


func speed_knots() -> float:
	return MathUtils.ms_to_knots(linear_velocity.length())


func heel_deg() -> float:
	return rad_to_deg(asin(clampf(global_transform.basis.x.y, -1.0, 1.0)))


func pitch_deg() -> float:
	return rad_to_deg(asin(clampf(-global_transform.basis.z.y, -1.0, 1.0)))


func _build_visuals() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.22, 0.12)
	wood.roughness = 0.85
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color(0.55, 0.40, 0.25)
	deck_mat.roughness = 0.9
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.92, 0.88, 0.78)
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED

	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(stats.beam_m, stats.draft_m + stats.freeboard_m, stats.length_m * 0.8)
	hull.mesh = hull_mesh
	hull.material_override = wood
	hull.position = Vector3(0, (stats.freeboard_m - stats.draft_m) * 0.5, stats.length_m * 0.1)
	add_child(hull)

	var bow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(stats.beam_m, stats.length_m * 0.2, stats.draft_m + stats.freeboard_m)
	bow.mesh = prism
	bow.material_override = wood
	bow.rotation_degrees = Vector3(-90, 0, 0)
	bow.position = Vector3(0, (stats.freeboard_m - stats.draft_m) * 0.5, -stats.length_m * 0.4)
	add_child(bow)

	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(stats.beam_m * 0.9, 0.1, stats.length_m * 0.85)
	deck.mesh = deck_mesh
	deck.material_override = deck_mat
	deck.position = Vector3(0, stats.freeboard_m + 0.05, 0)
	add_child(deck)

	for i in stats.mast_count:
		var z: float = lerpf(-0.15, 0.15, 0.5 if stats.mast_count == 1 else i / float(stats.mast_count - 1)) * stats.length_m
		var mast := MeshInstance3D.new()
		var mast_mesh := CylinderMesh.new()
		mast_mesh.top_radius = 0.12
		mast_mesh.bottom_radius = 0.2
		mast_mesh.height = stats.length_m * 0.75
		mast.mesh = mast_mesh
		mast.material_override = wood
		mast.position = Vector3(0, stats.freeboard_m + mast_mesh.height * 0.5, z)
		add_child(mast)
		var sail := MeshInstance3D.new()
		var sail_mesh := BoxMesh.new()
		sail_mesh.size = Vector3(0.05, mast_mesh.height * 0.7, stats.length_m * 0.4)
		sail.mesh = sail_mesh
		sail.material_override = cloth
		sail.position = Vector3(0, stats.freeboard_m + mast_mesh.height * 0.45, z + stats.length_m * 0.2)
		add_child(sail)
