class_name CameraRig
extends Node3D
## Third-person chase camera: 28 m behind, 11 m up, FOV 65. Right mouse drag orbits freely.

const DISTANCE: float = 24.0
const HEIGHT: float = 8.5
const FOLLOW_LAG: float = 2.5
const FOV_DEG: float = 65.0

var target: Node3D
## While the captain walks the deck the camera stays close behind him instead (the ship still sets the yaw).
var focus: Node3D
## ... from off the ship's beam (the sails are edge-on from there), looking down on the deck.
const FOCUS_DISTANCE: float = 8.0
const FOCUS_HEIGHT: float = 7.0
const FOCUS_SIDE_YAW: float = PI * 0.5
var _had_focus: bool = false
var _glide: float = 0.0  ## 1 just after switching between ship and captain, gliding to 0
var _from_pos: Vector3
var _from_look: Vector3
var _last_look: Vector3
var camera: Camera3D
var _yaw: float = 0.0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0
var _dragging: bool = false
var _shake: float = 0.0
var _shake_t: float = 0.0


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
		scale = clampf((target as Ship).stats.length_m / 18.0, 0.7, 3.2)
	var height: float = (HEIGHT + _orbit_pitch * 25.0) * scale
	var pos: Vector3 = target.global_position + back * DISTANCE * scale + Vector3.UP * height
	var look_at_pos: Vector3 = target.global_position + Vector3(0, 3.0, 0) + (-back) * 6.0
	if focus != null and is_instance_valid(focus):
		var fy: float = yaw + FOCUS_SIDE_YAW
		var side := Vector3(-sin(fy), 0.0, -cos(fy))
		pos = focus.global_position + side * FOCUS_DISTANCE + Vector3.UP * (FOCUS_HEIGHT + _orbit_pitch * 8.0)
		look_at_pos = focus.global_position + Vector3(0, 0.9, 0)
	var has_focus: bool = focus != null and is_instance_valid(focus)
	if has_focus != _had_focus:
		_had_focus = has_focus
		_glide = 1.0
		_from_pos = global_position
		_from_look = _last_look
	if _glide > 0.0:
		_glide = maxf(_glide - delta / 0.8, 0.0)
		var k: float = _glide * _glide * (3.0 - 2.0 * _glide)
		pos = pos.lerp(_from_pos, k)
		look_at_pos = look_at_pos.lerp(_from_look, k)
	_last_look = look_at_pos
	if _shake > 0.0:  # a crash rattles the view; it dies away in about a second
		_shake_t += delta
		_shake = maxf(_shake - delta * 1.2, 0.0)
		pos += Vector3(sin(_shake_t * 61.0), sin(_shake_t * 47.0 + 1.3), cos(_shake_t * 53.0)) * _shake * 0.9 * scale
	global_position = pos
	camera.look_at(look_at_pos, Vector3.UP)


## Rattles the camera by `amount` (0..1) after a collision; a stronger shake replaces a weaker one.
func shake(amount: float) -> void:
	var settings: Node = Svc.node("Settings")
	if settings != null and settings.get("accessibility") != null:
		amount *= float(settings.accessibility.camera_shake)  # the accessibility slider
	_shake = maxf(_shake, clampf(amount, 0.0, 1.0))
