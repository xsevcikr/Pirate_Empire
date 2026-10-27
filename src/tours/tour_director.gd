class_name TourDirector
extends Node
## Runs the treasure tours in the world: advances voyage steps as the ship arrives, applies siren waters to the
## helm and hands out the dungeons, the guardians and the dig. Everything it decides is in TourState and the
## pure classes; this node only watches the ship and the clock.

signal step_completed(tour_id: String, step_id: String)
signal tour_completed(tour_id: String)

var ship: Ship
var state: Dictionary
var rng := RandomNumberGenerator.new()
var turns: Dictionary = {}  ## tour id -> Array[int] of the map puzzle
var sirens: SirenWaters
var wax: bool = false
var singing: bool = false
var _bus: Node
var _digs: Dictionary = {}


func _ready() -> void:
	_bus = Svc.node("EventBus")
	if state.is_empty() and Session.has_state():
		state = Session.state
	rng.seed = int(state.get("seed", 1)) * 31 + 18
	wax = TourState.root(state).has("wax")


func pos2() -> Vector2:
	return Vector2(ship.global_position.x, ship.global_position.z)


func _hours() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.day) * 24.0 + float(clock.hour) if clock != null else 0.0


func _hour_of_day() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.hour) if clock != null else 12.0


func _physics_process(delta: float) -> void:
	if ship == null or state.is_empty():
		return
	TourState.tick(state, delta)
	update_voyage(pos2(), _hour_of_day(), OceanCurrent.tide_m(_hours()), delta)


## Advance voyage steps for the position, hour of day and tide given. Public so tests can drive it.
func update_voyage(pos: Vector2, hour: float, tide: float, delta: float = 0.0) -> void:
	for id in TourState.active(state):
		var step: Dictionary = TourState.current_step(state, id)
		match step["kind"]:
			"sail", "escape":
				if TourState.arrived(step, pos, hour, tide):
					_done(id, step)
			"sirens":
				_siren_tick(id, step, pos, delta)


func _done(id: String, step: Dictionary) -> void:
	var finished: bool = TourState.complete_step(state, id)
	if _bus != null:
		_bus.toast.emit(Loc.t("tour.step_done"))
	step_completed.emit(id, step["id"])
	if finished:
		if _bus != null:
			_bus.toast.emit(Loc.t("tour.complete") % int(TourData.TOURS[id]["reward"]["gold"]))
		tour_completed.emit(id)


# ---- the map ----------------------------------------------------------------------------------------------

func puzzle_turns(tour_id: String) -> Array[int]:
	if not turns.has(tour_id):
		var r := RandomNumberGenerator.new()
		r.seed = int(state.get("seed", 1)) + tour_id.hash()
		turns[tour_id] = MapFragments.scramble(tour_id, r)
	return turns[tour_id]


func rotate_piece(tour_id: String, piece: int) -> bool:
	MapFragments.rotate(puzzle_turns(tour_id), piece)
	if TourState.read_map(state, tour_id, puzzle_turns(tour_id)):
		if _bus != null:
			_bus.toast.emit(Loc.t("tour.joined"))
		step_completed.emit(tour_id, "read_map")
		return true
	return false


# ---- sirens -----------------------------------------------------------------------------------------------

func is_protected() -> bool:
	return wax or (singing and SirenWaters.shanty_works(float(state["morale"])))


func buy_wax() -> bool:
	var cost: int = int(TourData.SIREN["wax_cost"])
	if wax:
		return true
	if int(state["gold"]) >= cost:
		state["gold"] = int(state["gold"]) - cost  # a player who cannot pay is given the wax, so the crossing is never locked
	wax = true
	TourState.root(state)["wax"] = true
	return true


func _siren_tick(id: String, step: Dictionary, pos: Vector2, delta: float) -> void:
	var centre: Vector2 = TourData.step_pos(step)
	if sirens == null:
		sirens = SirenWaters.new(centre, float(step["radius"]))
	elif sirens.centre != centre:
		sirens = SirenWaters.new(centre, float(step["radius"]))
	if delta > 0.0 and ship != null:
		var pull: Vector2 = sirens.pull(pos, is_protected())
		if pull != Vector2.ZERO:
			ship.apply_central_force(Vector3(pull.x, 0.0, pull.y))
		CrewLife.add_morale(state, sirens.morale_drain(pos, is_protected(), delta))
	if pos.distance_to(centre) <= TourData.ARRIVE_M and TourData.step_index(id, step["id"]) == int(TourState.progress(state, id)["step"]):
		_done(id, step)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("shanty"):
		singing = event.is_pressed()


# ---- encounters -------------------------------------------------------------------------------------------

func near_step(tour_id: String) -> bool:
	return pos2().distance_to(TourData.step_pos(TourState.current_step(state, tour_id))) <= TourData.ARRIVE_M


func count_paces(tour_id: String, counted: int, hour: float = -1.0) -> bool:
	var step: Dictionary = TourState.current_step(state, tour_id)
	if step["kind"] != "landing" or not near_step(tour_id):
		return false
	var h: float = hour if hour >= 0.0 else _hour_of_day()
	if h < TourData.DUSK_FROM_H or h > TourData.DUSK_TO_H:
		return false
	if not TourState.check_paces(step, counted):
		return false
	TourState.progress(state, tour_id)["spot_found"] = true
	return true


## Dig where the paces ended. Three empty holes in a row never happen at a tour spot.
func dig_spot(tour_id: String, accuracy: float = 1.0) -> String:
	var step: Dictionary = TourState.current_step(state, tour_id)
	if step["kind"] != "landing" or not bool(TourState.progress(state, tour_id).get("spot_found", false)):
		return ""
	var out: String = dig(accuracy, tour_id)
	if out == "chest":
		TourState.progress(state, tour_id)["spot_found"] = false
		_done(tour_id, step)
	return out


func start_dungeon(tour_id: String) -> Dungeon:
	var step: Dictionary = TourState.current_step(state, tour_id)
	if step["kind"] != "dungeon" or not near_step(tour_id):
		return null
	return Dungeon.new(step["dungeon"], int(state.get("seed", 1)) + tour_id.hash() + int(TourState.progress(state, tour_id)["step"]))


## The dungeon run ended: pay its gold and move on when it was walked to the exit.
func finish_dungeon(tour_id: String, run: Dungeon) -> void:
	state["gold"] = int(state["gold"]) + run.gold
	run.gold = 0
	for i in run.deaths:
		TourState.on_death(state, tour_id)
	run.deaths = 0
	if run.is_done():
		_done(tour_id, TourState.current_step(state, tour_id))


func start_guardian(tour_id: String) -> MonsterFight:
	var step: Dictionary = TourState.current_step(state, tour_id)
	if step["kind"] != "guardian" or not near_step(tour_id):
		return null
	return MonsterFight.new(step["monster"], int(state.get("difficulty", 1)))


func finish_guardian(tour_id: String, fight: MonsterFight) -> void:
	if fight.won():
		_done(tour_id, TourState.current_step(state, tour_id))
	elif fight.lost():
		var out: Dictionary = TourState.on_death(state, tour_id)
		if _bus != null:
			_bus.toast.emit(Loc.t("tour.died") % int(out["lost"]))
		if ship != null:
			var p: Vector2 = out["respawn"]
			ship.global_position = Vector3(p.x, 0.5, p.y + 420.0)
			ship.linear_velocity = Vector3.ZERO


func dig(accuracy: float, spot_id: String = "") -> String:
	if not _digs.has(spot_id):
		_digs[spot_id] = Digging.new(rng, spot_id != "")
	var d: Digging = _digs[spot_id]
	d.reset()
	var out: String = ""
	for i in TourData.DIG_SWINGS:
		out = d.swing(accuracy)
	return out
