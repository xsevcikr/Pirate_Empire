class_name BossAttacks
extends RefCounted
## Every boss's own attacks. Each attack has a tell (the wind-up the player sees, `tele` seconds long), what it
## does when it lands (`dmg`, and an `effect` that lingers), and the answers that work against it (`counter`):
## "dodge" (get out of the way, leaves the boss open), "block" (raise the blade or brace the hull, takes
## BLOCK_TAKEN of the hit), "strike" (hit the reaching limb before it lands) or the boss's own trick
## (chain_shot, shoot_lantern, cool_core, explosive_shot). `fx` is how the model acts it out (BossModel).
##
## Effects: poison and burn hurt every second, blind halves your blows, slow stops you dodging (the ship cannot
## turn, the legs are frozen), stun stops every answer and every blow for a moment.

const BLOCK_TAKEN: float = 0.25
const PHASE_GAP_S: Array[float] = [7.0, 6.0, 4.8]  ## seconds between attacks in each phase; the boss gets faster
const ENRAGE_PAUSE_S: float = 2.5  ## the boss roars when it changes phase and does not attack meanwhile

const ATTACKS: Dictionary = {
	"shell_king": {
		"pincer_sweep": {"tele": 1.6, "dmg": 40.0, "counter": ["dodge", "block"], "fx": "sweep", "part": "arm_r"},
		"claw_smash": {"tele": 2.0, "dmg": 60.0, "counter": ["dodge"], "fx": "slam", "part": "arm_l", "expose_bonus_s": 2.0},
		"bubble_spit": {"tele": 1.8, "dmg": 25.0, "counter": ["dodge", "block"], "effect": "poison", "eff_s": 5.0, "eff_dps": 4.0, "fx": "spit", "part": "head", "color": Color(0.55, 0.95, 0.35)},
		"burrow_burst": {"tele": 2.4, "dmg": 60.0, "counter": ["dodge"], "fx": "dive", "part": "body"},
		"shell_spin": {"tele": 2.2, "dmg": 45.0, "counter": ["dodge"], "effect": "stun", "eff_s": 1.5, "fx": "spin", "part": "body"},
	},
	"sea_serpent": {
		"venom_spit": {"tele": 1.8, "dmg": 80.0, "counter": ["dodge"], "effect": "poison", "eff_s": 6.0, "eff_dps": 15.0, "fx": "spit", "part": "head", "color": Color(0.5, 1.0, 0.25)},
		"head_strike": {"tele": 2.0, "dmg": 200.0, "counter": ["dodge"], "fx": "lunge", "part": "head"},
		"coil": {"tele": 2.4, "dmg": 120.0, "counter": ["chain_shot", "block"], "effect": "slow", "eff_s": 4.0, "fx": "grab", "part": "body"},
		"tail_sweep": {"tele": 1.6, "dmg": 90.0, "counter": ["block"], "fx": "sweep", "part": "tail"},
		"siren_shriek": {"tele": 2.0, "dmg": 40.0, "counter": ["block"], "effect": "stun", "eff_s": 3.0, "fx": "roar", "part": "head", "color": Color(0.7, 0.95, 1.0)},
	},
	"kraken": {
		"tentacle_slam": {"tele": 2.0, "dmg": 200.0, "counter": ["dodge"], "fx": "slam", "part": "arm_r"},
		"tidal_slap": {"tele": 1.6, "dmg": 160.0, "counter": ["block"], "fx": "sweep", "part": "arm_l"},
		"grab_and_crush": {"tele": 2.6, "dmg": 350.0, "counter": ["strike"], "effect": "slow", "eff_s": 4.0, "fx": "grab", "part": "arm_r"},
		"ink_spit": {"tele": 1.8, "dmg": 60.0, "counter": ["dodge"], "effect": "blind", "eff_s": 6.0, "fx": "spit", "part": "head", "color": Color(0.08, 0.05, 0.12)},
		"pull_into_whirlpool": {"tele": 2.4, "dmg": 150.0, "counter": ["dodge"], "effect": "slow", "eff_s": 5.0, "fx": "whirl", "part": "body"},
		"maw_from_below": {"tele": 2.6, "dmg": 300.0, "counter": ["dodge"], "fx": "dive", "part": "body"},
	},
	"ghost_admiral": {
		"teleport_behind": {"tele": 2.0, "dmg": 200.0, "counter": ["dodge"], "fx": "teleport", "part": "body"},
		"phantom_broadside": {"tele": 2.0, "dmg": 180.0, "counter": ["block"], "fx": "volley", "part": "body", "color": Color(0.35, 1.0, 0.7)},
		"soul_chains": {"tele": 2.2, "dmg": 90.0, "counter": ["shoot_lantern", "block"], "effect": "slow", "eff_s": 6.0, "fx": "grab", "part": "body", "color": Color(0.35, 1.0, 0.7)},
		"lightning_storm": {"tele": 2.4, "dmg": 250.0, "counter": ["block"], "fx": "rain", "part": "body", "color": Color(0.8, 0.95, 1.0)},
		"skeletal_boarders": {"tele": 2.2, "dmg": 120.0, "counter": ["block"], "fx": "summon", "part": "body"},
		"cursed_lantern": {"tele": 2.0, "dmg": 150.0, "counter": ["dodge"], "effect": "burn", "eff_s": 5.0, "eff_dps": 12.0, "fx": "spit", "part": "head", "color": Color(0.35, 1.0, 0.6)},
		"death_wail": {"tele": 1.8, "dmg": 60.0, "counter": ["block"], "effect": "stun", "eff_s": 3.0, "fx": "roar", "part": "head", "color": Color(0.6, 1.0, 0.8)},
	},
	"brass_colossus": {
		"fist_slam": {"tele": 1.8, "dmg": 50.0, "counter": ["dodge"], "fx": "slam", "part": "arm_r", "expose_bonus_s": 1.5},
		"steam_blast": {"tele": 1.6, "dmg": 35.0, "counter": ["block"], "effect": "blind", "eff_s": 3.0, "fx": "breath", "part": "head", "color": Color(0.95, 0.95, 0.95)},
		"rocket_fist": {"tele": 2.0, "dmg": 60.0, "counter": ["dodge"], "fx": "throw", "part": "arm_l", "color": Color(0.72, 0.52, 0.18)},
		"flame_jets": {"tele": 2.0, "dmg": 40.0, "counter": ["dodge"], "effect": "burn", "eff_s": 4.0, "eff_dps": 5.0, "fx": "breath", "part": "head", "color": Color(1.0, 0.45, 0.1)},
		"ground_slam": {"tele": 2.2, "dmg": 55.0, "counter": ["dodge"], "effect": "stun", "eff_s": 2.0, "fx": "quake", "part": "arm_r"},
		"overheat": {"tele": 3.0, "dmg": 80.0, "counter": ["cool_core"], "effect": "burn", "eff_s": 4.0, "eff_dps": 6.0, "fx": "nova", "part": "body", "color": Color(1.0, 0.35, 0.05)},
	},
	"ice_leviathan": {
		"hurl_ice": {"tele": 2.0, "dmg": 150.0, "counter": ["dodge"], "fx": "throw", "part": "head", "color": Color(0.85, 0.95, 1.0)},
		"freezing_breath": {"tele": 2.0, "dmg": 100.0, "counter": ["block"], "effect": "slow", "eff_s": 5.0, "fx": "breath", "part": "head", "color": Color(0.7, 0.92, 1.0)},
		"icicle_rain": {"tele": 2.2, "dmg": 180.0, "counter": ["block"], "fx": "rain", "part": "body", "color": Color(0.85, 0.95, 1.0)},
		"break_ice": {"tele": 2.0, "dmg": 200.0, "counter": ["dodge"], "fx": "quake", "part": "body"},
		"glacier_dive": {"tele": 2.6, "dmg": 280.0, "counter": ["dodge"], "fx": "dive", "part": "body"},
		"frost_lock": {"tele": 2.6, "dmg": 60.0, "counter": ["explosive_shot"], "effect": "stun", "eff_s": 3.0, "fx": "freeze", "part": "head", "color": Color(0.7, 0.92, 1.0)},
	},
	"valcourt": {
		"line_ahead_broadsides": {"tele": 2.0, "dmg": 250.0, "counter": ["dodge", "block"], "fx": "volley", "part": "body"},
		"board_if_close": {"tele": 2.0, "dmg": 100.0, "counter": ["dodge", "block"], "fx": "summon", "part": "body"},
		"fire_ships": {"tele": 2.0, "dmg": 200.0, "counter": ["dodge"], "effect": "burn", "eff_s": 4.0, "eff_dps": 10.0, "fx": "volley", "part": "body"},
		"iron_bulwark": {"tele": 2.0, "dmg": 0.0, "counter": [], "fx": "roar", "part": "body"},
		"ram_and_board": {"tele": 2.0, "dmg": 300.0, "counter": ["dodge"], "fx": "lunge", "part": "body"},
		"captain_duel": {"tele": 2.0, "dmg": 150.0, "counter": ["dodge", "block"], "fx": "lunge", "part": "body"},
	},
	"black_ibrahim": {
		"fleet_duel": {"tele": 2.0, "dmg": 250.0, "counter": ["dodge", "block"], "fx": "volley", "part": "body"},
		"frigate_formation": {"tele": 2.0, "dmg": 150.0, "counter": ["dodge", "block"], "fx": "volley", "part": "body"},
		"mortar_rain": {"tele": 2.4, "dmg": 300.0, "counter": ["dodge"], "fx": "rain", "part": "body"},
		"bombard_bases": {"tele": 2.0, "dmg": 200.0, "counter": ["dodge", "block"], "fx": "volley", "part": "body"},
		"burning_deck_duel": {"tele": 2.0, "dmg": 250.0, "counter": ["dodge", "block"], "effect": "burn", "eff_s": 4.0, "eff_dps": 10.0, "fx": "lunge", "part": "body"},
		"attack_pattern_three": {"tele": 2.0, "dmg": 300.0, "counter": ["dodge"], "fx": "volley", "part": "body"},
	},
}


static func of(boss_id: String, attack: String) -> Dictionary:
	return ATTACKS.get(boss_id, {}).get(attack, {})


static func tele_s(boss_id: String, attack: String) -> float:
	return float(of(boss_id, attack).get("tele", 2.0))


static func counters(boss_id: String, attack: String) -> Array:
	return of(boss_id, attack).get("counter", [])


## The hint under the tell: what works against this attack, in words.
static func answer_key(boss_id: String, attack: String) -> String:
	var c: Array = counters(boss_id, attack)
	if c.is_empty():
		return "answer.none"
	for special: String in c:
		if special not in ["dodge", "block"]:
			return "answer." + special
	if c.has("dodge") and c.has("block"):
		return "answer.either"
	return "answer." + str(c[0])
