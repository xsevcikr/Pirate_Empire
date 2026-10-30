class_name DeckCombat
extends RefCounted
## The deck fight as a simulation: fighters, hits, blocks, parries, morale, reinforcements from the men who are
## not on screen (a BoardingSim keeps those fighting), and the end of the fight. No nodes; stepped with tick().

signal fighter_hit(attacker_id: int, target_id: int, info: Dictionary)
signal fighter_died(fighter: FighterState)
signal ranged_fired(shooter_id: int, from_pos: Vector2, to_pos: Vector2)
signal keg_exploded(at: Vector2)
signal finished(result: Dictionary)

enum Outcome { ONGOING, PLAYER_WINS, ENEMY_WINS }

var fighters: Array[FighterState] = []
var player: FighterState
var time_s: float = 0.0
var outcome: Outcome = Outcome.ONGOING
var surrendered: bool = false
var timed_out: bool = false
var morale: Array[float] = [70.0, 70.0]
var sim: BoardingSim
var rng := RandomNumberGenerator.new()
var covers: Array[Dictionary] = []  ## {pos: Vector2, radius: float}
var kegs: Array[Dictionary] = []  ## {pos: Vector2, alive: bool}
var ropes: Array[Dictionary] = []  ## {pos: Vector2, kind: "net"|"swing", drop: Vector2, used: bool}
var grenades: Array[Dictionary] = []
var command: DeckData.Command = DeckData.Command.CHARGE
var player_kills: int = 0
var started_with: Array[int] = [0, 0]  ## men per side at the start, on screen and in reserve
var reserve_kind: Array[String] = ["green", "sailor"]

var _next_id: int = 1
var _spawn_clock: Array[float] = [0.0, 0.0]


## `mine`: {level, melee, ranged, shots, crew: [{type, level}], reserve, morale, effic}
## `theirs`: {fighters: [archetype or {kind, hp}], reserve, reserve_kind, morale}
func setup(mine: Dictionary, theirs: Dictionary, seed_value: int = 1) -> void:
	rng.seed = seed_value
	player = FighterState.make_player(int(mine.get("level", 1)), str(mine.get("melee", "rusty_cutlass")), str(mine.get("ranged", "flintlock")), int(mine.get("shots", 10)))
	player.pos = Vector2(-4.5, 0.0)
	player.dir = Vector2.RIGHT
	_add(player)
	var crew: Array = mine.get("crew", [])
	var mine_total: int = 1
	var effic: float = float(mine.get("effic", 1.0))
	for i in mini(crew.size(), DeckData.MAX_ON_SCREEN - 1):
		var f: FighterState = FighterState.make_crew(str(crew[i]["type"]), int(crew[i].get("level", 1)))
		f.morale_effic = effic
		f.display_name = str(crew[i].get("name", "Hand"))
		f.pos = _slot(0, i, mini(crew.size(), DeckData.MAX_ON_SCREEN - 1))
		f.dir = Vector2.RIGHT
		_add(f)
	var their_list: Array = theirs.get("fighters", [])
	for i in mini(their_list.size(), DeckData.MAX_ON_SCREEN):
		var spec: Variant = their_list[i]
		var kind: String = str(spec) if not (spec is Dictionary) else str(spec["kind"])
		var hp: float = -1.0 if not (spec is Dictionary) else float(spec.get("hp", -1.0))
		var e: FighterState = FighterState.make_enemy(kind, hp)
		e.pos = _slot(1, i, mini(their_list.size(), DeckData.MAX_ON_SCREEN))
		e.aim_left = rng.randf_range(DeckData.AI_AIM_S[0], DeckData.AI_AIM_S[1])
		_add(e)
	reserve_kind[1] = str(theirs.get("reserve_kind", "sailor"))
	var r0: int = int(mine.get("reserve", 0))
	var r1: int = int(theirs.get("reserve", 0))
	sim = BoardingSim.new(BoardingSide.new(r0, 1.0, 70.0), BoardingSide.new(r1, 0.8, 70.0), seed_value)
	morale[0] = float(mine.get("morale", 70.0))
	morale[1] = float(theirs.get("morale", 70.0))
	started_with[0] = crew.size() + 1 + r0
	started_with[1] = their_list.size() + r1
	if not covers.is_empty() or not kegs.is_empty():
		return
	_default_props()


## Cover and props every deck has: masts, crates, a cannon and a powder keg or two, and a rope to swing on.
func _default_props() -> void:
	covers = [
		{"pos": Vector2(-0.8, -4.0), "radius": 0.7},  # mainmast
		{"pos": Vector2(-0.8, 4.0), "radius": 0.7},  # foremast
		{"pos": Vector2(-5.5, 6.5), "radius": 0.8},  # our crates
		{"pos": Vector2(5.5, -6.5), "radius": 0.8},  # their crates
		{"pos": Vector2(2.5, 0.5), "radius": 0.9},  # a cannon
	]
	kegs = [{"pos": Vector2(3.5, 6.0), "alive": true}, {"pos": Vector2(-3.5, -6.0), "alive": true}]
	ropes = [
		{"pos": Vector2(-3.0, 1.5), "kind": "swing", "drop": Vector2.ZERO, "used": false},
		{"pos": Vector2(-1.5, -2.5), "kind": "net", "drop": Vector2(3.0, -2.0), "used": false},
	]


func _slot(team: int, index: int, count: int) -> Vector2:
	var rows: int = 4
	var col: int = floori(float(index) / float(rows))
	var row: int = index % rows
	var x: float = (-2.8 - 1.4 * float(col)) if team == 0 else (2.8 + 1.4 * float(col))
	var span: float = DeckData.DECK_HALF_LENGTH_M * 1.2
	var y: float = lerpf(-span * 0.5, span * 0.5, (float(row) + 0.5) / float(rows)) + (0.4 if col % 2 == 1 else 0.0)
	return Vector2(x, y)


func _add(f: FighterState) -> void:
	f.id = _next_id
	_next_id += 1
	fighters.append(f)


func by_id(id: int) -> FighterState:
	for f in fighters:
		if f.id == id:
			return f
	return null


## Living fighters on screen (the captain lying down still counts as alive here).
func alive_on_screen(team: int) -> int:
	var n: int = 0
	for f in fighters:
		if f.team == team and f.is_alive():
			n += 1
	return n


func standing_on_screen(team: int) -> int:
	var n: int = 0
	for f in fighters:
		if f.team == team and f.is_standing():
			n += 1
	return n


func reserve_of(team: int) -> int:
	var pool: float = sim.attacker.pool if team == 0 else sim.defender.pool
	return maxi(int(round(pool)), 0)


func enemies_of(f: FighterState) -> Array[FighterState]:
	var out: Array[FighterState] = []
	for o in fighters:
		if o.team != f.team and o.is_standing():
			out.append(o)
	return out


func nearest_enemy(f: FighterState) -> FighterState:
	var best: FighterState = null
	var best_d: float = INF
	for o in fighters:
		if o.team != f.team and o.is_standing():
			var d: float = o.pos.distance_squared_to(f.pos)
			if d < best_d:
				best_d = d
				best = o
	return best


# ---- stepping ----------------------------------------------------------------------------------

func tick(dt: float) -> void:
	if outcome != Outcome.ONGOING:
		return
	time_s += dt
	for f in fighters:
		f.tick(dt, time_s)
	for f in fighters:
		if f.is_standing() and not f.is_player:
			DeckAI.think(self, f, dt)
	_move_all(dt)
	_resolve_pending()
	_update_grenades(dt)
	_run_reserves(dt)
	_check_end()


func _move_all(dt: float) -> void:
	var bound_x: float = DeckData.DECK_HALF_WIDTH_M - DeckData.RAIL_OFFSET_M
	var bound_y: float = DeckData.DECK_HALF_LENGTH_M - 0.5
	for f in fighters:
		if not f.is_standing():
			continue
		var v := Vector2.ZERO
		if f.state == FighterState.State.DODGE:
			v = f.dodge_dir * (DeckData.DODGE_DISTANCE_M / DeckData.DODGE_TIME_S)
		elif f.stun_left <= 0.0:
			v = f.move_intent * f.move_speed * f.move_factor()
		f.pos += v * dt
		f.pos.x = clampf(f.pos.x, -bound_x, bound_x)
		f.pos.y = clampf(f.pos.y, -bound_y, bound_y)
	var min_d: float = DeckData.BODY_RADIUS_M * 2.0
	for i in fighters.size():
		var a: FighterState = fighters[i]
		if not a.is_standing():
			continue
		for j in range(i + 1, fighters.size()):
			var b: FighterState = fighters[j]
			if not b.is_standing():
				continue
			var d: Vector2 = b.pos - a.pos
			var len: float = d.length()
			if len < min_d and len > 0.0001:
				var push: Vector2 = d / len * (min_d - len) * 0.5
				a.pos -= push
				b.pos += push
			elif len <= 0.0001:
				b.pos += Vector2(0.01, 0.0)


func _resolve_pending() -> void:
	for f in fighters:
		if f.strike_pending:
			f.strike_pending = false
			_melee_strike(f)
		if f.kick_pending:
			f.kick_pending = false
			_kick(f)


func _in_arc(from_f: FighterState, to_pos: Vector2, range_m: float, arc_deg: float) -> bool:
	var d: Vector2 = to_pos - from_f.pos
	var len: float = d.length()
	if len > range_m:
		return false
	if len < 0.001:
		return true
	return absf(rad_to_deg(from_f.dir.angle_to(d))) <= arc_deg * 0.5


func _melee_strike(att: FighterState) -> void:
	var weapon: Dictionary = WeaponData.WEAPONS[att.melee]
	var heavy: bool = att.swing_heavy
	var dmg: float = DeckData.swing_damage(att.melee, heavy) * att.strength
	if not heavy:
		dmg *= DeckData.COMBO_MULT[clampi(att.combo, 0, DeckData.COMBO_MULT.size() - 1)]
	var tgt: FighterState = null
	var best: float = INF
	for o in fighters:
		if o.team != att.team and o.is_standing() and _in_arc(att, o.pos, DeckData.MELEE_RANGE_M, DeckData.MELEE_ARC_DEG):
			var d: float = o.pos.distance_squared_to(att.pos)
			if d < best:
				best = d
				tgt = o
	if tgt == null:
		return
	if weapon.has("backstab"):
		var behind: float = absf(rad_to_deg(tgt.dir.angle_to(att.pos - tgt.pos)))
		if behind >= 180.0 - DeckData.BACKSTAB_ARC_DEG * 0.5:
			dmg *= float(weapon["backstab"])
	var breaks: bool = heavy and bool(weapon.get("breaks_block_heavy", false))
	var res: Dictionary = tgt.receive_melee(att, dmg, heavy, breaks, time_s)
	_after_hit(att, tgt, res)


func _kick(att: FighterState) -> void:
	var tgt: FighterState = null
	var best: float = INF
	for o in fighters:
		if o.team != att.team and o.is_standing() and _in_arc(att, o.pos, DeckData.KICK_RANGE_M, DeckData.MELEE_ARC_DEG):
			var d: float = o.pos.distance_squared_to(att.pos)
			if d < best:
				best = d
				tgt = o
	if tgt == null:
		return
	var res: Dictionary = tgt.receive_raw(DeckData.KICK_DAMAGE, att)
	res["result"] = "kicked"
	if tgt.is_standing():
		tgt.stagger(DeckData.GUARD_BREAK_STAGGER_S if tgt.block_up else DeckData.KICK_STAGGER_S)
		var away: Vector2 = (tgt.pos - att.pos).normalized()
		tgt.pos += away * DeckData.KICK_PUSH_M
		var bound: float = DeckData.DECK_HALF_WIDTH_M
		if absf(tgt.pos.x) >= bound - DeckData.RAIL_OFFSET_M + 0.3 and absf(tgt.pos.x) > absf(att.pos.x):
			tgt.overboard = true
			tgt.hp = 0.0
			tgt.state = FighterState.State.DEAD if not tgt.is_player else FighterState.State.DOWN
			res["killed"] = true
			res["result"] = "overboard"
	_after_hit(att, tgt, res)


func _after_hit(att: FighterState, tgt: FighterState, res: Dictionary) -> void:
	fighter_hit.emit(att.id if att != null else -1, tgt.id, res)
	if res["killed"]:
		_on_death(tgt, att)


func _on_death(victim: FighterState, killer: FighterState) -> void:
	fighter_died.emit(victim)
	if killer != null:
		killer.kills += 1
		if killer.is_player:
			player_kills += 1
			if victim.team == 1:
				sim.player_kill(1)  # each man the captain cuts down is worth 3 of the abstract pool
	var count: float = float(maxi(started_with[victim.team], 1))
	morale[victim.team] = maxf(morale[victim.team] - DeckData.MORALE_PER_DEATH / count, 0.0)
	if victim.kind == "captain":
		morale[victim.team] *= 1.0 - BoardingSim.CAPTAIN_BREAK_MORALE_DROP


# ---- ranged, grenades, props --------------------------------------------------------------------

func _segment_hits_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	var t: float = 0.0 if len2 < 0.0001 else clampf((c - a).dot(ab) / len2, 0.0, 1.0)
	return (a + ab * t).distance_to(c) <= r


func covered(from_pos: Vector2, to_pos: Vector2) -> bool:
	for cv in covers:
		var c: Vector2 = cv["pos"]
		var r: float = cv["radius"]
		if from_pos.distance_to(c) <= r or to_pos.distance_to(c) <= r:
			continue
		if _segment_hits_circle(from_pos, to_pos, c, r):
			return true
	return false


## Fire the shooter's ranged weapon along `aim`. Returns true if a shot left the barrel.
func fire_ranged(shooter: FighterState, aim: Vector2) -> bool:
	if not shooter.can_fire():
		return false
	if shooter.state == FighterState.State.BLOCK:
		shooter.lower_block()
	var w: Dictionary = WeaponData.WEAPONS[shooter.ranged]
	var a: Vector2 = aim.normalized() if aim.length() > 0.001 else shooter.dir
	shooter.dir = a
	shooter.charges -= 1
	shooter.ranged_ammo -= 1
	if shooter.reload_left <= 0.0:
		shooter.reload_left = shooter.reload_time()
	var range_m: float = float(w["range"])
	var cone: float = float(w.get("cone_deg", DeckData.RANGED_AIM_CONE_DEG))
	var pellets: int = int(w.get("pellets", 1))
	var end: Vector2 = shooter.pos + a * range_m
	ranged_fired.emit(shooter.id, shooter.pos, end)
	for k in kegs:
		if k["alive"] and _segment_hits_circle(shooter.pos, end, k["pos"], 0.6):
			_explode_keg(k, shooter)
			break
	var candidates: Array[FighterState] = []
	for o in fighters:
		if o.team != shooter.team and o.is_standing():
			var d: Vector2 = o.pos - shooter.pos
			if d.length() <= range_m and absf(rad_to_deg(a.angle_to(d))) <= cone * 0.5:
				candidates.append(o)
	if candidates.is_empty():
		return true
	candidates.sort_custom(func(x: FighterState, y: FighterState) -> bool: return absf(a.angle_to(x.pos - shooter.pos)) < absf(a.angle_to(y.pos - shooter.pos)))
	var targets: Array[FighterState] = []
	if pellets > 1:
		targets.assign(candidates)
	else:
		targets.append(candidates[0])
	for t in targets:
		var dmg: float = float(w["damage"])
		if pellets > 1:
			dmg /= float(targets.size())  # the pellets spread over everyone in the cone
		if covered(shooter.pos, t.pos):
			dmg *= 1.0 - DeckData.COVER_RANGED_REDUCTION
		var res: Dictionary = t.receive_raw(dmg, shooter)
		if pellets > 1 and t.is_standing():
			t.pos += (t.pos - shooter.pos).normalized() * 1.0  # blunderbuss knockback
		_after_hit(shooter, t, res)
	return true


func _explode_keg(k: Dictionary, by: FighterState) -> void:
	if not k["alive"]:
		return
	k["alive"] = false
	keg_exploded.emit(k["pos"])
	for o in fighters.duplicate():
		if o.is_alive() and o.pos.distance_to(k["pos"]) <= DeckData.KEG_RADIUS_M:
			var res: Dictionary = o.receive_raw(DeckData.KEG_DAMAGE, by)
			_after_hit(by, o, res)
	for other in kegs:
		if other["alive"] and other["pos"].distance_to(k["pos"]) <= DeckData.KEG_RADIUS_M:
			_explode_keg(other, by)


func throw_grenade(thrower: FighterState, target: Vector2) -> void:
	grenades.append({"pos": target, "fuse": DeckData.GRENADE_FUSE_S, "thrower": thrower.id})


func _update_grenades(dt: float) -> void:
	for i in range(grenades.size() - 1, -1, -1):
		grenades[i]["fuse"] -= dt
		if grenades[i]["fuse"] <= 0.0:
			var g: Dictionary = grenades[i]
			grenades.remove_at(i)
			var thrower: FighterState = by_id(g["thrower"])
			for o in fighters.duplicate():
				if o.is_alive() and o.pos.distance_to(g["pos"]) <= DeckData.GRENADE_RADIUS_M:
					_after_hit(thrower, o, o.receive_raw(DeckData.GRENADE_DAMAGE, thrower))
			for k in kegs:
				if k["alive"] and k["pos"].distance_to(g["pos"]) <= DeckData.GRENADE_RADIUS_M:
					_explode_keg(k, thrower)


## Cut the rope nearest `f`: a net drops on the enemy, or the captain swings across for a drop attack.
func use_rope(f: FighterState) -> bool:
	for r in ropes:
		if r["used"] or r["pos"].distance_to(f.pos) > 2.0:
			continue
		r["used"] = true
		if r["kind"] == "net":
			for o in fighters.duplicate():
				if o.team != f.team and o.is_standing() and o.pos.distance_to(r["drop"]) <= DeckData.NET_RADIUS_M:
					var res: Dictionary = o.receive_raw(DeckData.NET_DAMAGE, f)
					o.stun_left = DeckData.NET_STUN_S
					_after_hit(f, o, res)
			return true
		var tgt: FighterState = null
		var best: float = DeckData.SWING_RANGE_M
		for o in fighters:
			if o.team != f.team and o.is_standing() and o.pos.distance_to(f.pos) <= best:
				best = o.pos.distance_to(f.pos)
				tgt = o
		if tgt == null:
			r["used"] = false
			return false
		f.pos = tgt.pos - (tgt.pos - f.pos).normalized() * 1.2
		f.dir = (tgt.pos - f.pos).normalized()
		var hit: Dictionary = tgt.receive_raw(DeckData.SWING_DAMAGE, f)
		if tgt.is_standing():
			tgt.stagger(DeckData.SWING_STAGGER_S)
		_after_hit(f, tgt, hit)
		return true
	return false


# ---- reserves, reinforcements, the end ---------------------------------------------------------

func _run_reserves(dt: float) -> void:
	if sim.outcome == BoardingSim.Outcome.ONGOING:
		sim.tick(dt)
	for team in 2:
		_spawn_clock[team] += dt
		if _spawn_clock[team] < DeckData.REINFORCE_DELAY_S or alive_on_screen(team) >= DeckData.MAX_ON_SCREEN:
			continue
		var pool: BoardingSide = sim.attacker if team == 0 else sim.defender
		if pool.pool < 1.0:
			continue
		pool.pool -= 1.0
		_spawn_clock[team] = 0.0
		var f: FighterState = FighterState.make_crew(reserve_kind[0]) if team == 0 else FighterState.make_enemy(reserve_kind[1])
		f.morale_effic = player.morale_effic if team == 0 else 1.0
		var rail: float = DeckData.DECK_HALF_WIDTH_M - DeckData.RAIL_OFFSET_M
		f.pos = Vector2(-rail if team == 0 else rail, rng.randf_range(-DeckData.DECK_HALF_LENGTH_M * 0.6, DeckData.DECK_HALF_LENGTH_M * 0.6))
		f.dir = Vector2.RIGHT if team == 0 else Vector2.LEFT
		_add(f)


func total_power(team: int) -> float:
	var p: float = float(reserve_of(team)) * DeckData.CREW_HP
	for f in fighters:
		if f.team == team and f.is_standing():
			p += f.hp * f.strength
	return p


func _check_end() -> void:
	var enemy_left: int = standing_on_screen(1) + reserve_of(1)
	var player_left: int = standing_on_screen(0) + reserve_of(0)
	if enemy_left == 0:
		_finish(Outcome.PLAYER_WINS)
	elif player_left == 0:
		_finish(Outcome.ENEMY_WINS)
	elif morale[1] < BoardingSim.MORALE_BREAK:
		surrendered = true
		_finish(Outcome.PLAYER_WINS)
	elif morale[0] < BoardingSim.MORALE_BREAK and player_left < enemy_left:
		surrendered = true
		_finish(Outcome.ENEMY_WINS)
	elif time_s >= BoardingSim.TIME_LIMIT_S:
		timed_out = true
		_finish(Outcome.PLAYER_WINS if total_power(0) >= total_power(1) else Outcome.ENEMY_WINS)


func _finish(o: Outcome) -> void:
	outcome = o
	finished.emit(result())


func result() -> Dictionary:
	var mine_left: int = reserve_of(0)
	for f in fighters:
		if f.team == 0 and f.is_standing() and not f.is_player:
			mine_left += 1
	return {
		"outcome": outcome, "player_won": outcome == Outcome.PLAYER_WINS, "surrendered": surrendered, "timed_out": timed_out,
		"crew_left": mine_left, "enemy_left": standing_on_screen(1) + reserve_of(1), "player_kills": player_kills,
		"parries": player.parries, "captain_down": player.state == FighterState.State.DOWN, "time_s": time_s,
		"captain_dead_enemy": _enemy_captain_dead(),
	}


func _enemy_captain_dead() -> bool:
	for f in fighters:
		if f.kind == "captain" and f.team == 1:
			return not f.is_alive()
	return false
