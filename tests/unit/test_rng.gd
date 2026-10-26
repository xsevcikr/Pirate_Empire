extends TestCase

const RngScript := preload("res://src/core/rng.gd")


func test_same_seed_same_sequence() -> void:
	var a: Node = RngScript.new()
	var b: Node = RngScript.new()
	a.set_seed(42)
	b.set_seed(42)
	for i in 10:
		assert_eq(a.stream("ai").randi(), b.stream("ai").randi())
	a.free()
	b.free()


func test_streams_independent() -> void:
	var a: Node = RngScript.new()
	a.set_seed(7)
	var first: int = a.stream("ai").randi()
	a.stream("economy").randi()
	var b: Node = RngScript.new()
	b.set_seed(7)
	assert_eq(b.stream("ai").randi(), first)
	a.free()
	b.free()
