class_name PrizeScreen
extends MenuScreen
## After a boarding is won: what was taken and what to do with the ship. Offers all six capture fates.

signal decided(fate: int)

var summary_lines: PackedStringArray = PackedStringArray()
var can_capture: bool = true


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
	var cap: Button = add_button("prize.capture", _choose.bind(CaptureFate.Fate.CAPTURE))
	cap.disabled = not can_capture
	if not can_capture:
		cap.tooltip_text = Loc.t("prize.no_crew")
	add_button("prize.sell", _choose.bind(CaptureFate.Fate.SELL))
	add_button("prize.sink", _choose.bind(CaptureFate.Fate.STRIP_AND_SINK))
	add_button("prize.release", _choose.bind(CaptureFate.Fate.RELEASE))
	add_button("prize.ransom", _choose.bind(CaptureFate.Fate.RANSOM))
	add_button("prize.press", _choose.bind(CaptureFate.Fate.PRESS_CREW))


func _choose(fate: int) -> void:
	get_tree().paused = false
	decided.emit(fate)
	closed.emit()
	queue_free()


func close() -> void:
	pass  # the player has to pick a fate
