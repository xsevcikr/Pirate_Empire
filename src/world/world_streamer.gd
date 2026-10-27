class_name WorldStreamer
extends Node
## Keeps the islands (and the harbours on them) near the player in the scene and frees the rest. At most one
## slice of one island is built per frame, so sailing across the map never stalls a frame.

const LOAD_RADIUS_M: float = 3200.0
const UNLOAD_RADIUS_M: float = 4200.0
const CHECK_S: float = 0.25

var gen: WorldGen
var player: Node3D
var world: Node
signal building_destroyed(building: DestructibleBuilding, by_player: bool)
var loaded: Dictionary = {}  ## island index -> Island
var _unload_due: Array[int] = []
var _forts_due: Array[PortScene] = []
var _ports_due: Array[String] = []
var ports: Dictionary = {}  ## port id -> PortScene
var peak_loaded: int = 0
var loads: int = 0
var unloads: int = 0
var _queue: Array[int] = []
var _building: Island = null
var _accum: float = 99.0


func _init() -> void:
	gen = PortData.gen()
	Island.prewarm()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_accum += delta
	if _accum >= CHECK_S:
		_accum = 0.0
		refresh(Vector2(player.global_position.x, player.global_position.z))
	pump()


## Decide what should be loaded around `at`. Loading itself happens in pump().
func refresh(at: Vector2) -> void:
	for i in gen.islands.size():
		var isl: Dictionary = gen.islands[i]
		var d: float = (isl["pos"] as Vector2).distance_to(at)
		if loaded.has(i):
			if d > UNLOAD_RADIUS_M + float(isl["radius"]) and not _unload_due.has(i):
				_unload_due.append(i)
		elif d <= LOAD_RADIUS_M + float(isl["radius"]) and not _queue.has(i):
			_queue.append(i)
	_queue.sort_custom(func(a: int, b: int) -> bool:
		return (gen.islands[a]["pos"] as Vector2).distance_to(at) < (gen.islands[b]["pos"] as Vector2).distance_to(at))


## One slice of work: finish the island being built or start the nearest queued one.
func pump() -> void:
	if not _forts_due.is_empty():
		var f: PortScene = _forts_due.pop_front()
		if is_instance_valid(f):
			f.build_fort()
		return
	if not _unload_due.is_empty():
		var u: int = _unload_due.pop_front()
		if loaded.has(u):
			_unload(u)
		return
	if not _ports_due.is_empty():
		_build_port(_ports_due.pop_front())
		return
	if _building != null:
		if not is_instance_valid(_building) or not _building.build_next_stage():
			_building = null
		return
	if _queue.is_empty():
		return
	var i: int = _queue.pop_front()
	if loaded.has(i):
		return
	var isl: Dictionary = gen.islands[i]
	var node := Island.make(isl["radius"], 100 + i, isl["biome"])
	node.staged = true
	node.name = "Island_%d" % i
	node.position = Vector3(isl["pos"].x, 0.0, isl["pos"].y)
	add_child(node)
	loaded[i] = node
	_building = node
	loads += 1
	peak_loaded = maxi(peak_loaded, loaded.size())
	if isl["city"] != "":
		_ports_due.append(IslandData.port_id_of(isl["city"]))


## The harbour's buildings are a frame of work of their own, so a port is built the pump after its island.
func _build_port(id: String) -> void:
	var ps := PortScene.new()
	ps.staged = true
	_forts_due.append(ps)
	ps.port_id = id
	ps.world = world
	ps.building_destroyed.connect(func(b: DestructibleBuilding, by_player: bool) -> void: building_destroyed.emit(b, by_player))
	add_child(ps)
	ports[id] = ps


func _unload(i: int) -> void:
	var node: Island = loaded[i]
	if node == _building:
		_building = null
	node.queue_free()
	loaded.erase(i)
	unloads += 1
	var city: String = gen.islands[i]["city"]
	if city != "":
		var id: String = IslandData.port_id_of(city)
		_ports_due.erase(id)
		if ports.has(id):
			ports[id].queue_free()
			ports.erase(id)


## Everything wanted near `at` is built; for tests and the first load.
func load_all_near(at: Vector2) -> void:
	refresh(at)
	while not _queue.is_empty() or _building != null:
		pump()
