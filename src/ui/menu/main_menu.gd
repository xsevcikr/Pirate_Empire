class_name MainMenu
extends MenuScreen
## Boot screen: the title island picture with the logo along the bottom and the theme playing, and the buttons
## Continue, New Game, Load, Settings, Quit down the left.

const PICTURE: String = "res://assets/ui/title_island.png"

var continue_button: Button
var new_game_button: Button


func _init() -> void:
	super()
	_title_key = ""


func _ready() -> void:
	Svc.node("Game").change_state(1)  # Game.State.MENU
	super()
	Sfx.music(AudioData.MENU_TRACK)
	tree_exiting.connect(func() -> void: Sfx.music(""))


func build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.05, 0.45, 0.68)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	move_child(back, 0)
	if ResourceLoader.exists(PICTURE):
		var pic := TextureRect.new()
		pic.name = "TitlePicture"
		pic.texture = load(PICTURE)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		move_child(pic, 1)
	var logo := TitleLogo.new()
	logo.name = "TitleLogo"
	logo.anchor_left = 0.0
	logo.anchor_right = 1.0
	logo.anchor_top = 1.0
	logo.anchor_bottom = 1.0
	logo.offset_top = -270.0
	logo.offset_bottom = -40.0
	add_child(logo)
	# the buttons go down the left over a soft panel, leaving the island and the logo clear
	var centre: Control = _box.get_parent()
	centre.anchor_right = 0.0
	centre.offset_left = 60.0
	centre.offset_right = 420.0
	centre.offset_bottom = -300.0
	_box.custom_minimum_size = Vector2(320, 0)
	continue_button = add_button("menu.continue", _on_continue)
	continue_button.disabled = Session.latest_slot() < 0
	new_game_button = add_button("menu.new_game", func() -> void: open_child(NewGameScreen.new()))
	add_button("ui.load", func() -> void: open_child(SaveLoadScreen.new()))
	add_button("menu.settings", func() -> void: open_child(SettingsScreen.new()))
	add_button("ui.quit", func() -> void: get_tree().quit())


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
