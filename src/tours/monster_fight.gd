class_name MonsterFight
extends RefCounted
## A telegraphed boss fight for the tour guardians (Shell King on foot, sea serpent from the ship). Boss supplies
## the hit points, the phase thresholds and the two-second telegraph; this class decides who gets hurt.
## Dodge inside the telegraph and the monster is left exposed for a few seconds; parry the Shell King's pincer
## and its claw cracks for good.

const WINDOW_S: float = 1.0  ## the last second of a telegraph is when a dodge or parry counts

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
var _dodged: bool = false
var _parried: bool = false
var _t: float = 0.0


func _init(monster_id: String, difficulty: int = 1, player_hp_override: float = -1.0) -> void:
	id = monster_id
	boss = Boss.new(monster_id, difficulty)
	cfg = TourData.MONSTERS[monster_id]
	player_max = player_hp_override if player_hp_override > 0.0 else float(TourData.PLAYER_HP[cfg["player"]])
	player_hp = player_max


func is_over() -> bool:
	return boss.defeated or player_hp <= 0.0


func won() -> bool:
	return boss.defeated


func lost() -> bool:
	return player_hp <= 0.0 and not boss.defeated


func is_exposed() -> bool:
	return exposed_s > 0.0


func telegraph() -> String:
	return boss.special_pending if boss.telegraph_left_s > 0.0 else ""


## Advance time. Returns the attack that landed this tick, or "".
func tick(delta: float) -> String:
	if is_over():
		return ""
	_t += delta
	exposed_s = maxf(exposed_s - delta, 0.0)
	var landed: String = boss.tick(delta)
	if landed == "":
		return ""
	var dmg: float = float(cfg["dmg"].get(landed, 0.0))
	if claw_cracked:
		dmg *= 1.0 - float(cfg.get("claw_crack_cut", 0.0))
	if chain_cut and id == "sea_serpent":
		dmg *= 1.0 - float(cfg.get("chain_cut", 0.0))
	if _parried and landed in cfg["parry"]:
		events.append("parried:" + landed)
		claw_cracked = true
		exposed_s = float(cfg["expose_s"])
	elif _dodged and landed in cfg["dodge"]:
		events.append("dodged:" + landed)
		exposed_s = float(cfg["expose_s"])
	else:
		if not god:
			player_hp = maxf(player_hp - dmg, 0.0)
		events.append("hit:" + landed)
	_dodged = false
	_parried = false
	return landed


## The player's dodge or parry counts when it is made during the last second of a telegraph.
func dodge() -> bool:
	if boss.telegraph_left_s > 0.0 and boss.telegraph_left_s <= WINDOW_S:
		_dodged = true
		return true
	return false


func parry() -> bool:
	if boss.telegraph_left_s > 0.0 and boss.telegraph_left_s <= WINDOW_S and boss.special_pending in cfg["parry"]:
		_parried = true
		return true
	return false


## A chain shot into the coils during a telegraph cuts the next coil attack.
func chain_shot() -> void:
	if id == "sea_serpent" and boss.telegraph_left_s > 0.0:
		chain_cut = true


## One strike by the player. Armour halves it unless the monster is exposed, then it multiplies.
func strike(base: float = -1.0) -> float:
	if is_over():
		return 0.0
	var dmg: float = base if base >= 0.0 else float(TourData.STRIKE_DMG[cfg["player"]])
	dmg *= float(cfg["exposed_mult"]) if is_exposed() else float(cfg["armor"])
	var before: float = boss.hp
	boss.damage(dmg, is_exposed())
	return before - boss.hp


## Cheat for route tests: the monster falls.
func cheat_kill() -> void:
	boss.damage(boss.max_hp + 1.0, true)


## What a player can do now, for the encounter panel.
func actions() -> Array[String]:
	var a: Array[String] = ["strike", "dodge"]
	if not (cfg["parry"] as Array).is_empty():
		a.append("parry")
	if id == "sea_serpent":
		a.append("chain_shot")
	return a


func do(action: String) -> void:
	match action:
		"strike":
			strike()
		"dodge":
			dodge()
		"parry":
			parry()
		"chain_shot":
			chain_shot()


## Perfect play for tests: dodge or parry at the right moment, strike when exposed or armoured. Returns when over.
func autoplay(max_s: float = 600.0, step: float = 0.1) -> bool:
	var swing_in: float = 0.0
	while not is_over() and _t < max_s:
		var t: String = telegraph()
		if t != "" and boss.telegraph_left_s <= WINDOW_S * 0.9:
			if t in cfg["parry"]:
				parry()
			else:
				dodge()
		if id == "sea_serpent" and t == "coil":
			chain_shot()
		swing_in -= step
		if swing_in <= 0.0:
			strike()
			swing_in = 0.8
		tick(step)
	return won()
