class_name PrizeScreen
extends MenuScreen
## After a boarding is won: what was taken and what to do with the ship. Full capture fates come with M14.

signal decided(fate: int)

var summary_lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	super()
	_title_key = "prize.title"
	dim = 0.55


func _ready() -> void:
	get_tree().paused = true
	super()


func build() -> void:
	for line in summary_lines:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(l)
	add_button("prize.release", _choose.bind(CaptureFate.Fate.RELEASE))
	add_button("prize.sink", _choose.bind(CaptureFate.Fate.STRIP_AND_SINK))


func _choose(fate: int) -> void:
	get_tree().paused = false
	decided.emit(fate)
	closed.emit()
	queue_free()


func close() -> void:
	pass  # the player has to pick a fate
