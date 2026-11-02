class_name CameraRig
extends Node3D
## Third-person chase camera: 28 m behind, 11 m up, FOV 65. Right mouse drag orbits freely.

const DISTANCE: float = 24.0
const HEIGHT: float = 8.5
const FOLLOW_LAG: float = 2.5
const FOV_DEG: float = 65.0

var target: Node3D
var camera: Camera3D
## Deck walking (auto drive): the camera follows this anchor on the captain instead of the ship, close behind and above,
## and turns with the ship; a right-drag swings it round him and it stays where it was left.
var walk_anchor: Node3D
var _walk_yaw: float = 0.0
var _walk_pitch: float = 0.75
const WALK_DISTANCE: float = 7.0
const WALK_HEIGHT: float = 2.6
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
	elif event is InputEventMouseMotion and _dragging and walk_anchor != null:
		_walk_yaw -= event.relative.x * 0.006
		_walk_pitch = clampf(_walk_pitch + event.relative.y * 0.004, -0.15, 0.9)
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
	if walk_anchor != null and is_instance_valid(walk_anchor):
		_follow_walker(delta)
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
	if _shake > 0.0:  # a crash rattles the view; it dies away in about a second
		_shake_t += delta
		_shake = maxf(_shake - delta * 1.2, 0.0)
		pos += Vector3(sin(_shake_t * 61.0), sin(_shake_t * 47.0 + 1.3), cos(_shake_t * 53.0)) * _shake * 0.9 * scale
	global_position = pos
	camera.look_at(target.global_position + Vector3(0, 3.0, 0) + (-back) * 6.0, Vector3.UP)


## Starts or stops following the captain on deck. The view starts behind him, looking toward the bow.
func set_walker(anchor: Node3D) -> void:
	walk_anchor = anchor
	_walk_yaw = 0.0
	_walk_pitch = 0.75
	if anchor == null and target != null:  # back at the helm: the chase view picks up the ship's heading at once
		var fwd: Vector3 = -target.global_transform.basis.z
		_yaw = atan2(fwd.x, fwd.z)


func _follow_walker(delta: float) -> void:
	var fwd: Vector3 = -target.global_transform.basis.z
	var yaw: float = atan2(fwd.x, fwd.z) + _walk_yaw
	var back := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var focus: Vector3 = walk_anchor.global_position
	var pos: Vector3 = focus + back * WALK_DISTANCE * cos(_walk_pitch) + Vector3.UP * (WALK_HEIGHT * 0.4 + WALK_DISTANCE * sin(_walk_pitch))
	global_position = global_position.lerp(pos, clampf(1.0 - exp(-10.0 * delta), 0.0, 1.0)) if delta > 0.0 else pos
	camera.look_at(focus + Vector3.UP * 0.3, Vector3.UP)


## Rattles the camera by `amount` (0..1) after a collision; a stronger shake replaces a weaker one.
func shake(amount: float) -> void:
	var settings: Node = Svc.node("Settings")
	if settings != null and settings.get("accessibility") != null:
		amount *= float(settings.accessibility.camera_shake)  # the accessibility slider
	_shake = maxf(_shake, clampf(amount, 0.0, 1.0))
