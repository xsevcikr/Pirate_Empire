class_name CrewManager
extends RefCounted
## Hiring crew and applying morale events.

const HIRE_COST: Dictionary = {"green": 40, "seasoned": 120}
const WAGE_PER_DAY: int = 1

const MORALE_DELTA: Dictionary = {
	"victory": 4.0, "loot_share": 8.0, "rum_ration_day": 3.0, "port_day": 1.0,
	"lost_battle": -6.0, "officer_death": -10.0, "hungry_day": -3.0, "unpaid_day": -2.0,
	"atrocity": -8.0, "long_voyage_day": -1.0,
}

var gold: int = 0
var morale: float = 70.0


static func band(morale_value: float) -> String:
	if morale_value < 15.0:
		return "mutinous"
	if morale_value < 40.0:
		return "unhappy"
	if morale_value < 70.0:
		return "content"
	if morale_value < 90.0:
		return "spirited"
	return "fervent"


static func efficiency_mult(morale_value: float) -> float:
	match band(morale_value):
		"unhappy":
			return 0.8
		"spirited":
			return 1.08
		"fervent":
			return 1.15
	return 1.0


## Hire `count` crew of `tier`. Refused when funds are short, the tier needs a tavern level you lack, or the ship is full.
func hire(count: int, tier: String, tavern_level: int, current_crew: int, crew_max: int) -> bool:
	if count <= 0 or current_crew + count > crew_max:
		return false
	if tier == "seasoned" and tavern_level < 2:
		return false
	var cost: int = HIRE_COST[tier] * count
	if cost > gold:
		return false
	gold -= cost
	return true


func apply_event(event: String, times: int = 1) -> void:
	morale = clampf(morale + MORALE_DELTA[event] * times, 0.0, 100.0)


## Crew party at a tavern: +10 morale per 1,000 gold.
func tavern_party(spend: int) -> bool:
	if spend > gold or spend < 1000:
		return false
	gold -= spend
	morale = clampf(morale + 10.0 * (spend / 1000), 0.0, 100.0)
	return true


func pay_off_mutiny(crew: int) -> bool:
	var cost: int = 100 * crew
	if cost > gold:
		return false
	gold -= cost
	morale = clampf(morale + 30.0, 0.0, 100.0)
	return true
