class_name WeatherBadge
extends CanvasLayer
## A small line at the top of the screen: the weather and the time of day ("Storm, night").

var weather: WeatherSystem
var _label: Label
var _shown: String = ""


func _ready() -> void:
	layer = 4
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_label.position = Vector2(-120, 8)
	_label.size = Vector2(240, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func text_for(id: String, hour: float) -> String:
	var phase: String = "night" if WeatherRules.is_night(hour) else ("dawn" if hour < 9.0 and hour >= 5.0 else ("dusk" if hour >= 17.0 and hour < 20.0 else "day"))
	return Loc.t("weather.badge") % [Loc.t("weather." + id), Loc.t("weather.phase." + phase)]


func _process(_delta: float) -> void:
	if weather == null:
		return
	var clock: Node = Svc.node("GameClock")
	var t: String = text_for(weather.now(), float(clock.hour) if clock != null else 12.0)
	if t != _shown:
		_shown = t
		_label.text = t
