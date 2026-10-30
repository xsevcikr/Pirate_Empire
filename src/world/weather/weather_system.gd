class_name WeatherSystem
extends Node
## Runs the weather at sea: every few game hours the region's WeatherChain picks the next weather, which fades in
## over BLEND_S seconds and sets the wind, the clouds, the light, the fog and the rain. In a storm it calls down
## lightning (St Elmo's fire on a masthead first) and sends big seas at the player's ship (the lookout calls the
## side first). Night and thick weather shorten how far enemy lookouts see. State lives in state["weather"].

signal weather_changed(id: String)
signal lightning(target: Ship, result: Dictionary)
signal big_sea(result: Dictionary)

const KEY: String = "weather"
const MAX_CATCH_UP_H: float = 48.0
const STORM_LOG_HOURS: float = 1.0  ## game hours in a storm before riding it out goes in the log

var world: Node  ## the sea scene: wind, ship, day_night, ocean
var state: Dictionary = {}  ## the save; a local one in the demo scene
var rng := RandomNumberGenerator.new()
var current: Dictionary = WeatherRules.blend("clear", "clear", 1.0)
var rain: RainFx
var force: String = ""  ## tests and screenshots: hold this weather, fully blended

var _chain := WeatherChain.new()
var _bolt_in: float = 0.0
var _sea_in: float = 0.0
var _warn_target: Ship = null
var _warn_left: float = -1.0
var _warn_glow: Node3D = null
var _sea_left: float = -1.0
var _flash: float = 0.0
var _last_h: float = -1.0


func _ready() -> void:
	rng.seed = int(state.get("seed", 1)) * 7919 + 13
	_bolt_in = rng.randf_range(WeatherRules.LIGHTNING_EVERY_S.x, WeatherRules.LIGHTNING_EVERY_S.y)
	_sea_in = rng.randf_range(WeatherRules.WAVE_EVERY_S.x, WeatherRules.WAVE_EVERY_S.y)
	rain = RainFx.new()
	add_child(rain)
	var w: Dictionary = data()
	current = WeatherRules.blend(str(w["prev"]), str(w["now"]), float(w["blend"]))


## The weather block of the save, created on first use: now, prev, blend 0..1, next_h (absolute game hour of the
## next change), storm_h (hours ridden out in the current storm), storm_day (a storm happened since the day began).
func data() -> Dictionary:
	if not state.has(KEY) or typeof(state[KEY]) != TYPE_DICTIONARY:
		state[KEY] = {}
	var w: Dictionary = state[KEY]
	for k: String in ["now", "prev"]:
		if not WeatherRules.PROFILES.has(str(w.get(k, ""))):
			w[k] = "clear"
	w["blend"] = float(w.get("blend", 1.0))
	w["next_h"] = float(w.get("next_h", -1.0))
	w["storm_h"] = float(w.get("storm_h", 0.0))
	w["storm_day"] = bool(w.get("storm_day", false))
	w["steps"] = int(w.get("steps", 0))
	return w


func now() -> String:
	return force if force != "" else str(data()["now"])


## Reads and clears "a storm happened today", for the crew's daily morale.
static func take_storm_day(st: Dictionary) -> bool:
	var w: Variant = st.get(KEY)
	if typeof(w) != TYPE_DICTIONARY:
		return false
	var had: bool = bool((w as Dictionary).get("storm_day", false))
	(w as Dictionary)["storm_day"] = false
	return had


## Moves the weather to its next state now. Public so tests can drive it.
func step(region: String) -> String:
	var w: Dictionary = data()
	w["steps"] = int(w["steps"]) + 1
	_chain.state = str(w["now"])
	_chain.rng.seed = hash([int(state.get("seed", 1)), int(w["steps"])])
	var tendency: Dictionary = WorldMap.REGIONS.get(region, {}).get("weather", {"clear": 1.0})
	var next: String = _chain.step(tendency)
	if next != str(w["now"]):
		w["prev"] = w["now"]
		w["now"] = next
		w["blend"] = 0.0
		weather_changed.emit(next)
		_toast(Loc.t("weather.turns") % Loc.t("weather." + next))
	return next


## Sets the weather at once (no fade). For tests, screenshots and the debug console.
func set_now(id: String) -> void:
	var w: Dictionary = data()
	w["prev"] = id
	w["now"] = id
	w["blend"] = 1.0
	current = WeatherRules.blend(id, id, 1.0)


func _clock_hours() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.day) * 24.0 + float(clock.hour) if clock != null else 0.0


func _hour_of_day() -> float:
	var clock: Node = Svc.node("GameClock")
	return float(clock.hour) if clock != null else 12.0


func _player() -> Ship:
	return world.get("ship") if world != null else null


func _process(delta: float) -> void:
	var w: Dictionary = data()
	var h: float = _clock_hours()
	if float(w["next_h"]) < 0.0 or h - float(w["next_h"]) > MAX_CATCH_UP_H:
		w["next_h"] = h + WeatherChain.STEP_HOURS
	while h >= float(w["next_h"]) and force == "":
		w["next_h"] = float(w["next_h"]) + WeatherChain.STEP_HOURS
		step(WorldMap.region_at(_player_pos()))
	if force != "":
		current = WeatherRules.blend(force, force, 1.0)
	else:
		w["blend"] = minf(float(w["blend"]) + delta / WeatherRules.BLEND_S, 1.0)
		current = WeatherRules.blend(str(w["prev"]), str(w["now"]), float(w["blend"]))
	var game_dh: float = clampf(h - _last_h, 0.0, 1.0) if _last_h >= 0.0 else 0.0
	_last_h = h
	_apply_world(delta)
	_storm_record(game_dh)
	_storm_hazards(delta)


func _player_pos() -> Vector2:
	var p: Ship = _player()
	return Vector2(p.global_position.x, p.global_position.z) if p != null and p.is_inside_tree() else Vector2.ZERO


## Wind, sky, rain, fire-damping rain on every deck, and the lookouts' range.
func _apply_world(delta: float) -> void:
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if world == null:
		return
	var wind: WindModel = world.get("wind")
	if wind != null and not SeaEvents.is_becalmed(state):
		wind.speed_kn = move_toward(wind.speed_kn, float(current["wind"]), WeatherRules.WIND_KN_PER_S * delta)
	var dn: DayNight = world.get("day_night")
	if dn != null:
		dn.weather = current
		dn.flash = _flash
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if rain != null:
		rain.set_rain(float(current["rain"]), cam, wind.direction if wind != null else Vector2.ZERO)
	var sight: float = WeatherRules.sight(current, _hour_of_day())
	var wet: bool = float(current["rain"]) > 0.3
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s == null:
			continue
		if s.damage != null:
			s.damage.rain = wet
		if s.ai != null:
			if not s.ai.has_meta("clear_detect"):
				s.ai.set_meta("clear_detect", s.ai.detect_range)
			s.ai.detect_range = float(s.ai.get_meta("clear_detect")) * sight


## Hours ridden out in a storm at sea go in the log and teach the crew, once the storm has passed.
func _storm_record(game_dh: float) -> void:
	var w: Dictionary = data()
	var in_port: bool = world != null and world.has_method("dock_port") and str(world.dock_port()) != ""
	if float(current["storm"]) > 0.5 and not in_port:
		w["storm_h"] = float(w["storm_h"]) + game_dh
		w["storm_day"] = true
	elif float(current["storm"]) < 0.2 and float(w["storm_h"]) > 0.0:
		if float(w["storm_h"]) >= STORM_LOG_HOURS and state.has("log"):
			CaptainLog.add(state, "storm", "storm_weathered")
			if state.has("roster"):
				CrewLife.award_xp(state, "storm")
			_toast(Loc.t("weather.weathered"))
		w["storm_h"] = 0.0


## Lightning and big seas while the storm is full. Each warns before it lands.
func _storm_hazards(delta: float) -> void:
	var player: Ship = _player()
	if _warn_left >= 0.0:
		_warn_left -= delta
		if _warn_left < 0.0:
			_strike(_warn_target)
	if _sea_left >= 0.0:
		_sea_left -= delta
		if _sea_left < 0.0 and player != null:
			hit_with_sea(player)
	if float(current["storm"]) < 0.7 or player == null or not player.is_inside_tree():
		return
	_bolt_in -= delta
	if _bolt_in <= 0.0 and _warn_left < 0.0:
		_bolt_in = rng.randf_range(WeatherRules.LIGHTNING_EVERY_S.x, WeatherRules.LIGHTNING_EVERY_S.y)
		warn_lightning(_pick_target(player))
	_sea_in -= delta
	if _sea_in <= 0.0 and _sea_left < 0.0:
		_sea_in = rng.randf_range(WeatherRules.WAVE_EVERY_S.x, WeatherRules.WAVE_EVERY_S.y)
		warn_sea(player)


func _pick_target(player: Ship) -> Ship:
	var near: Array[Ship] = []
	for n in get_tree().get_nodes_in_group("ships"):
		var s: Ship = n as Ship
		if s != null and s != player and s.damage != null and not s.damage.sunk \
				and s.global_position.distance_to(player.global_position) < WeatherRules.LIGHTNING_RANGE_M:
			near.append(s)
	if near.is_empty() or rng.randf() < WeatherRules.LIGHTNING_PLAYER_CHANCE:
		return player
	return near[rng.randi() % near.size()]


## St Elmo's fire on the target's masthead; the bolt follows LIGHTNING_WARN_S later.
func warn_lightning(target: Ship) -> void:
	if target == null or target.damage == null or WeatherRules.strike_mast(target.damage) < 0:
		return
	_warn_target = target
	_warn_left = WeatherRules.LIGHTNING_WARN_S
	if is_instance_valid(_warn_glow):
		_warn_glow.queue_free()
	_warn_glow = StormFx.st_elmo(target, masthead(target, WeatherRules.strike_mast(target.damage)))
	if target == _player():
		_toast(Loc.t("weather.st_elmo"))
		Sfx.bark("storm")


## The world position of the top of mast `i`.
static func masthead(s: Ship, i: int) -> Vector3:
	var top: float = clampf(s.stats.length_m * 0.8, 10.0, 34.0)
	if s.visuals != null and i >= 0 and i < s.visuals.mast_groups.size():
		return s.visuals.mast_groups[i].global_position + Vector3.UP * top
	return s.global_position + Vector3.UP * top


## The bolt lands: damage to the struck mast and its sail, a flash and thunder.
func _strike(target: Ship) -> Dictionary:
	if is_instance_valid(_warn_glow):
		_warn_glow.queue_free()
	_warn_glow = null
	if target == null or not is_instance_valid(target) or target.damage == null:
		return {}
	var mast: int = WeatherRules.strike_mast(target.damage)
	var top: Vector3 = masthead(target, mast)
	var is_player: bool = target == _player()
	var mult: float = 1.0
	var mast_factor: float = 1.0
	if is_player and state.has("skills"):
		var skill: float = Progression.stat(state, "storm_damage_mult")
		mult = skill if skill > 0.0 else 1.0
		mast_factor = TourRewards.storm_mast_factor(state)
	var res: Dictionary = WeatherRules.lightning_strike(target.damage, mast, target.sail_level, mult, mast_factor)
	_flash = 1.0
	if target.is_inside_tree():
		StormFx.bolt(target.get_parent(), top)
		Sfx.play("thunder", top)
		target.refresh_damage()
	if is_player:
		_shake(0.5)
		_toast(Loc.t("weather.struck_fell") if bool(res.get("mast_fell", false)) else Loc.t("weather.struck"))
	lightning.emit(target, res)
	return res


## The lookout calls a big sea and the side it comes from; it breaks WAVE_WARN_S later.
func warn_sea(player: Ship) -> void:
	_sea_left = WeatherRules.WAVE_WARN_S
	var wind: WindModel = world.get("wind") if world != null else null
	var dir: Vector2 = wind.direction if wind != null else Vector2(1, 0)
	_toast(Loc.t("weather.big_sea") % Loc.t("weather.side." + WeatherRules.wave_side(player.heading(), dir)))


## A big sea breaks over `player`: hull damage by how square she takes it, never below the storm floor.
func hit_with_sea(player: Ship) -> Dictionary:
	if player == null or player.damage == null or player.damage.sunk:
		return {}
	var wind: WindModel = world.get("wind") if world != null else null
	var dir: Vector2 = wind.direction if wind != null else Vector2(1, 0)
	var exposure: float = WeatherRules.wave_exposure(player.heading(), dir)
	var mult: float = 1.0
	if state.has("skills"):
		var skill: float = Progression.stat(state, "storm_damage_mult")
		mult = skill if skill > 0.0 else 1.0
	var section: int = WeatherRules.wave_section(player.damage, player.heading(), dir)
	var taken: float = WeatherRules.storm_hull_hit(player.damage, section, WeatherRules.wave_damage(player.stats.hull_hp, exposure, mult))
	var res: Dictionary = {"exposure": exposure, "hull": taken, "section": section}
	if player.is_inside_tree():
		var side: Vector3 = Vector3(-dir.x, 0.0, -dir.y) * player.stats.beam_m
		Vfx.splash(player.get_parent(), player.global_position + side + Vector3.UP * 2.0, 4.0)
		Sfx.play("hull_groan", player.global_position)
		player.refresh_damage()
		_shake(clampf(exposure, 0.25, 0.8))
	if taken > player.stats.hull_hp * 0.02:
		_toast(Loc.t("weather.sea_hit") % roundi(taken))
	big_sea.emit(res)
	return res


func _shake(amount: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.get_parent() is CameraRig:
		(cam.get_parent() as CameraRig).shake(amount)


func _toast(text: String) -> void:
	var bus: Node = Svc.node("EventBus")
	if bus != null:
		bus.toast.emit(text)
