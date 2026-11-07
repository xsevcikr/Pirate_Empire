extends SceneTree
## Weather in the running world: a storm darkens the sky, rains on the deck and blows a gale. St Elmo's fire warns
## before lightning strikes the player's mainmast; the lookout calls a big sea before it breaks. Taken on the beam
## it hurts far more than bow on, and a whole night of storm hits never sinks her. At night the lanterns are lit,
## the stars are out and enemy lookouts see less. The weather survives a save and load.

var _fails: Array[String] = []
var _step: int = 0
var _wait: int = 0
var _frames: int = 0
var _world: Node
var _ship: Ship
var _ws: WeatherSystem
var _toasts: Array[String] = []
var _enemy: Ship


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


func _initialize() -> void:
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	Session.begin_new("Test", 1, 1)
	Session.enter_world(self)


func _go(step: int, wait: int = 3) -> void:
	_step = step
	_wait = wait
	_frames = 0


func _clock() -> Node:
	return root.get_node("GameClock")


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	_frames += 1
	match _step:
		0:
			if current_scene == null or current_scene.name != "World":
				return false
			_world = current_scene
			_ship = _world.get("ship")
			_ws = _world.get("weather")
			_check(_ws != null, "the world runs the weather")
			root.get_node("EventBus").toast.connect(func(t: String) -> void: _toasts.append(t))
			_ship.global_position = Vector3(600.0, 0.3, 1400.0)
			_enemy = _world.call("_make_ship", load("res://data/ships/sloop.tres"), Vector3(700.0, 0.3, 1400.0), 90.0, "navy")
			_enemy.ai = ShipAI.new()
			_enemy.ai.ship = _enemy
			_enemy.add_child(_enemy.ai)
			_clock().hour = 12.0
			_ws.set_now("clear")
			_go(1, 30)
		1:
			var env: Environment = (_world.get("day_night") as DayNight).env
			var clear_fog: float = env.fog_density
			var clear_detect: float = _enemy.ai.detect_range
			_ws.force = "storm"
			_ws.set_now("storm")
			_world.set_meta("clear_fog", clear_fog)
			_world.set_meta("clear_detect", clear_detect)
			_go(2, 90)
		2:
			var dn: DayNight = _world.get("day_night")
			var wind: WindModel = _world.get("wind")
			_check(dn.env.fog_density > float(_world.get_meta("clear_fog")) * 2.0, "storm fog is thick: %f" % dn.env.fog_density)
			_check(_ws.rain.emitting, "it rains")
			_check(_ship.damage.rain, "the deck is wet (fires spread slower)")
			_check(wind.speed_kn > 16.0, "the wind is rising toward a gale: %.1f kn" % wind.speed_kn)
			_check(_enemy.ai.detect_range < float(_world.get_meta("clear_detect")) * 0.7, "lookouts see less in a storm")
			# lightning: warned, then lands on the mainmast
			_ship.sail_level = 3
			_ws.warn_lightning(_ship)
			_check(_find_kind(_ship, "st_elmo") != null, "St Elmo's fire glows on the masthead")
			_check(_toasts.any(func(t: String) -> bool: return t == Loc.t("weather.st_elmo")), "the crew call the warning")
			_world.set_meta("sail0", _ship.damage.sail_health())
			_world.set_meta("hull0", _ship.damage.hull_hp_total())
			_go(3, int(WeatherRules.LIGHTNING_WARN_S * 60.0) + 10)
		3:
			_check(_ship.damage.sail_health() < float(_world.get_meta("sail0")), "the bolt burned the sail")
			_check(absf(_ship.damage.hull_hp_total() - float(_world.get_meta("hull0"))) < 0.01, "the bolt left the hull alone")
			_check(_find_kind(_ship, "st_elmo") == null, "the glow is gone after the strike")
			# big seas: on the beam, then bow on
			var wind: WindModel = _world.get("wind")
			wind.direction = Vector2(1, 0)
			_ship.rotation = Vector3.ZERO  # bow north (-Z), the sea runs east: on the port beam
			_ship.angular_velocity = Vector3.ZERO
			var h0: float = _ship.damage.hull_hp_total()
			var beam: Dictionary = _ws.hit_with_sea(_ship)
			var beam_dmg: float = h0 - _ship.damage.hull_hp_total()
			_ship.rotation = Vector3(0, -PI / 2.0, 0)  # bow east, running with the sea
			var h1: float = _ship.damage.hull_hp_total()
			_ws.hit_with_sea(_ship)
			var stern_dmg: float = h1 - _ship.damage.hull_hp_total()
			print("big sea: beam %.0f HP (exposure %.2f), stern on %.0f HP" % [beam_dmg, float(beam.get("exposure", 0.0)), stern_dmg])
			_check(beam_dmg > 0.0 and beam_dmg > stern_dmg * 4.0, "the beam takes the sea far worse (%f vs %f)" % [beam_dmg, stern_dmg])
			_check(not _ship.damage.section_is_starboard(int(beam["section"])), "a sea from the west breaks on the port side")
			# a whole night of it: never sinks, never floods
			for i in 120:
				_ws.hit_with_sea(_ship)
				_ws.call("_strike", _ship)
			_check(not _ship.damage.sunk, "storm hits alone never sink her")
			_check(_ship.damage.hull_fraction() >= WeatherRules.STORM_HULL_FLOOR - 0.01, "the hull stops at the storm floor: %.2f" % _ship.damage.hull_fraction())
			_check(_ship.damage.leak_total() <= 0.0, "no breach from the storm")
			_go(4, 5)
		4:
			# night: lanterns and stars
			_ws.force = "clear"
			_ws.set_now("clear")
			_clock().hour = 23.0
			_go(5, 90)
		5:
			var lantern: Node3D = _ship.get_meta("lantern") if _ship.has_meta("lantern") else null
			_check(lantern != null and lantern.visible, "the stern lantern is lit at night")
			var stars: StarDome = (_world.get("day_night") as DayNight).stars
			_check(stars != null and stars.visible, "the stars are out")
			_check(_enemy.ai.detect_range < float(_world.get_meta("clear_detect")) * 0.75, "lookouts see less at night")
			_clock().hour = 12.0
			_go(6, 90)
		6:
			var lantern: Node3D = _ship.get_meta("lantern")
			_check(not lantern.visible, "lanterns are out by day")
			_check(absf(_enemy.ai.detect_range - float(_world.get_meta("clear_detect"))) < 1.0, "clear day: full sight")
			# weather is saved
			_ws.force = ""
			_ws.set_now("fog")
			_check(Session.save_to(_world, 1), "saved")
			_check(Session.load_slot(1), "loaded")
			_check(str((Session.state.get("weather", {}) as Dictionary).get("now", "")) == "fog", "the fog came back with the save")
			_check(WeatherSystem.take_storm_day(Session.state), "the storm day was noted for the crew's morale")
			_finish()
	return false


func _find_kind(n: Node, kind: String) -> Node:
	for c in n.get_children():
		if c.get_meta("kind", "") == kind:
			return c
	return null


func _finish() -> void:
	if _fails.is_empty():
		print("M24 WEATHER: PASS")
		quit(0)
	else:
		for f in _fails:
			print("FAIL: ", f)
		quit(1)
