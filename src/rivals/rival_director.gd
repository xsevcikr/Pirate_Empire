class_name RivalDirector
extends Node
## Runs the sea events and the rivals in the live world. Each game hour it rolls the event table for the region
## the ship is in, lets rivals come looking for the player, and puts ships where the events call for them. A rival
## ship that is looted is a win, and a player ship sunk with a rival close by is a loss (the rival levels up, takes a
## trophy and sends a taunt). The rules are in SeaEvents and RivalState; this only connects them to the world.

const SPAWN_DIST_M: float = 900.0
const LOSS_RADIUS_M: float = 2500.0
const BECALMED_KN: float = 0.5
const MAX_CATCH_UP_H: int = 3
const CULL_DIST_M: float = 5000.0  ## event and rival ships this far behind are taken off the sea
const KEEP_NEAR_M: float = 600.0
const MAX_AMBIENT_SHIPS: int = 10

var world: Node
var ship: Ship
var state: Dictionary
var rng := RandomNumberGenerator.new()
var active: Dictionary = {}  ## rival id -> its ship
var _hour_i: int = -1
var _day_i: int = -1
var _saved_wind: float = -1.0
var _bus: Node
var _ambient: Array = []  ## ships this director put on the sea, oldest first


func _ready() -> void:
	_bus = Svc.node("EventBus")
	if state.is_empty() and Session.has_state():
		state = Session.state
	rng.seed = int(state.get("seed", 1)) * 37 + 20
	if _bus != null:
		_bus.prize_taken.connect(_on_prize)
		_bus.player_defeated.connect(_on_defeated)


func _clock_hours() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.day) * 24.0 + float(clock.hour) if clock != null else 0.0


func _hour_of_day() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.hour) if clock != null else 12.0


func pos2() -> Vector2:
	return Vector2(ship.global_position.x, ship.global_position.z)


func _physics_process(_delta: float) -> void:
	if ship == null or state.is_empty():
		return
	var h: int = int(floorf(_clock_hours()))
	if _hour_i < 0:
		_hour_i = h
		_day_i = h / 24
		return
	if h - _hour_i > MAX_CATCH_UP_H:  # a jump of the clock (loading, sleeping) is not time spent at sea
		_hour_i = h
		_day_i = h / 24
	while _hour_i < h:
		_hour_i += 1
		hour_tick(WorldMap.region_at(pos2()), _storm(), float(_hour_i % 24))
	if h / 24 > _day_i:
		_day_i = h / 24
		_day_tick()
	_wind_tick()


func _storm() -> bool:
	return world != null and world.wind.speed_kn >= 25.0


## One game hour: roll the events, then the rivals. Public so tests can drive it.
func hour_tick(region: String, storm: bool, hour: float) -> Array[String]:
	state["day"] = int(state["day"])
	var ctx: Dictionary = SeaEvents.context(state, region, storm, hour)
	var fired: Array[String] = SeaEvents.roll(state, ctx, rng)
	for id in fired:
		_run_event(id, ctx)
	if SeaEvents.becalmed_hour(state) and not SeaEvents.is_becalmed(state):
		_toast("event.calm_ends", [])
	for rid: String in RivalData.ORDER:
		if active.has(rid) and is_instance_valid(active[rid]):
			continue
		if rng.randf() < RivalState.challenge_chance(state, rid, region):
			challenge(rid)
			fired.append("rival:" + rid)
			break
	cull()
	return fired


## Takes event and rival ships that sailed far behind off the sea, and keeps the count at the cap, so a long voyage
## does not fill the world with ships nobody will meet.
func cull() -> void:
	var here: Vector3 = ship.global_position
	var keep: Array = []
	for v in _ambient:
		if is_instance_valid(v):
			keep.append(v)
	_ambient = keep
	var i: int = 0
	while i < _ambient.size():
		var s: Ship = _ambient[i] as Ship
		var d: float = s.global_position.distance_to(here)
		var over_cap: bool = _ambient.size() > MAX_AMBIENT_SHIPS and d > KEEP_NEAR_M
		if d > CULL_DIST_M or over_cap:
			_remove(s)
			_ambient.remove_at(i)
		else:
			i += 1


func _remove(s: Ship) -> void:
	for rid: String in active.keys():
		if active[rid] == s:
			active.erase(rid)
	if world != null and world.prizes != null:
		world.prizes.targets.erase(s)
	s.queue_free()


func _day_tick() -> void:
	var out: Dictionary = SeaEvents.plague_day(state)
	if bool(out.get("cured", false)):
		_toast("event.plague_cured", [])
	elif bool(out.get("active", false)):
		_toast("event.plague_day", [int(out["lost"])])


## The wind drops to a whisper while the ship is becalmed and returns after.
func _wind_tick() -> void:
	if world == null:
		return
	if SeaEvents.is_becalmed(state):
		if _saved_wind < 0.0:
			_saved_wind = world.wind.speed_kn
		world.wind.speed_kn = BECALMED_KN
	elif _saved_wind >= 0.0:
		world.wind.speed_kn = _saved_wind
		_saved_wind = -1.0


func _run_event(id: String, ctx: Dictionary) -> void:
	var out: Dictionary = SeaEvents.apply(id, state, rng, ctx)
	_log(id)
	if str(out["toast"]) != "":
		_toast(str(out["toast"]), out["args"])
	if out.has("sail_damage") and ship != null:
		for i in ship.damage.sail_hp.size():
			ship.damage.sail_hp[i] *= 1.0 - float(out["sail_damage"])
	if out.has("spawn"):
		_spawn_event_ship(str(out["spawn"]), str(out.get("kind", "")))


func _log(what: String) -> void:
	var log: Array = state["log"]
	log.append({"day": int(state["day"]), "kind": "event", "id": what})
	while log.size() > 200:
		log.pop_front()


func _toast(key: String, args: Array) -> void:
	if _bus == null:
		return
	var text: String = Loc.t(key)
	_bus.toast.emit(text % args if not args.is_empty() else text)


func _ahead(dist: float, spread: float = 0.0) -> Vector3:
	var fwd: Vector3 = -ship.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side: Vector3 = fwd.cross(Vector3.UP)
	return ship.global_position + fwd * dist + side * spread


func _spawn_event_ship(kind: String, monster: String) -> void:
	if world == null or ship == null:
		return
	match kind:
		"merchant_convoy":
			var n: int = rng.randi_range(int(SeaEventData.EVENTS["merchant_convoy"]["ships"][0]), int(SeaEventData.EVENTS["merchant_convoy"]["ships"][1]))
			for i in n:
				_spawn("brigantine" if i % 2 == 0 else "schooner", "merchant", _ahead(SPAWN_DIST_M + 90.0 * i, 70.0 * i), {"gold": [150, 500], "cargo": {"sugar": 8}})
			for i in rng.randi_range(0, 2):
				_spawn("sloop", "navy", _ahead(SPAWN_DIST_M - 120.0, -90.0 * (i + 1)), {"gold": [100, 300]})
		"navy_patrol":
			_spawn("frigate", "navy", _ahead(SPAWN_DIST_M), {"gold": [300, 800]})
		"ghost_ship":
			world.spawn_ghost_sloops(pos2() + Vector2(0.0, -SPAWN_DIST_M))
		"monster":
			_start_monster(monster)


func _start_monster(kind: String) -> void:
	var fight_id: String = {"serpent": "sea_serpent", "shark": "shell_king"}.get(kind, "")
	if fight_id == "":  # a siren song: the crew's morale pays unless the ears are waxed
		if world.tours == null or not world.tours.is_protected():
			state["morale"] = maxf(0.0, float(state["morale"]) - 6.0)
		return
	if world.has_method("open_sea_fight"):
		world.open_sea_fight(MonsterFight.new(fight_id, int(state.get("difficulty", 1))))


func _spawn(class_id: String, faction: String, at: Vector3, loot: Dictionary) -> Ship:
	var s: Ship = world._make_ship(load("res://data/ships/%s.tres" % class_id), Vector3(at.x, 0.5, at.z), rng.randf_range(0.0, 360.0), faction)
	s.sail_level = 2
	s.crew.count = 14
	s.set_meta("rep_faction", faction)
	s.set_meta("loot_seed", rng.randi())
	s.set_meta("loot", loot)
	var ai := ShipAI.new()
	ai.ship = s
	ai.waypoints = [Vector3(at.x + 500.0, 0.0, at.z), Vector3(at.x, 0.0, at.z + 500.0)]
	s.ai = ai
	s.add_child(ai)
	world.prizes.add_target(s)
	_ambient.append(s)
	return s


# ---- rivals --------------------------------------------------------------------------------------

## A rival comes for the player: a ship of their class, scaled by their level.
func challenge(rid: String) -> Ship:
	var d: Dictionary = RivalData.def(rid)
	var st: Dictionary = RivalState.ship_strength(state, rid)
	RivalState.meet(state, rid)
	_toast("rival.appears", [d["name"], int(st["level"])])
	_log("rival_" + rid)
	if world == null or ship == null:
		return null
	var stats: ShipStats = (load("res://data/ships/%s.tres" % st["class"]) as ShipStats).duplicate()
	stats.hull_hp *= float(st["hp"])
	stats.guns_per_side = maxi(1, roundi(float(stats.guns_per_side) * float(st["guns"])))
	var s: Ship = world._make_ship(stats, _ahead(SPAWN_DIST_M), rng.randf_range(0.0, 360.0), "pirate")
	s.sail_level = 3
	s.crew.count = stats.crew_max
	s.set_meta("rival", rid)
	s.set_meta("rep_faction", "pirate")
	s.set_meta("loot_seed", rng.randi())
	s.set_meta("loot", {"gold": [int(d["gold"]) / 5, int(d["gold"]) / 3]})
	s.set_meta("loot_source", "rival")
	var ai := ShipAI.new()
	ai.ship = s
	s.ai = ai
	s.add_child(ai)
	world.prizes.add_target(s)
	active[rid] = s
	_ambient.append(s)
	return s


func _on_prize(info: Dictionary) -> void:
	var rid: String = str(info.get("rival", ""))
	if rid == "":
		return
	active.erase(rid)
	report_result(rid, true, int(info.get("fate", -1)) == CaptureFate.Fate.RELEASE)


func _on_defeated(_result: Dictionary) -> void:
	for rid: String in active.keys():
		var s: Ship = active[rid]
		if is_instance_valid(s) and not s.damage.sunk and s.global_position.distance_to(ship.global_position) <= LOSS_RADIUS_M:
			report_result(rid, false, false)
			break
	active.clear()


## A fight with a rival ended. Wins pay on the arc; losses level the rival up and take a trophy.
func report_result(rid: String, won: bool, spare: bool) -> Dictionary:
	active.erase(rid)
	var out: Dictionary = RivalState.record(state, rid, won, spare)
	var name: String = str(RivalData.def(rid)["name"])
	if won:
		if not (out["reward"] as Dictionary).is_empty():
			_toast("rival.defeated", [name, int(out["reward"]["gold"])])
	else:
		_toast("rival.trophy." + str(out["trophy"]), [name, int(out["level"])])
	_log("rival_%s_%s" % [rid, "won" if won else "lost"])
	return out
