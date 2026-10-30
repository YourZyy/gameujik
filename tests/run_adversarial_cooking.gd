extends SceneTree

const Assertions = preload("res://tests/assertions.gd")
const TestAdversarialCooking = preload("res://tests/suites/test_adversarial_cooking.gd")

func _initialize() -> void:
	print("==================================================")
	print("[ADVERSARIAL_RUNNER] COOK-001 Adversarial Harness")
	print("==================================================")

	Assertions.reset()
	var suite := TestAdversarialCooking.new()
	var all_passed := suite.run_all()

	print("==================================================")
	print("[ADVERSARIAL_RUNNER] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	var log_path := ProjectSettings.globalize_path("res://adversarial_cooking_summary.log")
	var log_file := FileAccess.open(log_path, FileAccess.WRITE)
	if log_file != null:
		log_file.store_line("Assertions Passed: %d" % Assertions.current_suite_passed)
		log_file.store_line("Assertions Failed: %d" % Assertions.current_suite_failed)
		log_file.store_line("All Passed: %s" % str(all_passed and Assertions.current_suite_failed == 0))
		log_file.close()

	if all_passed and Assertions.current_suite_failed == 0:
		print("  RESULT: ALL ADVERSARIAL CHALLENGES PASSED (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  RESULT: ADVERSARIAL CHALLENGES FAILED (Exit Code: 1)")
		print("==================================================")
		quit(1)
