class_name TestCase
extends RefCounted

## Base class for test_*.gd files. Each test_*() method should return true on
## success or false after an assert_* helper below has recorded last_error.

var last_error: String = ""


func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		return true
	last_error = message if message != "" else "expected true, got false"
	return false


func assert_false(condition: bool, message: String = "") -> bool:
	return assert_true(not condition, message if message != "" else "expected false, got true")


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		return true
	var detail: String = "expected %s, got %s" % [str(expected), str(actual)]
	last_error = "%s (%s)" % [message, detail] if message != "" else detail
	return false


func assert_null(value: Variant, message: String = "") -> bool:
	return assert_true(value == null, message if message != "" else "expected null")


func assert_not_null(value: Variant, message: String = "") -> bool:
	return assert_true(value != null, message if message != "" else "expected non-null")


func assert_has(container: Variant, value: Variant, message: String = "") -> bool:
	if container is Array:
		return assert_true((container as Array).has(value), message if message != "" else "expected array to contain %s" % str(value))
	if container is Dictionary:
		return assert_true((container as Dictionary).has(value), message if message != "" else "expected dict to have key %s" % str(value))
	last_error = "assert_has: unsupported container type"
	return false


func assert_not_has(container: Variant, value: Variant, message: String = "") -> bool:
	if container is Array:
		return assert_true(not (container as Array).has(value), message if message != "" else "expected array to not contain %s" % str(value))
	if container is Dictionary:
		return assert_true(not (container as Dictionary).has(value), message if message != "" else "expected dict to not have key %s" % str(value))
	last_error = "assert_not_has: unsupported container type"
	return false


func assert_array_eq_unordered(actual: Array, expected: Array, message: String = "") -> bool:
	if actual.size() != expected.size():
		last_error = "%s (size mismatch: expected %d, got %d)" % [message, expected.size(), actual.size()]
		return false
	for item in expected:
		if not actual.has(item):
			last_error = "%s (missing %s)" % [message, str(item)]
			return false
	return true
