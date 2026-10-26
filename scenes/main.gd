extends Node3D

@onready var _label: Label = %Title


func _ready() -> void:
	_label.text = "Pirate Empire"
