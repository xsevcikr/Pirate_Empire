extends SceneTree
## Soak scenario: a bot sails the world scene and fires broadsides, then reports memory growth.
##   godot --headless --path . --fixed-fps 60 -s res://tools/soak.gd -- --minutes=240
## Default is 1 simulated minute so the test suite stays fast.

var _w: Node
var _t: float = 0.0
var _limit_s: float = 60.0
var _mem0: float = 0.0
var _ready_to_run: bool = false
var _fire_t: float = 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			_limit_s = float(a.substr(10)) * 60.0
	_w = load("res://scenes/world.tscn").instantiate()
	root.add_child(_w)
	await process_frame
	await process_frame
	_mem0 = Performance.get_monitor(Performance.MEMORY_STATIC)
	_ready_to_run = true


func _physics_process(delta: float) -> bool:
	if not _ready_to_run:
		return false
	_t += delta
	_fire_t += delta
	if _fire_t > 6.0:
		_fire_t = 0.0
		Input.action_press("fire_port")
		Input.action_release("fire_port")
		_w.ship.broadside.fire(0)
	if _t >= _limit_s:
		var growth_mb: float = (Performance.get_monitor(Performance.MEMORY_STATIC) - _mem0) / 1048576.0
		print("SOAK %.0f s simulated, memory growth %.1f MB, orphan nodes %d" % [_t, growth_mb, int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
		if growth_mb < 50.0:
			print("SOAK: OK")
			quit(0)
		else:
			print("SOAK: FAILED")
			quit(1)
		return true
	return false
