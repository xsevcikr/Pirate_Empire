class_name CameraRig
extends Node3D
## Third-person chase camera: 28 m behind, 11 m up, FOV 65. Right mouse drag orbits freely.

const DISTANCE: float = 28.0
const HEIGHT: float = 11.0
const FOLLOW_LAG: float = 2.5
const FOV_DEG: float = 65.0

var target: Node3D
var camera: Camera3D
var _yaw: float = 0.0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = FOV_DEG
	camera.far = 20000.0
	camera.near = 0.2
	add_child(camera)
	camera.make_current()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_orbit_yaw -= event.relative.x * 0.005
		_orbit_pitch = clampf(_orbit_pitch + event.relative.y * 0.005, -0.5, 0.9)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.fov = clampf(camera.fov - 3.0, 35.0, 90.0)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.fov = clampf(camera.fov + 3.0, 35.0, 90.0)


func _process(delta: float) -> void:
	if target == null:
		return
	var fwd: Vector3 = -target.global_transform.basis.z
	var ship_yaw: float = atan2(fwd.x, fwd.z)
	_yaw = lerp_angle(_yaw, ship_yaw, 1.0 - exp(-FOLLOW_LAG * delta))
	if not _dragging:
		_orbit_yaw = lerpf(_orbit_yaw, 0.0, 1.0 - exp(-1.5 * delta))
		_orbit_pitch = lerpf(_orbit_pitch, 0.0, 1.0 - exp(-1.5 * delta))
	var yaw: float = _yaw + _orbit_yaw
	var back := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var scale: float = 1.0
	if target is Ship:
		scale = clampf((target as Ship).stats.length_m / 18.0, 1.0, 3.2)
	var height: float = (HEIGHT + _orbit_pitch * 25.0) * scale
	var pos: Vector3 = target.global_position + back * DISTANCE * scale + Vector3.UP * height
	global_position = pos
	camera.look_at(target.global_position + Vector3(0, 3.0, 0) + (-back) * 6.0, Vector3.UP)
