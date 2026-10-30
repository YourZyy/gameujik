class_name AdversarialArtOracle
extends SceneTree

## Adversarial Art & Audio Stress Oracle for ART-001
## Standalone wrapper delegating to Suite 25 (TestAdversarialArt)

const Assertions = preload("res://tests/assertions.gd")
const TestAdversarialArt = preload("res://tests/suites/test_adversarial_art.gd")

func _initialize() -> void:
	print("==================================================")
	print("[ADVERSARIAL_ART_ORACLE] ART-001 Empirical Stress & Accessibility Oracle")
	print("==================================================")

	var suite := TestAdversarialArt.new()
	var success := suite.run_all()

	print("==================================================")
	print("[ADVERSARIAL_ART_ORACLE] SUMMARY:")
	print("  Total Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Total Assertions Failed: %d" % Assertions.current_suite_failed)
	if success and Assertions.current_suite_failed == 0:
		print("  RESULT: ALL ADVERSARIAL ORACLES PASSED (Exit Code: 0)")
		quit(0)
	else:
		print("  RESULT: ADVERSARIAL FAILURES ENCOUNTERED (Exit Code: 1)")
		quit(1)
