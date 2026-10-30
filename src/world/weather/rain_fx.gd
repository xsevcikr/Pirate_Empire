class_name RainFx
extends CPUParticles3D
## Rain streaks in a box that follows the camera, slanted by the wind. WeatherSystem sets how hard it falls.

const MAX_DROPS: int = 1600
const BOX: Vector3 = Vector3(45.0, 18.0, 45.0)
const LEVELS: int = 4  ## the drop count changes in steps, since every change restarts the emitter

var level: float = 0.0
var _step: int = -1


func _init() -> void:
	set_meta("kind", "rain")
	emitting = false
	amount = MAX_DROPS
	lifetime = 1.1
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = BOX
	direction = Vector3.DOWN
	spread = 4.0
	initial_velocity_min = 26.0
	initial_velocity_max = 32.0
	gravity = Vector3(0, -9.8, 0)
	particle_flag_align_y = true
	var m := BoxMesh.new()
	m.size = Vector3(0.025, 1.3, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.78, 0.84, 0.92, 0.42)
	m.material = mat
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## `rain` 0..1. The box sits over `cam` and the drops lean downwind.
func set_rain(rain: float, cam: Camera3D, wind_dir: Vector2) -> void:
	level = clampf(rain, 0.0, 1.0)
	var step: int = ceili(level * LEVELS) if level > 0.05 else 0
	if step != _step:
		_step = step
		emitting = step > 0
		if step > 0:
			amount = maxi(MAX_DROPS * step / LEVELS, 1)
	if cam != null and is_inside_tree():
		var fwd: Vector3 = -cam.global_transform.basis.z
		global_position = cam.global_position + Vector3(fwd.x, 0.0, fwd.z).normalized() * 20.0 + Vector3.UP * 14.0
	gravity = Vector3(wind_dir.x * 6.0, -9.8, wind_dir.y * 6.0)
