class_name Assertions
extends RefCounted

static var current_suite_passed: int = 0
static var current_suite_failed: int = 0
static var failure_messages: Array[String] = []

static func reset() -> void:
	current_suite_passed = 0
	current_suite_failed = 0
	failure_messages.clear()

static func assert_true(condition: bool, message: String = "") -> bool:
	if condition:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected TRUE, got FALSE. " + message
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_false(condition: bool, message: String = "") -> bool:
	if not condition:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected FALSE, got TRUE. " + message
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_equal(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual == expected:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected %s, got %s. %s" % [str(expected), str(actual), message]
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_not_null(object: Variant, message: String = "") -> bool:
	if object != null:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected NOT NULL, got NULL. " + message
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_null(object: Variant, message: String = "") -> bool:
	if object == null:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected NULL, got %s. %s" % [str(object), message]
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_gt(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual > expected:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected %s > %s. %s" % [str(actual), str(expected), message]
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_ne(actual: Variant, expected: Variant, message: String = "") -> bool:
	if actual != expected:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected NOT %s, got %s. %s" % [str(expected), str(actual), message]
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_approx_equal(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> bool:
	if abs(actual - expected) <= tolerance:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected approx %f (+/-%f), got %f. %s" % [expected, tolerance, actual, message]
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false

static func assert_vector3_approx_equal(actual: Vector3, expected: Vector3, tolerance: float = 0.001, message: String = "") -> bool:
	if actual.distance_to(expected) <= tolerance:
		current_suite_passed += 1
		return true
	else:
		current_suite_failed += 1
		var err_msg := "Assertion failed: expected Vector3 approx %s (+/-%f), got %s. %s" % [str(expected), tolerance, str(actual), message]
		failure_messages.append(err_msg)
		printerr("  [FAIL] " + err_msg)
		push_error(err_msg)
		return false
