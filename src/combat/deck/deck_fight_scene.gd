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
var _lasers: Dictionary = {}  ## fighter id -> MeshInstance3D: the line of a levelled gun
var _deck_gun: Node3D
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
	add_to_group("deck_fight")
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
	combat.cannon_fired.connect(_on_cannon)
	combat.deck_gun_ready.connect(func() -> void: hud.note("deck.note_loaded"))
	hud.order_pressed.connect(give_order)
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
	_deck_gun = Kenney.place(self, "pirate", "cannon", Vector3(DeckData.CANNON_POS.x, 0.0, DeckData.CANNON_POS.y), 90.0, 0.85)
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
	Look.add_vignette(self)
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
		_update_lasers()
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


## Read the keyboard, mouse and pad into one intent dictionary.
func read_input() -> Dictionary:
	var move := Vector2(
		Input.get_action_strength("sail_up") - Input.get_action_strength("sail_down"),
		Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left"))
	var cmd: int = -1
	for i in DeckHud.ORDER_KEYS.size():
		if Input.is_physical_key_pressed((KEY_1 + i) as Key) and not _keys_down.has(i):
			cmd = i
	_keys_down.clear()
	for i in DeckHud.ORDER_KEYS.size():
		if Input.is_physical_key_pressed((KEY_1 + i) as Key):
			_keys_down[i] = true
	var out: Dictionary = {
		"move": move, "light": Input.is_action_just_pressed("deck_light"), "heavy": Input.is_action_just_pressed("deck_heavy"),
		"heavy_held": Input.is_action_pressed("deck_heavy"), "block": Input.is_action_pressed("deck_block"),
		"dodge": Input.is_action_just_pressed("deck_dodge"), "kick": Input.is_action_just_pressed("deck_kick"),
		"fire": Input.is_action_just_pressed("deck_fire"), "use": Input.is_action_just_pressed("deck_use"),
		"grenade": Input.is_action_just_pressed("deck_grenade"), "switch": Input.is_action_just_pressed("deck_switch"),
		"rum": Input.is_action_just_pressed("drink_rum"), "command": cmd,
	}
	var at: Variant = mouse_on_deck()
	if at != null:
		out["aim_point"] = at
	return out


var _keys_down: Dictionary = {}


## Where the mouse points on the deck (x across, y along), or null when there is no mouse over the window.
func mouse_on_deck() -> Variant:
	var vp: Viewport = get_viewport()
	if vp == null or camera == null or not camera.is_inside_tree():
		return null
	var m: Vector2 = vp.get_mouse_position()
	if not vp.get_visible_rect().has_point(m):
		return null
	var o: Vector3 = camera.project_ray_origin(m)
	var n: Vector3 = camera.project_ray_normal(m)
	var plane_y: float = global_position.y + 1.2  # chest height
	if absf(n.y) < 0.0001:
		return null
	var t: float = (plane_y - o.y) / n.y
	if t <= 0.0:
		return null
	var hit: Vector3 = o + n * t - global_position
	return Vector2(hit.x, hit.z)


## Turn an intent into actions on the captain. Public so tests can play the captain.
func apply_input(i: Dictionary) -> void:
	var p: FighterState = combat.player
	var cmd: int = int(i.get("command", -1))
	if cmd >= 0:
		give_order(cmd)
	if not p.is_standing():
		p.move_intent = Vector2.ZERO
		p.aiming = false
		return
	var move: Vector2 = i.get("move", Vector2.ZERO)
	p.move_intent = move.normalized() if move.length() > 0.1 else Vector2.ZERO
	if p.move_intent != Vector2.ZERO:
		Sfx.play("step_wood")
	if bool(i.get("switch", false)):
		p.cycle_mode()
		Sfx.play("ui_click")
	if p.mode == FighterState.Mode.GUN and (p.ranged == "" or p.ranged_ammo <= 0):
		p.cycle_mode()  # out of shot: the blade, or the fists, come out
	var foe: FighterState = combat.nearest_enemy(p)
	var gun: bool = p.mode == FighterState.Mode.GUN
	p.aiming = gun and bool(i.get("heavy_held", false)) and p.state != FighterState.State.DRINK
	# Aiming: the captain turns to the mouse (or holds on the nearest man in front when there is no mouse).
	# Otherwise he faces the nearest enemy when one is close, or the way he walks.
	var aim_point: Variant = i.get("aim_point", null)
	if p.aiming and aim_point is Vector2 and (aim_point as Vector2).distance_to(p.pos) > 0.3:
		p.dir = ((aim_point as Vector2) - p.pos).normalized()
	elif p.aiming and foe != null:
		p.dir = (foe.pos - p.pos).normalized()
	elif foe != null and foe.pos.distance_to(p.pos) <= LOCK_ON_M:
		p.dir = (foe.pos - p.pos).normalized()
	elif p.move_intent != Vector2.ZERO:
		p.dir = p.move_intent
	if bool(i.get("block", false)):
		p.raise_block(combat.time_s)
	elif p.state == FighterState.State.BLOCK:
		p.lower_block()
	if bool(i.get("dodge", false)):
		p.aiming = false
		p.try_dodge(p.move_intent if p.move_intent != Vector2.ZERO else -p.dir)
	if gun:
		if bool(i.get("light", false)) or bool(i.get("fire", false)):
			combat.fire_ranged(p, p.dir)
	else:
		if bool(i.get("light", false)):
			p.try_swing(false)
		if bool(i.get("heavy", false)):
			p.try_swing(true)
		if bool(i.get("fire", false)):
			# a quick shot from the hip at the nearest man, without putting the blade away
			var aim: Vector2 = foe.pos - p.pos if foe != null and foe.pos.distance_to(p.pos) <= LOCK_ON_M * 3.0 else p.dir
			combat.fire_ranged(p, aim)
	if bool(i.get("kick", false)):
		p.try_kick()
	if bool(i.get("rum", false)):
		if p.try_drink():
			Sfx.play("ui_confirm")
		elif hud != null:
			hud.note("deck.note_no_rum" if p.rum_left <= 0 else ("deck.note_full_hp" if p.hp >= p.hp_max else "deck.note_rum_wait"))
	if bool(i.get("use", false)):
		combat.use_rope(p)
	if bool(i.get("grenade", false)) and foe != null:
		combat.throw_grenade(p, foe.pos)


## An order from the buttons or keys 1-8: a squad stance, or a job for a few hands.
func give_order(order: int) -> void:
	var key: String = ""
	match order:
		DeckHud.Order.LOAD_CANNON:
			key = "deck.note_loading" if combat.order_load_cannon() else ("deck.note_loaded" if combat.cannon_loaded else "deck.note_no_hands")
		DeckHud.Order.FIRE_CANNON:
			var hits: int = combat.order_fire_cannon()
			key = "deck.note_not_loaded" if hits < 0 else ""
		DeckHud.Order.REPAIR:
			if combat.order_repair():
				key = "deck.note_repairing"
			else:
				key = "deck.note_repair_stop"
		_:
			if order >= 0 and order <= DeckHud.Order.RETREAT:
				combat.command = order as DeckData.Command
				key = DeckHud.COMMAND_KEYS[order]
	if key != "" and hud != null:
		hud.note(key)
	Sfx.play("ui_click")


## A thin line along every levelled gun: the captain's while he aims (gold), and each enemy's for the moment
## before he fires (red), so a man can see the shot coming and get out of its way.
func _update_lasers() -> void:
	for f in combat.fighters:
		var on: bool = f.is_standing() and ((f.is_player and f.aiming) or f.aim_lock_left > 0.0)
		var l: MeshInstance3D = _lasers.get(f.id)
		if not on:
			if l != null:
				l.visible = false
			continue
		if l == null:
			l = MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.035, 0.035, 1.0)
			l.mesh = b
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1.0, 0.85, 0.3, 0.7) if f.team == 0 else Color(1.0, 0.2, 0.15, 0.75)
			l.material_override = mat
			l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			l.set_meta("kind", "aim_line")
			add_child(l)
			_lasers[f.id] = l
		l.visible = true
		var d: Vector2 = f.dir if f.is_player else f.aim_dir
		var length: float = float(WeaponData.WEAPONS[f.ranged]["range"]) if f.ranged != "" else 10.0
		length = minf(length, 16.0)
		var from := Vector3(f.pos.x, 1.3, f.pos.y)
		var to := from + Vector3(d.x, 0.0, d.y) * length
		l.position = (from + to) * 0.5
		l.scale = Vector3(1.0, 1.0, length)
		l.look_at_from_position(l.position, to, Vector3.UP)


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
	var res: String = str(info.get("result", "hit"))
	var att: FighterState = combat.by_id(_a)
	if res == "parried":
		Sfx.play("parry_ring")
	elif att != null and att.melee == "fists" and att.state == FighterState.State.SWING:
		Sfx.play("wood_impact")  # a fist on a jaw
	else:
		Sfx.play("sword_clash")
	if hud != null:
		hud.on_hit(info, v.fighter.pos if v != null else Vector2.ZERO, v.fighter.team if v != null else 1)


func _on_cannon(from_pos: Vector2, direction: Vector2) -> void:
	Sfx.play("cannon_swivel")
	var at := global_position + Vector3(from_pos.x, 1.0, from_pos.y)
	Vfx.muzzle(self, at, Vector3(direction.x, 0.0, direction.y))
	if _deck_gun != null:
		_deck_gun.rotation.y = atan2(direction.x, direction.y)
	_shake = 1.2


func _on_keg(at: Vector2) -> void:
	Sfx.play("explosion")
	for k in _kegs:
		if absf(k.position.x - at.x) < 0.1 and absf(k.position.z - at.y) < 0.1:
			k.visible = false
	_shake = 1.5


func _on_shot(_id: int, from_pos: Vector2, to_pos: Vector2) -> void:
	Sfx.play("blunderbuss" if from_pos.distance_to(to_pos) < 4.0 else ("musket" if _id == combat.player.id else "pistol"))
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
