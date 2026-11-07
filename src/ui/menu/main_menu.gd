class_name MainMenu
extends MenuScreen
## Boot screen: the treasure-island picture with the PIRATE EMPIRE lettering along the bottom, and the
## Continue, New Game, Load, Settings, Quit buttons over the open sea on the right.
## The picture comes from tools/render_title.gd and the lettering from tools/gen_title_logo.py.

const ISLAND: Texture2D = preload("res://assets/title/title_island.png")
const LOGO: Texture2D = preload("res://assets/title/title_logo.png")

var continue_button: Button
var new_game_button: Button


func _ready() -> void:
	Svc.node("Game").change_state(1)  # Game.State.MENU
	super()


func build() -> void:
	var back := TextureRect.new()
	back.name = "Island"
	back.texture = ISLAND
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	move_child(back, 0)
	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.anchor_left = 0.2
	logo.anchor_right = 0.8
	logo.anchor_top = 0.7
	logo.anchor_bottom = 0.97
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	# the button column sits over the open water right of the island
	var column: Control = _box.get_parent() as Control
	column.anchor_left = 0.76
	column.anchor_right = 0.97
	column.anchor_top = 0.16
	column.anchor_bottom = 0.68
	column.offset_left = 0.0
	column.offset_right = 0.0
	column.offset_top = 0.0
	column.offset_bottom = 0.0
	_box.custom_minimum_size = Vector2(360, 0)
	continue_button = add_button("menu.continue", _on_continue)
	continue_button.disabled = Session.latest_slot() < 0
	new_game_button = add_button("menu.new_game", func() -> void: open_child(NewGameScreen.new()))
	add_button("ui.load", func() -> void: open_child(SaveLoadScreen.new()))
	add_button("menu.settings", func() -> void: open_child(SettingsScreen.new()))
	add_button("ui.quit", func() -> void: get_tree().quit())
	for b in _box.get_children():
		(b as Button).custom_minimum_size.y = 54
		(b as Button).add_theme_font_size_override("font_size", 24)


func focus_first() -> void:
	if _child != null:
		return
	var target: Button = new_game_button if continue_button.disabled else continue_button
	target.grab_focus()


func _on_continue() -> void:
	if Session.load_slot(Session.latest_slot()):
		Session.enter_world(get_tree())


func close() -> void:
	pass  # nothing sits below the main menu
