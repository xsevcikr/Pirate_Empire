extends Node
## Global typed signals so systems stay decoupled.

signal game_state_changed(new_state: int)
signal settings_changed

signal toast(text: String)
signal port_docked(port_id: String)
signal port_undocked(port_id: String)
signal trade_made(kind: String, id: String, units: float, gold: int)
signal crew_hired(tier: String)
signal prize_taken(info: Dictionary)
signal quest_taken(quest_id: String)
signal quest_completed(quest_id: String)
signal tutorial_event(event_name: String)
signal tutorial_step_changed(step_id: String)
