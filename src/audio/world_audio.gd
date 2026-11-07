class_name WorldAudio
extends Node
## The sea's conductor: every half second reads the situation and asks the mixer for the right music, sets the
## ambience from the weather, rings the hour bell, and turns events into sound effects and crew barks.

const THINK_S: float = 0.5
const LAND_NEAR_M: float = 900.0
const FLOOD_SECTION_HP: float = 0.5

var world: Node3D
var _t: float = 0.0
var _hour_seen: int = -1
var _near_land_prev: bool = false
var _sail_seen: Dictionary = {}
var ctx: Dictionary = {}
var singing: String = ""  ## the shanty the crew is singing at sea, or ""
var _sing_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the port and boarding screens pause the sea but need their music
	var bus: Node = Svc.node("EventBus")
	if bus == null:
		return
	bus.trade_made.connect(func(_k: String, _i: String, _u: float, _g: int) -> void: Sfx.play("coin"))
	bus.prize_taken.connect(func(_info: Dictionary) -> void:
		Sfx.play("chest")
		Sfx.bark("victory"))
	bus.level_up.connect(func(_l: int) -> void:
		Sfx.play("level_up")
		Sfx.bark("level_up"))
	bus.achievement_unlocked.connect(func(_id: String) -> void: Sfx.play("achievement"))
	bus.quest_completed.connect(func(_id: String) -> void: Sfx.play("ui_confirm"))
	bus.port_docked.connect(func(_id: String) -> void: Sfx.play("rope_creak"))
	bus.boarding_resolved.connect(func(won: bool, _p: int, _o: bool) -> void:
		if won:
			Sfx.bark("victory"))
	bus.ship_sunk.connect(func(pos: Vector2, _c: String) -> void: Sfx.play("explosion", pos))


## The situation the music is chosen from.
func read_context() -> Dictionary:
	var c: Dictionary = {}
	if world == null or world.ship == null:
		return c
	var p3: Vector3 = world.ship.global_position
	var p := Vector2(p3.x, p3.z)
	c["region"] = WorldMap.region_at(p)
	c["in_port"] = world.get_node_or_null("PortLayer") != null
	c["boarding"] = world.get_tree().paused and world.get_tree().get_first_node_in_group("deck_fight") != null
	var fight: Node = world.get_node_or_null("MapLayer")
	if fight != null and fight.get_child_count() > 0 and fight.get_child(0) is TourEncounterScreen:
		var tf: Variant = (fight.get_child(0) as TourEncounterScreen).fight
		if tf != null:
			c["boss"] = true
			c["boss_id"] = str(tf.id)
	var hostile: float = 99999.0
	var combat: bool = false
	for n in world.get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null or s == world.ship or s.ai == null or s.damage.sunk:
			continue
		if s.faction == "merchant":
			continue
		var d: float = s.global_position.distance_to(p3)
		hostile = minf(hostile, d)
		if s.ai.state == AiLogic.State.ENGAGE and d < 700.0:
			combat = true
	c["hostile_dist"] = hostile
	c["enemy_in_combat"] = combat
	c["weather"] = "storm" if world.wind.sea_state() >= AudioData.STORM_FROM else "clear"
	return c


func _process(delta: float) -> void:
	_t += delta
	_sing_left -= delta
	var audio: Node = Svc.node("Audio")
	if audio == null or world == null or world.ship == null:
		return
	audio.update_ambience(world.wind.sea_state(), world.wind.speed_kn, _near_land_prev, delta)
	if _t < THINK_S:
		return
	_t = 0.0
	ctx = read_context()
	if singing != "" and (_sing_left <= 0.0 or _fighting(ctx) or bool(ctx.get("in_port", false))):
		stop_singing()
	audio.set_music(AudioData.track_for(ctx))
	_near_land_prev = world.streamer != null and _land_close()
	_hour_bell()
	_barks(ctx)


func _fighting(c: Dictionary) -> bool:
	return bool(c.get("enemy_in_combat", false)) or bool(c.get("boarding", false)) or bool(c.get("boss", false))


## H at sea: the crew strikes up a shanty (or says why it will not). Returns the shanty sung, or "".
func sing() -> String:
	if not Session.has_state() or bool(ctx.get("in_port", false)):
		return ""
	var why: String = SeaShanty.refusal(Session.state, _fighting(ctx))
	if why != "":
		_toast(Loc.t("shanty.refuse_" + why))
		if why == "morale":
			Sfx.bark("grumble")
		return ""
	var r: Dictionary = SeaShanty.sing(Session.state, int(Session.state["day"]))
	singing = r["track"]
	_sing_left = SeaShanty.SING_S
	Sfx.music(singing)
	_toast(Loc.t("tavern.sung_" + str(r["shanty"])) + ("  " + Loc.t("shanty.morale") % int(r["morale"]) if float(r["morale"]) > 0.0 else ""))
	return str(r["shanty"])


func stop_singing() -> void:
	if singing == "":
		return
	singing = ""
	Sfx.music("")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shanty") and not event.is_echo() and not get_tree().paused:
		if singing != "":
			stop_singing()
		else:
			sing()


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)


func _land_close() -> bool:
	var p3: Vector3 = world.ship.global_position
	for isl: Node in world.streamer.loaded.values():
		if isl is Node3D and (isl as Node3D).global_position.distance_to(p3) < LAND_NEAR_M:
			return true
	return false


func _hour_bell() -> void:
	var clock: Node = world.get_node_or_null("/root/GameClock")
	if clock == null:
		return
	var h: int = int(clock.hour)
	if _hour_seen >= 0 and h != _hour_seen:
		Sfx.play("bell")
	_hour_seen = h


func _barks(c: Dictionary) -> void:
	var s: Ship = world.ship
	if s.damage.sunk:
		return
	if c.get("weather", "clear") == "storm":
		Sfx.bark("storm")
	if bool(c.get("boarding", false)):
		Sfx.bark("boarding")
	if _near_land_prev and not bool(c.get("in_port", false)):
		Sfx.bark("land_ho")
	if float(c.get("hostile_dist", 99999.0)) < 1200.0:
		Sfx.bark("sail_ho")
	if s.crew.morale < 40.0:
		Sfx.bark("grumble")
	if s.broadside.ready_count(0) + s.broadside.ready_count(1) == s.broadside.gun_count() * 2 and bool(c.get("enemy_in_combat", false)):
		Sfx.bark("reload")
	if s.damage.flood_fraction() > FLOOD_SECTION_HP:
		Sfx.bark("flooding")
