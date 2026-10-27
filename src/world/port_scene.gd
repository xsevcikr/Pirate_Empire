class_name PortScene
extends Node3D
## A small harbour for a port: a pier running out from the island to the dock point, a few warehouses and a lantern.
## Plain boxes for now; the named, styled cities arrive in M16.

const PIER_WIDTH_M: float = 6.0
const PIER_HEIGHT_M: float = 1.4
const WOOD := Color(0.36, 0.24, 0.14)
const ROOF := Color(0.45, 0.16, 0.12)

var port_id: String = PortData.START_PORT


func _ready() -> void:
	var dock: Vector2 = PortData.PORTS[port_id]["dock"]
	var island_edge_z: float = 150.0
	position = Vector3(dock.x, 0.0, dock.y)
	var length: float = dock.y - island_edge_z - 12.0
	_box(Vector3(PIER_WIDTH_M, 0.4, length), Vector3(0, PIER_HEIGHT_M, -length * 0.5 - 6.0), WOOD)
	for i in 8:
		var z: float = -6.0 - float(i) * length / 7.0
		_box(Vector3(0.5, 3.0, 0.5), Vector3(PIER_WIDTH_M * 0.5 - 0.3, PIER_HEIGHT_M - 1.2, z), WOOD)
		_box(Vector3(0.5, 3.0, 0.5), Vector3(-PIER_WIDTH_M * 0.5 + 0.3, PIER_HEIGHT_M - 1.2, z), WOOD)
	for i in 6:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var z2: float = -length + 14.0 + float(i) * 11.0
		_box(Vector3(9, 5, 8), Vector3(side * 16.0, PIER_HEIGHT_M + 2.5, z2), WOOD)
		_box(Vector3(10, 1.2, 9), Vector3(side * 16.0, PIER_HEIGHT_M + 5.6, z2), ROOF)
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0, PIER_HEIGHT_M + 4.0, -8.0)
	lantern.light_color = Color(1.0, 0.75, 0.4)
	lantern.omni_range = 40.0
	add_child(lantern)
	_box(Vector3(0.4, 4.0, 0.4), Vector3(0, PIER_HEIGHT_M + 2.0, -8.0), WOOD)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
