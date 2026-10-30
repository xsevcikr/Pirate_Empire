class_name WeaponData
extends RefCounted
## Captain's weapons: price and combat numbers (spec section 13). Deck combat itself arrives in M14.

## kind: melee | offhand | pistol | long | grenade. damage: [light, heavy] for melee, single value for guns.
const WEAPONS: Dictionary = {
	"rusty_cutlass": {"kind": "melee", "price": 0, "damage": [18, 32], "speed": [0.5, 1.1]},
	"cutlass": {"kind": "melee", "price": 250, "damage": [25, 45], "speed": [0.5, 1.1]},
	"rapier": {"kind": "melee", "price": 600, "damage": [18, 34], "speed": [0.35, 0.9], "parry_window": 0.3},
	"boarding_axe": {"kind": "melee", "price": 450, "damage": [35, 65], "speed": [0.8, 1.5], "breaks_block_heavy": true, "chops_ropes": true},
	"dagger": {"kind": "offhand", "price": 120, "damage": [12, 12], "speed": [0.3, 0.3], "backstab": 3.0},
	"flintlock": {"kind": "pistol", "price": 300, "damage": 60, "reload": 5.0, "range": 15.0},
	"musket": {"kind": "long", "price": 700, "damage": 90, "reload": 8.0, "range": 60.0, "bayonet": 30},
	"blunderbuss": {"kind": "long", "price": 900, "damage": 90, "pellets": 6, "reload": 7.0, "range": 8.0, "cone_deg": 20.0},
	"grenado": {"kind": "grenade", "price": 60, "damage": 80, "fuse": 3.0, "radius": 3.0},
	"club": {"kind": "melee", "price": 0, "damage": [10, 16], "speed": [0.6, 1.2]},
	"bayonet": {"kind": "melee", "price": 0, "damage": [30, 30], "speed": [0.7, 0.7]},
	"captains_cutlass": {"kind": "melee", "price": 0, "damage": [32, 58], "speed": [0.45, 1.0], "crew_strength_bonus": 0.10},
}
const PISTOL_START_SHOTS: int = 10
const SWIVEL_START_SHOTS: int = 40
const SHOTS_PER_SMALL_ARMS_UNIT: int = 20


static func sold_in_shops() -> Array:
	var out: Array = []
	for id in WEAPONS.keys():
		if WEAPONS[id]["price"] > 0:
			out.append(id)
	return out
