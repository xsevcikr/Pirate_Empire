class_name CrewDirector
extends Node
## Puts the rival pirate crews on the live sea. Each game hour their warbands may come for the player in the waters
## they hold; each day the crews raid, claim, spread and clash (PirateCrews). Claimed islands and the crews' lagoons
## have guards waiting, raiders sail for the player's own holdings, and a crew ship that gets alongside boards the
## player and fights it out on deck. Beating a crew's flagship at its lagoon ends that crew.

const CHECK_S: float = 0.5
const MAX_CATCH_UP_H: int = 3
const CULL_DIST_M: float = 5000.0
const ROLE_WARBAND: String = "warband"
const ROLE_GUARD: String = "guard"
const ROLE_FLAGSHIP: String = "flagship"
const ROLE_RAIDER: String = "raider"

var world: Node
var ship: Ship
var state: Dictionary
var rng := RandomNumberGenerator.new()
var ships: Array = []  ## every crew ship this director put on the sea
var lagoon_nodes: Dictionary = {}  ## crew id -> the lagoon's props
## Play a crew's boarding of the player as a 3D deck fight; headless runs settle it with the autopilot.
var use_deck_view: bool = DisplayServer.get_name() != "headless"
var _bus: Node
var _hour_i: int = -1
var _day_i: int = -1
var _check_t: float = 0.0
var _guarded: Dictionary = {}  ## island name or "lagoon:<id>" or "holding:<id>" -> true while its guards are out
var _boarding: bool = false


func _ready() -> void:
	_bus = Svc.node("EventBus")
	if state.is_empty() and Session.has_state():
		state = Session.state
	rng.seed = int(state.get("seed", 1)) * 53 + 23
	PirateCrews.root(state)
	if _bus != null:
		_bus.prize_taken.connect(_on_prize)
		_bus.player_defeated.connect(_on_defeated)
	_build_lagoons()


func _clock_hours() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.day) * 24.0 + float(clock.hour) if clock != null else 0.0


func pos2() -> Vector2:
	return Vector2(ship.global_position.x, ship.global_position.z)


func _physics_process(delta: float) -> void:
	if ship == null or state.is_empty():
		return
	var h: int = int(floorf(_clock_hours()))
	if _hour_i < 0 or h - _hour_i > MAX_CATCH_UP_H:
		_hour_i = h
		_day_i = h / 24
	while _hour_i < h:
		_hour_i += 1
		hour_tick(WorldMap.region_at(pos2()))
	if h / 24 > _day_i:
		_day_i = h / 24
		day_tick()
	_check_t += delta
	if _check_t >= CHECK_S:
		_check_t = 0.0
		proximity_tick()


## One game hour: raids that are due land, and a crew may send a warband. Public so tests can drive it.
func hour_tick(region: String) -> Array[String]:
	var fired: Array[String] = []
	for n in PirateCrews.resolve_threats(state, _clock_hours()):
		_say(n)
	for id in PirateCrews.alive_ids(state):
		if _warband_out(id):
			continue
		if rng.randf() < PirateCrews.warband_chance(state, id, region):
			send_warband(id)
			fired.append(id)
			break
	cull()
	return fired


func day_tick() -> Array[Dictionary]:
	var made: Array[Dictionary] = PirateCrews.day_tick(state, rng)
	for n in made:
		_say(n)
	return made


func _say(n: Dictionary) -> void:
	if _bus != null and not n.is_empty():
		_bus.toast.emit(PirateCrews.news_text(n))


func _warband_out(id: String) -> bool:
	for s in ships:
		if is_instance_valid(s) and s.get_meta("crew", "") == id and s.get_meta("crew_role", "") == ROLE_WARBAND and not s.damage.sunk:
			return true
	return false


# ---- ships ----------------------------------------------------------------------------------------

## A crew's ships come for the player: a warband of one to three, ahead and to one side.
func send_warband(id: String) -> Array[Ship]:
	var out: Array[Ship] = []
	var n: int = PirateCrews.warband_size(state, id)
	var ang: float = rng.randf_range(-1.2, 1.2)
	for i in n:
		var at: Vector2 = pos2() + Vector2.from_angle(_heading_angle() + ang) * CrewData.SPAWN_DIST_M + Vector2(90.0 * i, -70.0 * i)
		var s: Ship = spawn_crew_ship(id, PirateCrews.ship_class(state, id, i), at, ROLE_WARBAND)
		if s != null:
			out.append(s)
	if not out.is_empty() and _bus != null:
		_bus.toast.emit(Loc.t("pcrew.warband") % [CrewData.def(id)["name"], out.size()])
	return out


func _heading_angle() -> float:
	var f: Vector3 = -ship.global_transform.basis.z
	return atan2(f.z, f.x)


## One crew ship: its colours on the mast, its loot and the deck faction that makes its men fight like the crew.
func spawn_crew_ship(id: String, class_id: String, at: Vector2, role: String, tag: String = "") -> Ship:
	if world == null:
		return null
	var stats: ShipStats = (load("res://data/ships/%s.tres" % class_id) as ShipStats).duplicate()
	var flagship: bool = role == ROLE_FLAGSHIP
	if flagship:
		stats.hull_hp *= 1.5
	var s: Ship = world._make_ship(stats, Vector3(at.x, 0.5, at.y), rng.randf_range(0.0, 360.0), "pirate")
	s.sail_level = 3 if role == ROLE_WARBAND else 1
	s.crew.count = stats.crew_max
	s.crew.quality = 1.0 + 0.5 * float(CrewData.def(id)["grit"])
	s.crew.morale = 85.0
	s.display_label = "%s (%s)" % [stats.display_name, CrewData.def(id)["name"]]
	s.set_meta("crew", id)
	s.set_meta("crew_role", role)
	s.set_meta("crew_tag", tag)
	s.set_meta("deck_faction", CrewData.faction_of(id))
	s.set_meta("rep_faction", "pirate")
	s.set_meta("loot_seed", rng.randi())
	var chest: int = int(PirateCrews.get_crew(state, id)["gold"])
	var lo: int = maxi(120, int(float(chest) * CrewData.LOOT_GOLD[0]))
	s.set_meta("loot", {"gold": [lo, maxi(lo + 1, int(float(chest) * CrewData.LOOT_GOLD[1]))], "supplies": {"rum": 2}})
	s.set_meta("loot_source", "crew")
	var ai := ShipAI.new()
	ai.ship = s
	ai.personality = "aggressive"
	ai.detect_range = 2400.0 if role == ROLE_WARBAND else 1400.0
	ai.waypoints = [Vector3(at.x + 300.0, 0.0, at.y), Vector3(at.x, 0.0, at.y + 300.0)]
	s.ai = ai
	s.add_child(ai)
	if world.get("prizes") != null:
		world.prizes.add_target(s)
	ships.append(s)
	paint.call_deferred(s, id)
	return s


## The crew's colours on every flag of the ship.
static func paint(s: Ship, id: String) -> void:
	if not is_instance_valid(s) or s.visuals == null:
		return
	var c: Color = CrewData.def(id)["color"]
	var mark: Color = Color.WHITE if c.get_luminance() < 0.5 else Color(0.05, 0.05, 0.06)
	for m: ShaderMaterial in s.visuals.flag_materials:
		m.set_shader_parameter("base_color", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("mark_color", Vector3(mark.r, mark.g, mark.b))
		m.set_shader_parameter("skull", 1.0)


func crew_ships(id: String, role: String = "") -> Array[Ship]:
	var out: Array[Ship] = []
	for s in ships:
		if is_instance_valid(s) and not s.damage.sunk and s.get_meta("crew", "") == id and (role == "" or s.get_meta("crew_role", "") == role):
			out.append(s)
	return out


## Crew ships far behind leave the sea; guards and flagships stay while the player is near their post.
func cull() -> void:
	var keep: Array = []
	for s in ships:
		if not is_instance_valid(s):
			continue
		if s.global_position.distance_to(ship.global_position) > CULL_DIST_M:
			_forget_post(s)
			if world != null and world.get("prizes") != null:
				world.prizes.targets.erase(s)
			s.queue_free()
			continue
		keep.append(s)
	ships = keep


func _forget_post(s: Ship) -> void:
	var tag: String = str(s.get_meta("crew_tag", ""))
	if tag != "":
		_guarded.erase(tag)


# ---- places: claimed islands, lagoons, the player's holdings -------------------------------------------

## Every half second: guards appear when the player nears a claimed island, a lagoon or a holding under threat,
## and a crew ship alongside tries to board.
func proximity_tick() -> void:
	var p: Vector2 = pos2()
	var claims: Dictionary = PirateCrews.root(state)["claims"]
	for isl: String in claims:
		if _guarded.has(isl):
			continue
		var idx: int = PortData.gen().index_of(isl)
		if idx < 0:
			continue
		var d: Dictionary = PortData.gen().islands[idx]
		if p.distance_to(d["pos"]) <= CrewData.GUARD_RADIUS_M + float(d["radius"]):
			guard_island(isl)
	for id in PirateCrews.alive_ids(state):
		var tag: String = "lagoon:" + id
		if not _guarded.has(tag) and p.distance_to(CrewData.lagoon_pos(id)) <= CrewData.GUARD_RADIUS_M:
			defend_lagoon(id)
	for t: Dictionary in PirateCrews.root(state)["threats"]:
		var tag: String = "holding:" + str(t["crew"])
		var at: Vector2 = Vector2(float(t["pos"][0]), float(t["pos"][1]))
		if not _guarded.has(tag) and p.distance_to(at) <= CrewData.GUARD_RADIUS_M * 1.5:
			_guarded[tag] = true
			var id: String = str(t["crew"])
			for i in mini(2, maxi(1, int(PirateCrews.get_crew(state, id)["fleet"]))):
				spawn_crew_ship(id, PirateCrews.ship_class(state, id, i), at + Vector2(250.0 + 120.0 * i, 180.0), ROLE_RAIDER, tag)
	if not _boarding:
		for s in ships:
			if can_board_player(s):
				crew_boards_player(s)
				break


func guard_island(isl: String) -> Array[Ship]:
	var out: Array[Ship] = []
	var claim: Dictionary = PirateCrews.root(state)["claims"][isl]
	var id: String = claim["crew"]
	var d: Dictionary = PortData.gen().islands[PortData.gen().index_of(isl)]
	_guarded[isl] = true
	for i in 2:
		var at: Vector2 = (d["pos"] as Vector2) + Vector2.from_angle(TAU * float(i) / 2.0 + 0.6) * (float(d["radius"]) + 220.0)
		out.append(spawn_crew_ship(id, PirateCrews.ship_class(state, id, i), at, ROLE_GUARD, isl))
	if _bus != null:
		_bus.toast.emit(Loc.t("pcrew.guards") % [CrewData.def(id)["name"], isl])
	return out


## The crew's flagship waits in its lagoon with up to three ships of its fleet.
func defend_lagoon(id: String) -> Array[Ship]:
	var out: Array[Ship] = []
	var at: Vector2 = CrewData.lagoon_pos(id)
	var tag: String = "lagoon:" + id
	_guarded[tag] = true
	PirateCrews.get_crew(state, id)["lagoon_known"] = true
	out.append(spawn_crew_ship(id, str(CrewData.def(id)["flagship"]), at, ROLE_FLAGSHIP, tag))
	var n: int = mini(CrewData.LAGOON_GUARDS_MAX, int(PirateCrews.get_crew(state, id)["fleet"]))
	for i in n:
		out.append(spawn_crew_ship(id, PirateCrews.ship_class(state, id, i), at + Vector2.from_angle(TAU * float(i) / float(maxi(n, 1))) * 260.0, ROLE_GUARD, tag))
	if _bus != null:
		_bus.toast.emit(Loc.t("pcrew.lagoon_found") % CrewData.def(id)["name"])
	return out


## A small rocky cove at each lagoon: rocks, palms, a watchtower and the crew's flag, so it can be seen from afar.
func _build_lagoons() -> void:
	if world == null or not (world is Node3D):
		return
	for id: String in CrewData.ORDER:
		var root := Node3D.new()
		root.name = "Lagoon_" + id
		var p: Vector2 = CrewData.lagoon_pos(id)
		root.position = Vector3(p.x, 0.0, p.y)
		root.set_meta("kind", "crew_lagoon")
		(world as Node3D).add_child(root)
		lagoon_nodes[id] = root
		var r := RandomNumberGenerator.new()
		r.seed = hash(id)
		for k in 9:
			var a: float = TAU * float(k) / 9.0 + r.randf_range(-0.2, 0.2)
			var at := Vector3(cos(a), -0.6, sin(a)) * Vector3(150.0, 1.0, 150.0)
			var rock: Node3D = Kenney.place(root, "pirate", ["rocks-sand-a", "rocks-sand-b", "rocks-sand-c", "rocks-a"][k % 4], at, r.randf() * 360.0, 1.0)
			var rs: float = r.randf_range(10.0, 15.0)
			rock.scale = Vector3(rs, rs * 0.35, rs)
			if k % 3 == 0:
				Kenney.place(root, "pirate", "palm-bend", at + Vector3(0, 3.0, 0), r.randf() * 360.0, 6.0)
		var tower: Node3D = Kenney.place(root, "pirate", "tower-watch", Vector3(160.0, 0.0, 0.0), 180.0, 7.0)
		tower.set_meta("kind", "crew_tower")
		var flag: Node3D = Kenney.place(root, "pirate", "flag-pirate-high", Vector3(160.0, 14.0, 0.0), 0.0, 6.0)
		_tint(flag, CrewData.def(id)["color"])
		Kenney.place(root, "pirate", "structure-platform-dock", Vector3(120.0, -0.3, 30.0), 90.0, 6.0)


static func _tint(n: Node, c: Color) -> void:
	for mi: MeshInstance3D in Kenney.meshes_of(n):
		for i in mi.mesh.get_surface_count():
			var name: String = str(mi.mesh.surface_get_material(i).resource_name).to_lower() if mi.mesh.surface_get_material(i) != null else ""
			if name.contains("flag") or name.contains("cloth") or name.contains("red"):
				mi.set_surface_override_material(i, Kenney.flat(c, 0.0, true))


# ---- a crew boards the player ---------------------------------------------------------------------

## A crew ship alongside, near the player's speed, still fighting and not just back from a boarding, comes over the rail.
func can_board_player(s: Variant) -> bool:
	if not is_instance_valid(s) or s.damage.sunk or s.has_surrendered:
		return false
	if s.ai != null and s.ai.state == AiLogic.State.SURRENDER:
		return false
	if float(s.get_meta("board_cool_until", -1.0)) > Time.get_ticks_msec() / 1000.0:
		return false
	if world != null and world.get("prizes") != null and world.prizes._busy:
		return false
	if s.global_position.distance_to(ship.global_position) > CrewData.BOARD_PLAYER_M:
		return false
	return absf(s.speed_knots() - ship.speed_knots()) <= CrewData.BOARD_MAX_REL_KN and s.crew.count >= 4


## The crew comes over the rail. The whole crew defends; the fight is the usual deck fight against this crew's men.
func crew_boards_player(s: Ship) -> DeckCombat:
	_boarding = true
	var id: String = s.get_meta("crew", "")
	if _bus != null:
		_bus.toast.emit(Loc.t("pcrew.boarding") % CrewData.def(id)["name"])
	var deck: DeckCombat = DeckBridge.build(ship.crew.count + 1, ship.crew.quality * Progression.stat(state, "boarding_strength_mult"), ship.crew.morale,
		CrewData.faction_of(id), s.crew.count, s.crew.quality, s.crew.morale, state, int(state.get("seed", 1)) + int(s.get_meta("loot_seed", 3)))
	if not use_deck_view:
		var guard: int = 0
		while deck.outcome == DeckCombat.Outcome.ONGOING and guard < 60 * 600:
			DeckBridge.autopilot(deck, 1.0 / 30.0)
			deck.tick(1.0 / 30.0)
			guard += 1
		after_boarded(deck.result(), s)
		return deck
	var scene := DeckFightScene.new()
	get_tree().current_scene.add_child(scene)
	scene.start(deck)
	get_tree().paused = true
	scene.fight_over.connect(func(r: Dictionary) -> void:
		get_tree().paused = false
		after_boarded(r, s))
	return deck


## The fight on the player's deck is over. Won: the boarders' ship strikes and is the player's prize. Lost: they
## take their share of the purse (and a map, if they hunt treasure) and sail off.
func after_boarded(r: Dictionary, s: Ship) -> Dictionary:
	_boarding = false
	ship.crew.count = maxi(int(r.get("crew_left", 1)), 1)
	Session.reconcile_crew(ship)
	if not is_instance_valid(s):
		return {}
	var id: String = s.get_meta("crew", "")
	s.set_meta("board_cool_until", Time.get_ticks_msec() / 1000.0 + CrewData.BOARD_COOLDOWN_S)
	if bool(r.get("player_won", false)):
		s.crew.count = maxi(int(r.get("enemy_left", 0)), 0)
		s.surrender()
		CrewLife.add_morale(state, Morale.DELTA["victory"])
		if _bus != null:
			_bus.toast.emit(Loc.t("pcrew.repelled") % CrewData.def(id)["name"])
		var prizes: PrizeFlow = world.prizes if world != null else null
		if prizes != null and prizes.use_deck_view:
			prizes._on_boarding_finished(true, s)
		elif prizes != null:
			var loot: Dictionary = PrizeFlow.roll_loot(s, state)
			PrizeFlow.apply_loot(loot, state)
			prizes.finish_prize(s, loot, CaptureFate.Fate.STRIP_AND_SINK)
			s.queue_free()
		return {"won": true}
	s.crew.count = maxi(int(r.get("enemy_left", 1)), 1)
	CrewLife.add_morale(state, Morale.DELTA["defeat"])
	var out: Dictionary = PirateCrews.beat_player(state, id)
	if _bus != null:
		_bus.toast.emit(Loc.t("pcrew.plundered") % [CrewData.def(id)["name"], int(out["gold"])])
		if str(out["fragment"]) != "":
			_bus.toast.emit(Loc.t("pcrew.map_stolen") % CrewData.def(id)["name"])
	if s.ai != null:  # they sail away with the loot
		var away: Vector2 = Vector2(s.global_position.x, s.global_position.z) + (Vector2(s.global_position.x, s.global_position.z) - pos2()).normalized() * 3000.0
		s.ai.waypoints = [Vector3(away.x, 0.0, away.y)]
		s.ai.detect_range = 0.0
		s.ai.state = AiLogic.State.PATROL
	out["won"] = false
	return out


# ---- results ----------------------------------------------------------------------------------------

func _on_prize(info: Dictionary) -> void:
	var id: String = str(info.get("crew", ""))
	if id == "":
		return
	ship_beaten(id, str(info.get("crew_role", "")), str(info.get("crew_tag", "")), info.get("ship", null))


## The player sank or took one of a crew's ships: the crew loses it, a stolen map may come back, a beaten guard
## post pays its stash, and the flagship ends the crew.
func ship_beaten(id: String, role: String, tag: String, s: Variant = null) -> Dictionary:
	var region: String = WorldMap.region_at(pos2())
	var out: Dictionary = PirateCrews.ship_beaten(state, id, region, role == ROLE_FLAGSHIP)
	var map: String = PirateCrews.take_back_map(state, id)
	if map != "" and _bus != null:
		_bus.toast.emit(Loc.t("pcrew.map_back"))
	if bool(out["eliminated"]) and _bus != null:
		_bus.toast.emit(Loc.t("pcrew.eliminated") % [CrewData.def(id)["name"], int(out["gold"])])
	if role == ROLE_GUARD and PirateCrews.root(state)["claims"].has(tag) and _post_clear(tag, s):
		var stash: int = PirateCrews.take_claim(state, tag)
		out["stash"] = stash
		if _bus != null:
			_bus.toast.emit(Loc.t("pcrew.stash") % [tag, stash])
	return out


func _post_clear(tag: String, except: Variant) -> bool:
	for s in ships:
		if not is_instance_valid(s) or s == except or s.is_queued_for_deletion() or s.damage.sunk or s.has_surrendered:
			continue
		if world != null and world.get("prizes") != null and not world.prizes.targets.has(s):
			continue
		if s.get_meta("crew_tag", "") == tag:
			return false
	return true


## The player's ship went down: the nearest crew ship close by takes the win.
func _on_defeated(_result: Dictionary) -> void:
	var best: Ship = null
	var best_d: float = 2500.0
	for s in ships:
		if is_instance_valid(s) and not s.damage.sunk:
			var d: float = s.global_position.distance_to(ship.global_position)
			if d < best_d:
				best_d = d
				best = s
	if best != null:
		PirateCrews.beat_player(state, str(best.get_meta("crew", "")))
