class_name Siege
extends RefCounted
## Capturing a fort or city: silence the towers, break the boom, win the land assault, then choose its fate.

enum Phase { NAVAL, BOOM, LAND, CHOICE, DONE }
enum Fate { PLUNDER, RANSOM, OCCUPY }

const TOWER_HP: float = 1800.0
const BOOM_HP: float = 3000.0
const LAND_TIME_S: float = 6.0 * 60.0
const LAND_OBJECTIVES: Array[String] = ["gate", "barracks", "governors_house"]
const RANSOM_FRACTION: float = 0.5
const OCCUPY_UNREST_DAYS: int = 10
const OCCUPY_INCOME_PENALTY: float = 0.2
const PLUNDER_REP_PER_CITY: float = -2.0

var phase: Phase = Phase.NAVAL
var tower_hp: Array[float] = []
var boom_hp: float = BOOM_HP
var objectives: Dictionary = {}
var land_timer_s: float = 0.0
var plunder_value: float = 8000.0
var fate: Fate = Fate.PLUNDER
var captured: bool = false
var result: Dictionary = {}


func _init(towers: int = 4, plunder: float = 8000.0) -> void:
	for i in towers:
		tower_hp.append(TOWER_HP)
	plunder_value = clampf(plunder, 8000.0, 90000.0)
	for o in LAND_OBJECTIVES:
		objectives[o] = false


func towers_alive() -> int:
	var n: int = 0
	for h in tower_hp:
		if h > 0.0:
			n += 1
	return n


func hit_tower(index: int, damage: float) -> void:
	if phase != Phase.NAVAL:
		return
	tower_hp[index] = maxf(tower_hp[index] - damage, 0.0)
	if towers_alive() == 0:
		phase = Phase.BOOM


func hit_boom(damage: float) -> void:
	if phase != Phase.BOOM:
		return
	boom_hp = maxf(boom_hp - damage, 0.0)
	if boom_hp <= 0.0:
		phase = Phase.LAND


func take_objective(name: String) -> void:
	if phase != Phase.LAND or not objectives.has(name):
		return
	objectives[name] = true
	if not objectives.values().has(false):
		phase = Phase.CHOICE


func tick_land(delta: float) -> void:
	if phase != Phase.LAND:
		return
	land_timer_s += delta
	if land_timer_s >= LAND_TIME_S:
		phase = Phase.DONE  # assault failed
		result = {"captured": false}


func choose(f: Fate, ally_cities: int = 1) -> Dictionary:
	if phase != Phase.CHOICE:
		return {}
	fate = f
	phase = Phase.DONE
	match f:
		Fate.PLUNDER:
			result = {"gold": plunder_value, "reputation": PLUNDER_REP_PER_CITY * ally_cities, "tribute": 0.0, "base": false}
		Fate.RANSOM:
			result = {"gold": plunder_value * RANSOM_FRACTION, "reputation": 0.0, "tribute": plunder_value * 0.05, "base": false}
		Fate.OCCUPY:
			result = {"gold": 0.0, "reputation": 0.0, "tribute": 0.0, "base": true, "unrest_days": OCCUPY_UNREST_DAYS, "income_mult": 1.0 - OCCUPY_INCOME_PENALTY}
	captured = true
	result["captured"] = true
	return result
