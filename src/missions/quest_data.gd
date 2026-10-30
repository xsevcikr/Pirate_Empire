class_name QuestData
extends RefCounted
## Quest-board jobs. The first one is scripted (spec section 3); its loot always holds the first map fragment.

const JOBS: Dictionary = {
	"gallows_raid": {
		"title": "quest.gallows_raid.title", "text": "quest.gallows_raid.text", "reward": 300, "island": 10,
		"ship": {"class": "sloop", "guns_per_side": 2, "crew": 6, "faction": "merchant", "hull_hp": 700.0},
		"loot": {"gold": [180, 260], "cargo": {"sugar": 12}, "map_fragment": "drowned_purse_1"},
	},
}
const BOARD_ORDER: Array[String] = ["gallows_raid"]


static func available(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id in BOARD_ORDER:
		if not state["quests"].has(id) and not state["quests_done"].has(id):
			out.append(id)
	return out
