class_name ProgressDirector
extends Node
## Connects the game's events to the captain's progression: XP, levels, lifetime stats, the captain's log and
## achievements. Every on_* method works on the state alone, so tests drive them without a scene.

const DISCOVER_M: float = 900.0
const TICK_S: float = 2.0

var state: Dictionary
var ship: Ship
var _bus: Node
var _last_pos: Vector2 = Vector2.ZERO
var _have_pos: bool = false
var _tick: float = 0.0
var _last_day: int = -1
var _mast_times: Array[float] = []
var _clock_s: float = 0.0
var _watched: Dictionary = {}  ## ship instance id -> true, ships whose masts are counted


func _ready() -> void:
	_bus = Svc.node("EventBus")
	if state.is_empty() and Session.has_state():
		state = Session.state
	if _bus == null:
		return
	_bus.ship_sunk.connect(_on_ship_sunk)
	_bus.prize_taken.connect(on_prize)
	_bus.trade_made.connect(on_trade)
	_bus.boarding_resolved.connect(on_boarding)
	_bus.stat_event.connect(on_stat)
	_bus.island_found.connect(on_island)


func _process(delta: float) -> void:
	_clock_s += delta
	_tick += delta
	if _tick < TICK_S or ship == null or state.is_empty():
		return
	_tick = 0.0
	var p := Vector2(ship.global_position.x, ship.global_position.z)
	if _have_pos:
		var d: float = p.distance_to(_last_pos)
		if d < 500.0:  # a teleport (loading, fast travel) is not sailing
			on_distance(d)
	_last_pos = p
	_have_pos = true
	_look_for_islands(p)
	_watch_masts()
	var day: int = int(state.get("day", 0))
	if day != _last_day:
		_last_day = day
		on_day(day)


func _look_for_islands(p: Vector2) -> void:
	for isl: Dictionary in PortData.gen().islands:
		var nm: String = str(isl["name"])
		if not (state.get("islands_seen", []) as Array).has(nm) and (isl["pos"] as Vector2).distance_to(p) <= DISCOVER_M + float(isl["radius"]):
			if _bus != null:
				_bus.island_found.emit(nm)
			else:
				on_island(nm)


## Counts masts that snap on other ships: each ship seen gets its damage model watched once.
func _watch_masts() -> void:
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == ship or s.damage == null or _watched.has(s.get_instance_id()):
			continue
		_watched[s.get_instance_id()] = true
		s.damage.mast_fell.connect(func(_i: int) -> void: on_mast_fell(_clock_s))


# ---- events ------------------------------------------------------------------------------------------------

func _on_ship_sunk(pos: Vector2, class_id: String) -> void:
	if ship != null and Vector2(ship.global_position.x, ship.global_position.z).distance_to(pos) < 4.0:
		return  # that is us going down
	on_sunk(class_id)


func on_sunk(class_id: String) -> void:
	Achievements.record(state, "ships_sunk")
	_xp("sink", {"class_id": class_id})
	CaptainLog.add(state, "battle", "sank", class_id)
	_after()


func on_prize(info: Dictionary) -> void:
	_xp("capture", {"class_id": str(info.get("class_id", ""))})
	CaptainLog.add(state, "prize", "prize", str(info.get("class_id", "")))
	if str(info.get("rival", "")) != "":
		CaptainLog.add(state, "rival", "rival_prize", str(info["rival"]))
	_after()


func on_trade(kind: String, _id: String, _units: float, gold: int) -> void:
	if kind == "buy_ship":
		Achievements.record(state, "ships_bought")
	elif kind == "sell" and gold > 0:
		Achievements.record(state, "gold_earned", float(gold))
		_xp("trade", {"gold": gold})
	_after()


func on_boarding(player_won: bool, parries: int, outnumbered: bool) -> void:
	if parries > 0:
		Achievements.record(state, "best_parries", float(parries))
	if player_won:
		Achievements.record(state, "duels_won")
		_xp("duel")
		CaptainLog.add(state, "battle", "boarding_won")
		if outnumbered:
			Achievements.record(state, "outnumbered_boardings_won")
	else:
		CaptainLog.add(state, "battle", "boarding_lost")
	_after()


func on_tour_step(tour_id: String, step_id: String) -> void:
	if AchievementData.BOSS_STEPS.has(step_id):
		Achievements.record(state, str(AchievementData.BOSS_STAT_OF_STEP.get(step_id, "boss_" + step_id)))
		CaptainLog.add(state, "battle", "boss_" + step_id)
	_after()


func on_tour_done(tour_id: String) -> void:
	Achievements.record(state, "tours_done")
	_xp("tour", {"tour_id": tour_id})
	CaptainLog.add(state, "tour", "tour_done", tour_id)
	_after()


func on_island(island_name: String) -> void:
	if not state.has("islands_seen"):
		state["islands_seen"] = []
	if (state["islands_seen"] as Array).has(island_name):
		return
	state["islands_seen"].append(island_name)
	Achievements.record(state, "islands_found")
	_xp("island")
	CaptainLog.add(state, "discovery", "island", island_name)
	_after()


func on_stat(stat_name: String, amount: float) -> void:
	Achievements.record(state, stat_name, amount)
	_after()


func on_distance(metres: float) -> void:
	Achievements.record(state, "distance_km", metres / 1000.0)
	if int(Achievements.value(state, "distance_km")) != int(Achievements.value(state, "distance_km") - metres / 1000.0):
		_after()


## A mast on someone else's ship snapped at game-clock `t` seconds; masts within one battle window add up.
func on_mast_fell(t: float) -> void:
	_mast_times.append(t)
	while not _mast_times.is_empty() and t - _mast_times[0] > AchievementData.MAST_WINDOW_S:
		_mast_times.pop_front()
	Achievements.record(state, "best_masts_window", float(_mast_times.size()))
	_after()


## A new game day. Starving days spoil "Never Starved".
func on_day(_day: int) -> void:
	if int(state.get("starve_days", 0)) > 0:
		Achievements.record(state, "starved_days")
	_after()


func _xp(kind: String, ctx: Dictionary = {}) -> void:
	var gained: int = Progression.xp_for(kind, ctx)
	if kind == "trade":
		gained = _trade_xp(int(ctx.get("gold", 0)))
	var levels: int = Progression.add_xp(state, gained)
	if levels > 0:
		CaptainLog.add(state, "level", "level_up", str(state["captain_level"]))
		_toast("progress.level_up", [int(state["captain_level"])])
		if _bus != null:
			_bus.level_up.emit(int(state["captain_level"]))


## Trade profit is 1 XP per 100 gold; the remainder carries over so small sales still count.
func _trade_xp(gold: int) -> int:
	var rem: int = int(state.get("trade_rem", 0)) + gold
	state["trade_rem"] = rem % int(ProgressionData.XP["trade_gold_per_xp"])
	return rem / int(ProgressionData.XP["trade_gold_per_xp"])


func _after() -> void:
	for id in Achievements.check(state):
		CaptainLog.add(state, "achievement", "ach_" + id)
		_toast("progress.achievement", [Loc.t("ach." + id)])
		if _bus != null:
			_bus.achievement_unlocked.emit(id)


func _toast(key: String, args: Array) -> void:
	if _bus != null:
		_bus.toast.emit(Loc.t(key) % args)
