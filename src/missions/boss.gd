class_name Boss
extends RefCounted
## A three-phase boss script. Damage drives phase changes; the script exposes what the boss does each phase.
## The attacks themselves (tell length, damage, answers) are in BossAttacks.

const DIFFICULTY_HP: Array[float] = [0.8, 1.0, 1.3, 1.7]
const HEAL_PER_MIN_OUTSIDE: float = 0.20
const TELEGRAPH_S: float = 2.0

const DEFS: Dictionary = {
	"valcourt": {
		"name": "Admiral Valcourt", "hp": 18000.0, "phases": 3, "thresholds": [1.0, 0.5, 0.25],
		"actions": [["line_ahead_broadsides", "board_if_close"], ["fire_ships", "iron_bulwark"], ["ram_and_board", "captain_duel"]],
		"untargetable_phases": [], "captain_hp": 600.0, "reward": "Sovereign of Brass",
	},
	"ghost_admiral": {
		"name": "The Ghost Admiral", "hp": 12000.0, "phases": 3, "thresholds": [1.0, 0.66, 0.33],
		"actions": [["teleport_behind", "phantom_broadside"], ["soul_chains", "lightning_storm", "phantom_broadside"], ["skeletal_boarders", "cursed_lantern", "death_wail", "lightning_storm"]],
		"untargetable_phases": [0], "captain_hp": 0.0, "reward": "The Revenant",
	},
	"kraken": {
		"name": "The Kraken", "hp": 7000.0, "phases": 3, "thresholds": [1.0, 0.66, 0.33],
		"actions": [["tentacle_slam", "tidal_slap"], ["grab_and_crush", "ink_spit", "tentacle_slam"], ["pull_into_whirlpool", "maw_from_below", "tidal_slap", "grab_and_crush"]],
		"untargetable_phases": [], "captain_hp": 0.0, "reward": "Kraken Ink",
	},
	"shell_king": {
		"name": "The Shell King", "hp": 1200.0, "phases": 3, "thresholds": [1.0, 0.6, 0.3],
		"actions": [["pincer_sweep", "claw_smash"], ["bubble_spit", "pincer_sweep", "shell_spin"], ["burrow_burst", "claw_smash", "bubble_spit", "shell_spin"]],
		"untargetable_phases": [], "captain_hp": 0.0, "reward": "The Drowned Purse",
	},
	"sea_serpent": {
		"name": "The Sea Serpent", "hp": 4000.0, "phases": 3, "thresholds": [1.0, 0.66, 0.33],
		"actions": [["venom_spit", "head_strike"], ["coil", "tail_sweep", "venom_spit"], ["siren_shriek", "head_strike", "coil", "venom_spit"]],
		"untargetable_phases": [], "captain_hp": 0.0, "reward": "Song of the Sirens",
	},
	"brass_colossus": {
		"name": "The Brass Colossus", "hp": 5000.0, "phases": 3, "thresholds": [1.0, 0.66, 0.33],
		"actions": [["fist_slam", "steam_blast"], ["rocket_fist", "flame_jets", "fist_slam"], ["overheat", "ground_slam", "rocket_fist", "flame_jets"]],
		"untargetable_phases": [], "captain_hp": 0.0, "reward": "Iron Heart",
	},
	"ice_leviathan": {
		"name": "The Ice Leviathan", "hp": 9000.0, "phases": 3, "thresholds": [1.0, 0.66, 0.33],
		"actions": [["hurl_ice", "freezing_breath"], ["icicle_rain", "break_ice", "hurl_ice"], ["frost_lock", "glacier_dive", "freezing_breath", "icicle_rain"]],
		"untargetable_phases": [], "captain_hp": 0.0, "reward": "Frostmourn Vault",
	},
	"black_ibrahim": {
		"name": "Black Ibrahim", "hp": 20000.0, "phases": 3, "thresholds": [1.0, 0.6, 0.3],
		"actions": [["fleet_duel", "frigate_formation"], ["mortar_rain", "bombard_bases"], ["burning_deck_duel", "attack_pattern_three"]],
		"untargetable_phases": [], "captain_hp": 900.0, "reward": "Pirate King crown",
	},
}

var id: String
var max_hp: float
var hp: float
var phase: int = 0
var phases_seen: Array[int] = [0]
var defeated: bool = false
var telegraph_left_s: float = 0.0
var special_pending: String = ""
var in_arena: bool = true
var lantern_destroyed: bool = false
var untargetable: bool = false
var enrage_left_s: float = 0.0  ## the roar after a phase change; no attack meanwhile
var _action_i: int = 0
var _timer_s: float = 0.0


func _init(boss_id: String, difficulty: int = 1) -> void:
	id = boss_id
	max_hp = DEFS[id]["hp"] * DIFFICULTY_HP[difficulty]
	hp = max_hp
	untargetable = 0 in DEFS[id]["untargetable_phases"]


func def() -> Dictionary:
	return DEFS[id]


func current_actions() -> Array:
	return def()["actions"][phase]


## Apply damage. Untargetable phases ignore it unless `weak_point` is hit; the Ghost Admiral's last phase needs the lantern.
func damage(amount: float, weak_point: bool = false) -> void:
	if defeated:
		return
	if untargetable and not weak_point:
		return
	if id == "ghost_admiral" and phase == 2 and not lantern_destroyed:
		if weak_point:
			lantern_destroyed = true
		return
	hp = maxf(hp - amount, 0.0)
	_update_phase()


func _update_phase() -> void:
	var frac: float = hp / max_hp
	var th: Array = def()["thresholds"]
	var new_phase: int = 0
	# phase is the highest index whose threshold has been crossed
	for i in range(1, th.size()):
		if frac <= th[i]:
			new_phase = i
	if new_phase != phase:
		phase = new_phase
		phases_seen.append(phase)
		untargetable = phase in def()["untargetable_phases"]
		_action_i = 0
		_timer_s = 0.0
		enrage_left_s = BossAttacks.ENRAGE_PAUSE_S
	if hp <= 0.0:
		defeated = true


## Special attack cycle: the boss winds up for the attack's tell (about 2 s, with a red decal), then it lands.
## Each phase attacks more often. Returns the attack that landed this tick.
func tick(delta: float) -> String:
	if defeated:
		return ""
	if not in_arena:
		hp = minf(max_hp, hp + max_hp * HEAL_PER_MIN_OUTSIDE * delta / 60.0)
		return ""
	if enrage_left_s > 0.0 and telegraph_left_s <= 0.0:
		enrage_left_s = maxf(enrage_left_s - delta, 0.0)
		return ""
	_timer_s += delta
	if telegraph_left_s > 0.0:
		telegraph_left_s -= delta
		if telegraph_left_s <= 0.0:
			var landed: String = special_pending
			special_pending = ""
			return landed
		return ""
	if _timer_s >= BossAttacks.PHASE_GAP_S[mini(phase, BossAttacks.PHASE_GAP_S.size() - 1)]:
		_timer_s = 0.0
		var a: Array = current_actions()
		special_pending = a[_action_i % a.size()]
		_action_i += 1
		telegraph_left_s = BossAttacks.tele_s(id, special_pending)
	return ""
