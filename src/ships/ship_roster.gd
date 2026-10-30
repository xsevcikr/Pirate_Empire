class_name ShipRoster
extends RefCounted
## Which classes the AI sails: merchants and navy patrols mix in the new variants, and the giants start to appear
## once the player is famous enough to be worth a fleet's flagship.

## class -> [weight, fame the player needs before it shows up]
const MERCHANT: Dictionary = {"schooner": [4, 0], "brigantine": [4, 0], "east_indiaman": [2, 1500], "treasure_galleon": [1, 6000]}
const NAVY: Dictionary = {"frigate": [5, 0], "corvette": [4, 0], "dreadnought": [1, 8000]}
## A convoy this big sails behind an East Indiaman flagship.
const CONVOY_FLAGSHIP: String = "east_indiaman"
const CONVOY_FLAGSHIP_MIN_SHIPS: int = 4


static func pick(table: Dictionary, rng: RandomNumberGenerator, fame: int) -> String:
	var total: int = 0
	for id: String in table:
		if fame >= int(table[id][1]):
			total += int(table[id][0])
	var r: int = rng.randi() % maxi(total, 1)
	for id: String in table:
		if fame < int(table[id][1]):
			continue
		r -= int(table[id][0])
		if r < 0:
			return id
	return table.keys()[0]


static func merchant(rng: RandomNumberGenerator, fame: int) -> String:
	return pick(MERCHANT, rng, fame)


static func navy(rng: RandomNumberGenerator, fame: int) -> String:
	return pick(NAVY, rng, fame)


## The class of ship `slot` of a trade convoy of `ships` merchantmen.
static func convoy(slot: int, ships: int) -> String:
	if slot == 0 and ships >= CONVOY_FLAGSHIP_MIN_SHIPS:
		return CONVOY_FLAGSHIP
	return TradeData.CONVOY_STATS[slot % TradeData.CONVOY_STATS.size()]


## Crew a spawned AI ship carries: the usual 14 hands, or a giant's minimum crew so its guns are worked.
static func ai_crew(stats: ShipStats) -> int:
	return maxi(14, stats.crew_min) if stats.giant else 14
