class_name Sfx
extends RefCounted
## One-line calls for the rest of the game: Sfx.play("coin"), Sfx.bark("reload"), Sfx.music("boss_kraken").


static func play(id: String, pos: Variant = null) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.sfx.emit(id, pos)


static func bark(situation: String, arg: String = "") -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.bark.emit(situation, arg)


## Ask for a track for as long as a screen is open ("" gives the music back to the situation).
static func music(track: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.music_request.emit(track)
