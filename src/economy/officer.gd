class_name Officer
extends RefCounted
## A named officer with a role, a 10-level skill track and loyalty.

const MAX_LEVEL: int = 10
const ROLES: Dictionary = {
	"gunner": {"reload_time": -0.03, "aim_error": -0.04},
	"navigator": {"ship_speed": 0.015},
	"surgeon": {"crew_survival": 0.02},
	"carpenter": {"repair_speed": 0.03},
	"quartermaster": {"loot_share": 0.02, "wages": -0.01},
	"boatswain": {"boarding_strength": 0.03, "sail_change_speed": 0.02},
}
const SLOTS: int = 6

var display_name: String = ""
var role: String = "gunner"
var level: int = 1
var loyalty: float = 50.0
var hire_cost: int = 1200


func _init(n: String = "", r: String = "gunner", lvl: int = 1, cost: int = 1200) -> void:
	display_name = n
	role = r
	level = clampi(lvl, 1, MAX_LEVEL)
	hire_cost = cost


## Passive bonus for a stat at the current level (per-level value x level).
func passive(stat: String) -> float:
	return ROLES[role].get(stat, 0.0) * level


func add_loyalty(delta: float) -> void:
	loyalty = clampf(loyalty + delta, 0.0, 100.0)


func has_left() -> bool:
	return loyalty <= 0.0


func unlocks_variant() -> bool:
	return loyalty >= 90.0


## Returns remaining gold, or -1 if the roster is full or funds are short.
static func hire(roster: Array, officer: Officer, gold: int) -> int:
	if roster.size() >= SLOTS or officer.hire_cost > gold:
		return -1
	roster.append(officer)
	return gold - officer.hire_cost
