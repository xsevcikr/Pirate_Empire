class_name BountyDirector
extends Node
## Puts the bounty rules (Bounty) to work at sea: lets the bounties fade each quiet day, sends waves of bounty hunters
## after a wanted ship, keeps the wanted badge on the HUD up to date and clears hunters left far behind.

const SPAWN_DIST_M: float = 1100.0
const CULL_DIST_M: float = 6000.0
const MAX_CATCH_UP_H: int = 3

var world: Node
var ship: Ship
var state: Dictionary
var rng := RandomNumberGenerator.new()
var hunters: Array = []  ## the hunter ships at sea, oldest first
var _hour_i: int = -1
var _day_i: int = -1


func _ready() -> void:
	if state.is_empty() and Session.has_state():
		state = Session.state
	rng.seed = int(state.get("seed", 1)) * 53 + 11


func _clock_hours() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.day) * 24.0 + float(clock.hour) if clock != null else 0.0


func _physics_process(_delta: float) -> void:
	if ship == null or state.is_empty():
		return
	var h: int = int(floorf(_clock_hours()))
	if _hour_i < 0 or h - _hour_i > MAX_CATCH_UP_H:
		_hour_i = h
		_day_i = h / 24
		return
	while _hour_i < h:
		_hour_i += 1
		hour_tick(float(_hour_i))
	if h / 24 > _day_i:
		_day_i = h / 24
		Bounty.day_tick(state)


## One game hour: a wave of hunters if one is due. Public so tests can drive it. Returns the ships sent.
func hour_tick(now_h: float) -> Array[Ship]:
	var sent: Array[Ship] = []
	hunters = hunters.filter(func(s: Variant) -> bool: return is_instance_valid(s) and not (s as Ship).damage.sunk)
	for s: Ship in hunters.duplicate():
		if s.global_position.distance_to(ship.global_position) > CULL_DIST_M:
			hunters.erase(s)
			s.queue_free()
	if not Bounty.hunters_due(state, now_h):
		return sent
	var faction: String = Bounty.top_faction(state)
	var wave: Dictionary = Bounty.hunters(Bounty.stars(state))
	var room: int = int(wave["count"]) - hunters.size()
	for i in room:
		var cls: String = wave["classes"][rng.randi() % wave["classes"].size()]
		sent.append(spawn_hunter(cls, faction, i))
	if not sent.is_empty():
		_toast(Loc.t("bounty.hunters_sighted") % Loc.t("faction." + faction))
		Sfx.bark("sail_ho")
	return sent


## A bounty hunter of `faction` astern of the player; it flies a fighting flag and comes straight for the ship.
func spawn_hunter(class_id: String, faction: String, index: int = 0) -> Ship:
	var back: Vector3 = -ship.global_transform.basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.FORWARD
	var side: Vector3 = back.cross(Vector3.UP)
	var at: Vector3 = ship.global_position - back * SPAWN_DIST_M + side * (140.0 * float(index) - 70.0)
	var s: Ship = world._make_ship(load("res://data/ships/%s.tres" % class_id), Vector3(at.x, 0.5, at.z), rng.randf_range(0.0, 360.0),
		str(Bounty.HUNTER_SHIP_FACTION.get(faction, "navy")))
	s.sail_level = 3
	s.crew.count = ShipRoster.ai_crew(s.stats)
	s.set_meta("rep_faction", faction)
	s.set_meta("hunter", true)
	s.set_meta("loot_seed", rng.randi())
	s.set_meta("loot", {"gold": [200, 600]})
	var ai := ShipAI.new()
	ai.ship = s
	ai.personality = "aggressive"
	ai.waypoints = [ship.global_position]
	s.ai = ai
	s.add_child(ai)
	if world.prizes != null:
		world.prizes.add_target(s)
	hunters.append(s)
	return s


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)
