class_name DeckFighterView
extends Node3D
## One man on deck, town street or camp as a Kenney blocky character. Which of the 18 skins a man wears follows his kind
## and id; the animations (idle, walk, sprint, sword swings, shooting, kick, die) come with the model and are driven
## by the fighter's state each frame.

const KIND_SCALE: Dictionary = {"brute": 1.18, "captain": 1.08, "captain_player": 1.05, "sailor": 0.97}
const HEIGHT_M: float = 1.85  ## a normal man; the model is 2.7 units tall
const MODEL_H: float = 2.7
## Skins by kind. Letters are the Kenney characters: p eyepatch captain, q suit, k red jacket, j policeman, a/b rough
## sailors, m green bandolier, c/f/e/n townsfolk, i old doctor, o orc, l zombie, r ninja.
const SKINS: Dictionary = {
	"captain_player": ["p"], "captain": ["k", "q"], "officer": ["q"], "marine": ["j"], "guard": ["j"], "brute": ["o", "a"],
	"sailor": ["a", "b", "m", "c"], "crew": ["b", "a", "m", "c", "f", "r"], "peasant": ["c", "b", "a"],
	"merchant": ["i", "k", "q"], "townswoman": ["e", "f", "n"],
}
const CREW_SKINS: Dictionary = {"swordsman": ["m", "b"], "seasoned": ["a", "b"], "gunner": ["a", "r"], "musketeer": ["m", "j"], "bosun": ["k"]}
const ANIM_LOOPS: Array[String] = ["idle", "walk", "sprint"]
const CLOTH: Dictionary = {"steel": Color(0.72, 0.76, 0.84), "wood": Color(0.62, 0.38, 0.2), "iron": Color(0.3, 0.32, 0.38)}

var fighter: FighterState
var show_label: bool = true
var pose_idle_only: bool = false  ## ship-board crew: no fight, only standing about and walking
var _model: Node3D
var _pivot: Node3D  ## tilted for stagger and dodge
var _anim: AnimationPlayer
var _anim_name: String = ""
var _arm_r: Node3D
var _arm_l: Node3D
var _weapon: Node3D
var _gun: Node3D
var _shield: Node3D
var _label: Label3D
var _meshes: Array[MeshInstance3D] = []
var _flash_left: float = 0.0
var _last_flash: Color = Color(0, 0, 0, 0)
var _owned: bool = false
var _flash_color: Color = Color.WHITE
var _last_pos: Vector2
var _speed: float = 0.0
var _scrub: bool = false


## The skin letter for a fighter: stable for the same kind and id.
static func skin_for(f: FighterState) -> String:
	var pool: Array = SKINS.get(f.kind, SKINS["crew"])
	if f.kind == "crew" and CREW_SKINS.has(f.crew_type):
		pool = CREW_SKINS[f.crew_type]
	return str(pool[absi(f.id * 7919 + 3) % pool.size()])


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_model = Kenney.spawn("characters", "character-" + skin_for(fighter))
	_model.scale = Vector3.ONE * (HEIGHT_M / MODEL_H)
	_pivot.add_child(_model)
	_meshes = Kenney.meshes_of(_model)
	_anim = _model.get_node("AnimationPlayer") as AnimationPlayer
	for a in ANIM_LOOPS:
		_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var body: Node = _model.get_child(0)
	var torso: Node = body.find_child("torso", true, false)
	_arm_r = torso.get_node("arm-right") as Node3D
	_arm_l = torso.get_node("arm-left") as Node3D
	_dress()
	if fighter.is_player:
		var ring := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.62
		cm.bottom_radius = 0.62
		cm.height = 0.02
		ring.mesh = cm
		ring.material_override = _glow(Color(1.0, 0.82, 0.3))
		ring.position.y = 0.03
		ring.name = "Ring"
		add_child(ring)
	_label = Label3D.new()
	_label.visible = show_label
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 18
	_label.pixel_size = 0.01
	_label.no_depth_test = true
	_label.outline_size = 6
	_label.position.y = 2.45
	add_child(_label)
	scale = Vector3.ONE * float(KIND_SCALE.get(fighter.kind, 1.0))
	_last_pos = fighter.pos
	_play("idle", 0.0)
	_sync(0.0)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Weapon in the right hand, a firearm in the left for gunners, a round shield for blocking.
func _dress() -> void:
	_weapon = Node3D.new()
	_weapon.name = "Weapon"
	_arm_r.add_child(_weapon)
	_weapon.position = Vector3(-0.2, -0.95, 0.05)
	match fighter.melee:
		"none":
			pass
		"halberd":
			_part(_weapon, Kenney.mesh("arena", "weapon-spear"), Vector3(0, 0, 0), Vector3(-90, 0, 0), 3.4)
		"boarding_axe", "club":
			_part(_weapon, _stick(0.07, 1.1, CLOTH["wood"]), Vector3(0, 0, 0.35), Vector3(90, 0, 0), 1.0)
			if fighter.melee == "boarding_axe":
				_part(_weapon, _box(Vector3(0.06, 0.34, 0.3), CLOTH["steel"]), Vector3(0, 0.1, 0.7), Vector3.ZERO, 1.0)
			else:
				_part(_weapon, _box(Vector3(0.2, 0.2, 0.3), CLOTH["wood"].darkened(0.25)), Vector3(0, 0, 0.8), Vector3.ZERO, 1.0)
		"bayonet", "musket":
			_part(_weapon, Kenney.mesh("arena", "weapon-spear"), Vector3(0, 0, 0), Vector3(-90, 0, 0), 2.4)
		"dagger":
			_part(_weapon, Kenney.mesh("dungeon", "weapon-sword"), Vector3(0, 0, 0.1), Vector3(-90, 0, 0), 1.6)
		_:
			_part(_weapon, Kenney.mesh("dungeon", "weapon-sword"), Vector3(0, 0, 0.1), Vector3(-90, 0, 0), 2.8 if fighter.melee == "rapier" else 2.5)
	if fighter.ranged != "" and fighter.kind != "captain_player":
		_gun = Node3D.new()
		_gun.name = "Gun"
		_arm_l.add_child(_gun)
		_gun.position = Vector3(0.2, -0.95, 0.05)
		var long: bool = fighter.ranged != "flintlock"
		_part(_gun, _box(Vector3(0.1, 0.14, 0.5 if long else 0.26), CLOTH["wood"]), Vector3(0, 0, 0.2), Vector3.ZERO, 1.0)
		_part(_gun, _box(Vector3(0.07, 0.07, 0.8 if long else 0.34), CLOTH["iron"]), Vector3(0, 0.05, 0.6 if long else 0.34), Vector3.ZERO, 1.0)
	_shield = Node3D.new()
	_shield.name = "Shield"
	_arm_l.add_child(_shield)
	_shield.position = Vector3(0.28, -0.7, 0.3)
	_part(_shield, Kenney.mesh("dungeon", "shield-round"), Vector3.ZERO, Vector3(0, 90, 0), 2.2)
	_shield.visible = false


func _part(parent: Node3D, mesh: Mesh, at: Vector3, rot_deg: Vector3, s: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation_degrees = rot_deg
	mi.scale = Vector3.ONE * s
	parent.add_child(mi)
	_meshes.append(mi)


static var _prim: Dictionary = {}


## Flat-colour box and stick meshes in the toon surface, shared by size and colour.
static func _box(size: Vector3, c: Color) -> Mesh:
	var key: String = "b%s%s" % [size, c.to_html(false)]
	if not _prim.has(key):
		var m := BoxMesh.new()
		m.size = size
		m.material = _flat(c)
		_prim[key] = m
	return _prim[key] as Mesh


static func _stick(r: float, h: float, c: Color) -> Mesh:
	var key: String = "s%.2f%.2f%s" % [r, h, c.to_html(false)]
	if not _prim.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 8
		m.rings = 1
		m.material = _flat(c)
		_prim[key] = m
	return _prim[key] as Mesh


static func _flat(c: Color) -> Material:
	var sm := StandardMaterial3D.new()
	sm.albedo_color = c
	return Kenney.toon(sm)


func flash(result: String) -> void:
	_flash_left = 0.18
	match result:
		"parried":
			_flash_color = Color(1.0, 1.0, 0.4)
		"blocked", "guard_broken":
			_flash_color = Color(0.6, 0.8, 1.0)
		_:
			_flash_color = Color(1.0, 0.35, 0.3)


func _process(delta: float) -> void:
	if fighter == null or _anim == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	_sync(delta)


## Starts a looping or one-shot animation, or scrubs a timed one to `t` seconds.
func _play(name: String, blend: float) -> void:
	if name == _anim_name:
		return
	_anim_name = name
	_scrub = false
	_anim.play(name, blend)


func _scrub_to(name: String, seconds: float) -> void:
	if name != _anim_name or not _scrub:
		_anim_name = name
		_anim.play(name, 0.04)
		_anim.pause()
		_scrub = true
	var len: float = _anim.get_animation(name).length
	_anim.seek(clampf(seconds, 0.0, len - 0.001), true)


## Hit flash is a plain uniform, so a fighter takes private copies of its materials the first time it flashes.
func _set_flash(c: Color) -> void:
	for mi in _meshes:
		if not _owned:
			if mi.material_override != null:
				mi.material_override = mi.material_override.duplicate()
			for i in mi.mesh.get_surface_count():
				var o: Material = mi.get_surface_override_material(i)
				if o != null:
					mi.set_surface_override_material(i, o.duplicate())
		if mi.material_override is ShaderMaterial:
			(mi.material_override as ShaderMaterial).set_shader_parameter("flash", c)
		for i in mi.mesh.get_surface_count():
			var o2: Material = mi.get_surface_override_material(i)
			if o2 is ShaderMaterial:
				(o2 as ShaderMaterial).set_shader_parameter("flash", c)
	_owned = true


func _sync(delta: float) -> void:
	var moved: float = fighter.pos.distance_to(_last_pos)
	_last_pos = fighter.pos
	_speed = lerpf(_speed, moved / maxf(delta, 0.0001) if delta > 0.0 else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	position = Vector3(fighter.pos.x, 0.0, fighter.pos.y)
	rotation.y = atan2(fighter.dir.x, fighter.dir.y)
	var flash_c := Color(_flash_color.r, _flash_color.g, _flash_color.b, 0.6 if _flash_left > 0.0 else 0.0)
	if flash_c != _last_flash:
		_last_flash = flash_c
		_set_flash(flash_c)
	_pivot.rotation_degrees = Vector3.ZERO
	_pivot.position = Vector3.ZERO
	if _shield != null:
		_shield.visible = fighter.state == FighterState.State.BLOCK
	var armed: bool = fighter.melee != "none"
	match fighter.state:
		FighterState.State.SWING:
			var dur: float = maxf(fighter.swing_dur, 0.01)
			var t: float = clampf(fighter.state_t / dur, 0.0, 1.0)
			var left: bool = fighter.combo % 2 == 1
			var name: String = "attack-melee-left" if left else "attack-melee-right"
			_scrub_to(name, t * _anim.get_animation(name).length)
		FighterState.State.BLOCK:
			_play("holding-both", 0.06)
			_pivot.rotation_degrees.x = 6.0
		FighterState.State.STAGGER:
			_play("idle", 0.05)
			_pivot.rotation_degrees.x = -22.0
		FighterState.State.DODGE:
			_play("sprint", 0.05)
			_pivot.rotation_degrees.x = 35.0
			_pivot.position.y = -0.25
		FighterState.State.KICK:
			_scrub_to("attack-kick-right", clampf(fighter.state_t / DeckData.KICK_TIME_S, 0.0, 1.0) * _anim.get_animation("attack-kick-right").length)
		FighterState.State.DOWN, FighterState.State.DEAD:
			_scrub_to("die", fighter.state_t)
		_:
			if _speed > 3.2:
				_play("sprint", 0.1)
				_anim.speed_scale = clampf(_speed / 4.5, 0.8, 1.6)
			elif _speed > 0.25:
				_play("walk", 0.1)
				_anim.speed_scale = clampf(_speed / 1.6, 0.6, 1.8)
			else:
				_play("holding-right" if armed and not pose_idle_only else "idle", 0.12)
				_anim.speed_scale = 1.0
	visible = not fighter.overboard
	var tag: String = fighter.display_name if fighter.display_name != "" else fighter.kind
	_label.text = "%s  %d" % [tag, ceili(maxf(fighter.hp, 0.0))] if fighter.is_alive() else ""
	_label.modulate = Color(1, 1, 1) if fighter.team == 0 else Color(1.0, 0.65, 0.6)
