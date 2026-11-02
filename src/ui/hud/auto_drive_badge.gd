class_name AutoDriveBadge
extends CanvasLayer
## Top-centre badge for auto drive. Off: a small button "K  Auto drive". On: a gold-edged card that says where the
## ship is going (chart mark and distance, or the heading it holds) and which keys walk the captain.

const GOLD := Color(1.0, 0.8, 0.3)

var drive: AutoDrive
var panel: PanelContainer
var title: Label
var status: Label
var keys: Label
var button: Button
var _tick: float = 0.0


func _ready() -> void:
	layer = 7
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	root.offset_left = -260.0
	root.offset_right = 260.0
	root.offset_top = 84.0
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Look.ui_theme()
	add_child(root)

	button = Button.new()
	button.name = "AutoDriveButton"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(func() -> void:
		if drive != null:
			drive.toggle())
	root.add_child(button)

	panel = PanelContainer.new()
	panel.name = "AutoDriveCard"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.15, 0.26, 0.9)
	box.border_color = GOLD
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	title = _label(22, GOLD)
	col.add_child(title)
	status = _label(17, Color(1, 1, 1))
	col.add_child(status)
	keys = _label(14, Color(0.78, 0.84, 1.0))
	col.add_child(keys)
	refresh()


func _label(size: int, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		refresh()
	if panel.visible:  # a slow gold pulse so it is plain the ship is steering itself
		title.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)


func refresh() -> void:
	var on: bool = drive != null and drive.is_on()
	var key: String = OS.get_keycode_string(Rebind.key_of("auto_drive") as Key)
	panel.visible = on
	button.text = Loc.t("autodrive.button_helm" if on else "autodrive.button") % key
	if not on:
		return
	title.text = Loc.t("autodrive.title")
	var s: Ship = drive.ship()
	if drive.pilot.mode == Autopilot.Mode.COURSE and s != null:
		var left: float = drive.pilot.distance_left(Vector2(s.global_position.x, s.global_position.z))
		status.text = Loc.t("autodrive.status_course") % (left / 1000.0)
	elif s != null:
		status.text = Loc.t("autodrive.status_hold") % Loc.t(Autopilot.compass_key(drive.pilot.hold_dir))
	keys.text = Loc.t("autodrive.keys") % key
