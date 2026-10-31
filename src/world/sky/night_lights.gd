class_name NightLights
extends Node
## Stern lanterns on every ship at sea, lit from dusk to dawn. The glow shows on all of them; only the ships near
## the camera cast real light, to keep the light count low.

const LIGHT_RANGE_M: float = 16.0
const REAL_LIGHT_WITHIN_M: float = 260.0
const SCAN_EVERY_S: float = 1.0
const LANTERN: Color = Color(1.0, 0.72, 0.36)

var night: float = 0.0  ## DayNight sets this, 0..1
var _scan_in: float = 0.0
var _lanterns: Array[Node3D] = []
var _mat: StandardMaterial3D


func _init() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = LANTERN
	_mat.emission_enabled = true
	_mat.emission = LANTERN
	_mat.emission_energy_multiplier = 3.0


## Puts a lantern on `ship`'s stern rail if it has none yet.
func fit(ship: Ship) -> Node3D:
	if ship.has_meta("lantern"):
		return ship.get_meta("lantern")
	var root := Node3D.new()
	root.set_meta("kind", "lantern")
	var glass := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.45, 0.6, 0.45)
	glass.mesh = box
	glass.material_override = _mat
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glass)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = LANTERN
	light.omni_range = LIGHT_RANGE_M
	light.shadow_enabled = false
	root.add_child(light)
	var st: ShipStats = ship.stats
	root.position = Vector3(0.0, st.freeboard_m + 2.2, st.length_m * 0.45)
	ship.add_child(root)
	ship.set_meta("lantern", root)
	_lanterns.append(root)
	return root


func _process(delta: float) -> void:
	_scan_in -= delta
	if _scan_in <= 0.0 and is_inside_tree():
		_scan_in = SCAN_EVERY_S
		for n in get_tree().get_nodes_in_group("ships"):
			if n is Ship and (n as Ship).stats != null:
				fit(n)
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var lit: bool = night > 0.35
	var i: int = _lanterns.size() - 1
	while i >= 0:
		var l: Node3D = _lanterns[i]
		if not is_instance_valid(l):
			_lanterns.remove_at(i)
			i -= 1
			continue
		l.visible = lit
		var light: OmniLight3D = l.get_node("Light")
		light.visible = lit and (cam == null or l.global_position.distance_to(cam.global_position) < REAL_LIGHT_WITHIN_M)
		light.light_energy = 2.2 * night
		i -= 1
