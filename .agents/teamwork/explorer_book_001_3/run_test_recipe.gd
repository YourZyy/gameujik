extends SceneTree

const Assertions = preload("res://tests/assertions.gd")
const ProposedTestRecipe = preload("res://.agents/teamwork/explorer_book_001_3/proposed_test_recipe.gd")

func _initialize() -> void:
	print("==================================================")
	print("[STANDALONE_RUNNER] Proposed TestRecipe Verification")
	print("==================================================")

	await process_frame
	Assertions.reset()
	var suite := ProposedTestRecipe.new()
	var passed: bool = await suite.run_all()

	print("==================================================")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)
	print("==================================================")

	if passed and Assertions.current_suite_failed == 0:
		print("RESULT: PROPOSED TEST SUITE PASSED")
		quit(0)
	else:
		printerr("RESULT: PROPOSED TEST SUITE FAILED")
		quit(1)
