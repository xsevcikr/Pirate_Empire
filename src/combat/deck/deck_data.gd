class_name DeckData
extends RefCounted
## Numbers for real-time deck combat (spec section 13). Everything tunable is here, nothing in the logic.

# ---- the captain and everyone's stamina ----
const PLAYER_HP_BASE: float = 100.0
const PLAYER_HP_PER_LEVEL: float = 10.0
const STAMINA_MAX: float = 100.0
const STAMINA_REGEN_PER_S: float = 25.0  ## not while blocking
const ATTACK_STAMINA_LIGHT: float = 5.0
const ATTACK_STAMINA_HEAVY: float = 12.0

# ---- melee ----
const MELEE_RANGE_M: float = 2.0
const MELEE_ARC_DEG: float = 120.0  ## total width in front of the attacker
const STRIKE_POINT: float = 0.6  ## the blow lands this far into the swing
const COMBO_WINDOW_S: float = 0.5  ## a new swing inside this window continues the combo
const COMBO_MULT: Array[float] = [1.0, 1.1, 1.4]  ## three-hit combo
const HEAVY_CHARGE_S: float = 0.4
const BACKSTAB_ARC_DEG: float = 70.0  ## attacker this close to straight behind the target
const BACKSTAB_MULT: float = 3.0  ## dagger
const BRUTE_FRONT_REDUCTION: float = 0.5  ## armoured front: flank him

# ---- block, parry, dodge, kick ----
const BLOCK_REDUCTION: float = 0.8
const BLOCK_STAMINA_PER_DAMAGE: float = 0.5
const BLOCK_ARC_DEG: float = 140.0
const PARRY_WINDOW_S: float = 0.2  ## a block raised this shortly before the hit is a parry
const PARRY_STAGGER_S: float = 1.0
const PARRY_NEXT_HIT_MULT: float = 2.0
const GUARD_BREAK_STAGGER_S: float = 0.8
const DODGE_INVULN_S: float = 0.25
const DODGE_STAMINA: float = 25.0
const DODGE_DISTANCE_M: float = 3.0
const DODGE_TIME_S: float = 0.35
const KICK_STAMINA: float = 15.0
const KICK_DAMAGE: float = 8.0
const KICK_RANGE_M: float = 1.7
const KICK_TIME_S: float = 0.4
const KICK_STAGGER_S: float = 0.8
const KICK_PUSH_M: float = 1.5
const HIT_INTERRUPT_DAMAGE: float = 12.0

# ---- ranged and cover ----
const COVER_RANGED_REDUCTION: float = 0.7
const PISTOL_BRACE: int = 4
const RANGED_AIM_CONE_DEG: float = 12.0
const KEG_DAMAGE: float = 80.0
const KEG_RADIUS_M: float = 4.0
const NET_DAMAGE: float = 40.0
const NET_RADIUS_M: float = 3.0
const NET_STUN_S: float = 2.0
const SWING_DAMAGE: float = 45.0
const SWING_RANGE_M: float = 8.0
const SWING_STAGGER_S: float = 1.0
const GRENADE_DAMAGE: float = 80.0
const GRENADE_RADIUS_M: float = 3.0
const GRENADE_FUSE_S: float = 3.0

# ---- the deck ----
const DECK_HALF_WIDTH_M: float = 7.0  ## x runs from our rail (-) to theirs (+)
const DECK_HALF_LENGTH_M: float = 11.0
const RAIL_OFFSET_M: float = 0.7
const MAX_ON_SCREEN: int = 12
const REINFORCE_DELAY_S: float = 1.5
const MOVE_SPEED_MS: float = 4.2
const BLOCK_MOVE_FACTOR: float = 0.5
const SWING_MOVE_FACTOR: float = 0.3
const BODY_RADIUS_M: float = 0.45

# ---- the fight as a whole ----
const CREW_HP: float = 60.0
const MORALE_PER_DEATH: float = 40.0  ## total morale lost when the whole side falls (as in BoardingSim)
const PANIC_MORALE: float = 30.0  ## sailors run below this
const CAPTAIN_CARRIED_OFF_RANSOM_FRACTION: float = 0.5
const AI_THINK_S: float = 0.15
const AI_AIM_S: Array[float] = [2.5, 6.0]  ## seconds an AI shooter takes to line up a shot
const AI_ATTACK_PAUSE_S: Array[float] = [0.9, 1.8]  ## rest after an AI swing

## Enemy archetypes: hit points, melee weapon, ranged weapon ("" for none), traits.
const ENEMIES: Dictionary = {
	"sailor": {"hp": 40.0, "melee": "club", "ranged": "", "panics": true, "parry": 0.05, "block": 0.15, "speed": 3.8},
	"marine": {"hp": 70.0, "melee": "bayonet", "ranged": "musket", "panics": false, "parry": 0.15, "block": 0.30, "speed": 4.0},
	"officer": {"hp": 110.0, "melee": "rapier", "ranged": "", "panics": false, "parry": 0.45, "block": 0.55, "speed": 4.2, "rallies": true},
	"brute": {"hp": 160.0, "melee": "boarding_axe", "ranged": "", "panics": false, "parry": 0.0, "block": 0.10, "speed": 3.4, "front_armor": true, "heavy_bias": 0.5},
	"captain": {"hp": 250.0, "melee": "cutlass", "ranged": "flintlock", "panics": false, "parry": 0.5, "block": 0.6, "speed": 4.2},
}
## Crew fighters by crew type: melee weapon, damage multiplier, ranged weapon.
const CREW: Dictionary = {
	"green": {"melee": "cutlass", "strength": 1.0, "ranged": "", "parry": 0.10, "block": 0.25},
	"seasoned": {"melee": "cutlass", "strength": 1.3, "ranged": "", "parry": 0.20, "block": 0.35},
	"swordsman": {"melee": "cutlass", "strength": 1.6, "ranged": "", "parry": 0.40, "block": 0.45},
	"musketeer": {"melee": "bayonet", "strength": 1.0, "ranged": "musket", "parry": 0.10, "block": 0.20},
	"gunner": {"melee": "cutlass", "strength": 1.0, "ranged": "flintlock", "parry": 0.10, "block": 0.25},
	"carpenter": {"melee": "club", "strength": 1.0, "ranged": "", "parry": 0.05, "block": 0.20},
	"surgeon": {"melee": "dagger", "strength": 1.0, "ranged": "", "parry": 0.05, "block": 0.20},
	"cook": {"melee": "club", "strength": 1.0, "ranged": "", "parry": 0.05, "block": 0.20},
	"navigator": {"melee": "rapier", "strength": 1.0, "ranged": "flintlock", "parry": 0.15, "block": 0.25},
	"bosun": {"melee": "boarding_axe", "strength": 1.0, "ranged": "", "parry": 0.10, "block": 0.25},
	"quartermaster": {"melee": "cutlass", "strength": 1.0, "ranged": "flintlock", "parry": 0.20, "block": 0.30},
}
## Squad commands for the player's crew.
enum Command { CHARGE, HOLD, PROTECT, FOCUS_CAPTAIN, FALL_BACK }
const HOLD_LINE_X: float = -2.0
const PROTECT_RADIUS_M: float = 3.5


static func player_hp(level: int) -> float:
	return PLAYER_HP_BASE + PLAYER_HP_PER_LEVEL * float(maxi(level - 1, 0))


static func swing_time(weapon_id: String, heavy: bool) -> float:
	return float(WeaponData.WEAPONS[weapon_id]["speed"][1 if heavy else 0])


static func swing_damage(weapon_id: String, heavy: bool) -> float:
	return float(WeaponData.WEAPONS[weapon_id]["damage"][1 if heavy else 0])


static func parry_window(weapon_id: String) -> float:
	return float(WeaponData.WEAPONS[weapon_id].get("parry_window", PARRY_WINDOW_S))
