extends SceneTree
## Soak scenario: a bot plays a real game (new captain, game layer, clock, rivals, events) for a long stretch: it
## sails a loop of waypoints around the home waters, fires at whatever is near, docks and trades now and then, and
## restarts the voyage if it is sunk. Every ten simulated minutes it reports memory, nodes, ships and sound counts.
##   godot --headless --path . --fixed-fps 60 -s res://tools/soak.gd -- --minutes=240
## Default is 1 simulated minute so the test suite stays fast. Script errors show up as "ERROR" lines in the output.

const REPORT_EVERY_S: float = 600.0
const WAYPOINTS: Array[Vector2] = [Vector2(0, 420), Vector2(2600, 200), Vector2(3200, 2600), Vector2(500, 3400), Vector2(-2400, 2000), Vector2(-2600, -200)]
const MEM_GROWTH_LIMIT_MB: float = 200.0

var _w: Node
var _t: float = 0.0
var _limit_s: float = 60.0
var _mem0: float = 0.0
var _ready_to_run: bool = false
var _fire_t: float = 0.0
var _next_report: float = REPORT_EVERY_S
var _wp: int = 1
var _restarts: int = 0
var _frames: int = 0
var _worst_ms: float = 0.0
var _last_us: int = 0
var _peak_nodes: int = 0
var _clock_scale: float = 1.0  ## game-clock speed: raise it to push many game days through the systems
var _loading: bool = false
var _stuck_s: float = 0.0
var _load_frames: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			_limit_s = float(a.substr(10)) * 60.0
		if a.begins_with("--clock="):
			_clock_scale = float(a.substr(8))
	for s in [0, 1, 2, 3]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.SLOT_PATH % s))
	_start()


func _start() -> void:
	_ready_to_run = false
	_loading = true
	_load_frames = 0
	Session.begin_new("Soak", 1, 1)
	Session.enter_world(self)


func _finish_load() -> void:
	_loading = false
	_w = current_scene
	Svc.node("Audio").muted = true
	if _mem0 == 0.0:
		_mem0 = Performance.get_monitor(Performance.MEMORY_STATIC)
	_ready_to_run = true
	print("SOAK start after %d frames, restarts %d" % [_load_frames, _restarts])


func _physics_process(delta: float) -> bool:
	if _loading:
		_load_frames += 1
		if current_scene != null and current_scene.name == "World" and _load_frames > 4:
			_finish_load()
		return false
	if not _ready_to_run:
		return false
	if _w == null or not is_instance_valid(_w) or current_scene != _w or _w.ship == null or not is_instance_valid(_w.ship) or _w.ship.damage.sunk:
		_restarts += 1
		_start()
		return false
	_t += delta
	_frames += 1
	var now: int = Time.get_ticks_usec()
	if _last_us != 0:
		_worst_ms = maxf(_worst_ms, float(now - _last_us) / 1000.0)
	_last_us = now
	_clear_screens(delta)
	var clock: Node = root.get_node_or_null("GameClock")
	if clock != null:
		clock.time_scale = _clock_scale
	_steer()
	_fire_t += delta
	if _fire_t > 6.0:
		_fire_t = 0.0
		_w.ship.broadside.fire(0)
		_w.ship.broadside.fire(1)
	if get_nodes_in_group("ships").size() > 60:
		print("SOAK: too many ships %d" % get_nodes_in_group("ships").size())
	_peak_nodes = maxi(_peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	if _t >= _next_report:
		_next_report += REPORT_EVERY_S
		print(_report())
	if _t >= _limit_s:
		var growth_mb: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - _mem0) / 1048576.0
		print(_report())
		print("SOAK %.0f s simulated, memory growth %.1f MB, orphan nodes %d, restarts %d, peak nodes %d" % [_t, growth_mb, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), _restarts, _peak_nodes])
		if growth_mb < MEM_GROWTH_LIMIT_MB:
			print("SOAK: OK")
			quit(0)
		else:
			print("SOAK: FAILED")
			quit(1)
		return true
	return false


## A mutiny, inspection or the like opens a screen; the bot closes any that has been up for more than a few seconds.
func _clear_screens(delta: float) -> void:
	var open: bool = false
	for n in ["PortLayer", "MapLayer"]:
		if _w.get_node_or_null(n) != null:
			open = true
			_stuck_s += delta
			if _stuck_s > 5.0:
				_w.get_node(n).queue_free()
				paused = false
	if not open:
		_stuck_s = 0.0


## Head for the next waypoint under full sail.
func _steer() -> void:
	var ship: Ship = _w.ship
	var p := Vector2(ship.global_position.x, ship.global_position.z)
	if p.distance_to(WAYPOINTS[_wp]) < 150.0:
		_wp = (_wp + 1) % WAYPOINTS.size()
	var want: Vector2 = (WAYPOINTS[_wp] - p).normalized()
	var fwd3: Vector3 = -ship.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	ship.rudder_input = clampf(-fwd.cross(want) * 3.0, -1.0, 1.0)
	ship.sail_level = 3


func _ship_mix() -> String:
	var mix: Dictionary = {}
	for n in get_nodes_in_group("ships"):
		var k: String = "%s%s%s" % [(n as Ship).faction, "/convoy" if n.has_meta("convoy") else "", "/sunk" if (n as Ship).damage.sunk else ""]
		mix[k] = int(mix.get(k, 0)) + 1
	return str(mix)


func _report() -> String:
	var audio: Node = Svc.node("Audio")
	var sounds: int = 0
	for k in audio.played:
		sounds += int(audio.played[k])
	print("SOAK ships: ", _ship_mix())
	return "SOAK t=%dm mem=%.0fMB nodes=%d ships=%d day=%d gold=%d worst_frame=%.0fms sounds=%d restarts=%d" % [
		int(_t / 60.0), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		get_nodes_in_group("ships").size(), int(Session.state.get("day", 0)), int(Session.state.get("gold", 0)), _worst_ms, sounds, _restarts]
