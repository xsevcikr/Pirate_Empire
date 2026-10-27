class_name InteriorScreen
extends MenuScreen
## Below decks (I): the player's ship cut open. Three views (gun deck, hold, captain's cabin), drag to look around,
## wheel to move closer. The scene is in ShipInterior; this only frames it.

const VIEWS: Dictionary = {
	"gun_deck": {"y": 1.1, "z": 0.0, "d": 11.0},
	"hold": {"y": -3.6, "z": -0.62, "d": 8.0},
	"cabin": {"y": 0.6, "z": 0.66, "d": 6.0},
}

var stats: ShipStats
var view_id: String = "gun_deck"
var _cam: Camera3D
var _vp: SubViewport
var _yaw: float = 0.35
var _dist: float = 11.0
var _half_l: float = 10.0


func _init() -> void:
	super()
	_title_key = "interior.title"
	dim = 0.0


func build() -> void:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(1280, 720)
	cont.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.38, 0.32)
	env.ambient_light_energy = 1.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var inner: Node3D = ShipInterior.build(stats, Session.state)
	_vp.add_child(inner)
	_half_l = stats.length_m * 0.42
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_vp.add_child(_cam)
	_cam.make_current()
	add_child(cont)
	move_child(cont, 0)
	_frame()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for id in VIEWS.keys():
		var b := Button.new()
		b.text = Loc.t("interior." + id)
		b.pressed.connect(_pick.bind(id))
		row.add_child(b)
	add_button("menu.back", close)
	var holder: Control = _box.get_parent()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var info := Label.new()
	info.text = Loc.t("interior.gold") % [int(Session.state["gold"]), ShipInterior.chest_count(int(Session.state["gold"]))]
	_box.add_child(info)


func _pick(id: String) -> void:
	view_id = id
	_frame()


func _frame() -> void:
	if _cam == null:
		return
	var v: Dictionary = VIEWS[view_id]
	var focus := Vector3(0.0, float(v["y"]), float(v["z"]) * _half_l)
	var off := Vector3(cos(_yaw), 0.0, sin(_yaw)) * _dist * float(v["d"]) / 11.0
	_cam.global_position = focus + off + Vector3(0.0, 2.6, 0.0)
	_cam.look_at(focus, Vector3.UP)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw = clampf(_yaw - (event as InputEventMouseMotion).relative.x * 0.005, -1.3, 1.3)
		_frame()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist - 0.5, 2.5)
			_frame()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist + 0.5, 14.0)
			_frame()
