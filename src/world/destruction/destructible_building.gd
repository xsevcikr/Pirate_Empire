class_name DestructibleBuilding
extends StaticBody3D
## One breakable piece of a harbour or fort: a wall segment, tower, gate, dock, warehouse, crane, house or lighthouse.
## Cannonballs hit it (collision layer 4). It cracks at 66% and 33% of its HP, then collapses into rubble and burns;
## the save remembers it as destroyed until it is rebuilt three days later.

signal destroyed(building: DestructibleBuilding, by_player: bool)

var kind: String = "house"
var level: int = 1
var port_id: String = ""
var building_id: String = ""
var size: Vector3 = Vector3(8, 5, 8)
var wall_color: Color = Color(0.6, 0.5, 0.4)
var roof_color: Color = Color(0.4, 0.15, 0.1)
var max_hp: float = 250.0
var hp: float = 250.0
var is_ruin: bool = false
var _body: MeshInstance3D
var _roof: MeshInstance3D
var _material: StandardMaterial3D
var _stage: int = 0
var _burn_left: float = 0.0
var _fx_accum: float = 0.0


func _init() -> void:
	collision_layer = 4
	collision_mask = 0


func setup(k: String, lvl: int, id: String, port: String, sz: Vector3, wall: Color, roof: Color) -> void:
	kind = k
	level = lvl
	building_id = id
	port_id = port
	size = sz
	wall_color = wall
	roof_color = roof
	max_hp = DestructionData.hp_of(k, lvl)
	hp = max_hp


func _ready() -> void:
	add_to_group("destructible")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	_material = StandardMaterial3D.new()
	_material.albedo_color = wall_color
	_material.roughness = 0.95
	_body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_body.mesh = bm
	_body.material_override = _material
	_body.position.y = size.y * 0.5
	add_child(_body)
	TownBuilder.dress_body(_body, kind, size, building_id.hash())
	if kind in ["house", "warehouse"]:
		_roof = MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(size.x + 1.2, size.y * 0.45, size.z + 1.2)
		_roof.mesh = prism
		var rm := StandardMaterial3D.new()
		rm.albedo_color = roof_color
		_roof.material_override = rm
		_roof.position.y = size.y + prism.size.y * 0.5
		add_child(_roof)
	if is_ruin:
		_collapse(false, false)


func fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func is_alive() -> bool:
	return hp > 0.0 and not is_ruin


## Called by the projectile manager. Returns the damage dealt.
func take_shot(world_pos: Vector3, _normal: Vector3, _dir: Vector3, gun_id: String, ammo_id: String, distance: float, source: Node) -> Dictionary:
	if not is_alive():
		return {"damage": 0.0}
	var dmg: float = DestructionData.shot_damage(gun_id, distance, ammo_id)
	var ricochet: bool = false
	var by_player: bool = source is Ship and (source as Ship).ai == null
	if by_player and PortData.PORTS.has(port_id):
		CannonTower.raise_alert(port_id)
	hurt(dmg, by_player)
	Vfx.burst(get_parent(), world_pos, Color(0.7, 0.62, 0.5), 10, 7.0, 0.5, 0.08, -9.8, 90.0, Vector3.UP)
	return {"damage": dmg, "ricochet": ricochet}


func hurt(dmg: float, by_player: bool = false) -> void:
	if not is_alive():
		return
	hp = maxf(hp - dmg, 0.0)
	_apply_cracks()
	if hp <= 0.0:
		_collapse(true, by_player)


func _apply_cracks() -> void:
	var stage: int = DestructionData.crack_stage(fraction())
	if stage == _stage or stage >= 3:
		return
	_stage = stage
	_material.albedo_color = wall_color.darkened(0.18 * float(stage))
	# a dark crack slab on the front face for each stage reached
	var crack := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(size.x * 0.08, size.y * (0.5 + 0.2 * float(stage)), 0.08)
	crack.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.04, 0.04)
	crack.material_override = mat
	crack.position = Vector3(size.x * (0.12 * float(stage) - 0.2), size.y * 0.5, size.z * 0.5 + 0.05)
	crack.rotation.z = 0.35 * float(stage)
	add_child(crack)


## Fall into rubble: the intact mesh goes, rubble pieces drop, a fire burns for a while.
func _collapse(announce: bool, by_player: bool) -> void:
	is_ruin = true
	hp = 0.0
	collision_layer = 0
	if _body != null:
		_body.visible = false
	if _roof != null:
		_roof.visible = false
	var debris: DebrisManager = get_tree().get_first_node_in_group("debris") as DebrisManager if is_inside_tree() else null
	if debris != null:
		for i in DestructionData.RUBBLE_PIECES:
			var s := Vector3(size.x, size.y, size.z) * (0.18 + 0.05 * float(i))
			var at: Vector3 = global_position + Vector3((float(i) - 1.5) * size.x * 0.22, size.y * 0.7 + float(i) * 0.5, (float(i % 2) - 0.5) * size.z * 0.3)
			debris.spawn_rubble(at, s, wall_color.darkened(0.2 * float(i % 3)), Vector3(0, 40.0, 0))
	_burn_left = DestructionData.BURN_S if announce else 0.0
	if announce:
		destroyed.emit(self, by_player)


func _physics_process(delta: float) -> void:
	if _burn_left > 0.0:
		_burn_left -= delta
		_fx_accum += delta
		if _fx_accum >= 0.6:
			_fx_accum = 0.0
			Vfx.flames(get_parent(), global_position + Vector3(0, 1.5, 0))


## Rebuild: whole again, full HP.
func rebuild() -> void:
	is_ruin = false
	hp = max_hp
	_stage = 0
	collision_layer = 4
	_material.albedo_color = wall_color
	if _body != null:
		_body.visible = true
	if _roof != null:
		_roof.visible = true
	for c in get_children():
		if c is MeshInstance3D and c != _body and c != _roof:
			c.queue_free()
