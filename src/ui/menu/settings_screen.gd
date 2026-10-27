class_name SettingsScreen
extends MenuScreen
## Graphics, audio, language, accessibility and key rebinding.

var _waiting_action: String = ""
var _key_buttons: Dictionary = {}  ## action -> Button
var _page: int = 0
const PAGES: Array[String] = ["menu.page_general", "menu.page_access", "menu.page_keys"]


func _init() -> void:
	super()
	_title_key = "menu.settings"
	dim = 0.0


func build() -> void:
	var tabs := HBoxContainer.new()
	for i in PAGES.size():
		var t := Button.new()
		t.text = Loc.t(PAGES[i])
		t.toggle_mode = true
		t.button_pressed = i == _page
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(func() -> void:
			_page = i
			_rebuild())
		tabs.add_child(t)
	_box.add_child(tabs)
	match _page:
		0:
			_build_general()
		1:
			_build_access()
		2:
			_build_keys()
	add_button("menu.back", close)


func _build_general() -> void:
	var st: Node = Svc.node("Settings")
	var presets: Array = GraphicsPresets.TABLE.keys()
	var preset := OptionButton.new()
	for p: String in presets:
		preset.add_item(Loc.t("menu.preset_" + p))
	preset.select(presets.find(st.graphics_preset))
	preset.item_selected.connect(func(i: int) -> void:
		st.graphics_preset = presets[i]
		st.apply())
	add_row("menu.graphics", preset)
	var vol := HSlider.new()
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = st.master_volume
	vol.value_changed.connect(func(v: float) -> void:
		st.master_volume = v
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	add_row("menu.volume", vol)
	for n in ["music", "sfx", "voice", "ambience"]:
		var sl := HSlider.new()
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(st.get(n + "_volume"))
		sl.value_changed.connect(func(v: float) -> void:
			st.set(n + "_volume", v)
			st.apply())
		add_row("menu.vol_" + n, sl)
	var lang := OptionButton.new()
	var locales: Array = Loc.locales()
	for l in locales:
		lang.add_item(Loc.t("menu.lang_" + str(l)))
	lang.select(locales.find(st.locale))
	lang.item_selected.connect(func(i: int) -> void:
		st.locale = locales[i]
		st.apply())
	add_row("menu.language", lang)


func _build_access() -> void:
	var a: Accessibility = Svc.node("Settings").accessibility
	var shake := HSlider.new()
	shake.max_value = 1.0
	shake.step = 0.05
	shake.value = a.camera_shake
	shake.value_changed.connect(a.set_camera_shake)
	add_row("menu.camera_shake", shake)
	var fov := HSlider.new()
	fov.min_value = 50.0
	fov.max_value = 100.0
	fov.step = 1.0
	fov.value = a.fov
	fov.value_changed.connect(a.set_fov)
	add_row("menu.fov", fov)
	var subs := CheckButton.new()
	subs.button_pressed = a.subtitles
	subs.toggled.connect(func(on: bool) -> void: a.subtitles = on)
	add_row("menu.subtitles", subs)
	var cb := CheckButton.new()
	cb.button_pressed = a.colorblind_markers
	cb.toggled.connect(func(on: bool) -> void: a.colorblind_markers = on)
	add_row("menu.colorblind", cb)


func _build_keys() -> void:
	_key_buttons.clear()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_box.add_child(scroll)
	for action: String in GameInput.ACTIONS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = action
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.text = OS.get_keycode_string(Rebind.key_of(action) as Key)
		b.custom_minimum_size = Vector2(160, 32)
		b.pressed.connect(_begin_rebind.bind(action, b))
		row.add_child(b)
		list.add_child(row)
		_key_buttons[action] = b
	add_button("menu.reset_keys", func() -> void:
		Rebind.reset_defaults()
		Rebind.save()
		_rebuild())


func _begin_rebind(action: String, button: Button) -> void:
	_waiting_action = action
	button.text = Loc.t("menu.press_key")


## Called with the next key event while a rebind is pending. Returns false when the key is taken.
func apply_rebind(key: int) -> bool:
	if _waiting_action == "":
		return false
	var ok: bool = Rebind.rebind(_waiting_action, key)
	_waiting_action = ""
	if ok:
		Rebind.save()
	_rebuild()
	return ok


func _input(event: InputEvent) -> void:
	if _waiting_action != "" and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).physical_keycode != KEY_ESCAPE:
			apply_rebind((event as InputEventKey).physical_keycode)
		else:
			_waiting_action = ""
			_rebuild()


func close() -> void:
	Svc.node("Settings").save_settings()
	closed.emit()
