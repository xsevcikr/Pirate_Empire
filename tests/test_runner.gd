extends SceneTree
## Minimal headless test runner.
## Run: godot --headless --path . -s res://tests/test_runner.gd
## Every tests/unit/test_*.gd script must extend TestCase; each method named test_* is run.

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	var dir := DirAccess.open("res://tests/unit")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		_run_file("res://tests/unit/" + f)
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		_failed += 1
		print("FAIL %s (script failed to load)" % path.get_file())
		return
	var obj: TestCase = script.new()
	for m in obj.get_method_list():
		var mname: String = m["name"]
		if not mname.begins_with("test_"):
			continue
		obj.failures.clear()
		obj.call(mname)
		if obj.failures.is_empty():
			_passed += 1
			print("PASS %s::%s" % [path.get_file(), mname])
		else:
			_failed += 1
			print("FAIL %s::%s" % [path.get_file(), mname])
			for msg in obj.failures:
				print("     " + msg)
