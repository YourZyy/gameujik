extends SceneTree

const Assertions = preload("res://tests/assertions.gd")
const TestSetup = preload("res://tests/suites/test_setup.gd")
const TestLevel = preload("res://tests/suites/test_level.gd")
const TestAdversarialLevel = preload("res://tests/suites/test_adversarial_level.gd")
const TestPlayer = preload("res://tests/suites/test_player.gd")
const TestAdversarialPlayer = preload("res://tests/suites/test_adversarial_player.gd")
const TestInteraction = preload("res://tests/suites/test_interaction.gd")
const TestInventory = preload("res://tests/suites/test_inventory.gd")
const TestRecipe = preload("res://tests/suites/test_recipe.gd")
const TestGardening = preload("res://tests/suites/test_gardening.gd")
const TestWorld = preload("res://tests/suites/test_world.gd")
const TestCooking = preload("res://tests/suites/test_cooking.gd")
const TestAdversarialCooking = preload("res://tests/suites/test_adversarial_cooking.gd")
const TestCookingHeat = preload("res://tests/suites/test_cooking_heat.gd")
const TestAdversarialCookingHeat = preload("res://tests/suites/test_adversarial_cooking_heat.gd")
const TestSocial = preload("res://tests/suites/test_social.gd")
const TestAdversarialSocial = preload("res://tests/suites/test_adversarial_social.gd")
const TestAdversarialLockFreeP0 = preload("res://tests/suites/test_adversarial_lock_free_p0.gd")
const TestAdversarialChallengerSnapshotSignals = preload("res://tests/suites/test_adversarial_challenger_snapshot_signals.gd")
const TestSave = preload("res://tests/suites/test_save.gd")
const TestAdversarialSave = preload("res://tests/suites/test_adversarial_save.gd")
const TestUI = preload("res://tests/suites/test_ui.gd")
const TestAdversarialUI = preload("res://tests/suites/test_adversarial_ui.gd")
const TestAdversarialUIStressOracle = preload("res://tests/suites/test_adversarial_ui_stress_oracle.gd")
const TestArt = preload("res://tests/suites/test_art.gd")
const TestAdversarialArt = preload("res://tests/suites/test_adversarial_art.gd")
const TestQAPlaythrough = preload("res://tests/suites/test_qa_playthrough.gd")

func _initialize() -> void:
	print("==================================================")
	print("[TEST_RUNNER] Buku Resep 2045 — Headless Test Runner")
	print("==================================================")
	
	Assertions.reset()
	var all_passed := true

	# Suite 1: TestSetup (T23, T24 baseline)
	var suite_setup := TestSetup.new()
	if not suite_setup.run_all():
		all_passed = false

	# Suite 2: TestLevel (T24, T25 graybox level & recovery)
	var suite_level := TestLevel.new()
	if not suite_level.run_all():
		all_passed = false

	# Suite 3: TestAdversarialLevel (LVL-001 Stress & Recovery Challenge)
	var suite_adv := TestAdversarialLevel.new()
	if not suite_adv.run_all():
		all_passed = false

	# Suite 4: TestPlayer (T18, T25, T26 first-person controls & physics)
	var suite_player := TestPlayer.new()
	if not suite_player.run_all():
		all_passed = false

	# Suite 5: TestAdversarialPlayer (PLY-001 Stress & Edge-Case Verification)
	var suite_adv_player := TestAdversarialPlayer.new()
	if not suite_adv_player.run_all():
		all_passed = false

	# Suite 6: TestInteraction (T18, T27, T28 interaction, occlusion & input context)
	var suite_interaction := TestInteraction.new()
	if not await suite_interaction.run_all():
		all_passed = false

	# Suite 7: TestInventory (T02, T03, T04, T29, T30, T31, T32, T33 inventory & storage)
	var suite_inventory := TestInventory.new()
	if not await suite_inventory.run_all():
		all_passed = false

	# Suite 8: TestRecipe (T01, T02, T03, T11, T31, notes registry, save snapshot, input context)
	var suite_recipe := TestRecipe.new()
	if not await suite_recipe.run_all():
		all_passed = false

	# Suite 9: TestGardening (T06, T07, T08, T32, T33, plot prep, tools, planting, fertilizing, watering)
	var suite_gardening := TestGardening.new()
	if not await suite_gardening.run_all():
		all_passed = false

	# Suite 10: TestWorld (T09, T37, T38, T39 world resources, reserves, sleep & calendar)
	var suite_world := TestWorld.new()
	if not await suite_world.run_all():
		all_passed = false

	# Suite 11: TestCooking (T10, T11, T12, T13, T40 kitchen validation, reservation, 4s hold prep, cancel & safe refund)
	var suite_cooking := TestCooking.new()
	if not await suite_cooking.run_all():
		all_passed = false

	# Suite 12: TestAdversarialCooking (COOK-001 Stress, Invariants & Matter Conservation)
	var suite_adv_cooking := TestAdversarialCooking.new()
	if not suite_adv_cooking.run_all():
		all_passed = false

	# Suite 13: TestCookingHeat (T12, T15, T19, T41, T42, T43 cooking heat control, pause, output & eating)
	var suite_cooking_heat := TestCookingHeat.new()
	if not suite_cooking_heat.run_all():
		all_passed = false

	# Suite 14: TestAdversarialCookingHeat (COOK-002 Stress, Invariants, Remake & Dish Eating Challenge)
	var suite_adv_cook_heat := TestAdversarialCookingHeat.new()
	if not suite_adv_cook_heat.run_all():
		all_passed = false

	# Suite 15: TestSocial (T43, T44, T45 neighbor dialogue, dish sharing & P0 closing)
	var suite_social := TestSocial.new()
	if not await suite_social.run_all():
		all_passed = false

	# Suite 16: TestAdversarialSocial (SOC-001 Bounds, Cancellation & Spam Verification - Challenger 1)
	var suite_adv_social := TestAdversarialSocial.new()
	if not await suite_adv_social.run_all():
		all_passed = false

	# Suite 17: TestAdversarialLockFreeP0 (SOC-001 Lock-Free Invariants, Alternative Sequences & Anti-Softlock - Challenger 2)
	var suite_adv_lock_free := TestAdversarialLockFreeP0.new()
	if not await suite_adv_lock_free.run_all():
		all_passed = false

	# Suite 18: TestAdversarialChallengerSnapshotSignals (SOC-001 Snapshot Deserialization & P0 Signal Stress - Challenger R2)
	var suite_adv_chal := TestAdversarialChallengerSnapshotSignals.new()
	if not suite_adv_chal.run_all():
		all_passed = false

	# Suite 19: TestSave (SAVE-001 Persistence, Checkpoint, Envelope & Error Recovery)
	var suite_save := TestSave.new()
	if not suite_save.run_all():
		all_passed = false

	# Suite 20: TestAdversarialSave (SAVE-001 Adversarial Stress, Atomic Crash Simulation & Multi-Roundtrip Idempotence)
	var suite_adv_save := TestAdversarialSave.new()
	if not suite_adv_save.run_all():
		all_passed = false

	# Suite 21: TestUI (UI-001 Integrated Menu, Pause, Settings, Focus, and Honest Notifications)
	var suite_ui := TestUI.new()
	if not suite_ui.run_all():
		all_passed = false

	# Suite 22: TestAdversarialUI (UI-001 Adversarial Stress, Input Bleed Guard & Modal Safety)
	var suite_adv_ui := TestAdversarialUI.new()
	if not suite_adv_ui.run_all():
		all_passed = false

	# Suite 23: TestAdversarialUIStressOracle (UI-001 Toast Spam, Muting & Save Roundtrip Oracle - Challenger 2)
	var suite_adv_ui_2 := TestAdversarialUIStressOracle.new()
	if not suite_adv_ui_2.run_all():
		all_passed = false

	# Suite 24: TestArt (ART-001 Visual & Audio Identity, T55 & T56)
	var suite_art := TestArt.new()
	if not suite_art.run_all():
		all_passed = false

	# Suite 25: TestAdversarialArt (ART-001 Empirical Adversarial Oracles & Stress Verification)
	var suite_adv_art := TestAdversarialArt.new()
	if not suite_adv_art.run_all():
		all_passed = false

	# Suite 26: TestQAPlaythrough (QA-001 End-to-End P0 Acceptance Playthrough & Final QA Regression)
	var suite_qa := TestQAPlaythrough.new()
	if not await suite_qa.run_all():
		all_passed = false

	# Summary
	print("==================================================")
	print("[TEST_RUNNER] SUMMARY:")
	print("  Assertions Passed: %d" % Assertions.current_suite_passed)
	print("  Assertions Failed: %d" % Assertions.current_suite_failed)

	var log_path := ProjectSettings.globalize_path("res://test_summary.log")
	var log_file := FileAccess.open(log_path, FileAccess.WRITE)
	if log_file != null:
		log_file.store_line("Assertions Passed: %d" % Assertions.current_suite_passed)
		log_file.store_line("Assertions Failed: %d" % Assertions.current_suite_failed)
		log_file.store_line("All Passed: %s" % str(all_passed and Assertions.current_suite_failed == 0))
		for msg in Assertions.failure_messages:
			print("  >> FAILURE: ", msg)
			log_file.store_line("FAIL: " + msg)
		log_file.close()

	# Flush pending idle deletions before exit
	await process_frame
	await process_frame

	if all_passed and Assertions.current_suite_failed == 0:
		print("  RESULT: ALL SUITES PASSED (Exit Code: 0)")
		print("==================================================")
		quit(0)
	else:
		printerr("  RESULT: TEST FAILURES ENCOUNTERED (Exit Code: 1)")
		print("==================================================")
		quit(1)
