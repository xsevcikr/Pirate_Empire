class_name CrewData
extends RefCounted
## The rival pirate crews (M23): four companies who sail the same waters as the player. Each owns ships, a hidden
## lagoon and a share of the sea, and does what pirates do: raids the trade lanes and the ports, claims islands to
## bury its loot on, races the player for treasure maps and hunts the player down. Every number lives here.

const ORDER: Array[String] = ["red_hand", "black_gulls", "bone_tide", "sea_wolves"]

## style: what the crew does most with its days (weights in STYLE_ACTIONS). home: the region its lagoon is in.
## grit: how hard its men are to beat on deck (0-1): better parries and blocks, quicker aim, no panic.
const CREWS: Dictionary = {
	"red_hand": {"name": "The Red Hand", "captain": "Bloody Bess Marlowe", "color": Color(0.82, 0.12, 0.10), "style": "raider",
		"home": "merchants_reach", "ships": ["sloop", "schooner", "brigantine"], "flagship": "frigate", "fleet": 6, "gold": 1500, "renown": 60, "grit": 0.45},
	"black_gulls": {"name": "The Black Gulls", "captain": "Gideon Crane", "color": Color(0.22, 0.22, 0.26), "style": "treasure",
		"home": "dead_reach", "ships": ["schooner", "brigantine"], "flagship": "galleon", "fleet": 5, "gold": 2500, "renown": 70, "grit": 0.55},
	"bone_tide": {"name": "The Bone Tide", "captain": "Old Mother Kell", "color": Color(0.88, 0.85, 0.70), "style": "plunderer",
		"home": "iron_marches", "ships": ["brigantine", "frigate"], "flagship": "galleon", "fleet": 5, "gold": 2000, "renown": 80, "grit": 0.65},
	"sea_wolves": {"name": "The Sea Wolves", "captain": "Rurik Halvard", "color": Color(0.16, 0.36, 0.78), "style": "hunter",
		"home": "coral_isles", "ships": ["sloop", "brigantine", "frigate"], "flagship": "frigate", "fleet": 7, "gold": 1200, "renown": 50, "grit": 0.75},
}

## How often a crew picks each daily action, by style.
const STYLE_ACTIONS: Dictionary = {
	"raider": {"raid_trade": 5, "raid_port": 1, "claim_island": 1, "expand": 2, "hunt": 1},
	"treasure": {"raid_trade": 1, "raid_port": 1, "claim_island": 4, "expand": 2, "hunt": 1},
	"plunderer": {"raid_trade": 1, "raid_port": 5, "claim_island": 1, "expand": 2, "hunt": 1},
	"hunter": {"raid_trade": 1, "raid_port": 1, "claim_island": 1, "expand": 2, "hunt": 5},
}

## Which regions touch which: crews spread into a neighbour of a region they already hold.
const NEIGHBOURS: Dictionary = {
	"albion_shallows": ["merchants_reach", "coral_isles"],
	"merchants_reach": ["albion_shallows", "haven_waters", "iron_marches"],
	"haven_waters": ["merchants_reach", "dead_reach", "coral_isles", "iron_marches"],
	"coral_isles": ["dead_reach", "haven_waters", "albion_shallows"],
	"iron_marches": ["merchants_reach", "haven_waters"],
	"dead_reach": ["coral_isles", "haven_waters"],
}

# ---- the crews' own economy (daily) ----
const START_INFLUENCE_HOME: float = 70.0
const START_INFLUENCE_NEAR: float = 20.0
const INFLUENCE_MAX: float = 100.0
const EXPAND_GAIN: float = 12.0
const INCOME_PER_SHIP: int = 40
const SHIP_COST: int = 900
const FLEET_MAX: int = 12
const RAID_TRADE_GOLD: Array[int] = [200, 500]
const RAID_PORT_GOLD: Array[int] = [300, 800]
const RAID_RENOWN: int = 5
const CLAIM_STASH: Array[int] = [500, 1500]
const CLAIMS_PER_CREW: int = 3
const CLASH_LOSS_CHANCE: float = 0.4  ## when two crews meet in a region, the weaker one may lose a ship
const NEWS_KEEP: int = 30

# ---- the crews and the player ----
const GRUDGE_MAX: float = 100.0
const GRUDGE_DECAY_PER_DAY: float = 2.0
const GRUDGE_PER_SHIP: float = 12.0  ## the player sank or took one of theirs
const GRUDGE_HUNT: float = 10.0  ## a hunt day
const LOSS_INFLUENCE: float = 8.0  ## a crew loses this much of a region when the player beats one of its ships there
const WIN_RENOWN: int = 10  ## the player's league score per crew ship beaten
const ELIMINATE_RENOWN: int = 100
const ELIMINATE_GOLD: int = 3000  ## on top of the crew's own chest
const PLUNDER_GOLD_FRACTION: float = 0.25  ## a crew that beats the player on deck takes this share of the purse
const PLUNDER_GOLD_CAP: int = 4000
const HOLDING_RAID_FRACTION: float = 0.15  ## a raid on the player's lagoon or base takes this share of what is stored
const HOLDING_RAID_HOURS: float = 12.0  ## warning before raiders reach the player's holding

# ---- the crews at sea (hourly, live world) ----
const WARBAND_CHANCE_PER_HOUR: float = 0.05  ## at full influence, before grudge and style
const HUNTER_FACTOR: float = 1.6
const WARBAND_MAX: int = 3
const SPAWN_DIST_M: float = 1000.0
const GUARD_RADIUS_M: float = 900.0  ## approach a claimed island or a lagoon this close and its guards are there
const LAGOON_GUARDS_MAX: int = 3
const LAGOON_CLEARANCE_M: float = 220.0
const BOARD_PLAYER_M: float = 45.0  ## a crew ship this close will try to board the player
const BOARD_MAX_REL_KN: float = 4.0  ## and only when the two ships are near the same speed
const BOARD_COOLDOWN_S: float = 90.0
const LOOT_GOLD: Array[float] = [0.15, 0.3]  ## share of the crew's chest a ship carries
const FRAGMENT_DROP: float = 0.25  ## chance a beaten crew ship has a treasure map fragment
const DECK_PARRY_ADD: float = 0.35  ## times grit
const DECK_BLOCK_ADD: float = 0.30
const DECK_AIM_MULT: float = 0.6  ## at full grit, crew shooters take this share of the usual time to aim
const DECK_MIX: Array[String] = ["officer", "marine", "brute", "marine", "sailor", "marine"]


static func def(id: String) -> Dictionary:
	return CREWS[id]


static func faction_of(id: String) -> String:
	return "crew_" + id


static func id_of_faction(faction: String) -> String:
	return faction.substr(5) if faction.begins_with("crew_") and CREWS.has(faction.substr(5)) else ""


static var _lagoons: Dictionary = {}


## Where a crew's hidden lagoon is: open water near the middle of its home region, clear of every island.
static func lagoon_pos(id: String) -> Vector2:
	if _lagoons.has(id):
		return _lagoons[id]
	var rect: Rect2 = WorldMap.REGIONS[def(id)["home"]]["rect"]
	var centre: Vector2 = rect.get_center()
	var islands: Array = PortData.gen().islands
	var found: Vector2 = centre
	for ring in 40:
		var r: float = 150.0 * float(ring)
		var steps: int = maxi(1, ring * 6)
		var ok: bool = false
		for k in steps:
			var p: Vector2 = centre + Vector2.from_angle(TAU * float(k) / float(steps)) * r
			if not rect.grow(-300.0).has_point(p):
				continue
			if _clear(p, islands):
				found = p
				ok = true
				break
		if ok:
			break
	_lagoons[id] = found
	return found


static func _clear(p: Vector2, islands: Array) -> bool:
	for isl: Dictionary in islands:
		if p.distance_to(isl["pos"]) < float(isl["radius"]) + LAGOON_CLEARANCE_M:
			return false
	return true
