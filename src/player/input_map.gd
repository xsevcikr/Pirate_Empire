class_name GameInput
extends RefCounted
## Registers the default keyboard bindings at runtime (rebinding comes with the options screen).

const ACTIONS: Dictionary = {
	"steer_left": [KEY_A, KEY_LEFT],
	"steer_right": [KEY_D, KEY_RIGHT],
	"sail_up": [KEY_W, KEY_UP],
	"sail_down": [KEY_S, KEY_DOWN],
	"camera_mode": [KEY_C],
	"time_fast": [KEY_T],
	"wind_cw": [KEY_BRACKETRIGHT],
	"wind_ccw": [KEY_BRACKETLEFT],
	"fire_port": [KEY_Q],
	"fire_starboard": [KEY_E],
	"elev_up": [KEY_R],
	"elev_down": [KEY_F],
	"crew_focus": [KEY_TAB],
	"grapple": [KEY_G],
	"photo_mode": [KEY_P],
	"ammo_1": [KEY_1],
	"ammo_2": [KEY_2],
	"ammo_3": [KEY_3],
	"ammo_4": [KEY_4],
	"ammo_5": [KEY_5],
	"wind_stronger": [KEY_EQUAL, KEY_KP_ADD],
	"wind_weaker": [KEY_MINUS, KEY_KP_SUBTRACT],
}


static func register() -> void:
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		InputMap.action_add_event("pause", esc)
		var start := InputEventJoypadButton.new()
		start.button_index = JOY_BUTTON_START
		InputMap.action_add_event("pause", start)
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		elif not InputMap.action_get_events(action).is_empty():
			continue
		for key: int in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key as Key
			InputMap.action_add_event(action, ev)
