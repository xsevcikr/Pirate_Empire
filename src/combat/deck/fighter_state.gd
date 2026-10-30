class_name FighterState
extends RefCounted
## One man on deck, as plain data and timers: no nodes, so every rule can be tested without a scene.

enum State { IDLE, SWING, BLOCK, STAGGER, DODGE, KICK, DRINK, DOWN, DEAD }
## What the captain has in hand: his blade, his bare fists, or his gun (the left and right buttons fire and aim).
enum Mode { BLADE, FISTS, GUN }

var id: int = 0
var team: int = 0  ## 0 = the player's side, 1 = the enemy
var kind: String = "crew"  ## captain_player, crew, sailor, marine, officer, brute, captain
var crew_type: String = "green"
var display_name: String = ""
var is_player: bool = false

var hp: float = DeckData.FIGHTER_HP
var hp_max: float = DeckData.FIGHTER_HP
var stamina_max: float = DeckData.STAMINA_MAX
var stamina: float = DeckData.STAMINA_MAX
## Captain skills (progression): multipliers on this fighter's blade, parry window and pistol reload.
var melee_mult: float = 1.0
var parry_mult: float = 1.0
var pistol_reload_mult: float = 1.0
var pos: Vector2 = Vector2.ZERO  ## x across the deck (our rail negative), y along it
var dir: Vector2 = Vector2.RIGHT
var move_speed: float = DeckData.MOVE_SPEED_MS
var move_intent: Vector2 = Vector2.ZERO

var melee: String = "cutlass"
var blade: String = ""  ## the blade he owns ("" for none): `melee` is "fists" while it is put away
var mode: Mode = Mode.BLADE
var ranged: String = ""
var strength: float = 1.0
var front_armor: bool = false
var panics: bool = false
var rallies: bool = false
var parry_skill: float = 0.1  ## chance an AI man answers a blow with a parry-timed block
var block_skill: float = 0.25
var heavy_bias: float = 0.0
var morale_effic: float = 1.0  ## 0.75 to 1.1 from the crew's morale band

var state: State = State.IDLE
var state_t: float = 0.0
var stagger_left: float = 0.0
var stun_left: float = 0.0
var vulnerable: float = 1.0  ## the next hit taken is multiplied by this (after a parry)

var swing_heavy: bool = false
var swing_dur: float = 0.5
var swing_struck: bool = false
var strike_pending: bool = false
var combo: int = 0
var combo_left: float = 0.0
var charge_t: float = 0.0

var block_up: bool = false
var block_started: float = -1000.0

var dodge_dir: Vector2 = Vector2.ZERO
var kick_pending: bool = false
var kick_done: bool = false

var charges: int = 0
var ranged_ammo: int = 0
var reload_left: float = 0.0
var aim_left: float = 0.0  ## AI men take their time between shots
var aim_skill_deg: float = 4.0  ## spread of an AI man's shot, one standard deviation
var aiming: bool = false  ## the captain holds his aim: slower feet, a steadier hand
var aim_hold_t: float = 0.0
var aim_lock_left: float = 0.0  ## an AI man stands with his gun levelled at `aim_dir` until this runs out
var aim_dir: Vector2 = Vector2.RIGHT
var aim_fire_pending: bool = false

var rum_left: int = 0
var rum_cool: float = 0.0
var rum_drunk: int = 0

var job: DeckData.Job = DeckData.Job.NONE
var job_spot: Vector2 = Vector2.ZERO

var command_target: int = -1
var target_id: int = -1
var think_left: float = 0.0
var overboard: bool = false

var kills: int = 0
var parries: int = 0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var last_hit_by: int = -1


static func make_player(level: int, melee_id: String, ranged_id: String, ranged_shots: int, start_hp: float = -1.0) -> FighterState:
	var f := FighterState.new()
	f.kind = "captain_player"
	f.is_player = true
	f.team = 0
	f.hp_max = DeckData.player_hp(level)
	f.hp = clampf(start_hp, 1.0, f.hp_max) if start_hp > 0.0 else f.hp_max
	f.blade = melee_id if melee_id != "fists" else ""
	f.melee = f.blade if f.blade != "" else "fists"
	f.mode = Mode.BLADE if f.blade != "" else Mode.FISTS
	f.ranged = ranged_id if ranged_shots > 0 else ""
	f.ranged_ammo = ranged_shots
	f.charges = mini(ranged_shots, DeckData.PISTOL_BRACE) if ranged_id != "" else 0
	f.display_name = "Captain"
	return f


static func make_crew(type: String, level: int = 1) -> FighterState:
	var spec: Dictionary = DeckData.CREW.get(type, DeckData.CREW["green"])
	var f := FighterState.new()
	f.kind = "crew"
	f.crew_type = type
	f.team = 0
	f.hp_max = DeckData.CREW_HP
	f.hp = f.hp_max
	f.melee = spec["melee"]
	f.blade = f.melee if f.melee != "fists" else ""
	f.ranged = spec["ranged"]
	f.strength = float(spec["strength"])
	f.parry_skill = minf(float(spec["parry"]) + 0.02 * float(level - 1), 0.6)
	f.block_skill = minf(float(spec["block"]) + 0.02 * float(level - 1), 0.7)
	f.aim_skill_deg = float(spec.get("aim", 3.5))
	if f.ranged != "":
		f.ranged_ammo = 6
		f.charges = 1 if f.ranged == "musket" else 2
	return f


static func make_enemy(archetype: String, hp_override: float = -1.0) -> FighterState:
	var spec: Dictionary = DeckData.ENEMIES[archetype]
	var f := FighterState.new()
	f.kind = archetype
	f.team = 1
	f.hp_max = hp_override if hp_override > 0.0 else float(spec["hp"])
	f.hp = f.hp_max
	f.melee = spec["melee"]
	f.blade = f.melee if f.melee != "fists" else ""
	f.mode = Mode.BLADE if f.blade != "" else Mode.FISTS
	f.ranged = spec["ranged"]
	f.aim_skill_deg = float(spec.get("aim", 3.0)) * float(Difficulty.value("aim_error"))
	f.panics = bool(spec["panics"])
	f.rallies = bool(spec.get("rallies", false))
	f.front_armor = bool(spec.get("front_armor", false))
	f.parry_skill = float(spec["parry"])
	f.block_skill = float(spec["block"])
	f.move_speed = float(spec["speed"])
	f.heavy_bias = float(spec.get("heavy_bias", 0.0))
	f.dir = Vector2.LEFT
	if f.ranged != "":
		f.ranged_ammo = 4
		f.charges = 1
	f.rum_left = 1 if archetype == "captain" else 0
	return f


## Blade, fists, gun, round again; a mode he cannot use is skipped.
func cycle_mode() -> void:
	for step in 3:
		var next: Mode = ((mode + 1 + step) % 3) as Mode
		if set_mode(next):
			return


func set_mode(m: Mode) -> bool:
	match m:
		Mode.BLADE:
			if blade == "":
				return false
			melee = blade
		Mode.FISTS:
			melee = "fists"
		Mode.GUN:
			if ranged == "" or ranged_ammo <= 0:
				return false
	mode = m
	if m != Mode.GUN:
		aiming = false
		aim_hold_t = 0.0
	return true


## One standard deviation of the next shot's angle in degrees.
func shot_spread_deg() -> float:
	if not is_player:
		return aim_skill_deg
	if not aiming:
		return DeckData.AIM_SPREAD_HIP_DEG
	return lerpf(DeckData.AIM_SPREAD_HIP_DEG * 0.4, DeckData.AIM_SPREAD_STEADY_DEG, clampf(aim_hold_t / DeckData.AIM_STEADY_S, 0.0, 1.0))


## Take a pull of rum: a moment with the bottle up, then 50 hit points back.
func try_drink() -> bool:
	if not can_act() or rum_left <= 0 or rum_cool > 0.0 or hp >= hp_max:
		return false
	lower_block()
	aiming = false
	rum_left -= 1
	rum_cool = DeckData.RUM_COOLDOWN_S
	state = State.DRINK
	state_t = 0.0
	return true


func is_alive() -> bool:
	return state != State.DEAD


func is_standing() -> bool:
	return state != State.DEAD and state != State.DOWN


func can_act() -> bool:
	return (state == State.IDLE or state == State.BLOCK) and stun_left <= 0.0


func invulnerable() -> bool:
	return state == State.DODGE and state_t < DeckData.DODGE_INVULN_S


func move_factor() -> float:
	match state:
		State.IDLE:
			return DeckData.AIM_MOVE_FACTOR if aiming or aim_lock_left > 0.0 else 1.0
		State.DRINK:
			return 0.3
		State.BLOCK:
			return DeckData.BLOCK_MOVE_FACTOR
		State.SWING:
			return DeckData.SWING_MOVE_FACTOR
	return 0.0


## Advance timers by dt. `now` is the fight clock, used for block timing.
func tick(dt: float, _now: float) -> void:
	if state == State.DEAD:
		return
	rum_cool = maxf(rum_cool - dt, 0.0)
	aim_lock_left = maxf(aim_lock_left - dt, 0.0)
	aim_hold_t = aim_hold_t + dt if aiming else 0.0
	if not block_up:
		stamina = minf(stamina + DeckData.STAMINA_REGEN_PER_S * dt, stamina_max)
	if stun_left > 0.0:
		stun_left -= dt
	aim_left = maxf(aim_left - dt, 0.0)
	if reload_left > 0.0:
		reload_left -= dt
		if reload_left <= 0.0 and charges < _brace() and ranged_ammo > charges:
			charges += 1
			if charges < _brace() and ranged_ammo > charges:
				reload_left = reload_time()
	match state:
		State.SWING:
			state_t += dt
			if not swing_struck and state_t >= swing_dur * DeckData.STRIKE_POINT:
				swing_struck = true
				strike_pending = true
			if state_t >= swing_dur:
				state = State.IDLE
				state_t = 0.0
				combo_left = DeckData.COMBO_WINDOW_S
		State.STAGGER:
			stagger_left -= dt
			if stagger_left <= 0.0:
				state = State.IDLE
				state_t = 0.0
		State.DODGE:
			state_t += dt
			if state_t >= DeckData.DODGE_TIME_S:
				state = State.IDLE
				state_t = 0.0
		State.KICK:
			state_t += dt
			if not kick_done and state_t >= DeckData.KICK_TIME_S * 0.5:
				kick_done = true
				kick_pending = true
			if state_t >= DeckData.KICK_TIME_S:
				state = State.IDLE
				state_t = 0.0
		State.BLOCK:
			state_t += dt
		State.DRINK:
			state_t += dt
			if state_t >= DeckData.RUM_DRINK_S:
				hp = minf(hp + DeckData.RUM_HEAL, hp_max)
				rum_drunk += 1
				state = State.IDLE
				state_t = 0.0
		State.IDLE:
			if combo_left > 0.0:
				combo_left -= dt
				if combo_left <= 0.0:
					combo = 0


func _brace() -> int:
	return DeckData.PISTOL_BRACE if ranged == "flintlock" else 1


func reload_time() -> float:
	return float(WeaponData.WEAPONS[ranged]["reload"]) * pistol_reload_mult if ranged != "" else 0.0


# ---- actions -----------------------------------------------------------------------------------

## Start a swing. A light swing begun inside the combo window continues the three-hit combo.
func try_swing(heavy: bool) -> bool:
	if not can_act() or melee == "":
		return false
	var cost: float = DeckData.ATTACK_STAMINA_HEAVY if heavy else DeckData.ATTACK_STAMINA_LIGHT
	if stamina < cost:
		return false
	stamina -= cost
	if block_up:
		block_up = false
	if heavy:
		combo = 0
	elif combo_left > 0.0:
		combo = mini(combo + 1, DeckData.COMBO_MULT.size() - 1)
	else:
		combo = 0
	swing_heavy = heavy
	swing_dur = DeckData.swing_time(melee, heavy) / maxf(morale_effic, 0.5) / sqrt(maxf(strength, 0.5))  # a better swordsman is quicker
	swing_struck = false
	strike_pending = false
	state = State.SWING
	state_t = 0.0
	combo_left = 0.0
	return true


func raise_block(now: float) -> bool:
	if state == State.BLOCK:
		return true
	if not can_act() or state != State.IDLE:
		return false
	state = State.BLOCK
	state_t = 0.0
	block_up = true
	block_started = now
	return true


func lower_block() -> void:
	if state == State.BLOCK:
		state = State.IDLE
		state_t = 0.0
	block_up = false


func try_dodge(direction: Vector2) -> bool:
	if not can_act() or stamina < DeckData.DODGE_STAMINA:
		return false
	stamina -= DeckData.DODGE_STAMINA
	block_up = false
	dodge_dir = direction.normalized() if direction.length() > 0.01 else -dir
	state = State.DODGE
	state_t = 0.0
	return true


func try_kick() -> bool:
	if not can_act() or stamina < DeckData.KICK_STAMINA:
		return false
	stamina -= DeckData.KICK_STAMINA
	block_up = false
	state = State.KICK
	state_t = 0.0
	kick_pending = false
	kick_done = false
	return true


## Knocked off balance: cannot act for `seconds`; a swing in progress is lost.
func stagger(seconds: float) -> void:
	if state == State.DEAD or state == State.DOWN:
		return
	var carried: float = stagger_left if state == State.STAGGER else 0.0
	block_up = false
	aim_fire_pending = false
	aim_lock_left = 0.0
	swing_struck = true
	strike_pending = false
	state = State.STAGGER
	stagger_left = maxf(carried, seconds)
	state_t = 0.0


func can_fire() -> bool:
	return ranged != "" and charges > 0 and ranged_ammo > 0 and aim_left <= 0.0 and can_act()


## An AI man levels his gun along `direction` and fires when the lock runs out (DeckCombat does the firing).
func begin_aim(direction: Vector2) -> void:
	aim_dir = direction.normalized() if direction.length() > 0.001 else dir
	dir = aim_dir
	aim_lock_left = DeckData.AI_AIM_LOCK_S
	aim_fire_pending = true
	lower_block()


## Result of a fighter taking a melee blow. `att` may be null for traps. Returns
## {result: dodged | parried | blocked | guard_broken | hit | none, damage, killed}.
func receive_melee(att: FighterState, damage: float, heavy: bool, breaks_block: bool, now: float, attacker_weapon: String = "") -> Dictionary:
	if state == State.DEAD:
		return {"result": "none", "damage": 0.0, "killed": false}
	if invulnerable():
		return {"result": "dodged", "damage": 0.0, "killed": false}
	var from: Vector2 = (att.pos - pos) if att != null else dir
	var in_front: bool = from.length() < 0.001 or rad_to_deg(dir.angle_to(from)) <= DeckData.BLOCK_ARC_DEG * 0.5 and rad_to_deg(dir.angle_to(from)) >= -DeckData.BLOCK_ARC_DEG * 0.5
	var dmg: float = damage
	var result: String = "hit"
	if block_up and in_front and att != null:
		var window: float = DeckData.parry_window(melee) * parry_mult
		if now - block_started <= window:
			att.stagger(DeckData.PARRY_STAGGER_S)
			att.vulnerable = DeckData.PARRY_NEXT_HIT_MULT
			parries += 1
			return {"result": "parried", "damage": 0.0, "killed": false}
		if breaks_block:
			result = "guard_broken"
			stagger(DeckData.GUARD_BREAK_STAGGER_S)
		else:
			var drain: float = dmg * DeckData.BLOCK_STAMINA_PER_DAMAGE
			if stamina >= drain:
				stamina -= drain
				dmg *= 1.0 - DeckData.BLOCK_REDUCTION
				result = "blocked"
			else:
				stamina = 0.0
				dmg *= 0.5
				result = "guard_broken"
				stagger(DeckData.GUARD_BREAK_STAGGER_S)
	if front_armor and in_front and att != null and result == "hit":
		dmg *= 1.0 - DeckData.BRUTE_FRONT_REDUCTION
	if vulnerable > 1.0:
		dmg *= vulnerable
		vulnerable = 1.0
	return _apply_damage(dmg, att, result, heavy)


## Damage that skips blocking (a keg, a net, a grenade, a bullet).
func receive_raw(damage: float, att: FighterState = null) -> Dictionary:
	if state == State.DEAD or invulnerable():
		return {"result": "none" if state == State.DEAD else "dodged", "damage": 0.0, "killed": false}
	return _apply_damage(damage, att, "hit", true)


func _apply_damage(dmg: float, att: FighterState, result: String, heavy: bool) -> Dictionary:
	hp -= dmg
	damage_taken += dmg
	if att != null:
		att.damage_dealt += dmg
		last_hit_by = att.id
	if hp <= 0.0:
		hp = 0.0
		state = State.DOWN if is_player else State.DEAD
		block_up = false
		swing_struck = true
		strike_pending = false
		return {"result": result, "damage": dmg, "killed": true}
	if (state == State.SWING and not swing_struck or state == State.DRINK) and (dmg >= DeckData.HIT_INTERRUPT_DAMAGE or heavy):
		stagger(0.35)  # a blow knocks the swing, or the bottle, out of his hands
	return {"result": result, "damage": dmg, "killed": false}
