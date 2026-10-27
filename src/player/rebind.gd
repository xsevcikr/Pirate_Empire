class_name Rebind
extends RefCounted
## Rebinding of keyboard actions and persistence in user://input.cfg.

const PATH: String = "user://input.cfg"


static func key_of(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE


## Returns the action that already uses `key`, or "" if it is free.
static func conflict(action: String, key: int) -> String:
	for a in GameInput.ACTIONS.keys():
		if a == action:
			continue
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == key:
				return a
	return ""


## Replace all keys of `action` with `key`. Refuses when another action already has that key.
static func rebind(action: String, key: int) -> bool:
	if not InputMap.has_action(action) or conflict(action, key) != "":
		return false
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key as Key
	InputMap.action_add_event(action, ev)
	return true


static func reset_defaults() -> void:
	for action: String in GameInput.ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
	GameInput.register()


static func save(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	for action: String in GameInput.ACTIONS:
		cfg.set_value("keys", action, key_of(action))
	cfg.save(path)


static func load_file(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for action: String in GameInput.ACTIONS:
		if cfg.has_section_key("keys", action):
			var k: int = cfg.get_value("keys", action)
			if InputMap.has_action(action):
				InputMap.action_erase_events(action)
				var ev := InputEventKey.new()
				ev.physical_keycode = k as Key
				InputMap.action_add_event(action, ev)
