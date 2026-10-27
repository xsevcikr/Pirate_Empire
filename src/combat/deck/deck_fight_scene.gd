class_name DeckFightScene
extends Node3D
## The 3D side of a deck fight: a deck built from boxes, a capsule man for every fighter, a third-person camera
## behind the captain and the fight HUD. All rules live in DeckCombat; this node only draws and reads input.

signal fight_over(result: Dictionary)

const ARENA_ORIGIN: Vector3 = Vector3(0.0, 400.0, 0.0)
const CAM_BACK_M: float = 11.0
const CAM_UP_M: float = 6.5
const LOCK_ON_M: float = 5.0
const RESULT_HOLD_S: float = 2.5
const FIGHTER_HEIGHT_M: float = 1.8

var combat: DeckCombat
var hud: DeckHud
var camera: Camera3D
var _men: Dictionary = {}  ## fighter id -> DeckFighterView
var _kegs: Array[Node3D] = []
var _prev_camera: Camera3D
var _hold_left: float = -1.0
var _announced: bool = false
var _shake: float = 0.0
## Input for the next physics step; filled from the keyboard or set directly by tests.
var intent: Dictionary = {}


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = ARENA_ORIGIN


func start(c: DeckCombat) -> void:
	combat = c
	_build_deck()
	for f in combat.fighters:
		_add_view(f)
	camera = Camera3D.new()
	camera.fov = 62.0
	add_child(camera)
	var vp: Viewport = get_viewport()
	_prev_camera = vp.get_camera_3d() if vp != null else null
	camera.make_current()
	hud = DeckHud.new()
	hud.combat = combat
	var layer := CanvasLayer.new()
	layer.layer = 55
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(hud)
	combat.fighter_hit.connect(_on_hit)
	combat.keg_exploded.connect(_on_keg)
	combat.ranged_fired.connect(_on_shot)
	_place_camera(1.0)


func _exit_tree() -> void:
	if _prev_camera != null and is_instance_valid(_prev_camera) and _prev_camera.is_inside_tree():
		_prev_camera.make_current()


# ---- building the stage --------------------------------------------------------------------------

func _box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = Kenney.flat(color)
	m.position = at
	add_child(m)
	return m


func _build_deck() -> void:
	DeckArt.build_ship_side(self, -1.0, combat.covers)
	var none: Array[Dictionary] = []
	DeckArt.build_ship_side(self, 1.0, none)
	for k in combat.kegs:
		var keg := Node3D.new()
		keg.position = Vector3(k["pos"].x, 0.0, k["pos"].y)
		add_child(keg)
		DeckArt._barrel(keg, Vector3.ZERO)
		var fuse := MeshInstance3D.new()
		fuse.mesh = DeckArt.cyl(0.02, 0.02, 0.25, 4)
		fuse.material_override = DeckArt.plain(Color(1.0, 0.6, 0.2), 0.6)
		fuse.position = Vector3(0.0, 1.05, 0.0)
		keg.add_child(fuse)
		_kegs.append(keg)
	for r in combat.ropes:
		DeckArt._rope(self, Vector3(r["pos"].x, 0.1, r["pos"].y), Vector3(r["pos"].x, 9.5, r["pos"].y), 0.03, DeckArt.plain(Color(0.7, 0.58, 0.35), 0.95))
	var sun := DirectionalLight3D.new()
	Look.apply_sun(sun, 60.0)
	add_child(sun)
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.fog_enabled = true
	Look.apply_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var ocean := Ocean.new()
	ocean.model = WaveModel.new(3.0, Vector2(1, 0))
	ocean.position = Vector3(0.0, -3.4, 0.0)
	add_child(ocean)
	var dn := DayNight.new()
	dn.sun = sun
	dn.env = env
	dn.sky_material = sky_mat
	dn.ocean = ocean
	add_child(dn)
	dn.apply_hour(10.5)


func _add_view(f: FighterState) -> void:
	var v := DeckFighterView.new()
	v.fighter = f
	add_child(v)
	_men[f.id] = v


# ---- per frame -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if combat == null:
		return
	if combat.outcome == DeckCombat.Outcome.ONGOING:
		var gathered: Dictionary = intent if not intent.is_empty() else read_input()
		apply_input(gathered)
		combat.tick(delta)
		for f in combat.fighters:
			if not _men.has(f.id):
				_add_view(f)
	elif not _announced:
		_announced = true
		_hold_left = RESULT_HOLD_S
		hud.show_result(combat.result())
	if _hold_left >= 0.0:
		_hold_left -= delta
		if _hold_left < 0.0:
			fight_over.emit(combat.result())
			queue_free()
			return
	_shake = maxf(_shake - delta * 3.0, 0.0)
	_place_camera(delta)


## Read the keyboard and pad into one intent dictionary.
func read_input() -> Dictionary:
	var move := Vector2(
		Input.get_action_strength("sail_up") - Input.get_action_strength("sail_down"),
		Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"))
	var cmd: int = -1
	for i in 5:
		if Input.is_physical_key_pressed((KEY_1 + i) as Key):
			cmd = i
	return {
		"move": move, "light": Input.is_action_just_pressed("deck_light"), "heavy": Input.is_action_just_pressed("deck_heavy"),
		"block": Input.is_action_pressed("deck_block"), "dodge": Input.is_action_just_pressed("deck_dodge"),
		"kick": Input.is_action_just_pressed("deck_kick"), "fire": Input.is_action_just_pressed("deck_fire"),
		"use": Input.is_action_just_pressed("deck_use"), "grenade": Input.is_action_just_pressed("deck_grenade"), "command": cmd,
	}


## Turn an intent into actions on the captain. Public so tests can play the captain.
func apply_input(i: Dictionary) -> void:
	var p: FighterState = combat.player
	if not p.is_standing():
		p.move_intent = Vector2.ZERO
		return
	var move: Vector2 = i.get("move", Vector2.ZERO)
	p.move_intent = move.normalized() if move.length() > 0.1 else Vector2.ZERO
	# face the nearest enemy when one is close, otherwise the way we walk
	var foe: FighterState = combat.nearest_enemy(p)
	if foe != null and foe.pos.distance_to(p.pos) <= LOCK_ON_M:
		p.dir = (foe.pos - p.pos).normalized()
	elif p.move_intent != Vector2.ZERO:
		p.dir = p.move_intent
	if bool(i.get("block", false)):
		p.raise_block(combat.time_s)
	elif p.state == FighterState.State.BLOCK:
		p.lower_block()
	if bool(i.get("dodge", false)):
		p.try_dodge(p.move_intent if p.move_intent != Vector2.ZERO else -p.dir)
	if bool(i.get("light", false)):
		p.try_swing(false)
	if bool(i.get("heavy", false)):
		p.try_swing(true)
	if bool(i.get("kick", false)):
		p.try_kick()
	if bool(i.get("fire", false)) and foe != null:
		combat.fire_ranged(p, foe.pos - p.pos if foe.pos.distance_to(p.pos) <= LOCK_ON_M * 3.0 else p.dir)
	elif bool(i.get("fire", false)):
		combat.fire_ranged(p, p.dir)
	if bool(i.get("use", false)):
		combat.use_rope(p)
	if bool(i.get("grenade", false)) and foe != null:
		combat.throw_grenade(p, foe.pos)
	var cmd: int = int(i.get("command", -1))
	if cmd >= 0 and cmd < 5:
		combat.command = cmd as DeckData.Command


func _place_camera(delta: float) -> void:
	if not camera.is_inside_tree():
		return
	var p: FighterState = combat.player
	var focus := Vector3(p.pos.x, 1.2, p.pos.y)
	var want := focus + Vector3(-CAM_BACK_M, CAM_UP_M, 0.0)
	want.x = clampf(want.x, -DeckData.DECK_HALF_WIDTH_M - 3.0, DeckData.DECK_HALF_WIDTH_M)
	camera.position = camera.position.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	if _shake > 0.0:
		camera.position += Vector3(sin(combat.time_s * 90.0), cos(combat.time_s * 70.0), 0.0) * 0.05 * _shake
	camera.look_at(global_position + focus + Vector3(2.0, 0.0, 0.0), Vector3.UP)


func _on_hit(_a: int, t_id: int, info: Dictionary) -> void:
	var v: DeckFighterView = _men.get(t_id)
	if v != null:
		v.flash(str(info.get("result", "hit")))
	if t_id == combat.player.id:
		_shake = 1.0
	if hud != null:
		hud.on_hit(info, v.fighter.pos if v != null else Vector2.ZERO)


func _on_keg(at: Vector2) -> void:
	for k in _kegs:
		if absf(k.position.x - at.x) < 0.1 and absf(k.position.z - at.y) < 0.1:
			k.visible = false
	_shake = 1.5


func _on_shot(_id: int, from_pos: Vector2, to_pos: Vector2) -> void:
	var tracer := MeshInstance3D.new()
	var b := BoxMesh.new()
	var d: Vector2 = to_pos - from_pos
	b.size = Vector3(0.05, 0.05, minf(d.length(), 6.0))
	tracer.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	add_child(tracer)
	tracer.position = Vector3(from_pos.x, 1.3, from_pos.y) + Vector3(d.x, 0.0, d.y).normalized() * 3.0
	tracer.look_at_from_position(tracer.position, tracer.position + Vector3(d.x, 0.0, d.y), Vector3.UP)
	get_tree().create_timer(0.08).timeout.connect(tracer.queue_free)
