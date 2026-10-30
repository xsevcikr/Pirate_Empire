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
	get_tree().root.theme = Look.ui_theme()
	change_state(State.MENU)


var crashed_last_session: bool = false


func _enter_tree() -> void:
	crashed_last_session = CrashLog.begin()
	get_tree().set_auto_accept_quit(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		CrashLog.flush()
		CrashLog.end()
		get_tree().quit()
