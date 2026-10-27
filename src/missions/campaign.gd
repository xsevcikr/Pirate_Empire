class_name Campaign
extends RefCounted
## The first three acts as an ordered list of beats. `complete` advances when a beat's condition event arrives.

const ACTS: Array = [
	{"id": 1, "name": "Castaway Captain", "beats": ["escape_dredge", "tutorial_sail", "tutorial_shoot", "tutorial_board", "take_haven_tavern"], "unlocks": "act2"},
	{"id": 2, "name": "Letters and Lies", "beats": ["pick_patron", "build_first_base", "capture_fort_harrow_or_skull_bay"], "unlocks": "act3"},
	{"id": 3, "name": "The Lords of the Coast", "beats": ["defeat_anne_calloway", "defeat_redtooth_rael", "defeat_madame_zhu", "defeat_valcourt"], "unlocks": "act4"},
	{"id": 4, "name": "Beneath the Dead Reach", "beats": ["enter_dead_reach", "defeat_ghost_admiral", "defeat_kraken", "forge_tidecaller"], "unlocks": "act5"},
	{"id": 5, "name": "Pirate King", "beats": ["hold_four_ports", "defeat_iron_armada", "defeat_black_ibrahim", "crown_ceremony"], "unlocks": "new_game_plus"},
]

var act_index: int = 0
var beat_index: int = 0
var done_beats: Array[String] = []
var unlocked: Array[String] = ["act1"]
var finished_acts: int = 0


func current_beat() -> String:
	if act_index >= ACTS.size():
		return ""
	return ACTS[act_index]["beats"][beat_index]


## Report that a beat happened. Returns true if it was the current beat and the story moved on.
func complete(beat: String) -> bool:
	if beat != current_beat():
		return false
	done_beats.append(beat)
	beat_index += 1
	if beat_index >= ACTS[act_index]["beats"].size():
		unlocked.append(ACTS[act_index]["unlocks"])
		finished_acts += 1
		act_index += 1
		beat_index = 0
	return true


func is_done() -> bool:
	return act_index >= ACTS.size()
