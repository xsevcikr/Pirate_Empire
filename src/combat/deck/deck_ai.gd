class_name DeckAI
extends RefCounted
## Decisions for every fighter the player does not control: the enemy, and the crew following squad commands.

static func think(c: DeckCombat, f: FighterState, dt: float) -> void:
	f.think_left -= dt
	if f.think_left > 0.0:
		_maintain(c, f)
		return
	f.think_left = DeckData.AI_THINK_S + float(f.id % 5) * 0.01
	f.move_intent = Vector2.ZERO
	if not f.can_act() and f.state != FighterState.State.STAGGER:
		return
	var morale: float = c.morale[f.team]
	# Men who panic run for their rail and drop their guard.
	if f.panics and morale < DeckData.PANIC_MORALE and not _officer_rallying(c, f):
		f.lower_block()
		f.move_intent = Vector2(-1.0 if f.team == 0 else 1.0, 0.0)
		return
	if f.team == 0:
		_crew_think(c, f)
	else:
		_enemy_think(c, f)


## Keep walking toward the last decision between thinks.
static func _maintain(c: DeckCombat, f: FighterState) -> void:
	var t: FighterState = c.by_id(f.target_id)
	if t != null and not t.is_standing():
		f.think_left = 0.0


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
	# in reach
	if t.state == FighterState.State.SWING and not t.swing_struck:
		var time_to_hit: float = t.swing_dur * DeckData.STRIKE_POINT - t.state_t
		if time_to_hit < 0.35 and time_to_hit > 0.0:
			if c.rng.randf() < f.block_skill:
				if f.raise_block(c.time_s) and c.rng.randf() >= f.parry_skill:
					f.block_started = c.time_s - DeckData.PARRY_WINDOW_S * 1.5  # a plain block, not timed
				return
	if f.state == FighterState.State.BLOCK and (t.state != FighterState.State.SWING or t.swing_struck):
		f.lower_block()
	if f.can_act() and f.state == FighterState.State.IDLE:
		var swung: bool = false
		if t.stagger_left > 0.0 or t.stun_left > 0.0:
			swung = f.try_swing(true if c.rng.randf() < 0.5 else false)
		elif c.rng.randf() < 0.55 * aggression:
			swung = f.try_swing(c.rng.randf() < 0.2 + f.heavy_bias)
		if swung:  # a man catches his breath between exchanges
			f.think_left = c.rng.randf_range(DeckData.AI_ATTACK_PAUSE_S[0], DeckData.AI_ATTACK_PAUSE_S[1]) / maxf(aggression, 0.3)


static func _shoot(c: DeckCombat, f: FighterState, t: FighterState) -> void:
	if f.can_fire():
		c.fire_ranged(f, t.pos - f.pos)
		f.aim_left = c.rng.randf_range(DeckData.AI_AIM_S[0], DeckData.AI_AIM_S[1])
