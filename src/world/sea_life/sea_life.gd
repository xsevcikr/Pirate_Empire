class_name SeaLife
extends Node3D
## The animals round the player's ship. All of them react to her:
## - a pod of dolphins comes to ride the bow wave while she is under way, leaping beside the stem, and circles her
##   when she lies still;
## - now and then a whale surfaces off to one side, blows, and dives with its tail up (at once if she comes close);
## - flying fish burst out of the water ahead of the bow and glide away from her;
## - seagulls circle over the masts (more of them near land), scatter when the guns fire and swoop at a fresh catch.
## Everything is a handful of shared low-poly meshes moved by hand; nothing here touches the game state.

const POD_SIZE: int = 5
const GULLS_MAX: int = 6
const GULLS_AT_SEA: int = 3
const COAST_M: float = 700.0  ## nearer than this to an island counts as near land (more gulls)
const SCHOOL_MAX: int = 7
const SPLASHES: int = 8
const DOLPHIN_RIDE_KN: float = 3.0  ## slower than this they circle instead of riding the bow
const WHALE_SHY_M: float = 45.0
const GULL_SIZE: float = 1.8  ## cartoon scale, so they read from the chase camera

var ship: Ship
var islands: Array = []  ## {pos: Vector2, radius: float}, for the gull count
var rng := RandomNumberGenerator.new()

# dolphins
var pod_state: String = "away"  ## away, coming, riding, leaving
var _pod: Array[Dictionary] = []
var _pod_timer: float = 6.0
var _pod_left: float = 0.0
var _pod_side: float = 1.0
# whale
var whale_state: String = "away"  ## away, swimming, diving
var _whale: Node3D
var _whale_timer: float = 25.0
var _whale_t: float = 0.0
var _whale_dir: Vector3 = Vector3.FORWARD
var _whale_cycles: int = 0
var _spout: CPUParticles3D
# flying fish
var _fish: Array[Dictionary] = []
var _school_timer: float = 5.0
# gulls
var _gulls: Array[Dictionary] = []
var _scatter: float = 0.0  ## 0 circling .. 1 scattered
var _scatter_left: float = 0.0
var _gull_sound: float = 12.0
var gulls_wanted: int = GULLS_AT_SEA
# splashes
var _splashes: Array[CPUParticles3D] = []
var _next_splash: int = 0
var _splash_sound: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	name = "SeaLife"
	rng.seed = 4242
	for i in POD_SIZE:
		var d := MeshInstance3D.new()
		d.mesh = SeaLifeArt.dolphin()
		d.visible = false
		d.set_meta("kind", "dolphin")
		add_child(d)
		_pod.append({"node": d, "jump_in": rng.randf_range(0.5, 3.0), "jump_t": -1.0, "jump_len": 1.0, "jump_h": 1.4,
			"slot": i, "pos": Vector3.ZERO, "dir": Vector3.FORWARD})
	_whale = MeshInstance3D.new()
	(_whale as MeshInstance3D).mesh = SeaLifeArt.whale()
	_whale.visible = false
	_whale.set_meta("kind", "whale")
	add_child(_whale)
	_spout = _make_burst(48, 1.7, Color(0.95, 0.97, 1.0), 0.28, Vector2(8.0, 12.0), 10.0)
	for i in SCHOOL_MAX:
		var f := MeshInstance3D.new()
		f.mesh = SeaLifeArt.flying_fish()
		f.set_meta("size", 1.6)
		f.visible = false
		f.set_meta("kind", "flying_fish")
		add_child(f)
		_fish.append({"node": f, "t": 0.0, "life": 0.0, "delay": 0.0, "from": Vector3.ZERO, "vel": Vector3.ZERO, "h": 1.5})
	for i in GULLS_MAX:
		_gulls.append(_make_gull(i))
	for i in SPLASHES:
		_splashes.append(_make_burst(14, 0.8, Color(0.92, 0.97, 1.0), 0.12, Vector2(2.5, 4.5), 40.0))
	if ship != null:
		ship.broadside.fired.connect(func(_side: int, _count: int) -> void: scare_gulls())
		ship.hit_taken.connect(func(_r: Dictionary) -> void: scare_gulls())


func _make_gull(i: int) -> Dictionary:
	var g := Node3D.new()
	g.set_meta("kind", "gull")
	g.visible = false
	add_child(g)
	var body := MeshInstance3D.new()
	body.mesh = SeaLifeArt.gull_body()
	g.add_child(body)
	var wings: Array[Node3D] = []
	for side in [1.0, -1.0]:
		var w := MeshInstance3D.new()
		w.mesh = SeaLifeArt.gull_wing()
		w.position = Vector3(0.06 * side, 0.08, -0.04)
		w.scale = Vector3(side, 1.0, 1.0)
		g.add_child(w)
		wings.append(w)
	return {"node": g, "wings": wings, "angle": TAU * float(i) / float(GULLS_MAX), "radius": rng.randf_range(7.0, 16.0),
		"height": rng.randf_range(1.0, 6.0), "speed": rng.randf_range(0.35, 0.6) * (1.0 if i % 2 == 0 else -1.0),
		"flap": rng.randf_range(0.0, TAU), "swoop_t": -1.0, "swoop_to": Vector3.ZERO, "on": 0.0}


func _make_burst(amount: int, life: float, c: Color, size: float, speed: Vector2, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.85
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = Kenney.flat(c, 0.15)
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.set_meta("kind", "sea_splash")
	add_child(p)
	return p


func splash(at: Vector3) -> void:
	var p: CPUParticles3D = _splashes[_next_splash]
	_next_splash = (_next_splash + 1) % _splashes.size()
	p.global_position = at
	p.restart()
	if _splash_sound <= 0.0 and ship != null and at.distance_to(ship.global_position) < 60.0:
		_splash_sound = 1.5
		Sfx.play("splash", at)


## The guns fired or the ship was hit: the gulls flee and come back after a while.
func scare_gulls() -> void:
	_scatter_left = 7.0


## A fish landed on deck: the nearest gull swoops down to have a look.
func on_fish_caught(at: Vector3) -> void:
	var best: Dictionary = {}
	var best_d: float = INF
	for g: Dictionary in _gulls:
		var n: Node3D = g["node"]
		if not n.visible or float(g["swoop_t"]) >= 0.0:
			continue
		var d: float = n.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = g
	if not best.is_empty():
		best["swoop_t"] = 0.0
		best["swoop_to"] = at + Vector3(0, 1.6, 0)


func _water(x: float, z: float) -> float:
	return ship.ocean.height_at(x, z) if ship != null and ship.ocean != null else 0.0


func _process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship) or ship.stats == null:
		return
	_time += delta
	_splash_sound -= delta
	_dolphins(delta)
	_whale_tick(delta)
	_flying_fish(delta)
	_gull_tick(delta)


# ---- dolphins ---------------------------------------------------------------------------------------

func _dolphins(delta: float) -> void:
	var fwd: Vector3 = -ship.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var at: Vector3 = ship.global_position
	var kn: float = ship.speed_knots()
	var L: float = ship.stats.length_m
	var B: float = ship.stats.beam_m
	match pod_state:
		"away":
			_pod_timer -= delta
			if _pod_timer <= 0.0:
				pod_state = "coming"
				_pod_left = rng.randf_range(50.0, 80.0)
				_pod_side = 1.0 if rng.randf() < 0.5 else -1.0
				for d: Dictionary in _pod:
					d["pos"] = at + right * _pod_side * rng.randf_range(45.0, 60.0) + fwd * rng.randf_range(-10.0, 30.0)
					d["pos"].y = -2.0
					(d["node"] as Node3D).visible = true
			return
		"coming", "riding":
			_pod_left -= delta
			if _pod_left <= 0.0 or ship.damage.sunk:
				pod_state = "leaving"
				_pod_timer = 4.0
		"leaving":
			_pod_timer -= delta
			if _pod_timer <= 0.0:
				pod_state = "away"
				_pod_timer = rng.randf_range(35.0, 70.0)
				for d: Dictionary in _pod:
					(d["node"] as Node3D).visible = false
				return
	var all_close: bool = true
	for d: Dictionary in _pod:
		var i: int = int(d["slot"])
		var goal: Vector3
		if pod_state == "leaving":
			goal = d["pos"] + (right * _pod_side * 2.0 + fwd).normalized() * 30.0
		elif kn >= DOLPHIN_RIDE_KN:
			# riding the bow wave: two on each side of the stem, one ahead
			var side: float = 1.0 if i % 2 == 0 else -1.0
			var row: float = float(i / 2)
			goal = at + fwd * (L * 0.5 + 3.0 - row * 3.5) + right * side * (B * 0.5 + 1.8 + row * 1.4)
			if i == POD_SIZE - 1:
				goal = at + fwd * (L * 0.5 + 6.5)
			goal += right * sin(_time * 1.3 + float(i)) * 0.6
		else:
			# lying still: a lazy ring round the ship
			var a: float = _time * 0.25 + TAU * float(i) / float(POD_SIZE)
			goal = at + Vector3(cos(a), 0.0, sin(a)) * (L * 0.6 + 12.0)
		goal.y = 0.0
		var pos: Vector3 = d["pos"]
		var flat := Vector3(pos.x, 0.0, pos.z)
		var to: Vector3 = goal - flat
		var top_speed: float = MathUtils.knots_to_ms(kn) + 7.0
		var step: Vector3 = to.limit_length(top_speed * delta) if to.length() > 0.4 else to * clampf(delta * 3.0, 0.0, 1.0)
		flat += step
		if to.length() > 6.0:
			all_close = false
		var dir: Vector3 = step.normalized() if step.length() > 0.02 * delta else (fwd if kn >= DOLPHIN_RIDE_KN else d["dir"])
		d["dir"] = (d["dir"] as Vector3).lerp(dir, clampf(delta * 4.0, 0.0, 1.0)).normalized()
		var h: float = _water(flat.x, flat.z)
		var y: float = h - 0.1 + sin(_time * 2.0 + float(i)) * 0.08
		var pitch: float = 0.0
		if pod_state == "leaving":
			y = lerpf(h - 0.25, h - 4.0, 1.0 - _pod_timer / 4.0)
			pitch = -0.4
		elif float(d["jump_t"]) >= 0.0:
			d["jump_t"] = float(d["jump_t"]) + delta
			var u: float = float(d["jump_t"]) / float(d["jump_len"])
			if u >= 1.0:
				d["jump_t"] = -1.0
				d["jump_in"] = rng.randf_range(0.8, 2.6)
				splash(Vector3(flat.x, h, flat.z))
			else:
				y = h - 0.4 + sin(PI * u) * float(d["jump_h"])
				pitch = cos(PI * u) * 0.75
		elif pod_state == "riding" or pod_state == "coming":
			d["jump_in"] = float(d["jump_in"]) - delta
			if float(d["jump_in"]) <= 0.0:
				d["jump_t"] = 0.0
				d["jump_len"] = rng.randf_range(0.9, 1.3)
				d["jump_h"] = rng.randf_range(1.4, 2.4)
				splash(Vector3(flat.x, h, flat.z))
		pos = Vector3(flat.x, y, flat.z)
		d["pos"] = pos
		_place(d["node"], pos, d["dir"], pitch)
	if pod_state == "coming" and all_close:
		pod_state = "riding"


## Face `dir` (flat) with the nose raised by `pitch` radians.
func _place(n: Node3D, pos: Vector3, dir: Vector3, pitch: float, roll: float = 0.0) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001:
		flat = Vector3.FORWARD
	var b := Basis.looking_at(flat.normalized(), Vector3.UP)
	b = b * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	n.global_transform = Transform3D(b.scaled(Vector3.ONE * float(n.get_meta("size", 1.0))), pos)


# ---- whale ------------------------------------------------------------------------------------------

func _whale_tick(delta: float) -> void:
	var at: Vector3 = ship.global_position
	match whale_state:
		"away":
			_whale_timer -= delta
			if _whale_timer > 0.0:
				return
			var fwd: Vector3 = -ship.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var right := Vector3(-fwd.z, 0.0, fwd.x)
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			_whale.global_position = at + right * side * rng.randf_range(90.0, 140.0) + fwd * rng.randf_range(50.0, 110.0)
			_whale_dir = fwd.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4))
			whale_state = "swimming"
			_whale_t = 0.0
			_whale_cycles = 0
			_whale.visible = true
		"swimming":
			_whale_t += delta
			var p: Vector3 = _whale.global_position + _whale_dir * 2.6 * delta
			var cyc: float = fmod(_whale_t, 11.0)
			var h: float = _water(p.x, p.z)
			var y: float = h + 0.35 if cyc < 4.5 else h - 2.6
			p.y = lerpf(_whale.global_position.y, y, clampf(delta * 2.5, 0.0, 1.0))
			if cyc < delta and _whale_t > 0.5:
				_whale_cycles += 1
			if absf(cyc - 0.8) < delta * 0.5 + 0.0001 or (cyc >= 0.8 and cyc - delta < 0.8):
				_spout.global_position = p + _whale_dir * 3.6 + Vector3(0, 1.2, 0)
				_spout.restart()
				if at.distance_to(p) < 160.0:
					Sfx.play("splash", p)
			_place(_whale, p, _whale_dir, 0.0, sin(_whale_t * 0.5) * 0.04)
			var close: bool = Vector2(at.x - p.x, at.z - p.z).length() < WHALE_SHY_M
			if close or _whale_cycles >= 3:
				whale_state = "diving"
				_whale_t = 0.0
		"diving":
			_whale_t += delta
			var u: float = clampf(_whale_t / 5.0, 0.0, 1.0)
			var p2: Vector3 = _whale.global_position + _whale_dir * 3.2 * delta
			p2.y = _water(p2.x, p2.z) - 0.8 - u * u * 14.0
			_place(_whale, p2, _whale_dir, -sin(u * PI * 0.5) * 0.75)
			if u >= 1.0:
				whale_state = "away"
				_whale.visible = false
				_whale_timer = rng.randf_range(70.0, 150.0)


# ---- flying fish ------------------------------------------------------------------------------------

func _flying_fish(delta: float) -> void:
	var kn: float = ship.speed_knots()
	_school_timer -= delta
	if _school_timer <= 0.0:
		_school_timer = rng.randf_range(7.0, 14.0)
		if kn >= 4.0 and not ship.damage.sunk:
			_launch_school()
	for f: Dictionary in _fish:
		var n: Node3D = f["node"]
		if float(f["life"]) <= 0.0:
			continue
		if float(f["delay"]) > 0.0:
			f["delay"] = float(f["delay"]) - delta
			if float(f["delay"]) <= 0.0:
				n.visible = true
				splash(f["from"])
			continue
		f["t"] = float(f["t"]) + delta
		var u: float = float(f["t"]) / float(f["life"])
		if u >= 1.0:
			f["life"] = 0.0
			n.visible = false
			splash(n.global_position)
			continue
		var p: Vector3 = (f["from"] as Vector3) + (f["vel"] as Vector3) * float(f["t"])
		p.y = _water(p.x, p.z) + sin(PI * u) * float(f["h"]) - 0.1
		_place(n, p, f["vel"], cos(PI * u) * 0.3, sin(float(f["t"]) * 9.0) * 0.12)


func _launch_school() -> void:
	var fwd: Vector3 = -ship.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var base: Vector3 = ship.global_position + fwd * (ship.stats.length_m * 0.5 + rng.randf_range(10.0, 22.0)) + right * side * rng.randf_range(2.0, 7.0)
	var away: Vector3 = (fwd * 0.6 + right * side).normalized()  # they flee the bow, out to the side
	var n: int = rng.randi_range(4, SCHOOL_MAX)
	for i in n:
		var f: Dictionary = _fish[i]
		var from: Vector3 = base + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
		from.y = _water(from.x, from.z)
		f["from"] = from
		f["vel"] = away.rotated(Vector3.UP, rng.randf_range(-0.35, 0.35)) * rng.randf_range(9.0, 13.0) + fwd * MathUtils.knots_to_ms(ship.speed_knots()) * 0.6
		f["life"] = rng.randf_range(1.3, 2.3)
		f["t"] = 0.0
		f["delay"] = rng.randf_range(0.01, 0.5)
		f["h"] = rng.randf_range(1.0, 2.0)


func fish_in_air() -> int:
	var n: int = 0
	for f: Dictionary in _fish:
		if float(f["life"]) > 0.0:
			n += 1
	return n


# ---- gulls ------------------------------------------------------------------------------------------

func _near_land() -> bool:
	var p := Vector2(ship.global_position.x, ship.global_position.z)
	for isl: Dictionary in islands:
		if p.distance_to(isl["pos"]) < float(isl["radius"]) + COAST_M:
			return true
	return false


func _gull_tick(delta: float) -> void:
	gulls_wanted = GULLS_MAX if _near_land() else GULLS_AT_SEA
	_scatter_left = maxf(_scatter_left - delta, 0.0)
	var target: float = 1.0 if _scatter_left > 0.0 else 0.0
	_scatter = move_toward(_scatter, target, delta * (1.6 if target > _scatter else 0.12))
	var L: float = ship.stats.length_m
	var centre: Vector3 = ship.global_position + ship.global_transform.basis.z * L * 0.1 + Vector3.UP * (ship.stats.freeboard_m + L * 0.6)
	var shown: int = 0
	for i in _gulls.size():
		var g: Dictionary = _gulls[i]
		var n: Node3D = g["node"]
		# arrive and leave by fading in from far out, never popping in over the deck
		var want_on: float = 1.0 if i < gulls_wanted else 0.0
		g["on"] = move_toward(float(g["on"]), want_on, delta * 0.15)
		if float(g["on"]) <= 0.0:
			n.visible = false
			continue
		shown += 1
		n.visible = true
		var away: float = maxf(_scatter, 1.0 - float(g["on"]))
		g["angle"] = float(g["angle"]) + float(g["speed"]) * delta * (1.0 + away * 1.5)
		var a: float = float(g["angle"])
		var r: float = float(g["radius"]) * (1.0 + away * 5.0)
		var p: Vector3 = centre + Vector3(cos(a), 0.0, sin(a)) * r + Vector3.UP * (float(g["height"]) + away * 22.0 + sin(_time * 0.7 + a) * 1.2)
		var dir := Vector3(-sin(a), 0.0, cos(a)) * signf(float(g["speed"]))
		var flap_rate: float = 9.0 if away > 0.3 else 6.0
		if float(g["swoop_t"]) >= 0.0:
			g["swoop_t"] = float(g["swoop_t"]) + delta
			var u: float = float(g["swoop_t"]) / 3.0
			if u >= 1.0:
				g["swoop_t"] = -1.0
			else:
				var to: Vector3 = g["swoop_to"]
				p = p.lerp(to, sin(PI * u))
				flap_rate = 10.0
		g["flap"] = float(g["flap"]) + delta * flap_rate
		# glide most of the time, flap in bursts
		var burst: float = clampf(sin(float(g["flap"]) * 0.21) * 2.0, 0.0, 1.0) if away < 0.3 else 1.0
		var w: float = sin(float(g["flap"])) * 0.7 * burst + 0.12
		var wings: Array = g["wings"]
		(wings[0] as Node3D).rotation.z = w
		(wings[1] as Node3D).rotation.z = -w
		var bank: float = -0.35 * signf(float(g["speed"]))
		var b := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.BACK, bank)
		n.global_transform = Transform3D(b.scaled(Vector3.ONE * GULL_SIZE), p)
	_gull_sound -= delta
	if _gull_sound <= 0.0:
		_gull_sound = rng.randf_range(18.0, 40.0)
		if shown > 0:
			Sfx.play("gulls")


func gulls_shown() -> int:
	var n: int = 0
	for g: Dictionary in _gulls:
		if (g["node"] as Node3D).visible:
			n += 1
	return n
