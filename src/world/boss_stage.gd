class_name BossStage
extends Node3D
## The boss fight as you see it: the boss in front, your ship (or your captain on the sand) between it and the
## camera, and the attacks acted out. During a tell the boss holds its wind-up and a red ring marks where it will
## land, turning yellow in the last second when an answer counts. When it lands the stage throws the poison, the
## ice, the fist or the lightning, and your ship dodges, braces or takes it. Primitives and Kenney models only.

const LOOK: Dictionary = {
	"kraken": {"dist": 95.0, "cam": Vector3(45, 30, 80), "sea": true, "focus_y": 30.0},
	"sea_serpent": {"dist": 70.0, "cam": Vector3(40, 18, 62), "sea": true, "focus_y": 38.0},
	"ghost_admiral": {"dist": 75.0, "cam": Vector3(40, 26, 70), "sea": true, "focus_y": 18.0, "yaw": 90.0},
	"ice_leviathan": {"dist": 60.0, "cam": Vector3(58, 22, 30), "sea": true, "focus_y": 12.0},
	"valcourt": {"dist": 90.0, "cam": Vector3(34, 28, 66), "sea": true},
	"black_ibrahim": {"dist": 90.0, "cam": Vector3(34, 28, 66), "sea": true},
	"shell_king": {"dist": 20.0, "cam": Vector3(7, 7, 17), "sea": false, "focus_y": 6.0},
	"brass_colossus": {"dist": 34.0, "cam": Vector3(14, 10, 36), "sea": false, "focus_y": 21.0},
}

var fight: MonsterFight
var model: BossModel
var cam: Camera3D
var target: Node3D  ## the player's ship or captain
var _target_home: Vector3
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _fx: Array[Dictionary] = []  ## live effects: node, kind, t, life, from, to, ...
var _told: String = ""
var _react_t: float = -1.0
var _react: String = ""
var _shake: float = 0.0
var _t: float = 0.0
var _look: Dictionary
var _away_t: float = -1.0  ## the boss is out of its place (dived up under you, appeared beside you) this long


static func make(f: MonsterFight) -> BossStage:
	var s := BossStage.new()
	s.fight = f
	s.name = "BossStage"
	return s


func _ready() -> void:
	_look = LOOK.get(fight.id, LOOK["kraken"])
	_environment()
	if BossModel.has_model(fight.id):
		model = BossModel.make(fight.id)
		model.rotation.y = deg_to_rad(float(_look.get("yaw", 0.0)))
		add_child(model)
	else:
		_admiral_fleet()
	_player()
	_ring_mat = _unlit(Color(1.0, 0.15, 0.1, 0.0))
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	var r: float = _target_radius() * 1.25
	tm.inner_radius = r * 0.82
	tm.outer_radius = r
	tm.rings = 48
	_ring.mesh = tm
	_ring.material_override = _ring_mat
	_ring.position = _target_home + Vector3(0, 0.3, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	add_child(cam)
	_place_camera()


func _target_radius() -> float:
	return 9.0 if bool(_look["sea"]) else 1.6


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var sky: Color = {"ghost_admiral": Color(0.32, 0.42, 0.42), "ice_leviathan": Color(0.5, 0.64, 0.8), "brass_colossus": Color(0.55, 0.35, 0.28)}.get(fight.id, Color(0.55, 0.75, 0.9))
	env.background_color = sky
	Look.apply_environment(env)
	env.fog_enabled = true
	env.fog_light_color = sky
	env.fog_density = 0.002 if bool(_look["sea"]) else 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 150, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	ground.mesh = pm
	var c: Color = Color(0.3, 0.68, 0.88)
	match fight.id:
		"shell_king":
			c = Color(0.93, 0.83, 0.58)
		"brass_colossus":
			c = Color(0.35, 0.25, 0.22)
		"ghost_admiral":
			c = Color(0.18, 0.36, 0.38)
		"ice_leviathan":
			c = Color(0.3, 0.52, 0.72)
		"kraken":
			c = Color(0.16, 0.42, 0.55)
	ground.material_override = Kenney.flat(c)
	add_child(ground)
	if fight.id == "brass_colossus":
		for i in 6:
			var a: float = PI * 0.15 + PI * 0.7 * float(i) / 5.0
			_lava_pool(Vector3(cos(a) * 26.0, 0.05, sin(a) * 16.0))


func _lava_pool(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.0
	cm.bottom_radius = 3.0
	cm.height = 0.1
	mi.mesh = cm
	mi.material_override = Kenney.flat(Color(1.0, 0.45, 0.08), 0.7)
	mi.position = at
	add_child(mi)


## Valcourt and Black Ibrahim are fleets: a line of enemy ships stands in for the model.
func _admiral_fleet() -> void:
	for i in 3:
		var ship: Node3D = Kenney.spawn("pirate", "ship-large" if fight.id == "valcourt" else "ship-pirate-large")
		ship.scale = Vector3.ONE * 3.0
		ship.position = Vector3(-40.0 + float(i) * 40.0, 0.0, -float(i % 2) * 15.0)
		ship.rotation.y = PI * 0.5
		add_child(ship)


func _player() -> void:
	var d: float = float(_look["dist"])
	_target_home = Vector3(0, 0, d)
	if bool(_look["sea"]):
		target = Kenney.spawn("pirate", "ship-pirate-medium")
		target.scale = Vector3.ONE * 2.2
		target.rotation.y = PI * 0.5  # broadside on to the monster
	else:
		target = Kenney.spawn("characters", "character-a")
		target.scale = Vector3.ONE * 1.6
		target.rotation.y = PI  # facing the boss
	target.position = _target_home
	add_child(target)


func _place_camera() -> void:
	var off: Vector3 = _look["cam"]
	cam.position = _target_home + off + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake
	var focus: Vector3 = Vector3(0, float(_look.get("focus_y", float(_look["dist"]) * 0.22)), float(_look["dist"]) * 0.35)
	cam.look_at(focus, Vector3.UP)


func _unlit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _attack() -> Dictionary:
	return BossAttacks.of(fight.id, _told)


func _color() -> Color:
	return _attack().get("color", Color(1.0, 0.95, 0.85))


## Called by the panel every frame with what landed this tick (or "").
func follow(delta: float, landed: String) -> void:
	_t += delta
	var t: String = fight.telegraph()
	if t != "":
		_told = t
		var a: Dictionary = _attack()
		if model != null:
			model.windup(str(a.get("fx", "slam")), str(a.get("part", "body")), fight.telegraph_progress(), _color())
		var on: bool = fight.in_window()
		var pulse: float = 0.5 + 0.5 * sin(_t * (16.0 if on else 7.0))
		_ring_mat.albedo_color = (Color(1.0, 0.85, 0.1) if on else Color(1.0, 0.12, 0.08)) * Color(1, 1, 1, 0.45 + 0.4 * pulse)
		_ring.scale = Vector3.ONE * (1.6 - 0.6 * fight.telegraph_progress())
	else:
		_ring_mat.albedo_color.a = 0.0
	if landed != "":
		_told = landed
		_unleash(landed)
	_tick_fx(delta)
	_tick_react(delta)
	if _away_t >= 0.0:
		_away_t += delta
		if _away_t > 1.4 and model != null:
			model.position = Vector3.ZERO
			_away_t = -1.0
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_place_camera()


func _unleash(atk: String) -> void:
	var a: Dictionary = BossAttacks.of(fight.id, atk)
	var fx: String = str(a.get("fx", "slam"))
	var part: String = str(a.get("part", "body"))
	if model != null:
		model.unleash(fx, part)
	var to: Vector3 = _target_home + Vector3(0, 1.0, 0)
	var src: Vector3 = model.mouth_global() if model != null else Vector3(0, 10, 0)
	var r: float = maxf(_target_radius(), (model.size if model != null else 40.0) * 0.1)
	var c: Color = _color()
	match fx:
		"spit", "throw", "freeze":
			var from: Vector3 = model.part_global(part) if (model != null and fx == "throw") else src
			_projectile(from, to, c, r * (0.5 if fx == "throw" else 0.35), 0.45, r * 2.0, fx == "throw")
		"breath":
			for i in 14:
				_projectile(src, to + Vector3(randf_range(-r, r), 0, randf_range(-r, r)) * 0.6, c, r * 0.3 * (0.6 + float(i) / 14.0), 0.35 + float(i) * 0.02, 0.0, false, float(i) * 0.02)
		"roar":
			for i in 3:
				_wave(src, c, r * 6.0, 0.7, float(i) * 0.15)
		"whirl":
			for i in 4:
				_wave(to, Color(0.85, 0.97, 1.0), r * (3.5 - float(i) * 0.6), 1.0, float(i) * 0.12)
			_splash(to, Color(0.85, 0.95, 1.0), r)
		"slam", "quake", "sweep", "lunge", "grab", "dive":
			if fx == "dive" and model != null:  # it comes up from under you
				model.position = _target_home + Vector3(0, 0, -r * 2.5)
				_away_t = 0.0
			_wave(to, Color(1, 1, 1), r * 2.4, 0.5)
			_splash(to, Color(0.85, 0.95, 1.0) if bool(_look["sea"]) else Color(0.9, 0.8, 0.55), r)
			if fx == "grab":
				_chain(model.part_global(part) if model != null else src, to, c)
		"rain":
			for i in 12:
				var at: Vector3 = to + Vector3(randf_range(-r, r) * 1.6, 0, randf_range(-r, r) * 1.6)
				_projectile(at + Vector3(0, r * 6.0, 0), at, c, r * 0.3, 0.35, 0.0, true, float(i) * 0.03)
		"volley":
			for i in 6:
				var from: Vector3 = Vector3(-r * 2.5 + float(i) * r, r * 1.2, r * 1.5)
				_projectile(from, to + Vector3(randf_range(-r, r), 0, 0), c, r * 0.3, 0.5, r * 1.5, false, float(i) * 0.04)
		"summon":
			for i in 5:
				var at: Vector3 = to + Vector3(cos(float(i) * 1.3), 0, sin(float(i) * 1.3)) * r * 0.9
				_rise(at, Color(0.95, 0.95, 0.88), r * 0.45)
		"teleport":
			if model != null:  # it is suddenly right beside you
				model.position = _target_home + Vector3(-r * 4.0, 0, -r * 4.0)
				_away_t = 0.0
			_wave(to + Vector3(-r * 3.0, 0, r * 1.5), c, r * 3.0, 0.6)
		"spin":
			_wave(to, c, r * 2.0, 0.4)
		"nova":
			_wave(src, c, float(_look["dist"]) * 1.4, 0.8)
	_answer_anim(fight.last_outcome)


## The player's ship or captain: slides aside on a dodge, holds firm on a block, rocks on a hit.
func _answer_anim(outcome: String) -> void:
	_react = outcome
	_react_t = 0.0
	if outcome == "hit":
		_shake = 1.2 if bool(_look["sea"]) else 0.4


func _tick_react(delta: float) -> void:
	if target == null:
		return
	target.position = _target_home
	if _react_t < 0.0:
		return
	_react_t += delta
	var k: float = sin(clampf(_react_t / 0.9, 0.0, 1.0) * PI)
	var r: float = _target_radius()
	match _react:
		"dodged":
			target.position.x += r * 1.8 * k
		"hit":
			target.position.y -= r * 0.15 * k
			target.rotation.z = sin(_react_t * 30.0) * 0.12 * k
		"blocked", "countered":
			target.position.z += r * 0.25 * k
	if _react_t > 0.9:
		_react_t = -1.0
		target.rotation.z = 0.0


func _mesh(mesh: Mesh, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _unlit(c)
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


func _projectile(from: Vector3, to: Vector3, c: Color, r: float, life: float, arc: float, chunky: bool, delay: float = 0.0) -> void:
	var mesh: Mesh = _ball(r)
	if chunky:
		var b := BoxMesh.new()
		b.size = Vector3.ONE * r * 1.6
		mesh = b
	var mi: MeshInstance3D = _mesh(mesh, c, from)
	mi.visible = delay <= 0.0
	_fx.append({"node": mi, "kind": "fly", "t": -delay, "life": life, "from": from, "to": to, "arc": arc, "c": c, "r": r})


func _splash(at: Vector3, c: Color, r: float) -> void:
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		var mi: MeshInstance3D = _mesh(_ball(r * 0.18), c, at)
		_fx.append({"node": mi, "kind": "fly", "t": 0.0, "life": 0.5, "from": at, "to": at + Vector3(cos(a), 0, sin(a)) * r * 1.4, "arc": r * 1.2, "c": c, "r": 0.0})


func _wave(at: Vector3, c: Color, r: float, life: float, delay: float = 0.0) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	var mi: MeshInstance3D = _mesh(tm, c, at)
	mi.visible = false
	_fx.append({"node": mi, "kind": "wave", "t": -delay, "life": life, "r": r, "c": c})


func _chain(from: Vector3, to: Vector3, c: Color) -> void:
	for i in 10:
		var p: Vector3 = from.lerp(to, float(i) / 9.0)
		var mi: MeshInstance3D = _mesh(_ball(_target_radius() * 0.12), c, p)
		_fx.append({"node": mi, "kind": "hold", "t": 0.0, "life": 0.9})


func _rise(at: Vector3, c: Color, r: float) -> void:
	var cap := CapsuleMesh.new()
	cap.radius = r * 0.5
	cap.height = r * 3.0
	var mi: MeshInstance3D = _mesh(cap, c, at)
	_fx.append({"node": mi, "kind": "rise", "t": 0.0, "life": 1.0, "from": at, "to": at + Vector3(0, r * 1.5, 0)})


func _tick_fx(delta: float) -> void:
	var keep: Array[Dictionary] = []
	var cur: Array[Dictionary] = _fx
	_fx = []  # splashes spawned while ticking land here and join next frame
	for f in cur:
		f["t"] = float(f["t"]) + delta
		var t: float = float(f["t"])
		var mi: MeshInstance3D = f["node"]
		if t < 0.0:
			keep.append(f)
			continue
		mi.visible = true
		var k: float = clampf(t / float(f["life"]), 0.0, 1.0)
		match str(f["kind"]):
			"fly", "rise":
				var p: Vector3 = (f["from"] as Vector3).lerp(f["to"], k)
				p.y += float(f.get("arc", 0.0)) * sin(k * PI)
				mi.position = p
				mi.rotation.x += delta * 6.0
				if k >= 1.0 and str(f["kind"]) == "fly" and float(f.get("r", 0.0)) > 0.0:
					_splash(f["to"], f["c"], float(f["r"]) * 2.0)
			"wave":
				mi.scale = Vector3(1, 0.25, 1) * maxf(float(f["r"]) * k, 0.01)
				(mi.material_override as StandardMaterial3D).albedo_color.a = 0.8 * (1.0 - k)
			"hold":
				(mi.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k * k
		if k >= 1.0:
			mi.queue_free()
		else:
			keep.append(f)
	keep.append_array(_fx)
	_fx = keep
