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
	"interact": [KEY_SPACE],
	"world_map": [KEY_M],
	"kedge": [KEY_X],
	"dump_cargo": [KEY_B],
	"tour_journal": [KEY_N],
	"shanty": [KEY_H],
	"rivals": [KEY_O],
	"interior": [KEY_I],
	"skills": [KEY_U],
	"captain_log": [KEY_L],
	"customize": [KEY_Y],
	"fish": [KEY_COMMA],
	"ammo_1": [KEY_1],
	"ammo_2": [KEY_2],
	"ammo_3": [KEY_3],
	"ammo_4": [KEY_4],
	"ammo_5": [KEY_5],
	"deck_light": [KEY_J],
	"deck_heavy": [KEY_K],
	"deck_block": [KEY_SHIFT],
	"deck_dodge": [KEY_CTRL],
	"deck_kick": [KEY_V],
	"deck_fire": [KEY_F],
	"deck_use": [KEY_E],
	"deck_grenade": [KEY_G],
	"wind_stronger": [KEY_EQUAL, KEY_KP_ADD],
	"wind_weaker": [KEY_MINUS, KEY_KP_SUBTRACT],
}

## Gamepad buttons for the deck fight.
const DECK_PAD: Dictionary = {
	"deck_light": JOY_BUTTON_X, "deck_heavy": JOY_BUTTON_Y, "deck_block": JOY_BUTTON_LEFT_SHOULDER, "deck_dodge": JOY_BUTTON_B,
	"deck_kick": JOY_BUTTON_RIGHT_SHOULDER, "deck_fire": JOY_BUTTON_RIGHT_STICK, "deck_use": JOY_BUTTON_A,
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
		if action == "interact":
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_A
			InputMap.action_add_event(action, pad)
		if action == "deck_light" or action == "deck_heavy":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT if action == "deck_light" else MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, click)
		var pad_button: int = DECK_PAD.get(action, -1)
		if pad_button >= 0:
			var jb := InputEventJoypadButton.new()
			jb.button_index = pad_button as JoyButton
			InputMap.action_add_event(action, jb)
