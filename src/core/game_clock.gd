extends Node
## In-game clock. One full day cycle lasts DAY_LENGTH_S real seconds (48 min).

signal hour_changed(day: int, hour: float)

const DAY_LENGTH_S: float = 2880.0

var day: int = 1
var hour: float = 10.0
var time_scale: float = 1.0
var paused: bool = false


func advance(real_seconds: float) -> void:
	if paused:
		return
	hour += real_seconds * time_scale * 24.0 / DAY_LENGTH_S
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	hour_changed.emit(day, hour)


func _process(delta: float) -> void:
	advance(delta)
