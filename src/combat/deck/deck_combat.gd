class_name DeckCombat
extends RefCounted
## The deck fight as a simulation: fighters, hits, blocks, parries, morale, reinforcements from the men who are
## not on screen (a BoardingSim keeps those fighting), and the end of the fight. No nodes; stepped with tick().

signal fighter_hit(attacker_id: int, target_id: int, info: Dictionary)
signal fighter_died(fighter: FighterState)
signal ranged_fired(shooter_id: int, from_pos: Vector2, to_pos: Vector2)
signal keg_exploded(at: Vector2)
signal cannon_fired(from_pos: Vector2, direction: Vector2)
signal deck_gun_ready
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
## Our deck gun: loaded by the hands sent to it, fired on the captain's order.
var cannon_loaded: bool = false
var cannon_load: float = 0.0  ## man-seconds of work done toward the next load
var hull_repaired: float = 0.0  ## hull hit points the repair party has patched on our own ship

var _next_id: int = 1
var _spawn_clock: Array[float] = [0.0, 0.0]


## `mine`: {level, melee, ranged, shots, hp, rum, crew: [{type, level, name, melee_mult?, nerve?, panics?, rallies?}], reserve, morale, effic}
## `theirs`: {fighters: [archetype or {kind, hp}], reserve, reserve_kind, morale}
func setup(mine: Dictionary, theirs: Dictionary, seed_value: int = 1) -> void:
	rng.seed = seed_value
	player = FighterState.make_player(int(mine.get("level", 1)), str(mine.get("melee", "rusty_cutlass")), str(mine.get("ranged", "flintlock")), int(mine.get("shots", 10)),
		float(mine.get("hp", -1.0)))
	player.rum_left = int(mine.get("rum", DeckData.RUM_PER_FIGHT))
	var sk: Dictionary = mine.get("skills", {})
	player.stamina_max += float(sk.get("stamina_add", 0.0))
	player.stamina = player.stamina_max
	player.melee_mult = float(sk.get("melee_damage_mult", 1.0))
	player.parry_mult = float(sk.get("parry_window_mult", 1.0))
	player.pistol_reload_mult = float(sk.get("pistol_reload_mult", 1.0))
	player.pos = Vector2(-4.5, 0.0)
	player.dir = Vector2.RIGHT
	_add(player)
	var crew: Array = mine.get("crew", [])
	var mine_total: int = 1
	var effic: float = float(mine.get("effic", 1.0))
	for i in mini(crew.size(), DeckData.MAX_ON_SCREEN - 1):
		var f: FighterState = FighterState.make_crew(str(crew[i]["type"]), int(crew[i].get("level", 1)))
		f.morale_effic = effic * float(crew[i].get("nerve", 1.0))
		f.melee_mult = float(crew[i].get("melee_mult", 1.0))
		f.panics = f.panics or bool(crew[i].get("panics", false))
		f.rallies = f.rallies or bool(crew[i].get("rallies", false))
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
	_run_jobs(dt)
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
		if f.aim_fire_pending and f.aim_lock_left <= 0.0:
			f.aim_fire_pending = false
			if f.is_standing() and fire_ranged(f, f.aim_dir) and not f.is_player:
				f.aim_left = rng.randf_range(DeckData.AI_AIM_S[0], DeckData.AI_AIM_S[1])  # his next shot is a while off


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
	var dmg: float = DeckData.swing_damage(att.melee, heavy)
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
	dmg *= att.melee_mult
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


## Fire the shooter's ranged weapon along `aim`. The ball flies along the aim, thrown off by the shooter's spread
## (wide from the hip, tight once the captain has held his aim), and hits the first enemy whose body is on its line.
## A blunderbuss sprays its cone instead. Returns true if a shot left the barrel.
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
	var pellets: int = int(w.get("pellets", 1))
	var dmg: float = DeckData.gun_damage(shooter.ranged)
	if pellets > 1:
		var cone: float = float(w.get("cone_deg", DeckData.RANGED_AIM_CONE_DEG))
		ranged_fired.emit(shooter.id, shooter.pos, shooter.pos + a * range_m)
		var spray: Array[FighterState] = []
		for o in fighters:
			if o.team != shooter.team and o.is_standing():
				var d: Vector2 = o.pos - shooter.pos
				if d.length() <= range_m and absf(rad_to_deg(a.angle_to(d))) <= cone * 0.5:
					spray.append(o)
		spray.sort_custom(func(x: FighterState, y: FighterState) -> bool: return x.pos.distance_squared_to(shooter.pos) < y.pos.distance_squared_to(shooter.pos))
		for t in spray.slice(0, 3):
			var res: Dictionary = t.receive_raw(dmg * (1.0 - DeckData.COVER_RANGED_REDUCTION if covered(shooter.pos, t.pos) else 1.0), shooter)
			if t.is_standing():
				t.pos += (t.pos - shooter.pos).normalized() * 1.0  # blunderbuss knockback
			_after_hit(shooter, t, res)
		return true
	var shot: Vector2 = a.rotated(deg_to_rad(rng.randfn(0.0, shooter.shot_spread_deg())))
	var tgt: FighterState = null
	var best_t: float = range_m
	for o in fighters:
		if o.team == shooter.team or not o.is_standing():
			continue
		var along: float = (o.pos - shooter.pos).dot(shot)
		if along <= 0.0 or along >= best_t:
			continue
		if (shooter.pos + shot * along).distance_to(o.pos) <= DeckData.BULLET_RADIUS_M:
			best_t = along
			tgt = o
	var end: Vector2 = shooter.pos + shot * best_t
	for k in kegs:
		if k["alive"] and _segment_hits_circle(shooter.pos, end, k["pos"], 0.6):
			ranged_fired.emit(shooter.id, shooter.pos, k["pos"])
			_explode_keg(k, shooter)
			return true
	ranged_fired.emit(shooter.id, shooter.pos, end)
	if tgt == null:
		return true
	if covered(shooter.pos, tgt.pos):
		dmg *= 1.0 - DeckData.COVER_RANGED_REDUCTION
	_after_hit(shooter, tgt, tgt.receive_raw(dmg, shooter))
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


# ---- orders: the deck gun and the repair party -------------------------------------------------

## Send two hands to load our deck gun. False when it is already loaded or no one is free to go.
func order_load_cannon() -> bool:
	if cannon_loaded:
		return false
	var have: int = _on_job(DeckData.Job.CANNON).size()
	var sent: Array[FighterState] = _free_hands(DeckData.CANNON_CREW - have, "gunner")
	for i in sent.size():
		sent[i].job = DeckData.Job.CANNON
	_place_job(DeckData.Job.CANNON)
	return have + sent.size() > 0


## Fire the loaded deck gun at the thickest knot of the enemy. Returns how many men the grapeshot hit, or -1 when
## the gun is not loaded or nobody is standing at it.
func order_fire_cannon() -> int:
	var crew: Array[FighterState] = _on_job(DeckData.Job.CANNON)
	var at_gun: bool = false
	for f in crew:
		if f.pos.distance_to(f.job_spot) <= DeckData.AT_JOB_M * 1.5:
			at_gun = true
	if not cannon_loaded or not at_gun:
		return -1
	cannon_loaded = false
	cannon_load = 0.0
	var from: Vector2 = DeckData.CANNON_POS
	var aim: Vector2 = _best_cannon_aim(from)
	cannon_fired.emit(from, aim)
	var hit: Array[FighterState] = []
	for o in fighters:
		if o.team == 1 and o.is_standing() and _in_cone(from, aim, o.pos):
			hit.append(o)
	hit.sort_custom(func(x: FighterState, y: FighterState) -> bool: return x.pos.distance_squared_to(from) < y.pos.distance_squared_to(from))
	hit = hit.slice(0, DeckData.CANNON_MAX_HITS)
	for t in hit:
		var dmg: float = DeckData.GUN_DAMAGE * (1.0 - DeckData.COVER_RANGED_REDUCTION if covered(from, t.pos) else 1.0)
		_after_hit(player, t, t.receive_raw(dmg, player))
		if t.is_standing():
			t.stagger(DeckData.KICK_STAGGER_S)
	for k in kegs:
		if k["alive"] and _in_cone(from, aim, k["pos"]):
			_explode_keg(k, player)
	for f in crew:
		f.job = DeckData.Job.NONE
	return hit.size()


## Toggle the repair party: two hands (a carpenter first) go to our rail and patch the hull while the fight goes on.
## Returns true when a party was sent, false when it was called back (or nobody could go).
func order_repair() -> bool:
	var party: Array[FighterState] = _on_job(DeckData.Job.REPAIR)
	if not party.is_empty():
		for f in party:
			f.job = DeckData.Job.NONE
		return false
	var sent: Array[FighterState] = _free_hands(DeckData.REPAIR_CREW, "carpenter")
	for f in sent:
		f.job = DeckData.Job.REPAIR
	_place_job(DeckData.Job.REPAIR)
	return not sent.is_empty()


func _on_job(job: DeckData.Job) -> Array[FighterState]:
	var out: Array[FighterState] = []
	for f in fighters:
		if f.team == 0 and not f.is_player and f.is_standing() and f.job == job:
			out.append(f)
	return out


## Up to `n` hands with no job, men of `prefer` type first, then whoever is nearest our rail.
func _free_hands(n: int, prefer: String) -> Array[FighterState]:
	var pool: Array[FighterState] = _on_job(DeckData.Job.NONE)
	pool.sort_custom(func(x: FighterState, y: FighterState) -> bool:
		if (x.crew_type == prefer) != (y.crew_type == prefer):
			return x.crew_type == prefer
		return x.pos.x < y.pos.x)
	return pool.slice(0, maxi(n, 0))


func _place_job(job: DeckData.Job) -> void:
	var crew: Array[FighterState] = _on_job(job)
	for i in crew.size():
		if job == DeckData.Job.CANNON:
			crew[i].job_spot = DeckData.CANNON_POS + Vector2(-0.6, -0.9 if i % 2 == 0 else 0.9)
		else:
			crew[i].job_spot = Vector2(DeckData.REPAIR_SPOT_X, 5.0 + 1.2 * float(i))


func _run_jobs(dt: float) -> void:
	for f in fighters:
		if f.team != 0 or f.is_player or not f.is_standing() or f.job == DeckData.Job.NONE:
			continue
		if f.pos.distance_to(f.job_spot) > DeckData.AT_JOB_M or f.state != FighterState.State.IDLE:
			continue
		if f.job == DeckData.Job.CANNON and not cannon_loaded:
			cannon_load += dt
			if cannon_load >= DeckData.CANNON_LOAD_MAN_S:
				cannon_loaded = true
				deck_gun_ready.emit()
		elif f.job == DeckData.Job.REPAIR:
			hull_repaired += DeckData.REPAIR_HP_PER_MAN_S * dt


func _in_cone(from: Vector2, aim: Vector2, at: Vector2) -> bool:
	var d: Vector2 = at - from
	return d.length() <= DeckData.CANNON_RANGE_M and absf(rad_to_deg(aim.angle_to(d))) <= DeckData.CANNON_CONE_DEG * 0.5


## The bearing from `from` that puts the most standing enemies inside the grapeshot cone.
func _best_cannon_aim(from: Vector2) -> Vector2:
	var best: Vector2 = Vector2.RIGHT
	var best_n: int = -1
	for o in fighters:
		if o.team != 1 or not o.is_standing():
			continue
		var aim: Vector2 = (o.pos - from).normalized()
		var n: int = 0
		for p in fighters:
			if p.team == 1 and p.is_standing() and _in_cone(from, aim, p.pos):
				n += 1
		if n > best_n:
			best_n = n
			best = aim
	return best


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
	elif time_s >= DeckData.FIGHT_TIME_LIMIT_S:
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
		"captain_dead_enemy": _enemy_captain_dead(), "captain_hp": player.hp, "rum_drunk": player.rum_drunk,
		"hull_repaired": hull_repaired,
	}


func _enemy_captain_dead() -> bool:
	for f in fighters:
		if f.kind == "captain" and f.team == 1:
			return not f.is_alive()
	return false
