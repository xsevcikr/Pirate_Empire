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
	"ghost_ledger": {
		"name": "tour.ghost_ledger", "region": "dead_reach", "island": "Wraith Isle",
		"reward": {"gold": 10000, "perks": ["ship_revenant"], "pearls": 0},
		"steps": [
			{"id": "read_map", "kind": "clue", "island": "Haven Rock", "night": true, "text": "tour.gl.read_map"},
			{"id": "ghost_storm", "kind": "sail", "island": "Bonefield Shoals", "night": true, "hazard": "ghost_storm", "text": "tour.gl.storm"},
			{"id": "wraith_isle", "kind": "sail", "island": "Wraith Isle", "text": "tour.gl.isle"},
			{"id": "crypt", "kind": "dungeon", "island": "Wraith Isle", "dungeon": "crypt", "text": "tour.gl.crypt"},
			{"id": "ghost_admiral", "kind": "guardian", "island": "Wraith Isle", "monster": "ghost_admiral", "text": "tour.gl.admiral"},
			{"id": "escape", "kind": "escape", "island": "Haven Rock", "text": "tour.gl.escape"},
		],
	},
	"iron_heart": {
		"name": "tour.iron_heart", "region": "iron_marches", "island": "Cinder Bay",
		"reward": {"gold": 12000, "perks": ["explosive_blueprint", "armor_t5"], "pearls": 0},
		"steps": [
			{"id": "read_map", "kind": "clue", "island": "Ironhold", "text": "tour.ih.read_map"},
			{"id": "blockade", "kind": "sail", "island": "Cinder Bay", "hazard": "blockade", "text": "tour.ih.blockade"},
			{"id": "volcano", "kind": "dungeon", "island": "Cinder Bay", "dungeon": "volcano_tunnels", "text": "tour.ih.volcano"},
			{"id": "colossus", "kind": "guardian", "island": "Cinder Bay", "monster": "brass_colossus", "text": "tour.ih.colossus"},
			{"id": "escape", "kind": "escape", "island": "Ironhold", "text": "tour.ih.escape"},
		],
	},
	"frostmourn_vault": {
		"name": "tour.frostmourn_vault", "region": "dead_reach", "island": "Frostmourn",
		"reward": {"gold": 15000, "perks": ["frost_sails", "white_flag"], "pearls": 0},
		"steps": [
			{"id": "read_map", "kind": "clue", "island": "Haven Rock", "text": "tour.fv.read_map"},
			{"id": "icebergs", "kind": "sail", "island": "Frostmourn", "hazard": "icebergs", "text": "tour.fv.bergs"},
			{"id": "glacier", "kind": "dungeon", "island": "Frostmourn", "dungeon": "glacier_caves", "text": "tour.fv.glacier"},
			{"id": "leviathan", "kind": "guardian", "island": "Frostmourn", "monster": "ice_leviathan", "text": "tour.fv.leviathan"},
			{"id": "escape", "kind": "escape", "island": "Haven Rock", "text": "tour.fv.escape"},
		],
	},
	"krakens_maw": {
		"name": "tour.krakens_maw", "region": "dead_reach", "island": "Kraken's Maw",
		"requires": ["drowned_purse", "song_of_sirens", "ghost_ledger", "iron_heart", "frostmourn_vault"],
		"reward": {"gold": 40000, "perks": ["kraken_ink", "heart_of_the_deep", "unlock_black_ibrahim"], "pearls": 0},
		"steps": [
			{"id": "read_map", "kind": "clue", "island": "Haven Rock", "text": "tour.km.read_map"},
			{"id": "whirlpool", "kind": "sail", "island": "Kraken's Maw", "hazard": "whirlpool", "text": "tour.km.whirl"},
			{"id": "kraken", "kind": "guardian", "island": "Kraken's Maw", "monster": "kraken", "text": "tour.km.kraken"},
			{"id": "drowned_city", "kind": "dungeon", "island": "Kraken's Maw", "dungeon": "drowned_city", "text": "tour.km.city"},
			{"id": "escape", "kind": "escape", "island": "Haven Rock", "text": "tour.km.escape"},
		],
	},
}
const ORDER: Array[String] = ["drowned_purse", "song_of_sirens", "ghost_ledger", "iron_heart", "frostmourn_vault", "krakens_maw"]

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
const MONSTERS_BIG: Dictionary = {
	"valcourt": {
		"player": "ship", "armor": 0.6, "exposed_mult": 2.0, "expose_s": 3.0,
		"dmg": {"line_ahead_broadsides": 250.0, "board_if_close": 100.0, "fire_ships": 200.0, "iron_bulwark": 0.0, "ram_and_board": 300.0, "captain_duel": 150.0},
		"parry": [], "dodge": ["line_ahead_broadsides", "board_if_close", "fire_ships", "ram_and_board", "captain_duel"],
	},
	"ghost_admiral": {
		"player": "ship", "armor": 0.7, "exposed_mult": 2.0, "expose_s": 3.0, "lanterns": 2,
		"dmg": {"teleport_behind": 200.0, "phase_out": 0.0, "summon_ghost_sloops": 150.0, "lightning_storm": 250.0, "skeletal_boarders": 120.0, "cursed_lantern": 200.0},
		"parry": [], "dodge": ["teleport_behind", "summon_ghost_sloops", "lightning_storm", "skeletal_boarders", "cursed_lantern"],
	},
	"kraken": {
		"player": "ship", "armor": 1.0, "exposed_mult": 2.5, "expose_s": 4.0, "tentacles": 8, "tentacle_hp": 150.0, "head_up_s": 12.0,
		"dmg": {"tentacle_slam": 200.0, "grab_and_crush": 350.0, "pull_into_whirlpool": 150.0, "ink_cloud": 0.0, "head_emerges": 300.0, "ram_it": 0.0},
		"parry": [], "dodge": ["tentacle_slam", "grab_and_crush", "pull_into_whirlpool", "head_emerges"],
	},
	"black_ibrahim": {
		"player": "ship", "armor": 0.6, "exposed_mult": 2.0, "expose_s": 3.0,
		"dmg": {"fleet_duel": 250.0, "frigate_formation": 150.0, "mortar_rain": 300.0, "bombard_bases": 200.0, "burning_deck_duel": 250.0, "attack_pattern_three": 300.0},
		"parry": [], "dodge": ["fleet_duel", "frigate_formation", "mortar_rain", "bombard_bases", "burning_deck_duel", "attack_pattern_three"],
	},
	"brass_colossus": {
		"player": "captain", "armor": 0.5, "exposed_mult": 2.5, "expose_s": 3.0, "cool_extends_s": 3.0,
		"dmg": {"steam_blast": 50.0, "ground_slam": 60.0, "flame_jets": 45.0},
		"parry": [], "dodge": ["steam_blast", "ground_slam", "flame_jets"],
	},
	"ice_leviathan": {
		"player": "ship", "armor": 0.7, "exposed_mult": 2.0, "expose_s": 4.0, "explosive_mult": 2.0,
		"dmg": {"break_ice": 200.0, "hurl_ice": 150.0, "freezing_breath": 100.0},
		"parry": [], "dodge": ["break_ice", "hurl_ice", "freezing_breath"],
	},
}
const PLAYER_HP: Dictionary = {"captain": 100.0, "ship": 1200.0}
const STRIKE_DMG: Dictionary = {"captain": 30.0, "ship": 160.0}

## Dungeons: room count and the order of what is in them.
const DUNGEONS: Dictionary = {
	"sea_cave": {"rooms": ["entry", "trap", "puzzle:sluice", "chest", "guard", "exit"], "air_s": 0.0},
	"crypt": {"rooms": ["entry", "trap", "puzzle:bells", "guard", "chest", "exit"], "air_s": 0.0},
	"volcano_tunnels": {"rooms": ["entry", "puzzle:vents", "puzzle:cart", "chest", "exit"], "air_s": 0.0},
	"glacier_caves": {"rooms": ["entry", "puzzle:ice", "trap", "chest", "exit"], "air_s": 0.0},
	"drowned_city": {"rooms": ["entry", "puzzle:mirrors", "puzzle:rhyme", "guard", "chest", "exit"], "air_s": 0.0},
	"sunken_temple": {"rooms": ["entry", "puzzle:mirrors", "chest", "puzzle:rhyme", "guard", "exit"], "air_s": 120.0},
}
const SEQUENCES: Dictionary = {"rhyme": [4, 6], "bells": [4, 4], "cart": [5, 2]}  ## kind -> [length, symbols]
const VENTS: int = 3
const VENT_PERIOD_S: float = 6.0
const VENT_OPEN_S: float = 3.0
const VENT_BURN_DMG: float = 20.0
const ICE_GRID: int = 5
const ICE_ROCKS: int = 5
const RANDOM_REWARD: Array[int] = [1000, 8000]
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


## Treasure maps made by the random generator, rebuilt from the save by restore().
static var EXTRA: Dictionary = {}


static func tour(tour_id: String) -> Dictionary:
	return TOURS[tour_id] if TOURS.has(tour_id) else EXTRA[tour_id]


static func is_generated(tour_id: String) -> bool:
	return EXTRA.has(tour_id)


static func dungeon(dungeon_id: String, rooms: Array = []) -> Dictionary:
	if not rooms.is_empty():
		return {"rooms": rooms, "air_s": 0.0}
	return DUNGEONS[dungeon_id]


static func tour_ids() -> Array[String]:
	return ORDER


static func all_ids() -> Array[String]:
	var out: Array[String] = ORDER.duplicate()
	for id: String in EXTRA.keys():
		out.append(id)
	return out


## Put the generated tours saved in a state back into the registry.
static func restore(state: Dictionary) -> void:
	EXTRA.clear()
	for id: String in state.get("tours", {}).get("generated", {}).keys():
		EXTRA[id] = state["tours"]["generated"][id]


static func steps(tour_id: String) -> Array:
	return tour(tour_id)["steps"]


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
