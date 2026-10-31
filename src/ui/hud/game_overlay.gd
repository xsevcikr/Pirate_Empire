class_name GameOverlay
extends CanvasLayer
## Bottom-of-screen messages: the tutorial prompt, the dock hint, toasts, and the gold/food/cargo line.

const TOAST_SECONDS: float = 4.0
const MAX_TOASTS: int = 4

var _prompt: Label
var _hint: Label
var _info: Label
var _nav: Label
var _toasts: VBoxContainer
var _toast_age: Array[float] = []


func _ready() -> void:
	layer = 5
	_info = _make_label(Vector2.ZERO, 20)
	_info.anchor_top = 1.0
	_info.anchor_bottom = 1.0
	_info.offset_left = 32.0
	_info.offset_top = -76.0
	_info.offset_bottom = -46.0
	_nav = _make_label(Vector2.ZERO, 18)
	_nav.anchor_left = 1.0
	_nav.anchor_right = 1.0
	_nav.offset_left = -520.0
	_nav.offset_right = -24.0
	_nav.offset_top = 40.0
	_nav.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt = _bottom_centre(26, -230.0)
	_hint = _bottom_centre(24, -180.0)
	_toasts = VBoxContainer.new()
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -520.0
	_toasts.offset_right = -24.0
	_toasts.offset_top = 90.0
	add_child(_toasts)
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.connect(add_toast)


func set_nav(text: String) -> void:
	_nav.text = text


func _bottom_centre(size: int, offset_y: float) -> Label:
	var l: Label = _make_label(Vector2.ZERO, size)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = 0.0
	l.offset_right = 0.0
	l.offset_top = offset_y
	l.offset_bottom = offset_y + 40.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_dock_hint(text: String) -> void:
	_hint.text = text


func set_info(text: String) -> void:
	_info.text = text


## The one-line note at the bottom left, empty while all is well: the hold only when it is nearly full and morale
## only when the men are unhappy. Gold, food and water live on the status panel (StatusPanel) beside the chart.
static func status_text(st: Dictionary) -> String:
	var parts: Array[String] = []
	var cap: float = PortService.cargo_capacity(st)
	var full: float = PortService.cargo_used(st) / cap if cap > 0.0 else 0.0
	if full >= 0.8:
		parts.append(Loc.t("hud.status_cargo") % (full * 100.0))
	var morale: float = float(st["morale"])
	if morale < Morale.BANDS["content"]["min"]:
		parts.append(Loc.t("hud.status_morale") % Loc.t("morale." + Morale.band(morale)))
	return "   ".join(parts)


func add_toast(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toasts.add_child(l)
	_toast_age.append(0.0)
	while _toast_age.size() > MAX_TOASTS:
		_drop_toast(0)


func _process(delta: float) -> void:
	for i in range(_toast_age.size() - 1, -1, -1):
		_toast_age[i] += delta
		if _toast_age[i] > TOAST_SECONDS:
			_drop_toast(i)


func _drop_toast(i: int) -> void:
	var c: Node = _toasts.get_child(i)
	_toasts.remove_child(c)
	c.queue_free()
	_toast_age.remove_at(i)
