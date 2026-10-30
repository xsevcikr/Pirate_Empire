class_name PortScene
extends Node3D
## The harbour of a city: a pier running from the dock point in to the island, warehouses and houses in the
## faction's style (more of them in bigger cities), a crane, a flag, and a fort with a wall, gate and cannon towers.
## Every building is destructible; what the save says was destroyed stays a ruin until it is rebuilt.

signal building_destroyed(building: DestructibleBuilding, by_player: bool)

const PIER_WIDTH_M: float = 6.0
const PIER_HEIGHT_M: float = 1.4
const WOOD := Color(0.36, 0.24, 0.14)
const BUILDINGS_BY_TIER: Dictionary = {"village": 3, "town": 5, "city": 7, "capital": 9}
const SEGMENT_W_M: Array[float] = [12.0, 11.0, 10.0]

var port_id: String = PortData.START_PORT
var world: Node
var buildings: Array[DestructibleBuilding] = []
var fort_level: int = 1
var staged: bool = false
var _fort_length: float = 0.0
var _fort_built: bool = false
var _style: Dictionary = {}


## Fort level of a port: capitals of the great powers 3, other capitals 2, everyone else 1.
static func fort_level_of(port: Dictionary) -> int:
	if port["tier"] == "capital":
		return 3 if port["faction"] in ["navy", "iron_dominion"] else 2
	if port["tier"] == "city" and port["faction"] in ["navy", "iron_dominion"]:
		return 2
	return 1


func _ready() -> void:
	var port: Dictionary = PortData.PORTS[port_id]
	var dock: Vector2 = port["dock"]
	var isl: Dictionary = PortData.gen().islands[port["island"]]
	var to_island: Vector2 = (isl["pos"] as Vector2) - dock
	position = Vector3(dock.x, 0.0, dock.y)
	rotation.y = atan2(-to_island.x, -to_island.y)  # local -z points at the island
	_style = IslandData.style(port["faction"])
	fort_level = fort_level_of(port)
	var length: float = maxf(to_island.length() - float(isl["radius"]) * 0.85, 40.0)
	_make("dock", 0, Vector3(0, PIER_HEIGHT_M - 0.2, -length * 0.5 - 6.0), Vector3(PIER_WIDTH_M, 0.4, length), WOOD, WOOD)
	for i in 8:
		var z: float = -6.0 - float(i) * length / 7.0
		_post(Vector3(PIER_WIDTH_M * 0.5 - 0.3, PIER_HEIGHT_M - 1.2, z))
		_post(Vector3(-PIER_WIDTH_M * 0.5 + 0.3, PIER_HEIGHT_M - 1.2, z))
	var houses: int = int(BUILDINGS_BY_TIER[port["tier"]])
	for i in houses:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z2: float = -length + 14.0 + float(i) * (length - 22.0) / float(maxi(houses, 1))
		var warehouse: bool = i % 3 == 0
		var sz: Vector3 = Vector3(10.0, 6.0, 9.0) if warehouse else Vector3(6.0 + float(i % 3), 4.0 + float(i % 2), 6.0)
		_make("warehouse" if warehouse else "house", i, Vector3(side * (14.0 + float(i % 2) * 6.0), PIER_HEIGHT_M, z2), sz,
			(_style["wall"] as Color).darkened(0.22), _style["roof"])
	_make("crane", 0, Vector3(PIER_WIDTH_M * 0.5 + 2.5, PIER_HEIGHT_M, -length * 0.25), Vector3(1.6, 12.0, 1.6), WOOD.darkened(0.2), WOOD)
	if port["tier"] in ["capital", "city"]:
		_make("lighthouse", 0, Vector3(30.0, PIER_HEIGHT_M, -length + 4.0), Vector3(5.0, 22.0, 5.0), Color(0.86, 0.84, 0.78), Color(0.6, 0.2, 0.15))
	_flag(_style["flag"], Vector3(PIER_WIDTH_M * 0.5, PIER_HEIGHT_M, -length * 0.5))
	_fort_length = length
	if not staged:
		build_fort()
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0, PIER_HEIGHT_M + 4.0, -8.0)
	lantern.light_color = Color(1.0, 0.75, 0.4)
	lantern.omni_range = 40.0
	add_child(lantern)
	_post(Vector3(0, PIER_HEIGHT_M + 2.0, -8.0), Vector3(0.4, 4.0, 0.4))


## The fort goes up on its own frame when the streamer builds the harbour, so a port never costs one long frame.
func build_fort() -> void:
	if _fort_built:
		return
	_fort_built = true
	_build_fort(_fort_length)


func _island_ground(local: Vector3) -> float:
	var parent: Node = get_parent()
	if parent == null:
		return 0.0
	var isl: Island = parent.get_node_or_null("Island_%d" % int(PortData.PORTS[port_id]["island"])) as Island
	if isl == null or not isl.is_inside_tree():
		return 0.0
	var world_p: Vector3 = to_global(local)
	return maxf(isl.ground_y(Vector2(world_p.x - isl.global_position.x, world_p.z - isl.global_position.z)), 0.0)


## A wall of segments across the island behind the pier, a gate in the middle and a cannon tower at each end.
func _build_fort(length: float) -> void:
	var n: int = DestructionData.WALL_SEGMENTS[fort_level - 1]
	var w: float = SEGMENT_W_M[fort_level - 1]
	var z: float = -length - 22.0
	var wall_col: Color = (_style["wall"] as Color).darkened(0.3)
	for i in n:
		var x: float = (float(i) - float(n - 1) * 0.5) * w
		var gate: bool = i == n / 2
		var at := Vector3(x, _island_ground(Vector3(x, 0, z)), z)
		_make("gate" if gate else "wall", i, at, Vector3(w, 7.0 if gate else 6.0, 3.0), wall_col, wall_col, fort_level)
	var span: float = float(n) * w * 0.5 + 4.0
	var towers: Array[float] = [-span, span]
	if fort_level >= 2:
		towers.append_array([-span * 0.5, span * 0.5])
	for i in towers.size():
		var x: float = towers[i]
		_make("tower", i, Vector3(x, _island_ground(Vector3(x, 0, z)), z), Vector3(6.0, 11.0, 6.0), wall_col.darkened(0.1), wall_col)


func _make(kind: String, idx: int, at: Vector3, size: Vector3, wall: Color, roof: Color, level: int = 1) -> DestructibleBuilding:
	var b: DestructibleBuilding = CannonTower.new() if kind == "tower" else DestructibleBuilding.new()
	var id: String = "%s:%s:%d" % [port_id, kind, idx]
	b.setup(kind, level, id, port_id, size, wall, roof)
	b.position = at
	if Session.has_state() and Session.state.get("destroyed", {}).has(id):
		b.is_ruin = true
	if b is CannonTower:
		(b as CannonTower).world = world
	add_child(b)
	buildings.append(b)
	b.destroyed.connect(func(bb: DestructibleBuilding, by_player: bool) -> void:
		if Session.has_state():
			Session.state["destroyed"][bb.building_id] = int(Session.state["day"])
		building_destroyed.emit(bb, by_player))
	return b


## Bring back buildings whose three days are up.
func rebuild_due() -> int:
	var n: int = 0
	for b in buildings:
		if b.is_ruin and not (Session.state.get("destroyed", {}).has(b.building_id)):
			b.rebuild()
			n += 1
	return n


func _post(pos: Vector3, sz: Vector3 = Vector3(0.5, 3.0, 0.5)) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = sz
	mi.mesh = mesh
	mi.material_override = _mat(WOOD)
	mi.position = pos
	add_child(mi)


func _flag(color: Color, base: Vector3) -> void:
	_post(base + Vector3(0, 5.5, 0), Vector3(0.3, 11.0, 0.3))
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 2.2, 3.4)
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = base + Vector3(0, 9.6, 1.8)
	add_child(mi)


func _mat(color: Color) -> ShaderMaterial:
	return Kenney.flat(Look.cartoon(color))
