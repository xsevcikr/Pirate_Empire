class_name DeckFighterView
extends Node3D
## A capsule man with a blade arm and a shield disc. Poses follow the fighter's state each frame.

const TEAM_COLORS: Array[Color] = [Color(0.2, 0.45, 0.8), Color(0.75, 0.2, 0.2)]
const KIND_SCALE: Dictionary = {"brute": 1.25, "captain": 1.15, "captain_player": 1.05}
const SWING_ARC_DEG: float = 130.0

var fighter: FighterState
var _body: MeshInstance3D
var _arm: Node3D
var _shield: MeshInstance3D
var _label: Label3D
var _mat: StandardMaterial3D
var _flash_left: float = 0.0
var _flash_color: Color = Color.WHITE


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color()
	_body = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	_body.mesh = cap
	_body.material_override = _mat
	_body.position.y = 0.9
	add_child(_body)
	_arm = Node3D.new()
	_arm.position = Vector3(0.0, 1.2, 0.0)
	add_child(_arm)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 1.1)
	blade.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.82, 0.84, 0.88)
	bmat.metallic = 0.8
	blade.material_override = bmat
	blade.position = Vector3(0.35, 0.0, 0.75)
	_arm.add_child(blade)
	_shield = MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.45
	sm.bottom_radius = 0.45
	sm.height = 0.06
	_shield.mesh = sm
	_shield.rotation_degrees.x = 90.0
	_shield.position = Vector3(0.0, 1.1, 0.55)
	_shield.visible = false
	add_child(_shield)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 20
	_label.pixel_size = 0.01
	_label.no_depth_test = true
	_label.position.y = 2.4
	add_child(_label)
	var s: float = KIND_SCALE.get(fighter.kind, 1.0)
	scale = Vector3.ONE * s
	_sync()


func _base_color() -> Color:
	if fighter.is_player:
		return Color(0.95, 0.8, 0.25)
	return TEAM_COLORS[fighter.team]


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
	if fighter == null or _mat == null:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	_sync()


func _sync() -> void:
	position = Vector3(fighter.pos.x, 0.0, fighter.pos.y)
	rotation.y = atan2(fighter.dir.x, fighter.dir.y)
	_mat.albedo_color = _flash_color if _flash_left > 0.0 else _base_color()
	_shield.visible = fighter.state == FighterState.State.BLOCK
	_arm.rotation_degrees = Vector3.ZERO
	_body.rotation_degrees = Vector3.ZERO
	_body.position.y = 0.9
	match fighter.state:
		FighterState.State.SWING:
			var t: float = clampf(fighter.state_t / maxf(fighter.swing_dur, 0.01), 0.0, 1.0)
			_arm.rotation_degrees.y = lerpf(SWING_ARC_DEG * 0.5, -SWING_ARC_DEG * 0.5, t) * (1.0 if fighter.combo % 2 == 0 else -1.0)
			_arm.rotation_degrees.x = -30.0 if fighter.swing_heavy else 0.0
		FighterState.State.STAGGER:
			_body.rotation_degrees.x = -18.0
		FighterState.State.DODGE:
			_body.rotation_degrees.x = 35.0
			_body.position.y = 0.6
		FighterState.State.KICK:
			_body.rotation_degrees.x = -12.0
		FighterState.State.DOWN, FighterState.State.DEAD:
			_body.rotation_degrees.x = 88.0
			_body.position.y = 0.4
	visible = not fighter.overboard
	var tag: String = fighter.display_name if fighter.display_name != "" else fighter.kind
	_label.text = "%s  %d" % [tag, ceili(maxf(fighter.hp, 0.0))] if fighter.is_alive() else ""
