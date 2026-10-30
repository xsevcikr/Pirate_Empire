class_name ConvoyManager
extends Node
## Puts real merchant ships and escorts on the sea for convoys that sail near the player. The convoy record in
## the save state stays the truth: a ship that sinks or is taken is struck off it, so it never arrives.

const CHECK_S: float = 1.0
const DESPAWN_FACTOR: float = 1.8

var world: Node3D
var prizes: PrizeFlow
var _live: Dictionary = {}  ## convoy id -> Array[Ship]
var _accum: float = 0.0


func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < CHECK_S or world == null or world.ship == null:
		return
	_accum = 0.0
	refresh(GameClock.day * 24.0 + GameClock.hour)


func refresh(now_h: float) -> void:
	var p3: Vector3 = world.ship.global_position
	var player := Vector2(p3.x, p3.z)
	for c: Dictionary in TradeNetwork.near(Session.state, now_h, player, TradeData.CONVOY_SPAWN_RANGE_M):
		if not _live.has(int(c["id"])):
			_spawn(c, TradeNetwork.position_at(c, now_h))
	for id: int in _live.keys():
		var c: Dictionary = TradeNetwork.find(Session.state, id)
		if c.is_empty():
			_live.erase(id)
			continue
		var ships: Array = _live[id]
		ships = ships.filter(func(s: Ship) -> bool: return is_instance_valid(s) and not s.damage.sunk)
		_live[id] = ships
		var far: bool = TradeNetwork.position_at(c, now_h).distance_to(player) > TradeData.CONVOY_SPAWN_RANGE_M * DESPAWN_FACTOR
		if far or ships.is_empty():
			for s: Ship in ships:
				s.queue_free()
			_live.erase(id)


func live_ships(convoy_id: int) -> Array:
	return _live.get(convoy_id, [])


func _spawn(c: Dictionary, at: Vector2) -> void:
	var dest: Vector2 = TradeNetwork.dock_of(c["to"])
	var dir: Vector2 = (dest - TradeNetwork.dock_of(c["from"])).normalized()
	var yaw: float = rad_to_deg(atan2(-dir.x, -dir.y))
	var ships: Array[Ship] = []
	var per_ship: float = float(c["units"]) / maxf(float(c["ships"]), 1.0)
	for i in int(c["ships"]):
		var cls: String = ShipRoster.convoy(i, int(c["ships"]))
		var s: Ship = _make(cls, at, dir, i, "merchant", c, yaw)
		s.set_meta("rep_faction", "merchant")
		s.set_meta("loot_seed", 40 + int(c["id"]) + i)
		s.set_meta("loot", {"gold": [20, 60], "cargo": {c["good"]: floorf(per_ship)}})
		ships.append(s)
	for j in int(c["escorts"]):
		var e: Ship = _make(TradeData.ESCORT_STATS, at, dir, int(c["ships"]) + j, "navy", c, yaw)
		e.set_meta("rep_faction", "navy")
		e.set_meta("loot_seed", 90 + int(c["id"]) + j)
		e.set_meta("loot", {"gold": [60, 140]})
		ships.append(e)
	_live[int(c["id"])] = ships


func _make(cls: String, at: Vector2, dir: Vector2, slot: int, faction: String, c: Dictionary, yaw: float) -> Ship:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var pos: Vector2 = at - dir * 60.0 * float(slot) + side * (30.0 if slot % 2 == 0 else -30.0)
	var stats: ShipStats = load("res://data/ships/%s.tres" % cls)
	var s: Ship = world._make_ship(stats, Vector3(pos.x, 0.5, pos.y), yaw, faction)
	s.sail_level = 2
	s.crew.count = maxi(int(stats.crew_max * 0.5), 3)
	s.set_meta("convoy", int(c["id"]))
	var ai := ShipAI.new()
	ai.ship = s
	var d: Vector2 = TradeNetwork.dock_of(c["to"])
	ai.waypoints = [Vector3(d.x, 0.0, d.y)]
	s.ai = ai
	s.add_child(ai)
	prizes.add_target(s)
	return s
