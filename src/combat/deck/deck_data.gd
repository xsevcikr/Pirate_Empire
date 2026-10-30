class_name DeckData
extends RefCounted
## Numbers for real-time deck combat (spec section 13). Everything tunable is here, nothing in the logic.

# ---- hit points and the three kinds of blow (Rob's combat rework) ----
const FIGHTER_HP: float = 200.0  ## every man on deck, the captain included
const GUN_DAMAGE: float = 50.0  ## a pistol or musket ball, a deck gun's grapeshot per man
const SWORD_DAMAGE: float = 30.0  ## any blade or club, light swing
const FIST_DAMAGE: float = 20.0  ## a punch, when there is no blade or the captain puts it away
const HEAVY_MULT: float = 1.5  ## a heavy swing or a haymaker
const FIGHT_TIME_LIMIT_S: float = 300.0  ## 200 HP fights last longer than the old 120 s crew-pool limit

# ---- aiming a gun ----
const AIM_SPREAD_HIP_DEG: float = 7.0  ## one standard deviation of a shot fired from the hip
const AIM_SPREAD_STEADY_DEG: float = 0.8  ## after holding the aim this long
const AIM_STEADY_S: float = 0.6
const AIM_MOVE_FACTOR: float = 0.35
const AI_AIM_LOCK_S: float = 0.9  ## an AI shooter stands and aims this long before the shot: time to dodge
const BULLET_RADIUS_M: float = 0.45  ## a ball hits a man whose body is this close to its line

# ---- rum and recovery ----
const RUM_HEAL: float = 50.0
const RUM_DRINK_S: float = 0.8  ## the captain cannot fight while he drinks
const RUM_COOLDOWN_S: float = 8.0
const RUM_PER_FIGHT: int = 3  ## bottles the captain carries into one fight
const RUM_SUPPLY_PER_DRINK: float = 0.02  ## of a supply unit of rum
const REGEN_HP_PER_S: float = 0.5  ## out of a fight, real seconds: 200 HP back in under seven minutes
const KNOCKED_OUT_HP: float = 25.0  ## the captain wakes with this much after going down

# ---- the captain and everyone's stamina ----
const PLAYER_HP_BASE: float = FIGHTER_HP
const PLAYER_HP_PER_LEVEL: float = 0.0
const STAMINA_MAX: float = 100.0
const STAMINA_REGEN_PER_S: float = 25.0  ## not while blocking
const ATTACK_STAMINA_LIGHT: float = 12.0  ## swinging non-stop slowly winds a man
const ATTACK_STAMINA_HEAVY: float = 22.0

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
const HIT_INTERRUPT_DAMAGE: float = 35.0  ## a plain 30 blow does not stop a man mid-swing; a heavy or a combo does
const BLOCK_RECOIL_S: float = 0.3  ## a blow that lands on a raised guard throws the attacker off for a moment

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
const CREW_HP: float = FIGHTER_HP
const MORALE_PER_DEATH: float = 40.0  ## total morale lost when the whole side falls (as in BoardingSim)
const PANIC_MORALE: float = 30.0  ## sailors run below this
const CAPTAIN_CARRIED_OFF_RANSOM_FRACTION: float = 0.5
const AI_THINK_S: float = 0.15
const AI_AIM_S: Array[float] = [2.5, 6.0]  ## seconds between an AI shooter's shots
const AI_ATTACK_PAUSE_S: Array[float] = [0.7, 1.5]  ## rest after an AI swing
const AI_DODGE_CHANCE: float = 0.35  ## an AI man who sees a heavy blow or a levelled gun coming throws himself aside
const AI_KICK_BLOCKER_S: float = 0.7  ## an AI man kicks a guard held up this long
const AI_REACT_S: float = 0.3  ## an AI man sees a blow coming this long before it lands, and decides once per blow

## Enemy archetypes: hit points, melee weapon, ranged weapon ("" for none), traits.
const ENEMIES: Dictionary = {
	"sailor": {"hp": 200.0, "melee": "club", "ranged": "", "panics": true, "parry": 0.10, "block": 0.30, "speed": 3.9, "aim": 0.0},
	"brawler": {"hp": 200.0, "melee": "fists", "ranged": "", "panics": true, "parry": 0.15, "block": 0.40, "speed": 4.3, "aim": 0.0, "heavy_bias": 0.25},
	"marine": {"hp": 200.0, "melee": "bayonet", "ranged": "musket", "panics": false, "parry": 0.20, "block": 0.45, "speed": 4.0, "aim": 2.5},
	"officer": {"hp": 200.0, "melee": "rapier", "ranged": "flintlock", "panics": false, "parry": 0.50, "block": 0.65, "speed": 4.2, "rallies": true, "aim": 3.0},
	"brute": {"hp": 200.0, "melee": "boarding_axe", "ranged": "", "panics": false, "parry": 0.0, "block": 0.20, "speed": 3.5, "front_armor": true, "heavy_bias": 0.5, "aim": 0.0},
	"captain": {"hp": 200.0, "melee": "cutlass", "ranged": "flintlock", "panics": false, "parry": 0.55, "block": 0.70, "speed": 4.3, "aim": 2.0},
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
## Jobs a few hands can be pulled off the fight for, from the order buttons: work our deck gun or patch our hull.
enum Job { NONE, CANNON, REPAIR }
const CANNON_POS: Vector2 = Vector2(-5.4, -2.2)  ## our swivel gun, turned inboard at our rail
const CANNON_CREW: int = 2
const CANNON_LOAD_MAN_S: float = 10.0  ## man-seconds to sponge, load and ram: five seconds for two hands
const CANNON_RANGE_M: float = 15.0
const CANNON_CONE_DEG: float = 28.0
const CANNON_MAX_HITS: int = 4
const REPAIR_CREW: int = 2
const REPAIR_HP_PER_MAN_S: float = 1.2  ## hull hit points a hand patches each second while left alone
const REPAIR_SPOT_X: float = -6.0
const AT_JOB_M: float = 1.1
const HOLD_LINE_X: float = -2.0
const PROTECT_RADIUS_M: float = 3.5


static func player_hp(level: int) -> float:
	return PLAYER_HP_BASE + PLAYER_HP_PER_LEVEL * float(maxi(level - 1, 0))


static func swing_time(weapon_id: String, heavy: bool) -> float:
	return float(WeaponData.WEAPONS[weapon_id]["speed"][1 if heavy else 0])


## Every blade hits for 30 and fists for 20 (half as much again when heavy); weapons differ in speed and tricks.
static func swing_damage(weapon_id: String, heavy: bool) -> float:
	var base: float = FIST_DAMAGE if weapon_id == "fists" else SWORD_DAMAGE
	return base * (HEAVY_MULT if heavy else 1.0)


## Every gun hits for 50.
static func gun_damage(_weapon_id: String) -> float:
	return GUN_DAMAGE


static func parry_window(weapon_id: String) -> float:
	return float(WeaponData.WEAPONS[weapon_id].get("parry_window", PARRY_WINDOW_S))
