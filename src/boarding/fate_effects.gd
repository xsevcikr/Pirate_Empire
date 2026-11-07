class_name FateEffects
extends RefCounted
## Puts the outcome of CaptureFate.resolve into the running state: gold, notoriety, morale, press-ganged hands
## and prize ships. Kept apart from the screen so it can be tested on a plain dictionary.

const PRIZE_CREW: int = 6  ## hands needed to sail a prize home
const MIN_CREW_LEFT: int = 8  ## the flagship keeps at least this many
const EQUIPMENT_FRACTION: float = 0.25  ## of the hull's price, stripped as guns and fittings


static func prize_crew_available(state: Dictionary) -> int:
	return maxi(int(state["crew"]) - MIN_CREW_LEFT, 0) / PRIZE_CREW


## Inputs for CaptureFate.resolve.
static func fate_info(state: Dictionary, ship_price: float, survivors: int, kindly: bool) -> Dictionary:
	return {"ship_value": ship_price, "cargo_value": 0.0, "equipment_value": ship_price * EQUIPMENT_FRACTION,
		"survivors": survivors, "prize_crew_available": prize_crew_available(state), "kindly_crew": kindly}


## Returns {recruits, ship_added, gold} actually applied.
static func apply(state: Dictionary, effects: Dictionary, ship_class: String, ship_name: String) -> Dictionary:
	var applied: Dictionary = {"recruits": 0, "ship_added": false, "gold": int(effects["gold"]), "rescue_fleet": bool(effects["rescue_fleet"])}
	state["gold"] = int(state["gold"]) + int(effects["gold"])
	state["fame"] = int(state["fame"]) + int(effects["notoriety"])
	CrewLife.add_morale(state, float(effects["morale"]) + float(effects["loyalty"]))
	var room: int = PortService.crew_room(state)
	var n: int = mini(int(effects["recruits"]), maxi(room, 0))
	for i in n:
		state["roster"].append({"name": PortService.NAMES[(int(state["seed"]) + state["roster"].size() * 7 + i) % PortService.NAMES.size()], "type": "green", "level": 1, "xp": 0})
		CrewPersona.ensure_last(state)
		state["crew"] = int(state["crew"]) + 1
	applied["recruits"] = n
	if bool(effects["ship_added"]):
		CrewLife.remove_crew(state, PRIZE_CREW)
		state["fleet"].append({"class": ship_class, "name": ship_name, "crew": PRIZE_CREW, "hull": 0.5})
		applied["ship_added"] = true
	return applied
