class_name MonsterFight
extends RefCounted
## A telegraphed boss fight (the tour guardians, the sea monsters and the admirals). Boss supplies the hit points,
## the phases and which attack comes next; BossAttacks says how long each tell is, what it does and what answers
## it. This class decides who gets hurt.
##
## Answer inside the last second of a tell: dodge and the boss is left open for a few seconds, block (raise the
## blade, brace the hull) and you take a quarter of it, or use the boss's own trick (cut the reaching arm, chain
## shot the coils, shoot the lantern, cool the core, blast the ice). Some attacks cannot be dodged, some cannot be
## blocked; the tell says which. What lands can poison, burn, blind, slow or stun you for a while.
## The player never sees the boss's health, only their own.

const WINDOW_S: float = 1.0  ## the last second of a telegraph is when a dodge or block counts
const BLIND_MULT: float = 0.5
const SPECIALS: Array[String] = ["chain_shot", "shoot_lantern", "cool_core", "explosive_shot"]
const RELOAD_S: Dictionary = {"captain": 0.8, "ship": 3.0}  ## a sword swing, a broadside reload: no button mashing

var id: String
var boss: Boss
var cfg: Dictionary
var player_hp: float
var player_max: float
var exposed_s: float = 0.0
var claw_cracked: bool = false
var chain_cut: bool = false
var god: bool = false  ## combat cheat for route tests
var events: Array[String] = []
var lanterns_left: int = 0
var tentacles_left: int = 0
var tentacle_hp: float = 0.0
var sails_slowed_s: float = 0.0
var effects: Dictionary = {}  ## poison / burn / blind / slow / stun -> seconds left
var dot_dps: float = 0.0  ## what poison and burn take each second while they last
var last_outcome: String = ""  ## hit, dodged, blocked, countered: what happened to the last attack
var last_attack: String = ""
var reload_left_s: float = 0.0
var _last_phase: int = 0
var _answer: String = ""
var _t: float = 0.0


func _init(monster_id: String, difficulty: int = 1, player_hp_override: float = -1.0) -> void:
	id = monster_id
	boss = Boss.new(monster_id, difficulty)
	cfg = TourData.MONSTERS[monster_id] if TourData.MONSTERS.has(monster_id) else TourData.MONSTERS_BIG[monster_id]
	player_max = player_hp_override if player_hp_override > 0.0 else float(TourData.PLAYER_HP[cfg["player"]])
	player_hp = player_max
	lanterns_left = int(cfg.get("lanterns", 0))
	tentacles_left = int(cfg.get("tentacles", 0))
	tentacle_hp = float(cfg.get("tentacle_hp", 0.0))


func is_over() -> bool:
	return boss.defeated or player_hp <= 0.0


func won() -> bool:
	return boss.defeated


func lost() -> bool:
	return player_hp <= 0.0 and not boss.defeated


func is_exposed() -> bool:
	return exposed_s > 0.0


func on_foot() -> bool:
	return str(cfg["player"]) == "captain"


func has_effect(e: String) -> bool:
	return float(effects.get(e, 0.0)) > 0.0


func telegraph() -> String:
	return boss.special_pending if boss.telegraph_left_s > 0.0 else ""


## How far along the tell is, 0 when it starts and 1 when it lands. The model and the red decal follow it.
func telegraph_progress() -> float:
	var t: String = telegraph()
	if t == "":
		return 0.0
	var total: float = BossAttacks.tele_s(id, t)
	return clampf(1.0 - boss.telegraph_left_s / total, 0.0, 1.0)


func in_window() -> bool:
	return boss.telegraph_left_s > 0.0 and boss.telegraph_left_s <= WINDOW_S


## The answer the player has given to the attack that is coming, or "".
func answered() -> String:
	return _answer


## Advance time. Returns the attack that landed this tick (dodged, blocked or not), or "".
func tick(delta: float) -> String:
	if is_over():
		return ""
	_t += delta
	var was_exposed: bool = exposed_s > 0.0
	exposed_s = maxf(exposed_s - delta, 0.0)
	reload_left_s = maxf(reload_left_s - delta, 0.0)
	sails_slowed_s = maxf(sails_slowed_s - delta, 0.0)
	_tick_effects(delta)
	if was_exposed and exposed_s <= 0.0 and id == "kraken":
		tentacles_left = int(cfg["tentacles"])  # the tentacles grow back once the head sinks
		tentacle_hp = float(cfg["tentacle_hp"])
	var landed: String = boss.tick(delta)
	if boss.phase != _last_phase:
		_last_phase = boss.phase
		events.append("phase:%d" % boss.phase)
		Sfx.play(str(AudioData.ROAR_OF.get(id, "roar_kraken")))
		if id == "ghost_admiral" and boss.phase == 2:
			lanterns_left = 1
	if landed == "":
		return ""
	_land(landed)
	return landed


func _tick_effects(delta: float) -> void:
	for e: String in effects.keys():
		var left: float = float(effects[e]) - delta
		if (e == "poison" or e == "burn") and not god:
			player_hp = maxf(player_hp - dot_dps * minf(delta, float(effects[e])), 0.0)
		if left <= 0.0:
			effects.erase(e)
		else:
			effects[e] = left
	if not has_effect("poison") and not has_effect("burn"):
		dot_dps = 0.0


func _land(atk: String) -> void:
	Sfx.play(str(AudioData.ROAR_OF.get(id, "roar_kraken")))
	var a: Dictionary = BossAttacks.of(id, atk)
	var dmg: float = float(a.get("dmg", 0.0))
	var ok: Array = a.get("counter", [])
	if claw_cracked:
		dmg *= 1.0 - float(cfg.get("claw_crack_cut", 0.0))
	if chain_cut and id == "sea_serpent" and atk == "coil":
		dmg *= 1.0 - float(cfg.get("chain_cut", 0.0))
	var expose: float = float(cfg["expose_s"]) + float(a.get("expose_bonus_s", 0.0))
	last_attack = atk
	if _answer != "" and _answer in ok:
		match _answer:
			"dodge":
				last_outcome = "dodged"
				exposed_s = expose
			"block":
				last_outcome = "blocked"
				_hurt(dmg * BossAttacks.BLOCK_TAKEN)
				if id == "shell_king" and atk == "pincer_sweep":
					claw_cracked = true  # the pincer breaks on the blade
					exposed_s = expose
					events.append("parried:" + atk)
			"chain_shot":
				last_outcome = "countered"
				_hurt(dmg)  # chain_cut already took most of it
				exposed_s = expose
			_:
				last_outcome = "countered"
				exposed_s = expose
		events.append(last_outcome + ":" + atk)
	else:
		last_outcome = "hit"
		_hurt(dmg)
		events.append("hit:" + atk)
		var e: String = str(a.get("effect", ""))
		if e != "":
			effects[e] = maxf(float(effects.get(e, 0.0)), float(a.get("eff_s", 0.0)))
			if e == "poison" or e == "burn":
				dot_dps = maxf(dot_dps, float(a.get("eff_dps", 0.0)))
			if e == "slow":
				sails_slowed_s = float(a.get("eff_s", 0.0))
	_answer = ""


func _hurt(dmg: float) -> void:
	if not god:
		player_hp = maxf(player_hp - dmg, 0.0)


func _can_answer() -> bool:
	return not is_over() and not has_effect("stun")


## Get out of the way. Counts in the last second of a tell, not while slowed or stunned.
func dodge() -> bool:
	if not _can_answer() or has_effect("slow") or not in_window():
		return false
	_answer = "dodge"
	return true


## Raise the blade or brace the hull. Counts in the last second of a tell.
func block() -> bool:
	if not _can_answer() or not in_window():
		return false
	if "block" not in BossAttacks.counters(id, boss.special_pending):
		return false
	_answer = "block"
	return true


## Old name for block, from when only the Shell King's pincer could be turned.
func parry() -> bool:
	return block()


## The boss's own trick, used any time during the tell of an attack it answers.
func _special(kind: String) -> bool:
	if _can_answer() and telegraph() != "" and kind in BossAttacks.counters(id, telegraph()):
		_answer = kind
		return true
	return false


## A chain shot into the coils during a telegraph cuts the next coil attack.
func chain_shot() -> void:
	if id == "sea_serpent" and boss.telegraph_left_s > 0.0 and _can_answer():
		chain_cut = true
		_special("chain_shot")


## One strike by the player. Armour halves it unless the monster is exposed, then it multiplies. The Kraken's
## tentacles take the blows until all eight are severed; then the head is up for a while. A strike in the window
## of an attack that reaches out (the Kraken's grab) cuts it off.
func strike(base: float = -1.0, ammo: String = "round") -> float:
	if is_over() or has_effect("stun"):
		return 0.0
	if in_window() and "strike" in BossAttacks.counters(id, boss.special_pending):
		_answer = "strike"
	var dmg: float = base if base >= 0.0 else float(TourData.STRIKE_DMG[cfg["player"]])
	if has_effect("blind"):
		dmg *= BLIND_MULT
	if id == "kraken" and tentacles_left > 0 and not is_exposed():
		tentacle_hp -= dmg
		if tentacle_hp <= 0.0:
			tentacles_left -= 1
			tentacle_hp = float(cfg["tentacle_hp"])
			if tentacles_left == 0:
				exposed_s = float(cfg["head_up_s"])
		return 0.0
	dmg *= float(cfg["exposed_mult"]) if is_exposed() else float(cfg["armor"])
	if ammo == "explosive" and cfg.has("explosive_mult"):
		dmg *= float(cfg["explosive_mult"])
	var before: float = boss.hp
	boss.damage(dmg, is_exposed())
	return before - boss.hp


## Shoot a cursed lantern off the Ghost Admiral's stern: two make phase one targetable, one opens the last phase.
## The soul chains hang from a lantern too: shooting it during their tell breaks them.
func shoot_lantern() -> bool:
	if id != "ghost_admiral" or has_effect("stun"):
		return false
	if _special("shoot_lantern"):
		return true
	if lanterns_left <= 0:
		return false
	lanterns_left -= 1
	if boss.phase == 0 and lanterns_left == 0:
		boss.untargetable = false
	if boss.phase == 2:
		boss.damage(0.0, true)
	return true


## Water on the Brass Colossus's core keeps it open longer, and stops it overheating.
func cool_core() -> void:
	if id != "brass_colossus":
		return
	if _special("cool_core"):
		return
	if is_exposed():
		exposed_s += float(cfg["cool_extends_s"])


## An explosive shell: double damage on the Ice Leviathan, and it shatters the frost lock during its tell.
func explosive_shot() -> float:
	_special("explosive_shot")
	return strike(-1.0, "explosive")


## Cheat for route tests: the monster falls.
func cheat_kill() -> void:
	boss.damage(boss.max_hp + 1.0, true)


## What a player can do now, for the encounter panel.
func actions() -> Array[String]:
	var a: Array[String] = ["strike", "dodge", "block"]
	if id == "sea_serpent":
		a.append("chain_shot")
	if id == "ghost_admiral":
		a.append("shoot_lantern")
	if id == "brass_colossus":
		a.append("cool_core")
	if id == "ice_leviathan":
		a.append("explosive_shot")
	return a


## Swing or fire, if the blade is back or the guns are loaded.
func attack(explosive: bool = false) -> float:
	if reload_left_s > 0.0 or is_over() or has_effect("stun"):
		return 0.0
	reload_left_s = float(RELOAD_S[cfg["player"]])
	return explosive_shot() if explosive else strike()


func do(action: String) -> void:
	match action:
		"strike":
			attack()
		"dodge":
			dodge()
		"block", "parry":
			block()
		"chain_shot":
			chain_shot()
		"shoot_lantern":
			shoot_lantern()
		"cool_core":
			cool_core()
		"explosive_shot":
			attack(true)


## The best answer to the attack being told, for autoplay and the screenshot tools.
func best_answer() -> String:
	var ok: Array = BossAttacks.counters(id, telegraph())
	for s in ok:
		if s in SPECIALS or s == "strike":
			return s
	if ok.has("dodge") and not has_effect("slow"):
		return "dodge"
	if ok.has("block"):
		return "block"
	return ""


## Perfect play for tests: answer every tell at the right moment, strike when exposed or armoured. Returns when over.
func autoplay(max_s: float = 600.0, step: float = 0.1) -> bool:
	while not is_over() and _t < max_s:
		var t: String = telegraph()
		if t != "" and _answer == "":
			var best: String = best_answer()
			if best in SPECIALS:
				do(best)
			elif best != "" and boss.telegraph_left_s <= WINDOW_S * 0.9:
				do(best)
		if reload_left_s <= 0.0:
			if lanterns_left > 0:
				shoot_lantern()
			elif id == "brass_colossus" and is_exposed():
				cool_core()
			attack(id == "ice_leviathan")
		tick(step)
	return won()
