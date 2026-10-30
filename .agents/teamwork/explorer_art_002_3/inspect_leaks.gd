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

func _initialize() -> void:
	print("=== OBJECT AND ORPHAN NODE TRACKER PER SUITE ===")
	Assertions.reset()
	
	var suites: Array[Dictionary] = [
		{"name": "Suite 01: TestSetup", "cls": TestSetup, "async": false},
		{"name": "Suite 02: TestLevel", "cls": TestLevel, "async": false},
		{"name": "Suite 03: TestAdversarialLevel", "cls": TestAdversarialLevel, "async": false},
		{"name": "Suite 04: TestPlayer", "cls": TestPlayer, "async": false},
		{"name": "Suite 05: TestAdversarialPlayer", "cls": TestAdversarialPlayer, "async": false},
		{"name": "Suite 06: TestInteraction", "cls": TestInteraction, "async": true},
		{"name": "Suite 07: TestInventory", "cls": TestInventory, "async": true},
		{"name": "Suite 08: TestRecipe", "cls": TestRecipe, "async": true},
		{"name": "Suite 09: TestGardening", "cls": TestGardening, "async": true},
		{"name": "Suite 10: TestWorld", "cls": TestWorld, "async": true},
		{"name": "Suite 11: TestCooking", "cls": TestCooking, "async": true},
		{"name": "Suite 12: TestAdversarialCooking", "cls": TestAdversarialCooking, "async": false},
		{"name": "Suite 13: TestCookingHeat", "cls": TestCookingHeat, "async": false},
		{"name": "Suite 14: TestAdversarialCookingHeat", "cls": TestAdversarialCookingHeat, "async": false},
		{"name": "Suite 15: TestSocial", "cls": TestSocial, "async": true},
		{"name": "Suite 16: TestAdversarialSocial", "cls": TestAdversarialSocial, "async": true},
		{"name": "Suite 17: TestAdversarialLockFreeP0", "cls": TestAdversarialLockFreeP0, "async": true},
		{"name": "Suite 18: TestAdversarialChallengerSnapshotSignals", "cls": TestAdversarialChallengerSnapshotSignals, "async": false},
		{"name": "Suite 19: TestSave", "cls": TestSave, "async": false},
		{"name": "Suite 20: TestAdversarialSave", "cls": TestAdversarialSave, "async": false},
		{"name": "Suite 21: TestUI", "cls": TestUI, "async": false},
		{"name": "Suite 22: TestAdversarialUI", "cls": TestAdversarialUI, "async": false},
		{"name": "Suite 23: TestAdversarialUIStressOracle", "cls": TestAdversarialUIStressOracle, "async": false},
		{"name": "Suite 24: TestArt", "cls": TestArt, "async": false}
	]
	
	for entry in suites:
		var pre_obj: int = Performance.get_monitor(Performance.OBJECT_COUNT)
		var pre_node: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var pre_orphan: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var pre_res: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		
		var inst = entry["cls"].new()
		if entry["async"]:
			await inst.run_all()
		else:
			inst.run_all()
		inst = null
		
		var post_obj: int = Performance.get_monitor(Performance.OBJECT_COUNT)
		var post_node: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var post_orphan: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var post_res: int = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		
		print("[SUITE_LEAK_TRACK] %-42s | Delta Obj: %+5d | Delta Node: %+3d | Delta Orphan: %+3d | Delta Res: %+3d | Total Obj: %d" % [
			entry["name"],
			post_obj - pre_obj,
			post_node - pre_node,
			post_orphan - pre_orphan,
			post_res - pre_res,
			post_obj
		])
		
	quit(0)
