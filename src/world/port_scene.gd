class_name PortScene
extends Node3D
## The harbour of a city: a pier running from the dock point in to the island, warehouses and houses in the
## faction's style (more of them in bigger cities), a flag, lantern, and a cannon tower for forts and capitals.

const PIER_WIDTH_M: float = 6.0
const PIER_HEIGHT_M: float = 1.4
const WOOD := Color(0.36, 0.24, 0.14)
const BUILDINGS_BY_TIER: Dictionary = {"village": 3, "town": 5, "city": 7, "capital": 9}

var port_id: String = PortData.START_PORT


func _ready() -> void:
	var port: Dictionary = PortData.PORTS[port_id]
	var dock: Vector2 = port["dock"]
	var isl: Dictionary = PortData.gen().islands[port["island"]]
	var to_island: Vector2 = (isl["pos"] as Vector2) - dock
	position = Vector3(dock.x, 0.0, dock.y)
	rotation.y = atan2(-to_island.x, -to_island.y)  # local -z points at the island
	var style: Dictionary = IslandData.style(port["faction"])
	var length: float = maxf(to_island.length() - float(isl["radius"]) * 0.85, 40.0)
	_box(Vector3(PIER_WIDTH_M, 0.4, length), Vector3(0, PIER_HEIGHT_M, -length * 0.5 - 6.0), WOOD)
	for i in 8:
		var z: float = -6.0 - float(i) * length / 7.0
		_box(Vector3(0.5, 3.0, 0.5), Vector3(PIER_WIDTH_M * 0.5 - 0.3, PIER_HEIGHT_M - 1.2, z), WOOD)
		_box(Vector3(0.5, 3.0, 0.5), Vector3(-PIER_WIDTH_M * 0.5 + 0.3, PIER_HEIGHT_M - 1.2, z), WOOD)
	var houses: int = int(BUILDINGS_BY_TIER[port["tier"]])
	for i in houses:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z2: float = -length + 14.0 + float(i) * (length - 22.0) / float(maxi(houses, 1))
		var w: float = 8.0 + float(i % 3) * 2.0
		var h: float = 4.0 + float(i % 4) * 1.5
		_building(style, Vector3(side * (14.0 + float(i % 2) * 6.0), PIER_HEIGHT_M, z2), Vector3(w, h, 8.0))
	_flag(style["flag"], Vector3(PIER_WIDTH_M * 0.5, PIER_HEIGHT_M, -length * 0.5))
	if port["tier"] in ["capital", "city"] or port["faction"] == "navy":
		_tower(style, Vector3(-22.0, PIER_HEIGHT_M, -length + 6.0))
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0, PIER_HEIGHT_M + 4.0, -8.0)
	lantern.light_color = Color(1.0, 0.75, 0.4)
	lantern.omni_range = 40.0
	add_child(lantern)
	_box(Vector3(0.4, 4.0, 0.4), Vector3(0, PIER_HEIGHT_M + 2.0, -8.0), WOOD)


func _building(style: Dictionary, base: Vector3, size: Vector3) -> void:
	_box(size, base + Vector3(0, size.y * 0.5, 0), (style["wall"] as Color).darkened(0.22))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 1.2, size.y * 0.45, size.z + 1.2)
	roof.mesh = prism
	roof.material_override = _mat(style["roof"])
	roof.position = base + Vector3(0, size.y + prism.size.y * 0.5, 0)
	add_child(roof)
	_box(Vector3(1.6, 2.6, 0.2), base + Vector3(0, 1.3, -size.z * 0.5 - 0.05 if base.x > 0.0 else size.z * 0.5 + 0.05), WOOD.darkened(0.3))


func _tower(style: Dictionary, base: Vector3) -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.5
	cyl.bottom_radius = 5.5
	cyl.height = 12.0
	body.mesh = cyl
	body.material_override = _mat(style["wall"])
	body.position = base + Vector3(0, 6.0, 0)
	add_child(body)
	for k in 3:
		var barrel := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.3
		bm.bottom_radius = 0.4
		bm.height = 3.4
		barrel.mesh = bm
		barrel.material_override = _mat(Color(0.12, 0.12, 0.13))
		var a: float = float(k) * 0.5 - 0.5
		barrel.position = base + Vector3(sin(a) * 4.6, 11.0, cos(a) * 4.6 - 1.0)
		barrel.rotation = Vector3(deg_to_rad(80.0), a, 0.0)
		add_child(barrel)


func _flag(color: Color, base: Vector3) -> void:
	_box(Vector3(0.3, 11.0, 0.3), base + Vector3(0, 5.5, 0), WOOD.darkened(0.2))
	_box(Vector3(0.1, 2.2, 3.4), base + Vector3(0, 9.6, 1.8), color)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	add_child(mi)
