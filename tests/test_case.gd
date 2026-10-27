class_name TestCase
extends RefCounted

var failures: Array[String] = []


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		failures.append(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		failures.append("%s expected %s got %s" % [msg, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tol: float, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		failures.append("%s expected %s +-%s got %s" % [msg, str(expected), str(tol), str(actual)])
