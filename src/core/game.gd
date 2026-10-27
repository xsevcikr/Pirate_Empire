extends Node
## Top-level game state machine.

enum State { BOOT, MENU, PLAYING, PAUSED, CUTSCENE }

var state: State = State.BOOT


func change_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	EventBus.game_state_changed.emit(int(new_state))


func _ready() -> void:
	change_state(State.MENU)
