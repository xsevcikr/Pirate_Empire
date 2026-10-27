class_name CrewState
extends RefCounted
## Crew count, role split and efficiency for guns, sails and repair.

enum Focus { BALANCED, GUNS, SAILS, REPAIR }

const SPLITS: Dictionary = {
	Focus.BALANCED: [0.5, 0.25, 0.25],
	Focus.GUNS: [0.7, 0.15, 0.15],
	Focus.SAILS: [0.3, 0.55, 0.15],
	Focus.REPAIR: [0.25, 0.15, 0.6],
}

var count: int = 20
var crew_min: int = 8
var crew_max: int = 30
var focus: Focus = Focus.BALANCED
var quality: float = 1.0
var morale: float = 70.0
var brief_morale: bool = false  ## player ship: morale bands from the spec (Morale) instead of the older table
var captain_hands: int = 0  ## the captain works a gun or a sheet when the crew is thin (player ship only)


func _init(stats: ShipStats = null) -> void:
	if stats:
		crew_min = stats.crew_min
		crew_max = stats.crew_max
		count = int((stats.crew_min + stats.crew_max) * 0.5)


func guns_crew() -> float:
	return (count + captain_hands) * SPLITS[focus][0]


func sails_crew() -> float:
	return (count + captain_hands) * SPLITS[focus][1]


func repair_crew() -> float:
	return (count + captain_hands) * SPLITS[focus][2]


## Guns efficiency: crew at guns relative to half the class minimum, clamped.
func guns_efficiency() -> float:
	return clampf(guns_crew() / (crew_min * 0.5), 0.3, 1.0) * quality * morale_factor()


func sails_efficiency() -> float:
	return clampf(sails_crew() / (crew_min * 0.25), 0.3, 1.0) * quality * morale_factor()


func morale_factor() -> float:
	if brief_morale:
		return Morale.efficiency(morale)
	if morale < 15.0:
		return 0.7
	if morale < 40.0:
		return 0.8
	if morale < 70.0:
		return 1.0
	if morale < 90.0:
		return 1.08
	return 1.15


## Reload and action times grow by crew_min / count when under-crewed (up to 3x).
func understaffed_multiplier() -> float:
	if count >= crew_min:
		return 1.0
	return minf(float(crew_min) / maxf(float(count), 1.0), 3.0)


func kill(n: int) -> int:
	var killed: int = mini(n, count)
	count -= killed
	return killed
