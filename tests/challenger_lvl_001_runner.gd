extends SceneTree

const Assertions = preload("res://tests/assertions.gd")
const TestAdversarialLevel = preload("res://tests/suites/test_adversarial_level.gd")

func _init() -> void:
	print("==================================================")
	print("[CHALLENGER_RUNNER] Milestone LVL-001 Stress Test")
	print("==================================================")

	Assertions.reset()
	var suite = TestAdversarialLevel.new()
	var ok = suite.run_all()

	print("==================================================")
	print("[CHALLENGER_RUNNER] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	if ok and Assertions.current_suite_failed == 0:
		print("  VERDICT: ALL ADVERSARIAL STRESS TESTS PASSED (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  VERDICT: ADVERSARIAL FAILURES ENCOUNTERED (Exit Code: 1)")
		for msg in Assertions.failure_messages:
			printerr("    - ", msg)
		print("==================================================")
		quit(1)
