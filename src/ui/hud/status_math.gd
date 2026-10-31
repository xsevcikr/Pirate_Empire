class_name StatusMath
extends RefCounted
## The numbers behind the status panel, kept apart from the drawing so they can be tested: for every row how full
## its bar is, the text beside it, and whether it is fine (OK), getting low (LOW, yellow) or about to run out
## (DANGER, red and pulsing).

enum { OK, LOW, DANGER }

const HP_PER_HEART: float = 50.0  ## a rum bottle heals one heart
const FULL_DAYS: float = 10.0  ## food or water for this many days fills the bar
const LOW_DAYS: float = 3.0
const DANGER_DAYS: float = 1.5
const FULL_BROADSIDES: float = 20.0
const LOW_BROADSIDES: float = 6.0
const DANGER_BROADSIDES: float = 3.0
const FULL_BOTTLES: float = 6.0
const LOW_BOTTLES: int = 2
const ROWS: Array[String] = ["hull", "crew", "ammo", "rum", "food", "water"]


## How many hearts the captain has, in halves: 4 hearts at full health (200 HP), one heart is 50 HP.
static func hearts(hp: float) -> Dictionary:
	var total: int = roundi(DeckData.FIGHTER_HP / HP_PER_HEART)
	var halves: int = clampi(ceili(hp / (HP_PER_HEART * 0.5) - 0.001), 0, total * 2)
	var frac: float = hp / DeckData.FIGHTER_HP
	return {"total": total, "halves": halves, "level": _by_share(frac)}


## Fine above half, low under half, danger at a quarter or less.
static func _by_share(frac: float) -> int:
	if frac <= 0.25:
		return DANGER
	if frac < 0.5:
		return LOW
	return OK


## Every row of the panel. `ship` holds what the ship knows: hull (0..1), crew, crew_min, crew_max, ammo (shots of
## the loaded kind) and guns (per side). Rows come back as {frac, text, level}.
static func rows(state: Dictionary, ship: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var hull: float = clampf(float(ship.get("hull", 1.0)), 0.0, 1.0)
	out["hull"] = {"frac": hull, "text": "%d%%" % roundi(hull * 100.0), "level": _by_share(hull)}
	var crew: int = int(ship.get("crew", 0))
	var cmax: int = maxi(int(ship.get("crew_max", 1)), 1)
	var clevel: int = DANGER if crew < int(ship.get("crew_min", 0)) else (LOW if crew < cmax / 2 else OK)
	out["crew"] = {"frac": clampf(float(crew) / float(cmax), 0.0, 1.0), "text": "%d/%d" % [crew, cmax], "level": clevel}
	var shots: int = int(ship.get("ammo", 0))
	var broadsides: float = float(shots) / float(maxi(int(ship.get("guns", 1)), 1))
	var alevel: int = DANGER if broadsides < DANGER_BROADSIDES else (LOW if broadsides < LOW_BROADSIDES else OK)
	out["ammo"] = {"frac": clampf(broadsides / FULL_BROADSIDES, 0.0, 1.0), "text": str(shots), "level": alevel}
	var bottles: int = floori(CaptainHealth.rum_supply(state) / DeckData.RUM_SUPPLY_PER_DRINK + 0.0001)
	var rlevel: int = DANGER if bottles <= 0 else (LOW if bottles <= LOW_BOTTLES else OK)
	out["rum"] = {"frac": clampf(float(bottles) / FULL_BOTTLES, 0.0, 1.0), "text": str(bottles), "level": rlevel}
	for supply in ["food", "water"]:
		var days: float = CrewLife.days_left(state, supply) if state.has("supplies") and state.has("roster") else 0.0
		var dlevel: int = DANGER if days < DANGER_DAYS else (LOW if days < LOW_DAYS else OK)
		out[supply] = {"frac": clampf(days / FULL_DAYS, 0.0, 1.0), "text": Loc.t("status.days") % floori(days), "level": dlevel}
	return out


## Bar colours: green, yellow, red.
static func colour(level: int) -> Color:
	match level:
		DANGER:
			return Color(0.92, 0.22, 0.16)
		LOW:
			return Color(0.98, 0.78, 0.18)
	return Color(0.38, 0.76, 0.3)
