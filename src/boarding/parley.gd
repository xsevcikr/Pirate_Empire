class_name Parley
extends RefCounted
## "Strike your colours!": the captain hails a ship alongside and demands her surrender before anyone crosses the
## rail. Whether she strikes depends on who she is, how badly she is hurt, how the two crews compare and how feared
## the captain is. A ship that refuses stiffens her crew's resolve and will not listen a second time.

const RANGE_M: float = 120.0  ## a hail carries this far
## Base chance by the defender's faction: merchants want to live, the navy is duty bound.
const BASE: Dictionary = {"merchant": 0.30, "pirate": 0.05, "navy": -0.20, "default": 0.10}
const POWER_WEIGHT: float = 0.25  ## per whole step of our fighting power over theirs
const POWER_CAP: Array[float] = [-0.30, 0.40]
const HULL_WEIGHT: float = 0.40  ## a wreck strikes more readily
const FAME_FULL: float = 2000.0  ## fame at which the captain's name is worth the whole FAME_WEIGHT
const FAME_WEIGHT: float = 0.15
const LOYAL_WEIGHT: float = 0.10  ## the whole crew devoted and roaring at the rail
const CHANCE_CAP: Array[float] = [0.02, 0.95]
const REFUSED_MORALE: float = 10.0  ## the defenders' morale after they tell you to go hang
const CAPTAIN_VALUE: float = 4.0  ## the captain counts as this many men, as in BoardingController


## Fighting power of a crew for the parley sum: men × quality × morale efficiency.
static func power(men: int, quality: float, morale: float) -> float:
	return float(men) * maxf(quality, 0.1) * Morale.efficiency(morale)


## Chance that the defender strikes. `ctx`: {faction, ours, theirs (powers), hull (0..1 of the defender),
## fame, devoted_share (0..1 of our roster)}.
static func chance(ctx: Dictionary) -> float:
	var c: float = float(BASE.get(str(ctx.get("faction", "default")), BASE["default"]))
	var ratio: float = float(ctx.get("ours", 1.0)) / maxf(float(ctx.get("theirs", 1.0)), 0.1)
	c += clampf((ratio - 1.0) * POWER_WEIGHT, POWER_CAP[0], POWER_CAP[1])
	c += (1.0 - clampf(float(ctx.get("hull", 1.0)), 0.0, 1.0)) * HULL_WEIGHT
	c += minf(float(ctx.get("fame", 0.0)) / FAME_FULL, 1.0) * FAME_WEIGHT
	c += clampf(float(ctx.get("devoted_share", 0.0)), 0.0, 1.0) * LOYAL_WEIGHT
	return clampf(c, CHANCE_CAP[0], CHANCE_CAP[1])


## Ships that never strike to a hail: a named rival captain, a rival crew's flagship, one that already refused,
## one already struck.
static func can_hail(ship: Ship) -> bool:
	if ship == null or not is_instance_valid(ship) or ship.damage.sunk or ship.has_surrendered:
		return false
	if bool(ship.get_meta("parley_refused", false)) or ship.has_meta("rival"):
		return false
	return str(ship.get_meta("crew_role", "")) != "flagship"


## The parley context for the player's `ours` ship hailing `theirs`.
static func context(ours: Ship, theirs: Ship, state: Dictionary) -> Dictionary:
	var roster: Array = state.get("roster", [])
	var devoted: float = 0.0
	if not roster.is_empty():
		devoted = float(CrewPersona.count_at_least(state, CrewPersona.BANDS["devoted"])) / float(roster.size())
	var mine: float = power(ours.crew.count, ours.crew.quality, ours.crew.morale) + CAPTAIN_VALUE
	var defenders: int = int(round(theirs.crew.count * (1.0 + theirs.stats.boarding_defense)))
	return {
		"faction": str(theirs.get_meta("rep_faction", theirs.faction)), "ours": mine, "theirs": power(defenders, theirs.crew.quality, theirs.crew.morale),
		"hull": theirs.damage.hull_fraction(), "fame": float(state.get("fame", 0)), "devoted_share": devoted,
	}


## Hail the ship. Struck: she surrenders on the spot. Refused: her crew's morale rises and she will not hear
## another hail. Returns {struck, chance}.
static func hail(ours: Ship, theirs: Ship, state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if not can_hail(theirs):
		return {"struck": false, "chance": 0.0}
	var c: float = chance(context(ours, theirs, state))
	if rng.randf() < c:
		theirs.surrender()
		CrewPersona.on_event(state, "parley")
		return {"struck": true, "chance": c}
	theirs.set_meta("parley_refused", true)
	theirs.crew.morale = minf(theirs.crew.morale + REFUSED_MORALE, 100.0)
	return {"struck": false, "chance": c}
