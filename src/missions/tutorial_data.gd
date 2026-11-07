class_name TutorialData
extends RefCounted
## The first-ten-minutes tutorial as data: each step waits for one named event, then moves to the next.

## Events: left_dock, steered, timer, finn_talked, lugger_looted, docked, sold_fish, hired_crew, bought_food, quest_taken.
const STEPS: Array[Dictionary] = [
	{"id": "leave_dock", "prompt": "tut.leave_dock", "wait": "left_dock"},
	{"id": "steer", "prompt": "tut.steer", "wait": "steered"},
	{"id": "compass", "prompt": "tut.compass", "wait": "timer", "seconds": 12.0},
	{"id": "back_to_dock", "prompt": "tut.back_to_dock", "wait": "docked"},
	{"id": "find_finn", "prompt": "tut.find_finn", "wait": "finn_talked"},
	{"id": "hunt_lugger", "prompt": "tut.hunt_lugger", "wait": "lugger_looted"},
	{"id": "return_port", "prompt": "tut.return_port", "wait": "docked"},
	{"id": "sell_fish", "prompt": "tut.sell_fish", "wait": "sold_fish"},
	{"id": "hire_crew", "prompt": "tut.hire_crew", "wait": "hired_crew"},
	{"id": "buy_food", "prompt": "tut.buy_food", "wait": "bought_food"},
	{"id": "quest_board", "prompt": "tut.quest_board", "wait": "quest_taken"},
	{"id": "done", "prompt": "", "wait": ""},
]
const HIRES_NEEDED: int = 4


static func index_of(step_id: String) -> int:
	for i in STEPS.size():
		if STEPS[i]["id"] == step_id:
			return i
	return STEPS.size() - 1


## The step that follows `step_id` when `event_name` arrives, or the same step if the event is not the awaited one.
static func advance(step_id: String, event_name: String) -> String:
	var i: int = index_of(step_id)
	if STEPS[i]["wait"] == "" or STEPS[i]["wait"] != event_name:
		return step_id
	return STEPS[mini(i + 1, STEPS.size() - 1)]["id"]


static func prompt_key(step_id: String) -> String:
	return STEPS[index_of(step_id)]["prompt"]
