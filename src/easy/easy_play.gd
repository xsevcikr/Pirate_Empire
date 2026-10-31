class_name EasyPlay
extends RefCounted
## The kid-friendly layer's saved record, state["easy_play"]: goals done (id -> day) and stars, ports visited, the
## collection book (id -> how many found), hidden loot found (spot id -> day) and the parrot's count of finds.
## Everything here is static on the state so tests drive it without a scene.


static func store(state: Dictionary) -> Dictionary:
	if not (state.get("easy_play") is Dictionary):
		state["easy_play"] = {}
	var s: Dictionary = state["easy_play"]
	for k in ["done", "collection", "loot"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	if not (s.get("ports") is Array):
		s["ports"] = []
	for k in ["stars", "finds"]:
		s[k] = int(s.get(k, 0))
	return s


static func fresh() -> Dictionary:
	return {"done": {}, "stars": 0, "ports": [], "collection": {}, "loot": {}, "finds": 0}


# ---- collection ------------------------------------------------------------------------------------------

## Adds one of `id` to the book. Returns true when it is the first one (a new page filled).
static func collect(state: Dictionary, id: String) -> bool:
	var c: Dictionary = store(state)["collection"]
	var first: bool = int(c.get(id, 0)) <= 0
	c[id] = int(c.get(id, 0)) + 1
	return first


static func has_item(state: Dictionary, id: String) -> bool:
	return int(store(state)["collection"].get(id, 0)) > 0


static func count_of(state: Dictionary, id: String) -> int:
	return int(store(state)["collection"].get(id, 0))


## Different entries of a kind owned (shells, flags, ships).
static func kinds_owned(state: Dictionary, kind: String) -> int:
	var n: int = 0
	for id in CollectionData.ids_of(kind):
		if has_item(state, id):
			n += 1
	return n


static func total_of(state: Dictionary, kind: String) -> int:
	var n: int = 0
	for id in CollectionData.ids_of(kind):
		n += count_of(state, id)
	return n


static func rare_cards(state: Dictionary) -> int:
	var n: int = 0
	for id in CollectionData.ship_card_ids():
		if CollectionData.is_rare_card(id) and has_item(state, id):
			n += 1
	return n


## A ship card for `class_id` (sunk, captured or owned). Returns true when the card is new.
static func add_ship_card(state: Dictionary, class_id: String) -> bool:
	if not PortData.CLASS_ORDER.has(class_id):
		return false
	var id: String = CollectionData.ship_card(class_id)
	if has_item(state, id):
		return false
	return collect(state, id)


## The faction's flag, the first time one of its ships is sunk or taken. Returns the flag id when new, else "".
static func add_faction_flag(state: Dictionary, faction: String) -> String:
	var id: String = CollectionData.flag_of_faction(faction)
	if id == "" or has_item(state, id):
		return ""
	collect(state, id)
	return id


static func visit_port(state: Dictionary, port_id: String) -> bool:
	var ports: Array = store(state)["ports"]
	if ports.has(port_id):
		return false
	ports.append(port_id)
	return true


# ---- goals -------------------------------------------------------------------------------------------------

## A goal's counter: the collection and parrot counts live here, the rest are lifetime stats (Achievements).
static func value(state: Dictionary, stat: String) -> float:
	var s: Dictionary = store(state)
	match stat:
		"parrot_finds":
			return float(s["finds"])
		"ports_visited":
			return float((s["ports"] as Array).size())
		"shells":
			return float(total_of(state, "shells"))
		"shell_kinds":
			return float(kinds_owned(state, "shells"))
		"flags", "flag_kinds":
			return float(kinds_owned(state, "flags"))
		"ship_cards":
			return float(kinds_owned(state, "ships"))
		"rare_cards":
			return float(rare_cards(state))
		"maps_found":
			return float((state.get("map_fragments", []) as Array).size())
		"bosses_beaten":
			var n: float = 0.0
			for step in AchievementData.BOSS_STEPS:
				n += minf(Achievements.value(state, str(AchievementData.BOSS_STAT_OF_STEP.get(step, "boss_" + step))), 1.0)
			return n
	return Achievements.value(state, stat)


static func is_done(state: Dictionary, id: String) -> bool:
	return store(state)["done"].has(id)


static func stars(state: Dictionary) -> int:
	return int(store(state)["stars"])


## 0..1 progress toward a goal.
static func progress(state: Dictionary, goal: Dictionary) -> float:
	if is_done(state, str(goal["id"])):
		return 1.0
	return clampf(value(state, str(goal["stat"])) / maxf(float(goal["goal"]), 0.001), 0.0, 1.0)


## The first unfinished goals in list order, as many as the HUD card shows.
static func active(state: Dictionary, n: int = GoalData.ACTIVE_SHOWN) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g in GoalData.LIST:
		if not is_done(state, str(g["id"])):
			out.append(g)
			if out.size() >= n:
				break
	return out


## Marks every goal whose counter reached its target and pays its stars and gold. Returns the goals newly done.
static func check(state: Dictionary) -> Array[Dictionary]:
	var s: Dictionary = store(state)
	var fresh: Array[Dictionary] = []
	for g in GoalData.LIST:
		var id: String = str(g["id"])
		if s["done"].has(id):
			continue
		if value(state, str(g["stat"])) >= float(g["goal"]):
			s["done"][id] = int(state.get("day", 0))
			s["stars"] = int(s["stars"]) + int(g["stars"])
			state["gold"] = int(state.get("gold", 0)) + int(g["stars"]) * GoalData.GOLD_PER_STAR
			fresh.append(g)
	return fresh


## The parrot's colour for the stars earned.
static func parrot_colour(state: Dictionary) -> Dictionary:
	var best: Dictionary = GoalData.PARROT_COLOURS[0]
	for c in GoalData.PARROT_COLOURS:
		if stars(state) >= int(c["stars"]):
			best = c
	return best


## A goal's text, with the parrot's name filled in where it appears.
static func goal_text(id: String) -> String:
	var t: String = Loc.t("goal." + id)
	return t % Loc.t(ParrotHints.NAME_KEY) if t.contains("%s") else t
