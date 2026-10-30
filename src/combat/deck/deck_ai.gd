class_name DeckAI
extends RefCounted
## Decisions for every fighter the player does not control: the enemy, and the crew following squad commands.

static func think(c: DeckCombat, f: FighterState, dt: float) -> void:
	_react(c, f)
	f.think_left -= dt
	if f.think_left > 0.0:
		_maintain(c, f)
		return
	f.think_left = DeckData.AI_THINK_S + float(f.id % 5) * 0.01
	f.move_intent = Vector2.ZERO
	if not f.can_act() and f.state != FighterState.State.STAGGER:
		return
	if f.aim_lock_left > 0.0:  # stands still with the gun levelled until the shot goes
		return
	var morale: float = c.morale[f.team]
	# Men who panic run for their rail and drop their guard.
	if f.panics and morale < DeckData.PANIC_MORALE and not _officer_rallying(c, f):
		f.lower_block()
		f.move_intent = Vector2(-1.0 if f.team == 0 else 1.0, 0.0)
		return
	if _dodge_danger(c, f):
		return
	if f.team == 0 and f.job != DeckData.Job.NONE:
		_job_think(c, f)
	elif f.team == 0:
		_crew_think(c, f)
	else:
		_enemy_think(c, f)


## Keep walking toward the last decision between thinks.
static func _maintain(c: DeckCombat, f: FighterState) -> void:
	var t: FighterState = c.by_id(f.target_id)
	if t != null and not t.is_standing():
		f.think_left = 0.0


## Every frame, whatever he is busy with: a man who sees a blow about to land on him decides once how to meet it,
## by his skill: step out of a heavy one, raise his guard (on time, a parry), or take it. When the blow is spent he
## drops his guard and answers at once.
static func _react(c: DeckCombat, f: FighterState) -> void:
	var incoming: bool = false
	for o in c.fighters:
		if o.team == f.team or o.state != FighterState.State.SWING or (o.swing_struck and not o.strike_pending):
			continue
		if o.pos.distance_to(f.pos) > DeckData.MELEE_RANGE_M + 0.4 or not c._in_arc(o, f.pos, DeckData.MELEE_RANGE_M + 0.4, DeckData.MELEE_ARC_DEG):
			continue
		incoming = true
		var time_to_hit: float = o.swing_dur * DeckData.STRIKE_POINT - o.state_t
		var key: int = o.id * 100000 + o.swing_serial
		if time_to_hit > DeckData.AI_REACT_S or f.reacted_key == key:
			continue
		f.reacted_key = key
		if f.state == FighterState.State.BLOCK:
			continue
		if o.swing_heavy and f.stamina >= DeckData.DODGE_STAMINA + 10.0 and c.rng.randf() < DeckData.AI_DODGE_CHANCE * (0.5 + f.block_skill):
			if f.try_dodge((f.pos - o.pos).normalized()):
				continue
		if c.rng.randf() < f.block_skill and f.raise_block(c.time_s):
			if c.rng.randf() >= f.parry_skill:
				f.block_started = c.time_s - DeckData.PARRY_WINDOW_S * 2.0  # a plain block, not a timed parry
			else:
				f.block_started = c.time_s + maxf(time_to_hit - DeckData.PARRY_WINDOW_S * 0.5, 0.0)  # timed to meet it
	if not incoming and f.state == FighterState.State.BLOCK and f.state_t > 0.15:
		f.lower_block()
		f.think_left = minf(f.think_left, 0.05)  # the riposte


## A man who sees a gun levelled at him may throw himself aside.
static func _dodge_danger(c: DeckCombat, f: FighterState) -> bool:
	if f.stamina < DeckData.DODGE_STAMINA + 10.0 or not f.can_act():
		return false
	for o in c.fighters:
		if o.team == f.team or not o.is_standing():
			continue
		var to_me: Vector2 = f.pos - o.pos
		var dist: float = to_me.length()
		var levelled: bool = (o.aim_lock_left > 0.0 and o.aim_lock_left < 0.5) or (o.is_player and o.aiming and o.aim_hold_t > 0.25)
		var aim: Vector2 = o.aim_dir if not o.is_player else o.dir
		if levelled and dist > 2.0 and dist < 20.0 and absf(rad_to_deg(aim.angle_to(to_me))) < 6.0:
			if c.rng.randf() < DeckData.AI_DODGE_CHANCE * 0.3:
				var side: Vector2 = to_me.orthogonal().normalized() * (1.0 if c.rng.randf() < 0.5 else -1.0)
				return f.try_dodge(side)
	return false


## A hand on a job walks to it and works, fighting only a man who comes right up to him.
static func _job_think(c: DeckCombat, f: FighterState) -> void:
	var near: FighterState = c.nearest_enemy(f)
	if near != null and near.pos.distance_to(f.pos) < 1.8:
		_fight(c, f, near, f.morale_effic)
		return
	f.lower_block()
	var to_spot: Vector2 = f.job_spot - f.pos
	if to_spot.length() > DeckData.AT_JOB_M * 0.6:
		f.move_intent = to_spot.normalized()
		f.dir = f.move_intent
	elif f.job == DeckData.Job.CANNON:
		f.dir = (DeckData.CANNON_POS - f.pos).normalized() if f.pos.distance_to(DeckData.CANNON_POS) > 0.05 else Vector2.RIGHT
	else:
		f.dir = Vector2.LEFT  # over the rail, at the hull


static func _officer_rallying(c: DeckCombat, f: FighterState) -> bool:
	for o in c.fighters:
		if o.team == f.team and o.rallies and o.is_standing() and o.pos.distance_to(f.pos) < 6.0:
			return true
	return false


static func _enemy_think(c: DeckCombat, f: FighterState) -> void:
	var target: FighterState = _pick_target(c, f)
	if target == null:
		return
	_fight(c, f, target, 1.0)


static func _crew_think(c: DeckCombat, f: FighterState) -> void:
	var press: float = f.morale_effic  # 0.75 to 1.1: how hard the men press
	match c.command:
		DeckData.Command.FALL_BACK:
			f.lower_block()
			var rail_x: float = -(DeckData.DECK_HALF_WIDTH_M - DeckData.RAIL_OFFSET_M)
			var to_rail: Vector2 = Vector2(rail_x, f.pos.y) - f.pos
			if to_rail.length() > 0.8:
				f.move_intent = to_rail.normalized()
			var adjacent: FighterState = c.nearest_enemy(f)
			if adjacent != null and adjacent.pos.distance_to(f.pos) < 1.8:
				_fight(c, f, adjacent, press * 0.6)
			return
		DeckData.Command.HOLD:
			var near: FighterState = c.nearest_enemy(f)
			if near != null and near.pos.distance_to(f.pos) < 3.0:
				_fight(c, f, near, press)
			else:
				var hold: Vector2 = Vector2(DeckData.HOLD_LINE_X, f.pos.y) - f.pos
				if hold.length() > 0.8:
					f.move_intent = hold.normalized()
				if near != null:
					f.dir = (near.pos - f.pos).normalized()
			if near != null and f.ranged != "" and near.pos.distance_to(f.pos) > 3.0:
				_shoot(c, f, near)
			return
		DeckData.Command.PROTECT:
			var around: FighterState = c.nearest_enemy(c.player)
			if c.player.is_standing() and f.pos.distance_to(c.player.pos) > DeckData.PROTECT_RADIUS_M:
				f.move_intent = (c.player.pos - f.pos).normalized()
				return
			if around != null and around.pos.distance_to(f.pos) < 4.0:
				_fight(c, f, around, press)
			return
		DeckData.Command.FOCUS_CAPTAIN:
			var boss: FighterState = _find_kind(c, "captain")
			if boss == null:
				boss = _find_kind(c, "officer")
			if boss != null:
				_fight(c, f, boss, press)
				return
	var target: FighterState = c.nearest_enemy(f)
	if target != null:
		_fight(c, f, target, press)


static func _find_kind(c: DeckCombat, kind: String) -> FighterState:
	for o in c.fighters:
		if o.team == 1 and o.kind == kind and o.is_standing():
			return o
	return null


static func _pick_target(c: DeckCombat, f: FighterState) -> FighterState:
	var best: FighterState = null
	var best_score: float = INF
	for o in c.fighters:
		if o.team == f.team or not o.is_standing():
			continue
		var d: float = o.pos.distance_to(f.pos)
		var score: float = d
		if o.is_player:
			score -= 1.5  # everyone wants the captain a little
		if f.kind == "brute":
			score -= 2.0 if o.kind == "crew" else 0.0
		if score < best_score:
			best_score = score
			best = o
	return best


## Approach, answer blows with blocks and parries, and strike.
static func _fight(c: DeckCombat, f: FighterState, t: FighterState, aggression: float) -> void:
	f.target_id = t.id
	var to_t: Vector2 = t.pos - f.pos
	var dist: float = to_t.length()
	if dist > 0.001:
		f.dir = to_t / dist
	if f.ranged != "" and f.can_fire() and dist > 4.0 and dist <= float(WeaponData.WEAPONS[f.ranged]["range"]):
		_shoot(c, f, t)
		return
	# a hurt captain who has a moment to himself takes a pull of rum
	if not f.is_player and f.rum_left > 0 and f.hp < f.hp_max * 0.35 and dist > 2.6:
		if f.try_drink():
			return
	var reach: float = DeckData.MELEE_RANGE_M * 0.85
	if dist > reach:
		var approach: Vector2 = to_t.normalized()
		if f.front_armor and t.is_standing():
			pass
		# a brute's target is easier to flank: circle a little
		f.move_intent = approach
		if f.ranged != "" and dist < 4.0 and f.charges > 0 and f.kind != "marine":
			f.move_intent = Vector2.ZERO
		return
	# in reach: blocking and parrying is _react's job, every frame
	if f.state == FighterState.State.BLOCK:
		return
	# a man who hides behind his guard gets a boot in it
	if t.state == FighterState.State.BLOCK and t.state_t > DeckData.AI_KICK_BLOCKER_S and dist < DeckData.KICK_RANGE_M and f.state == FighterState.State.IDLE:
		if c.rng.randf() < 0.5 * aggression and f.try_kick():
			f.think_left = c.rng.randf_range(DeckData.AI_ATTACK_PAUSE_S[0], DeckData.AI_ATTACK_PAUSE_S[1])
			return
	if f.can_act() and f.state == FighterState.State.IDLE:
		var swung: bool = false
		if t.stagger_left > 0.0 or t.stun_left > 0.0:
			swung = f.try_swing(true if c.rng.randf() < 0.5 else false)
		elif c.rng.randf() < 0.55 * aggression:
			swung = f.try_swing(c.rng.randf() < 0.2 + f.heavy_bias)
		if swung:  # a man catches his breath between exchanges
			f.think_left = c.rng.randf_range(DeckData.AI_ATTACK_PAUSE_S[0], DeckData.AI_ATTACK_PAUSE_S[1]) / maxf(aggression, 0.3)


## Level the gun at where the man stands now; the shot goes when the aim lock runs out, so he can still dodge it.
static func _shoot(c: DeckCombat, f: FighterState, t: FighterState) -> void:
	if f.can_fire() and f.aim_lock_left <= 0.0 and not f.aim_fire_pending:
		f.begin_aim(t.pos - f.pos)
		f.move_intent = Vector2.ZERO
		f.think_left = DeckData.AI_AIM_LOCK_S
