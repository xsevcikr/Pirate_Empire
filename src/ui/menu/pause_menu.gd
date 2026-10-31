class_name PauseMenu
extends MenuScreen
## In-game pause: resume, save, load, settings, back to the main menu.

var world: Node


func _init() -> void:
	super()
	_title_key = "menu.paused"
	dim = 0.6


func _ready() -> void:
	get_tree().paused = true
	Svc.node("Game").change_state(3)  # Game.State.PAUSED
	super()


func build() -> void:
	add_button("menu.resume", close)
	add_button("crew.screen", func() -> void: open_child(CrewScreen.new()))
	add_button("goals.title", func() -> void: open_child(GoalsScreen.new()))
	add_button("coll.title", func() -> void: open_child(CollectionScreen.new()))
	add_button("ui.save", func() -> void:
		var s := SaveLoadScreen.new()
		s.world = world
		open_child(s))
	add_button("ui.load", func() -> void: open_child(SaveLoadScreen.new()))
	add_button("menu.settings", func() -> void: open_child(SettingsScreen.new()))
	add_button("menu.quit_to_menu", func() -> void: Session.quit_to_menu(get_tree()))


func close() -> void:
	get_tree().paused = false
	Svc.node("Game").change_state(2)  # Game.State.PLAYING
	closed.emit()
	queue_free()
