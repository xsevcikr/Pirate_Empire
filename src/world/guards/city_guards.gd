class_name CityGuards
extends Node
## Puts the city watch to sea: the first cannonball the player lands on a harbour (CannonTower.raise_alert) sends
## that city's guard boats out from the pier to hunt them. Each boat is a normal prize; when the last one is sunk or
## taken the city's war chest is paid out (CityGuardData.pay). Sail far enough off and the watch gives up.

signal wave_launched(port_id: String, count: int)
signal wave_beaten(port_id: String, reward: Dictionary)

const CHECK_EVERY_S: float = 0.5

var world: Node
var ship: Ship
var state: Dictionary = {}
## port id -> Array[Ship] of guard boats still afloat and unbeaten.
var active: Dictionary = {}
## port id -> day its watch was last beaten. Kept for the session only.
var beaten_day: Dictionary = {}
var _accum: float = 0.0


func _ready() -> void:
	if world != null and world.get("prizes") != null:
		(world.prizes as PrizeFlow).prize_resolved.connect(_on_prize_resolved)


func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum < CHECK_EVERY_S:
		return
	_accum = 0.0
	for port_id: String in CannonTower.alert.keys():
		if PortData.PORTS.has(port_id) and CityGuardData.can_launch(port_id, _day(), active, beaten_day):
			launch(port_id)
	for port_id: String in active.keys():
		_check_give_up(port_id)


func _day() -> int:
	var clock: Node = Svc.node("GameClock")
	return int(clock.day) if clock != null else int(state.get("day", 0))


## Send a city's watch out. Returns the boats launched.
func launch(port_id: String) -> Array[Ship]:
	var out: Array[Ship] = []
	if world == null or not PortData.PORTS.has(port_id):
		return out
	var port: Dictionary = PortData.PORTS[port_id]
	var dock: Vector2 = port["dock"]
	var isl: Dictionary = PortData.gen().islands[int(port["island"])]
	var classes: Array = CityGuardData.wave_for(str(port["tier"]))
	var pts: Array[Vector2] = CityGuardData.launch_points(dock, isl["pos"], classes.size(),
		Vector2(ship.global_position.x, ship.global_position.z) if ship != null else null)
	for i in classes.size():
		out.append(_spawn_guard(port_id, str(classes[i]), pts[i], i))
	active[port_id] = out
	wave_launched.emit(port_id, out.size())
	_toast(Loc.t("guards.launched") % [out.size(), port["name"]])
	Sfx.play("bell")
	return out


func _spawn_guard(port_id: String, class_id: String, at: Vector2, idx: int) -> Ship:
	var stats: ShipStats = load("res://data/ships/%s.tres" % class_id) as ShipStats
	var target_pos: Vector3 = ship.global_position if ship != null else Vector3(at.x, 0.0, at.y)
	var yaw: float = rad_to_deg(atan2(-(target_pos.x - at.x), -(target_pos.z - at.y)))
	var s: Ship = world._make_ship(stats, Vector3(at.x, 0.5, at.y), yaw, CityGuardData.GUARD_FACTION)
	s.sail_level = 3
	s.crew.count = stats.crew_max
	s.display_label = Loc.t("guards.boat") % PortData.PORTS[port_id]["name"]
	s.set_meta("city_guard", port_id)
	s.set_meta("rep_faction", _rep_faction(port_id))
	s.set_meta("loot_seed", port_id.hash() + idx * 31 + _day())
	s.set_meta("loot", CityGuardData.BOAT_LOOT.duplicate(true))
	var ai := ShipAI.new()
	ai.ship = s
	ai.personality = "aggressive"
	ai.detect_range = CityGuardData.DETECT_M
	ai.waypoints = [Vector3(at.x, 0.0, at.y), Vector3(target_pos.x, 0.0, target_pos.z)]
	if ship != null:
		ai.target = ship
	s.ai = ai
	s.add_child(ai)
	if world.get("prizes") != null:
		(world.prizes as PrizeFlow).add_target(s)
	return s


## Reputation from beating guards goes against the city's owner, if that faction is one the save tracks.
func _rep_faction(port_id: String) -> String:
	var f: String = str(PortData.PORTS[port_id]["faction"])
	if state.has("rep") and (state["rep"] as Dictionary).has(f):
		return f
	return CityGuardData.GUARD_FACTION


func _on_prize_resolved(info: Dictionary) -> void:
	var s: Variant = info.get("ship")
	if not (s is Ship) or not is_instance_valid(s) or not (s as Ship).has_meta("city_guard"):
		return
	guard_beaten(s as Ship)


## One guard boat is out of the fight. When it was the last of its wave, the city pays up.
func guard_beaten(s: Ship) -> void:
	var port_id: String = str(s.get_meta("city_guard"))
	if not active.has(port_id):
		return
	var boats: Array = active[port_id]
	boats.erase(s)
	if not _alive(boats).is_empty():
		return
	active.erase(port_id)
	beaten_day[port_id] = _day()
	CannonTower.alert.erase(port_id)
	var tier: String = str(PortData.PORTS[port_id]["tier"])
	var reward: Dictionary = CityGuardData.pay(state, tier)
	if ship != null:
		ship.broadside.ammo["round"] = int(ship.broadside.ammo.get("round", 0)) + int(reward["round"])
	_toast(Loc.t("guards.beaten") % [PortData.PORTS[port_id]["name"], int(reward["gold"]), int(reward["round"]), int(reward["pistol_shots"]), int(reward["rum"])])
	Sfx.play("chest")
	Sfx.bark("victory")
	wave_beaten.emit(port_id, reward)


func _alive(boats: Array) -> Array:
	var out: Array = []
	for b: Variant in boats:
		if b is Ship and is_instance_valid(b) and not (b as Ship).damage.sunk:
			out.append(b)
	return out


## The player ran: the watch rows home and the city can call it out again next time it is attacked.
func _check_give_up(port_id: String) -> void:
	if ship == null:
		return
	var dock: Vector2 = PortData.PORTS[port_id]["dock"]
	if Vector2(ship.global_position.x, ship.global_position.z).distance_to(dock) < CityGuardData.GIVE_UP_M:
		return
	for b: Variant in _alive(active[port_id]):
		var s: Ship = b as Ship
		if world.get("prizes") != null:
			(world.prizes as PrizeFlow).targets.erase(s)
		s.queue_free()
	active.erase(port_id)
	CannonTower.alert.erase(port_id)
	_toast(Loc.t("guards.gave_up") % PortData.PORTS[port_id]["name"])


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)
