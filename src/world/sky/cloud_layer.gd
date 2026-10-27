class_name CloudLayer
extends MeshInstance3D
## Cumulus on a big flat quad that follows the camera so the sky is never empty. DayNight tints it.

const HEIGHT_M: float = 1400.0
const SIZE_M: float = 24000.0

var _mat: ShaderMaterial
var _t: float = 0.0


func _init() -> void:
	var q := PlaneMesh.new()
	q.size = Vector2(SIZE_M, SIZE_M)
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/clouds.gdshader")
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 20000.0


func tint(lit: Color, shade: Color, coverage: float) -> void:
	_mat.set_shader_parameter("lit_color", lit)
	_mat.set_shader_parameter("shade_color", shade)
	_mat.set_shader_parameter("coverage", coverage)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("cloud_time", _t)
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		global_position = Vector3(cam.global_position.x, HEIGHT_M, cam.global_position.z)
