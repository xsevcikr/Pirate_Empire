class_name MainMenu
extends MenuScreen
## Boot screen: Continue, New Game, Load, Settings, Quit.

var continue_button: Button
var new_game_button: Button


func _init() -> void:
	super()
	_title_key = "game.title"


func _ready() -> void:
	Svc.node("Game").change_state(1)  # Game.State.MENU
	super()


func build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.03, 0.08, 0.14)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	move_child(back, 0)
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
