class_name MenuScreen
extends Control
## Base for menu pages: a centred column of focusable buttons, back on ui_cancel, child pages stacked on top.

signal closed

var dim: float = 0.0  ## backdrop alpha; the main menu draws its own
var _box: VBoxContainer
var _title_key: String = ""
var _child: MenuScreen = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Look.ui_theme()  # pages sit under CanvasLayers, which stop the root window's theme


func _ready() -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null and not bus.settings_changed.is_connected(_rebuild):
		bus.settings_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.08, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(460, 0)
	_box.add_theme_constant_override("separation", 10)
	center.add_child(_box)
	if _title_key != "":
		var title := Label.new()
		title.text = Loc.t(_title_key)
		title.add_theme_font_size_override("font_size", 34)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(title)
	build()
	focus_first.call_deferred()


## Override: add controls to `_box`.
func build() -> void:
	pass


func add_button(key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = Loc.t(key)
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(cb)
	b.pressed.connect(Sfx.play.bind("ui_click"))
	_box.add_child(b)
	return b


func add_row(label_key: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = Loc.t(label_key)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	control.focus_mode = Control.FOCUS_ALL
	control.custom_minimum_size = Vector2(220, 36)
	row.add_child(control)
	_box.add_child(row)


func focus_first() -> void:
	if _child != null or not is_inside_tree():
		return
	var btn: Control = _first_focusable(self)
	if btn != null:
		btn.grab_focus()


func _first_focusable(n: Node) -> Control:
	for c in n.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL and not (c is Button and (c as Button).disabled):
			return c
		var deeper: Control = _first_focusable(c)
		if deeper != null:
			return deeper
	return null


func open_child(screen: MenuScreen) -> void:
	_child = screen
	visible = false
	get_parent().add_child(screen)
	screen.closed.connect(_on_child_closed.bind(screen))


func _on_child_closed(screen: MenuScreen) -> void:
	screen.queue_free()
	_child = null
	visible = true
	_rebuild()


func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _child == null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
