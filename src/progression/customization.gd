class_name Customization
extends RefCounted
## The captain's choices, kept in state["custom"]: flag, sails, hull, figurehead, pet, captain looks, false colours.


static func default_custom() -> Dictionary:
	return {
		"flag": {"emblem": 0, "color": 1, "layout": 0, "pixels": []},
		"sail": {"pattern": 0, "color": 0},
		"hull": {"paint": 0, "trim": 0, "lanterns": 1, "gold_leaf": false},
		"figurehead": "plain", "pet": "", "false_colors": "",
		"captain": CustomizationData.DEFAULT_CAPTAIN.duplicate(), "owned": [],
	}


static func get_custom(state: Dictionary) -> Dictionary:
	if not state.has("custom") or (state["custom"] as Dictionary).is_empty():
		state["custom"] = default_custom()
	return state["custom"]


static func set_flag(state: Dictionary, emblem: int, color: int, layout: int) -> bool:
	if emblem < 0 or emblem >= CustomizationData.EMBLEMS.size() or color < 0 or color >= CustomizationData.FLAG_COLORS.size() \
			or layout < 0 or layout >= CustomizationData.FLAG_LAYOUTS.size():
		return false
	var f: Dictionary = get_custom(state)["flag"]
	f["emblem"] = emblem
	f["color"] = color
	f["layout"] = layout
	f["pixels"] = []
	return true


## The pixel flag editor: a 16x16 grid of palette indexes. Replaces the emblem flag until set_flag is used again.
static func set_pixels(state: Dictionary, pixels: Array) -> bool:
	if pixels.size() != CustomizationData.PIXEL_SIZE * CustomizationData.PIXEL_SIZE:
		return false
	for p in pixels:
		if int(p) < 0 or int(p) >= CustomizationData.PIXEL_PALETTE.size():
			return false
	get_custom(state)["flag"]["pixels"] = pixels.duplicate()
	return true


static func set_sail(state: Dictionary, pattern: int, color: int) -> bool:
	if pattern < 0 or pattern >= CustomizationData.SAIL_PATTERNS.size() or color < 0 or color >= CustomizationData.SAIL_COLORS.size():
		return false
	var s: Dictionary = get_custom(state)["sail"]
	s["pattern"] = pattern
	s["color"] = color
	return true


static func gold_leaf_allowed(state: Dictionary) -> bool:
	return int(state.get("fame", 0)) >= CustomizationData.GOLD_LEAF_FAME


static func set_hull(state: Dictionary, paint: int, trim: int, lanterns: int, gold_leaf: bool) -> bool:
	if paint < 0 or paint >= CustomizationData.HULL_PAINTS.size() or trim < 0 or trim >= CustomizationData.TRIM_COLORS.size() \
			or lanterns < 0 or lanterns >= CustomizationData.LANTERN_STYLES.size():
		return false
	if gold_leaf and not gold_leaf_allowed(state):
		return false
	var h: Dictionary = get_custom(state)["hull"]
	h["paint"] = paint
	h["trim"] = trim
	h["lanterns"] = lanterns
	h["gold_leaf"] = gold_leaf
	return true


static func set_figurehead(state: Dictionary, id: String) -> bool:
	if not CustomizationData.FIGUREHEADS.has(id):
		return false
	get_custom(state)["figurehead"] = id
	# The Siren lifts the crew's spirits once, the first time she is mounted.
	if id == "siren" and not bool(state.get("siren_paid", false)):
		state["siren_paid"] = true
		var m: float = float(CustomizationData.FIGUREHEADS["siren"]["morale_bonus"])
		state["morale"] = clampf(float(state["morale"]) + m, 0.0, 100.0)
	return true


static func set_pet(state: Dictionary, id: String) -> bool:
	if id != "" and not CustomizationData.PETS.has(id):
		return false
	get_custom(state)["pet"] = id
	return true


static func set_ship_name(state: Dictionary, name: String) -> bool:
	var clean: String = name.strip_edges()
	if clean.length() < 1 or clean.length() > 24:
		return false
	state["ship_name"] = clean
	return true


## A captain look is free, bought, or earned: has the captain got it?
static func owns(state: Dictionary, slot: String, choice: String) -> bool:
	var key: String = "%s/%s" % [slot, choice]
	if not CustomizationData.GATED.has(key):
		return true
	var gate: Dictionary = CustomizationData.GATED[key]
	if gate.has("achievement") and Achievements.unlocked(state, str(gate["achievement"])):
		return true
	return get_custom(state)["owned"].has(key)


static func buy(state: Dictionary, slot: String, choice: String) -> bool:
	var key: String = "%s/%s" % [slot, choice]
	if owns(state, slot, choice) or not CustomizationData.GATED.has(key) or not CustomizationData.GATED[key].has("cost"):
		return false
	var cost: int = int(CustomizationData.GATED[key]["cost"])
	if int(state["gold"]) < cost:
		return false
	state["gold"] = int(state["gold"]) - cost
	get_custom(state)["owned"].append(key)
	return true


static func set_look(state: Dictionary, slot: String, choice: String) -> bool:
	if not CustomizationData.CAPTAIN_SLOTS.has(slot) or not (CustomizationData.CAPTAIN_SLOTS[slot] as Array).has(choice) or not owns(state, slot, choice):
		return false
	get_custom(state)["captain"][slot] = choice
	return true


## Flying another faction's colours. Pass "" to fly your own.
static func set_false_colors(state: Dictionary, faction: String) -> bool:
	if faction != "" and not state["rep"].has(faction):
		return false
	get_custom(state)["false_colors"] = faction
	return true


## Giving the game away: you are hoisted to your own colours and the faction you imitated loses 10 reputation.
## Returns the faction that was fooled, or "" when no false colours were flying.
static func reveal_false_colors(state: Dictionary) -> String:
	var f: String = str(get_custom(state)["false_colors"])
	if f == "":
		return ""
	state["rep"][f] = clampf(float(state["rep"][f]) - CustomizationData.FALSE_COLORS_REP_LOSS, -100.0, 100.0)
	get_custom(state)["false_colors"] = ""
	return f


## The stat bonuses from the figurehead and pet, e.g. bonus(state, "loot_mult") (1.0 when there is none).
static func bonus(state: Dictionary, stat: String, neutral: float = 1.0) -> float:
	var c: Dictionary = get_custom(state)
	var v: float = neutral
	var head: Dictionary = CustomizationData.FIGUREHEADS.get(str(c["figurehead"]), {})
	if head.has(stat):
		v = v + float(head[stat]) if neutral == 0.0 else v * float(head[stat])
	var pet: Dictionary = CustomizationData.PETS.get(str(c["pet"]), {})
	if pet.has(stat):
		v = v + float(pet[stat]) if neutral == 0.0 else v * float(pet[stat])
	return v
