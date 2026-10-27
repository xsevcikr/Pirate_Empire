class_name CannonTower
extends DestructibleBuilding
## A fort tower with six guns: fires at ships its faction is hostile to until it is destroyed.

const RANGE_M: float = 450.0
const SHOT_EVERY_S: float = 7.0
const GUN: String = "12pdr"

var world: Node
var _cool: float = 3.0


func _ready() -> void:
	super()
	add_to_group("towers")
	var top := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = size.x * 0.58
	cm.bottom_radius = size.x * 0.5
	cm.height = 1.6
	top.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = wall_color.darkened(0.1)
	top.material_override = m
	top.position.y = size.y + 0.8
	add_child(top)
	for k in 3:
		var barrel := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.28
		bm.bottom_radius = 0.36
		bm.height = 3.0
		barrel.mesh = bm
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.1, 0.1, 0.11)
		barrel.material_override = bmat
		var a: float = float(k) * 0.55 - 0.55
		barrel.position = Vector3(sin(a) * size.x * 0.6, size.y + 1.0, cos(a) * size.x * 0.6)
		barrel.rotation = Vector3(deg_to_rad(80.0), a, 0.0)
		add_child(barrel)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_alive() or world == null:
		return
	for k in alert.keys():
		alert[k] = float(alert[k]) - delta / maxf(float(get_tree().get_nodes_in_group("towers").size()), 1.0)
		if float(alert[k]) <= 0.0:
			alert.erase(k)
	_cool -= delta
	if _cool > 0.0:
		return
	var target: Ship = _pick_target()
	if target == null:
		return
	_cool = SHOT_EVERY_S
	var from: Vector3 = global_position + Vector3(0, size.y + 1.0, 0)
	var to: Vector3 = target.global_position + Vector3(randf_range(-6, 6), 1.0, randf_range(-6, 6))
	var dist: float = from.distance_to(to)
	var v: float = float(GunData.GUNS[GUN]["velocity"])
	var dir: Vector3 = (to - from).normalized()
	# lob: raise the aim by the drop over the flight time
	var t: float = dist / v
	dir.y += 0.5 * GunData.shot_gravity(GUN) * t / v
	world.projectiles.fire(from, dir.normalized() * v, GUN, "round", self)
	Vfx.muzzle(get_parent(), from + dir.normalized() * 2.0, dir.normalized())


## Ports that were attacked this session: port id -> seconds of alert left. Their towers fire on the player.
static var alert: Dictionary = {}
const ALERT_S: float = 180.0


static func raise_alert(port: String) -> void:
	alert[port] = ALERT_S


func _pick_target() -> Ship:
	var best: Ship = null
	var best_d: float = RANGE_M
	var faction: String = _faction()
	var hunted: bool = Session.has_state() and float(Session.state["rep"].get(faction, 0.0)) <= -60.0
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s.damage.sunk:
			continue
		var wanted: bool
		if s.ai == null:  # the player
			wanted = hunted or float(alert.get(port_id, 0.0)) > 0.0
		else:
			wanted = FactionRel.hostile(faction.replace("_dominion", ""), s.faction.replace("_dominion", ""))
		if not wanted:
			continue
		var d: float = s.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _faction() -> String:
	return str(PortData.PORTS[port_id]["faction"]) if PortData.PORTS.has(port_id) else "none"
