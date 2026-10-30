class_name StarDome
extends MeshInstance3D
## Stars and the moon on a sphere round the camera. DayNight sets how dark it is, where the moon is and how much
## of the sky the clouds hide.

const RADIUS_M: float = 15000.0

var _mat: ShaderMaterial
var _t: float = 0.0


func _init() -> void:
	set_meta("kind", "star_dome")
	var s := SphereMesh.new()
	s.radius = RADIUS_M
	s.height = RADIUS_M * 2.0
	s.radial_segments = 32
	s.rings = 16
	mesh = s
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/stars.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = RADIUS_M
	visible = false


func set_night(night: float, cover: float, moon_dir: Vector3) -> void:
	visible = night > 0.01
	_mat.set_shader_parameter("night", night)
	_mat.set_shader_parameter("cover", cover)
	_mat.set_shader_parameter("moon_dir", moon_dir)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("star_time", _t)
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		global_position = cam.global_position
