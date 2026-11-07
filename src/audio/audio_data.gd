class_name AudioData
extends RefCounted
## Every sound in the game: which file, which bus, how loud, and what plays when. All numbers live here.

const ROOT: String = "res://audio/"
const BUSES: Array[String] = ["Music", "SFX", "Voice", "Ambience"]  ## children of Master
const CROSSFADE_S: float = 2.0
const DUCK_DB: float = -7.0
const DUCK_TAIL_S: float = 0.35
const SFX_POOL: int = 16
const SFX_MAX_DIST_M: float = 900.0
const DEFAULT_COOLDOWN_S: float = 0.06

## SFX: id -> {db, pitch (+- fraction), pos (positional by default), cd (seconds before it may repeat)}.
const SFX: Dictionary = {
	"cannon_swivel": {"db": -4.0, "pitch": 0.06, "pos": true}, "cannon_6pdr": {"db": -2.0, "pitch": 0.05, "pos": true},
	"cannon_12pdr": {"db": -1.0, "pitch": 0.05, "pos": true}, "cannon_24pdr": {"db": 0.0, "pitch": 0.05, "pos": true},
	"ball_whistle": {"db": -10.0, "pitch": 0.1, "pos": true}, "splash": {"db": -5.0, "pitch": 0.12, "pos": true},
	"wood_impact": {"db": -3.0, "pitch": 0.1, "pos": true}, "splinter": {"db": -6.0, "pitch": 0.1, "pos": true},
	"mast_creak": {"db": -9.0, "pitch": 0.08, "pos": true, "cd": 4.0}, "mast_snap": {"db": 0.0, "pitch": 0.05, "pos": true},
	"fire_crackle": {"db": -8.0, "pitch": 0.05, "pos": true, "cd": 1.5}, "explosion": {"db": 2.0, "pitch": 0.05, "pos": true},
	"bell": {"db": -6.0, "pitch": 0.0, "pos": false, "cd": 2.0}, "sail_flap": {"db": -9.0, "pitch": 0.1, "pos": false, "cd": 2.0},
	"sail_fill": {"db": -8.0, "pitch": 0.05, "pos": false, "cd": 2.0}, "rope_creak": {"db": -12.0, "pitch": 0.15, "pos": false, "cd": 3.0},
	"hull_groan": {"db": -7.0, "pitch": 0.1, "pos": false, "cd": 8.0}, "thunder": {"db": -3.0, "pitch": 0.1, "pos": false, "cd": 6.0},
	"sword_clash": {"db": -4.0, "pitch": 0.1, "pos": false}, "parry_ring": {"db": -3.0, "pitch": 0.05, "pos": false},
	"pistol": {"db": -3.0, "pitch": 0.06, "pos": false}, "musket": {"db": -2.0, "pitch": 0.06, "pos": false},
	"blunderbuss": {"db": -1.0, "pitch": 0.06, "pos": false}, "step_wood": {"db": -12.0, "pitch": 0.15, "pos": false, "cd": 0.2},
	"step_sand": {"db": -13.0, "pitch": 0.15, "pos": false, "cd": 0.2}, "coin": {"db": -6.0, "pitch": 0.08, "pos": false, "cd": 0.15},
	"chest": {"db": -4.0, "pitch": 0.03, "pos": false}, "roar_kraken": {"db": 0.0, "pitch": 0.04, "pos": false, "cd": 3.0},
	"roar_serpent": {"db": 0.0, "pitch": 0.04, "pos": false, "cd": 3.0}, "roar_crab": {"db": -1.0, "pitch": 0.04, "pos": false, "cd": 3.0},
	"roar_colossus": {"db": 0.0, "pitch": 0.04, "pos": false, "cd": 3.0}, "roar_leviathan": {"db": 0.0, "pitch": 0.04, "pos": false, "cd": 3.0},
	"roar_ghost": {"db": -1.0, "pitch": 0.04, "pos": false, "cd": 3.0}, "ui_click": {"db": -8.0, "pitch": 0.03, "pos": false},
	"ui_confirm": {"db": -6.0, "pitch": 0.0, "pos": false}, "level_up": {"db": -4.0, "pitch": 0.0, "pos": false},
	"achievement": {"db": -4.0, "pitch": 0.0, "pos": false}, "dice_roll": {"db": -6.0, "pitch": 0.05, "pos": false},
	"card": {"db": -8.0, "pitch": 0.08, "pos": false}, "gulls": {"db": -14.0, "pitch": 0.1, "pos": false, "cd": 6.0},
	"hull_crash": {"db": 0.0, "pitch": 0.08, "pos": true, "cd": 0.3}, "hammer": {"db": -6.0, "pitch": 0.1, "pos": false, "cd": 1.0},
	"pump": {"db": -12.0, "pitch": 0.08, "pos": false, "cd": 1.6},
}

## Looped ambience: id -> {file, db}. The mixer sets each one's loudness from the situation.
const AMBIENCE: Dictionary = {
	"waves_calm": {"db": -14.0}, "waves_mid": {"db": -14.0}, "waves_rough": {"db": -12.0}, "wind": {"db": -16.0}, "rain": {"db": -14.0},
}
const SEA_STATE_ROUGH: float = 4.5  ## waves_rough fades in above this
const SEA_STATE_CALM: float = 2.0   ## waves_calm fades out above this
const RAIN_FROM: float = 4.5
const STORM_FROM: float = 6.0
const THUNDER_EVERY_S: Vector2 = Vector2(18.0, 50.0)
const GULL_NEAR_M: float = 650.0
const GULL_EVERY_S: Vector2 = Vector2(10.0, 25.0)
const GROAN_SEA_STATE: float = 5.5

## Music: layer -> file. The explore layer plays the region's theme instead where one exists.
const LAYERS: Dictionary = {
	"EXPLORE": "layer_explore", "TENSION": "layer_tension", "COMBAT": "layer_combat", "BOARDING": "layer_boarding",
	"BOSS": "layer_boss", "PORT": "layer_port", "STORM": "layer_storm",
}
const REGION_THEMES: Array[String] = ["albion_shallows", "merchants_reach", "haven_waters", "coral_isles", "iron_marches", "dead_reach"]
const BOSS_THEMES: Array[String] = [
	"kraken", "sea_serpent", "shell_king", "ghost_admiral", "brass_colossus", "ice_leviathan", "valcourt", "black_ibrahim",
	"molly", "isabeau", "saltjaw", "vale",
]
const TAVERN_TRACK: String = "tavern_band"
const MENU_TRACK: String = "menu_theme"  ## the title screen
const SHANTIES: Array[String] = ["drunken_sailor", "haul_the_anchor", "black_gale", "pieces_of_eight", "rum_and_rope"]
const SHANTY_MIN_MORALE: float = 80.0  ## sung at Loyal morale

## Voices: file groups.
const VOICE_FILES: Dictionary = {
	"crew": ["bark_a", "bark_b", "bark_c"], "captain": ["captain_a", "captain_b"], "taunt": ["taunt_a", "taunt_b"],
}

## Barks: situation -> {lines (string keys), voice, cd (seconds between barks of this kind)}.
const BARKS: Dictionary = {
	"reload": {"lines": ["bark.reload.0", "bark.reload.1"], "voice": "crew", "cd": 14.0},
	"fire_hold": {"lines": ["bark.fire.0", "bark.fire.1"], "voice": "crew", "cd": 8.0},
	"sail_ho": {"lines": ["bark.sail.0", "bark.sail.1"], "voice": "crew", "cd": 30.0},
	"flooding": {"lines": ["bark.flood.0", "bark.flood.1"], "voice": "crew", "cd": 12.0},
	"mast_down": {"lines": ["bark.mast.0", "bark.mast.1"], "voice": "crew", "cd": 6.0},
	"breach": {"lines": ["bark.breach.0", "bark.breach.1", "bark.breach.2"], "voice": "crew", "cd": 6.0},
	"patched": {"lines": ["bark.patched.0", "bark.patched.1"], "voice": "crew", "cd": 10.0},
	"grumble": {"lines": ["bark.grumble.0", "bark.grumble.1", "bark.grumble.2"], "voice": "crew", "cd": 90.0},
	"victory": {"lines": ["bark.victory.0", "bark.victory.1"], "voice": "captain", "cd": 5.0},
	"level_up": {"lines": ["bark.level.0"], "voice": "captain", "cd": 5.0},
	"storm": {"lines": ["bark.storm.0", "bark.storm.1"], "voice": "captain", "cd": 60.0},
	"land_ho": {"lines": ["bark.land.0", "bark.land.1"], "voice": "crew", "cd": 60.0},
	"boarding": {"lines": ["bark.board.0", "bark.board.1"], "voice": "captain", "cd": 10.0},
	"taunt_molly": {"lines": ["bark.taunt.molly"], "voice": "taunt", "cd": 60.0},
	"taunt_isabeau": {"lines": ["bark.taunt.isabeau"], "voice": "taunt", "cd": 60.0},
	"taunt_saltjaw": {"lines": ["bark.taunt.saltjaw"], "voice": "taunt", "cd": 60.0},
	"taunt_vale": {"lines": ["bark.taunt.vale"], "voice": "taunt", "cd": 60.0},
	"taunt_valcourt": {"lines": ["bark.taunt.valcourt"], "voice": "taunt", "cd": 60.0},
	"taunt_ibrahim": {"lines": ["bark.taunt.ibrahim"], "voice": "taunt", "cd": 60.0},
}

## Game actions and the sound each one makes, so nothing the player does is silent. A test checks every entry.
const ACTION_SFX: Dictionary = {
	"fire_swivel": "cannon_swivel", "fire_6pdr": "cannon_6pdr", "fire_12pdr": "cannon_12pdr", "fire_24pdr": "cannon_24pdr",
	"ball_in_flight": "ball_whistle", "ball_hits_water": "splash", "ball_hits_hull": "wood_impact", "hull_splinters": "splinter",
	"mast_strains": "mast_creak", "mast_falls": "mast_snap", "fire_in_hold": "fire_crackle", "magazine_blows": "explosion",
	"hour_strikes": "bell", "sails_luff": "sail_flap", "sails_fill": "sail_fill", "rigging_works": "rope_creak", "storm_hull": "hull_groan",
	"lightning": "thunder", "blades_meet": "sword_clash", "parry": "parry_ring", "pistol_shot": "pistol", "musket_shot": "musket",
	"blunderbuss_shot": "blunderbuss", "walk_on_wood": "step_wood", "walk_on_sand": "step_sand", "trade": "coin", "open_chest": "chest",
	"kraken_attack": "roar_kraken", "serpent_attack": "roar_serpent", "shell_king_attack": "roar_crab", "colossus_attack": "roar_colossus",
	"leviathan_attack": "roar_leviathan", "ghost_admiral_attack": "roar_ghost", "menu_click": "ui_click", "menu_confirm": "ui_confirm",
	"level_up": "level_up", "achievement": "achievement", "roll_dice": "dice_roll", "deal_card": "card", "gulls_near_land": "gulls",
	"dock": "rope_creak", "prize_taken": "chest", "quest_done": "ui_confirm",
	"ram_ship": "hull_crash", "patch_hole": "hammer", "work_pumps": "pump",
}

const CANNON_OF: Dictionary = {
	"swivel": "cannon_swivel", "6pdr": "cannon_6pdr", "long9": "cannon_6pdr", "12pdr": "cannon_12pdr",
	"carronade": "cannon_12pdr", "24pdr": "cannon_24pdr", "32pdr": "cannon_24pdr",
}

## The monster that roars for each boss id.
const ROAR_OF: Dictionary = {
	"kraken": "roar_kraken", "sea_serpent": "roar_serpent", "shell_king": "roar_crab", "brass_colossus": "roar_colossus",
	"ice_leviathan": "roar_leviathan", "ghost_admiral": "roar_ghost",
}


## The effect for a gun: the nearest calibre we have a recording of.
static func cannon_sfx(gun_id: String) -> String:
	return str(CANNON_OF.get(gun_id, "cannon_6pdr"))


## Every music track the game can ask for.
static func all_music() -> Array[String]:
	var out: Array[String] = [TAVERN_TRACK, MENU_TRACK]
	for layer: String in LAYERS:
		out.append(str(LAYERS[layer]))
	for r in REGION_THEMES:
		out.append("region_" + r)
	for b in BOSS_THEMES:
		out.append("boss_" + b)
	for s in SHANTIES:
		out.append("shanty_" + s)
	return out


static func sfx_path(id: String) -> String:
	return ROOT + "sfx/%s.ogg" % id


static func music_path(track: String) -> String:
	return ROOT + "music/%s.ogg" % track


static func voice_path(id: String) -> String:
	return ROOT + "voice/%s.ogg" % id


static func ambience_path(id: String) -> String:
	return ROOT + "ambience/%s.ogg" % id


## The music track for a situation. ctx: boss (boss id or ""), plus everything AudioDirector.pick reads and "region".
static func track_for(ctx: Dictionary) -> String:
	var boss: String = str(ctx.get("boss_id", ""))
	if boss != "" and BOSS_THEMES.has(boss):
		return "boss_" + boss
	var layer: AudioDirector.Music = AudioDirector.pick(ctx)
	var name: String = AudioDirector.Music.keys()[layer]
	if layer == AudioDirector.Music.EXPLORE and REGION_THEMES.has(str(ctx.get("region", ""))):
		return "region_" + str(ctx["region"])
	return str(LAYERS[name])


## Crossfade gains at time t into a fade of `dur`: [outgoing, incoming], equal-power.
static func crossfade_gains(t: float, dur: float = CROSSFADE_S) -> Array[float]:
	var k: float = clampf(t / maxf(dur, 0.001), 0.0, 1.0)
	return [cos(k * PI * 0.5), sin(k * PI * 0.5)]


## Loudness (0..1) of each ambience loop for the sea state: [calm, mid, rough, wind, rain].
static func ambience_mix(sea_state: float, wind_kn: float) -> Dictionary:
	var calm: float = clampf(1.0 - (sea_state - 0.5) / (SEA_STATE_CALM + 0.5), 0.0, 1.0)
	var rough: float = clampf((sea_state - SEA_STATE_ROUGH + 1.0) / 2.0, 0.0, 1.0)
	var mid: float = clampf(1.0 - absf(sea_state - 3.0) / 2.0, 0.0, 1.0)
	return {
		"waves_calm": calm, "waves_mid": mid, "waves_rough": rough,
		"wind": clampf(wind_kn / 30.0, 0.05, 1.0), "rain": clampf((sea_state - RAIN_FROM + 0.5) / 2.0, 0.0, 1.0),
	}
