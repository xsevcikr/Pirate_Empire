class_name RivalData
extends RefCounted
## The six named rivals (spec section 19). Each has a ship, a way of fighting, a three-encounter story arc and a
## reward for beating them. Valcourt and Black Ibrahim are the campaign's bosses: they take part in the rivalry
## record, but their fights are the boss fights.

const ORDER: Array[String] = ["molly", "isabeau", "saltjaw", "vale", "valcourt", "ibrahim"]
const CAMPAIGN: Array[String] = ["valcourt", "ibrahim"]

const MEET_GAIN: float = 12.0  ## rivalry meter per meeting
const LOSS_GAIN: float = 8.0   ## extra when they win
const WIN_GAIN: float = 4.0
const METER_MAX: float = 100.0
const CHALLENGE_PER_HOUR_MAX: float = 0.06  ## at a full meter
const NEMESIS_FACTOR: float = 2.5
const LEVEL_MAX: int = 10
const LEVEL_STAT_GAIN: float = 0.12  ## hull and gun strength per level above 1
const ARC_LENGTH: int = 3
const DOUBLE_REWARD: float = 2.0
const TROPHIES: Array[String] = ["flag", "figurehead"]
const BOUNTY_FOR_VALE: float = 40.0

## home: regions where the rival is found unless they are your nemesis. start: what the arc needs before the first meeting.
const RIVALS: Dictionary = {
	"molly": {"name": "Mad Molly Thorne", "ship": "sloop", "ship_late": "brigantine", "style": "rammer", "home": ["haven_waters", "albion_shallows"], "gold": 1500,
		"start": {"fragments": 1}, "reward": {"officer": "molly", "ship": "brigantine"}, "spare": true, "hp": 1.0, "guns": 1.0},
	"isabeau": {"name": "Isabeau \"La Sirène\" Marchetti", "ship": "schooner", "ship_late": "xebec", "style": "smuggler", "home": ["coral_isles", "merchants_reach"], "gold": 3000,
		"start": {"tours_done": 1}, "reward": {"hold": "smugglers_hold", "coves": true}, "spare": false, "hp": 0.9, "guns": 1.0, "night_ambush": true},
	"saltjaw": {"name": "Saltjaw Briggs", "ship": "galleon", "ship_late": "treasure_galleon", "style": "broadside", "home": ["merchants_reach", "iron_marches"], "gold": 25000,
		"start": {"prizes": 4}, "reward": {"ship": "galleon"}, "spare": false, "hp": 1.6, "guns": 1.3},
	"vale": {"name": "Commodore Edmund Vale", "ship": "frigate", "style": "line_ahead", "squadron": 3, "home": ["albion_shallows", "merchants_reach"], "gold": 4000,
		"start": {"bounty": 40.0}, "reward": {"ship": "frigate", "officer": "navy_officer"}, "spare": true, "hp": 1.2, "guns": 1.1, "chain_shot": true},
	"valcourt": {"name": "Admiral Valcourt", "ship": "sovereign", "style": "boss", "home": ["albion_shallows"], "gold": 8000, "start": {}, "reward": {"perk": "valcourt"}, "spare": false, "hp": 2.0, "guns": 1.5},
	"ibrahim": {"name": "Black Ibrahim", "ship": "man_o_war", "style": "boss", "home": ["iron_marches"], "gold": 15000, "start": {}, "reward": {"perk": "black_ibrahim"}, "spare": false, "hp": 2.4, "guns": 1.6},
}

## What each rival does at the three arc encounters.
const ARC: Dictionary = {
	"molly": ["steals_fragment", "rams_you", "last_stand"],
	"isabeau": ["tour_race", "offers_partnership", "fog_ambush"],
	"saltjaw": ["shares_convoy", "convoy_fight", "treasure_cove"],
	"vale": ["warning", "hunt", "decision"],
	"valcourt": ["act3_boss"],
	"ibrahim": ["act5_boss"],
}


static func def(id: String) -> Dictionary:
	return RIVALS[id]


## Hull and gun strength at a level: grows by LEVEL_STAT_GAIN per level above the first.
static func strength(id: String, level: int) -> float:
	return 1.0 + LEVEL_STAT_GAIN * float(clampi(level, 1, LEVEL_MAX) - 1)
