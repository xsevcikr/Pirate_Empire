class_name TourData
extends RefCounted
## Every number and text key of the treasure tours: the two tours of milestone 18, their steps, hint prices, map
## fragment drop rates, monsters, traps and the digging table. Nothing here changes at run time.

const DROP_RATE: Dictionary = {"merchant": 0.04, "pirate": 0.08, "treasure_galleon": 0.15, "rival": 1.0}
const FRAGMENTS_PER_TOUR: int = 3
const HINT_COST: Array[int] = [0, 0, 50, 500]  ## index = hint level; level 1 is the navigator, 2 and 3 the tavern
const STUCK_FREE_S: float = 600.0  ## a step open this long gives its hints for free: nobody is ever locked out
const DEATH_GOLD_LOSS: float = 0.20
const PACE_TOLERANCE: int = 3
const DUSK_FROM_H: float = 17.0
const DUSK_TO_H: float = 20.0
const LOW_TIDE_M: float = 0.15  ## the reef maze at Skull Atoll can be sailed when the tide is below this
const ARRIVE_M: float = 450.0

## id -> tour. Steps run in order. kind: clue | sail | landing | sirens | dungeon | guardian | escape.
const TOURS: Dictionary = {
	"drowned_purse": {
		"name": "tour.drowned_purse", "region": "haven_waters", "island": "Skull Atoll",
		"reward": {"gold": 1500, "perks": ["captains_cutlass", "sloop_discount_50"], "pearls": 0},
		"steps": [
			{"id": "read_map", "kind": "clue", "island": "Haven Rock", "text": "tour.dp.read_map"},
			{"id": "reef_maze", "kind": "sail", "island": "Skull Atoll", "tide_below": 0.15, "text": "tour.dp.reef_maze"},
			{"id": "count_paces", "kind": "landing", "island": "Skull Atoll", "paces": 40, "dir": "west", "dusk": true, "text": "tour.dp.paces"},
			{"id": "sea_cave", "kind": "dungeon", "island": "Skull Atoll", "dungeon": "sea_cave", "text": "tour.dp.cave"},
			{"id": "shell_king", "kind": "guardian", "island": "Skull Atoll", "monster": "shell_king", "text": "tour.dp.king"},
			{"id": "escape", "kind": "escape", "island": "Haven Rock", "text": "tour.dp.escape"},
		],
	},
	"song_of_sirens": {
		"name": "tour.song_of_sirens", "region": "coral_isles", "island": "Moana Reef",
		"reward": {"gold": 6000, "perks": ["siren_figurehead", "harpoon_blueprint"], "pearls": 40},
		"steps": [
			{"id": "read_map", "kind": "clue", "island": "Pearlhome", "text": "tour.ss.read_map"},
			{"id": "weeping_rock", "kind": "sail", "island": "Pearlhome", "text": "tour.ss.rock"},
			{"id": "siren_waters", "kind": "sirens", "island": "Moana Reef", "radius": 1500.0, "text": "tour.ss.sirens"},
			{"id": "serpent", "kind": "guardian", "island": "Moana Reef", "monster": "sea_serpent", "text": "tour.ss.serpent"},
			{"id": "sunken_temple", "kind": "dungeon", "island": "Moana Reef", "dungeon": "sunken_temple", "text": "tour.ss.temple"},
			{"id": "escape", "kind": "escape", "island": "Pearlhome", "text": "tour.ss.escape"},
		],
	},
}
const ORDER: Array[String] = ["drowned_purse", "song_of_sirens"]

## Siren waters: the pull on the helm, the morale it drains and how the player stops it.
const SIREN: Dictionary = {
	"pull_n": 60000.0, "morale_per_s": -0.5, "choir_size": 8, "siren_hp": 150.0,
	"wax_cost": 20, "shanty_min_morale": 40.0,
}

## Monsters fought through MonsterFight. dmg is what an attack that is not dodged does to the player.
const MONSTERS: Dictionary = {
	"shell_king": {
		"player": "captain", "armor": 0.5, "exposed_mult": 2.0, "expose_s": 3.0, "claw_crack_cut": 0.4,
		"dmg": {"pincer_sweep": 40.0, "burrow_burst": 60.0, "shell_spin": 45.0},
		"parry": ["pincer_sweep"], "dodge": ["pincer_sweep", "burrow_burst", "shell_spin"],
	},
	"sea_serpent": {
		"player": "ship", "armor": 1.0, "exposed_mult": 3.0, "expose_s": 4.0, "chain_cut": 0.75,
		"dmg": {"coil": 120.0, "head_strike": 200.0, "tail_sweep": 90.0},
		"parry": [], "dodge": ["coil", "head_strike", "tail_sweep"],
	},
}
const PLAYER_HP: Dictionary = {"captain": 100.0, "ship": 1200.0}
const STRIKE_DMG: Dictionary = {"captain": 30.0, "ship": 160.0}

## Dungeons: room count and the order of what is in them.
const DUNGEONS: Dictionary = {
	"sea_cave": {"rooms": ["entry", "trap", "puzzle:sluice", "chest", "guard", "exit"], "air_s": 0.0},
	"sunken_temple": {"rooms": ["entry", "puzzle:mirrors", "chest", "puzzle:rhyme", "guard", "exit"], "air_s": 120.0},
}
const TORCH_S: float = 300.0
const SLUICE_GATES: int = 3
const SLUICE_TIME_S: float = 180.0
const MIRRORS: int = 3
const RHYME_LEN: int = 4
const SKELETON_HP: float = 60.0
const SKELETON_REASSEMBLE_S: float = 8.0
const SKELETON_MAX_REASSEMBLES: int = 3
const AIR_POCKET_REFILL: float = 1.0
const DRAWN_AIR_DAMAGE: float = 25.0  ## hull-less drowning: HP lost each time the air timer runs out before a pocket is found

const TRAPS: Dictionary = {
	"dart": {"dmg": 15.0, "detect": 0.6, "disarm": 0.8},
	"pit": {"dmg": 30.0, "detect": 0.5, "disarm": 0.5},
	"blade": {"dmg": 40.0, "detect": 0.7, "disarm": 0.4},
	"flood": {"dmg": 20.0, "detect": 0.4, "disarm": 0.6},
}
const TRAP_LIGHT_BONUS: float = 0.3  ## a lit torch adds this to the chance to spot a trap

const CHEST: Dictionary = {
	"small": {"gold": [20, 60], "weight": 0.6},
	"medium": {"gold": [100, 250], "weight": 0.3},
	"large": {"gold": [400, 800], "weight": 0.1},
}

const DIG_SWINGS: int = 5
const DIG_TABLE: Dictionary = {"chest": 0.70, "trap": 0.15, "skeleton": 0.10, "nothing": 0.05}
const DIG_PITY_EMPTY: int = 2  ## after two empty holes the next one on a tour spot always holds the chest
const DIG_SNAKE_DMG: float = 20.0


static func tour_ids() -> Array[String]:
	return ORDER


static func steps(tour_id: String) -> Array:
	return TOURS[tour_id]["steps"]


static func step_index(tour_id: String, step_id: String) -> int:
	var s: Array = steps(tour_id)
	for i in s.size():
		if s[i]["id"] == step_id:
			return i
	return -1


static func fragment_id(tour_id: String, n: int) -> String:
	return "%s_%d" % [tour_id, n]


## Where a step happens, in world metres (x east, y south).
static func step_pos(step: Dictionary) -> Vector2:
	var g: WorldGen = PortData.gen()
	var i: int = g.index_of(step["island"])
	return g.islands[i]["pos"] as Vector2 if i >= 0 else Vector2.ZERO
