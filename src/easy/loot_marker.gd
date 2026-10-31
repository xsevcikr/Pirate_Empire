class_name LootMarker
extends Node3D
## A hidden treasure the parrot has spotted: Kenney's pirate chest bobbing on a barrel in the water, with a soft
## golden beam above it so a young captain can find it from far off.

const CHEST_SCALE: float = 2.6
const BEAM_H: float = 40.0

var spot_id: String = ""
var spot: Vector2 = Vector2.ZERO
var ocean: WaveModel

var _float: Node3D
var _beam: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	set_meta("kind", "loot_marker")
	_float = Node3D.new()
	add_child(_float)
	var barrel: Node3D = Kenney.spawn("pirate", "barrel")
	barrel.scale = Vector3.ONE * CHEST_SCALE
	barrel.rotation_degrees = Vector3(90, 0, 0)
	barrel.position = Vector3(0, -0.6, 0)
	_float.add_child(barrel)
	var chest: Node3D = Kenney.spawn("pirate", "chest")
	chest.scale = Vector3.ONE * CHEST_SCALE
	chest.position = Vector3(0, 0.4, 0)
	_float.add_child(chest)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 1.6
	cyl.height = BEAM_H
	cyl.radial_segments = 12
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.28)
	_beam.material_override = mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0, BEAM_H * 0.5, 0)
	add_child(_beam)
	_place()


func _process(delta: float) -> void:
	_t += delta
	_place()
	_float.rotation.y = _t * 0.6
	_float.rotation.z = sin(_t * 1.4) * 0.08


func _place() -> void:
	var h: float = ocean.height_at(spot.x, spot.y) if ocean != null else 0.0
	global_position = Vector3(spot.x, h, spot.y)
