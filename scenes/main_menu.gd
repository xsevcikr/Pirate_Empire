extends Node
## Entry scene: shows the main menu.


func _ready() -> void:
	add_child(MainMenu.new())
