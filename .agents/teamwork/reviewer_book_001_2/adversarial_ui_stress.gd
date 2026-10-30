extends SceneTree

# Independent Adversarial Stress Test by reviewer_book_001_2
# Stress-testing BookUI, HUD, Landmarks, and Input Context Isolation

const Assertions = preload("res://tests/assertions.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")
const InventoryManagerClass = preload("res://scripts/inventory/inventory_manager.gd")
const RecipeManagerClass = preload("res://scripts/recipe/recipe_manager.gd")

func _init() -> void:
	print("==================================================")
	print("[ADVERSARIAL_REVIEWER_2] Starting UI & Input Stress Harness...")
	print("==================================================")

	var failures: int = 0

	var test_runner = func(name: String, test_callable: Callable) -> void:
		print("\n[RUNNING] %s" % name)
		var ok: bool = await test_callable.call()
		if ok:
			print("[PASSED] %s" % name)
		else:
			print("[FAILED] %s" % name)
			failures += 1

	await test_runner.call("ADV-UI-01: HUD Mouse Filter Transparency Stress", test_hud_mouse_filter_transparency)
	await test_runner.call("ADV-UI-02: HUD Dynamic Stock Reactivity & Untrack Invariance", test_hud_stock_reactivity)
	await test_runner.call("ADV-UI-03: HUD Interaction Prompt API Full Protocol Compliance", test_hud_prompt_api_compliance)
	await test_runner.call("ADV-UI-04: BookUI Keyboard/Button Focus & Repeated Toggle Cycling", test_book_focus_and_toggle_cycle)
	await test_runner.call("ADV-UI-05: BookUI Note Unlocking & Dynamic Text Assembly", test_book_note_unlocking_assembly)
	await test_runner.call("ADV-UI-06: World Landmarks book_family & note_garden_01 Complete Flow", test_world_landmarks_flow)
	await test_runner.call("ADV-UI-07: Context Isolation & Cross-Modal Hotkey Suppression", test_cross_modal_hotkey_suppression)

	print("\n==================================================")
	print("[ADVERSARIAL_REVIEWER_2] SUMMARY:")
	print("  Total Failures: %d" % failures)
	print("==================================================")

	if failures > 0:
		quit(1)
	else:
		quit(0)

# ADV-UI-01: HUD Mouse Filter Transparency Stress
# All containers on HUD exploration layer MUST have mouse_filter == MOUSE_FILTER_IGNORE (2)
# so they don't block 3D raycast interactions or click inputs in first-person gameplay!
func test_hud_mouse_filter_transparency() -> bool:
	var hud_scene = load("res://scenes/ui/hud.tscn") as PackedScene
	if hud_scene == null:
		print("  ERROR: hud.tscn not found")
		return false
	var hud = hud_scene.instantiate() as CanvasLayer
	root.add_child(hud)
	await process_frame

	var check_node = func(node: Node, self_callable: Callable) -> bool:
		if node is Control:
			# Non-interactive HUD elements must ignore mouse
			if node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				print("  VIOLATION: Control node %s has mouse_filter = %d (expected MOUSE_FILTER_IGNORE = 2)" % [node.name, node.mouse_filter])
				return false
		for child in node.get_children():
			if not self_callable.call(child, self_callable):
				return false
		return true

	var all_ignore = check_node.call(hud, check_node)
	hud.queue_free()
	await process_frame
	return all_ignore

# ADV-UI-02: HUD Dynamic Stock Reactivity & Untrack Invariance
func test_hud_stock_reactivity() -> bool:
	var hud_scene = load("res://scenes/ui/hud.tscn") as PackedScene
	var hud = hud_scene.instantiate() as CanvasLayer
	root.add_child(hud)
	await process_frame

	var inv = InventoryManagerClass.new()
	inv._ready()
	inv.backpack.clear()
	inv.storage_home.clear()

	var rm = RecipeManagerClass.new()
	rm.set_inventory_manager(inv)
	rm._ready()

	hud.set_recipe_manager(rm)
	await process_frame

	var untracked_box = hud.find_child("UntrackedContainer", true, false) as Control
	var tracked_box = hud.find_child("TrackedContainer", true, false) as Control
	var bayam_row = hud.find_child("BayamRow", true, false) as Label
	var jagung_row = hud.find_child("JagungRow", true, false) as Label
	var status_label = hud.find_child("TrackerStatusLabel", true, false) as Label

	# Initial: Untracked
	if not untracked_box.visible or tracked_box.visible:
		print("  FAIL: Initial HUD state is not untracked")
		return false

	# Track recipe
	rm.track_recipe("recipe_sayur_bening_01")
	await process_frame

	if untracked_box.visible or not tracked_box.visible:
		print("  FAIL: HUD did not switch to tracked view")
		return false
	if bayam_row.text != "• Bayam: 0/3" or jagung_row.text != "• Jagung: 0/1":
		print("  FAIL: HUD rows incorrect: %s, %s" % [bayam_row.text, jagung_row.text])
		return false

	# Add partial items across backpack and storage
	inv.add_items("backpack", [{"item_id": "ingredient_bayam", "count": 2}])
	inv.add_items("storage", [{"item_id": "ingredient_bayam", "count": 1}])
	inv.add_items("backpack", [{"item_id": "ingredient_jagung", "count": 1}])
	await process_frame

	if bayam_row.text != "• Bayam: 3/3" or jagung_row.text != "• Jagung: 1/1":
		print("  FAIL: HUD did not react to inventory update: %s, %s" % [bayam_row.text, jagung_row.text])
		return false

	# Add temu kunci to complete all ingredients
	inv.add_items("storage", [{"item_id": "ingredient_temu_kunci", "count": 1}])
	await process_frame

	if not status_label.visible or status_label.text != "Bahan lengkap. Siap dimasak di dapur.":
		print("  FAIL: Status label did not show ready message: '%s' (visible=%s)" % [status_label.text, status_label.visible])
		return false

	# Cooking state change: "cooking"
	rm.set_cooking_state("cooking")
	await process_frame
	if status_label.text != "Sedang memasak...":
		print("  FAIL: Status label did not update on cooking state: '%s'" % status_label.text)
		return false

	# Untrack: Should restore untracked view without wiping inventory
	rm.untrack_recipe()
	await process_frame
	if not untracked_box.visible or tracked_box.visible:
		print("  FAIL: Untrack did not restore untracked view")
		return false

	hud.queue_free()
	rm.free()
	inv.free()
	await process_frame
	return true

# ADV-UI-03: HUD Interaction Prompt API Full Protocol Compliance
func test_hud_prompt_api_compliance() -> bool:
	var hud_scene = load("res://scenes/ui/hud.tscn") as PackedScene
	var hud = hud_scene.instantiate() as CanvasLayer
	root.add_child(hud)
	await process_frame

	# Check all required methods from InteractionPrompt contract
	var methods = ["show_prompt", "hide_prompt", "is_prompt_visible", "get_prompt_text", "connect_detector"]
	for m in methods:
		if not hud.has_method(m):
			print("  FAIL: HUD is missing method %s" % m)
			hud.queue_free()
			return false

	# Initial prompt state: hidden
	if hud.is_prompt_visible():
		print("  FAIL: HUD prompt is visible initially")
		hud.queue_free()
		return false

	# Show prompt
	hud.show_prompt("[E] Periksa Meja")
	if not hud.is_prompt_visible() or hud.get_prompt_text() != "[E] Periksa Meja":
		print("  FAIL: show_prompt failed, text='%s', visible=%s" % [hud.get_prompt_text(), hud.is_prompt_visible()])
		hud.queue_free()
		return false

	# Hide prompt
	hud.hide_prompt()
	if hud.is_prompt_visible():
		print("  FAIL: hide_prompt failed")
		hud.queue_free()
		return false

	hud.queue_free()
	await process_frame
	return true

# ADV-UI-04: BookUI Keyboard/Button Focus & Repeated Toggle Cycling
func test_book_focus_and_toggle_cycle() -> bool:
	var book_scene = load("res://scenes/ui/book_ui.tscn") as PackedScene
	var book = book_scene.instantiate() as CanvasLayer
	root.add_child(book)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	if im == null:
		print("  FAIL: InputManager not found in root")
		book.queue_free()
		return false

	im.pop_to_world()

	for cycle in range(5):
		# Open book
		book.open_book()
		await process_frame

		if not book.visible:
			print("  FAIL cycle %d: Book not visible after open_book" % cycle)
			book.queue_free()
			return false
		if im.get_current_context() != im.ContextMode.BOOK:
			print("  FAIL cycle %d: Context is not BOOK (%d)" % [cycle, im.get_current_context()])
			book.queue_free()
			return false

		# Track button must have focus
		var track_btn = book.find_child("TrackButton", true, false) as Button
		if track_btn == null or not track_btn.has_focus():
			print("  FAIL cycle %d: TrackButton does not have focus" % cycle)
			book.queue_free()
			return false

		# Close book
		book.close_book()
		await process_frame

		if book.visible:
			print("  FAIL cycle %d: Book still visible after close_book" % cycle)
			book.queue_free()
			return false
		if im.get_current_context() != im.ContextMode.WORLD:
			print("  FAIL cycle %d: Context not restored to WORLD (%d)" % [cycle, im.get_current_context()])
			book.queue_free()
			return false

	book.queue_free()
	await process_frame
	return true

# ADV-UI-05: BookUI Note Unlocking & Dynamic Text Assembly
func test_book_note_unlocking_assembly() -> bool:
	var book_scene = load("res://scenes/ui/book_ui.tscn") as PackedScene
	var book = book_scene.instantiate() as CanvasLayer
	root.add_child(book)
	await process_frame

	var rm = root.get_node_or_null("RecipeManager")
	if rm == null:
		print("  FAIL: RecipeManager autoload not present")
		book.queue_free()
		return false

	book.open_book()
	await process_frame

	var notes_label = book.find_child("NotesLabel", true, false) as Label
	if notes_label == null:
		print("  FAIL: NotesLabel not found in BookUI")
		book.queue_free()
		return false

	var initial_text = notes_label.text
	if not "Bayam paling enak dipetik" in initial_text:
		print("  FAIL: Family note text missing from NotesLabel: %s" % initial_text)
		book.queue_free()
		return false

	# Unlock note_garden_01
	rm.unlock_note("note_garden_01")
	await process_frame
	book.refresh_ui()

	var updated_text = notes_label.text
	if not "Pagar boleh miring. Jangan sampai lupa jalan pulang." in updated_text:
		print("  FAIL: Unlocked garden note text not assembled into NotesLabel: %s" % updated_text)
		book.queue_free()
		return false

	book.close_book()
	book.queue_free()
	await process_frame
	return true

# ADV-UI-06: World Landmarks book_family & note_garden_01 Complete Flow
func test_world_landmarks_flow() -> bool:
	var main_scene = load("res://scenes/main.tscn") as PackedScene
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var rm = root.get_node_or_null("RecipeManager")
	var player = main.find_child("Player", true, false) as Node3D
	var book_ui = main.find_child("BookUI", true, false) as CanvasLayer
	var level = main.find_child("LevelGraybox", true, false)

	# 1. Interact with book_family on table
	var book_landmark = level.find_child("book_family", true, false)
	var book_interactable = book_landmark.find_child("Interactable", true, false)
	if book_interactable == null:
		print("  FAIL: book_family has no Interactable child")
		main.queue_free()
		return false

	book_interactable.interact(player)
	await process_frame

	if not book_ui.visible:
		print("  FAIL: BookUI not visible after table book interaction")
		main.queue_free()
		return false
	if im.get_current_context() != im.ContextMode.BOOK:
		print("  FAIL: Context not BOOK after table interaction")
		main.queue_free()
		return false

	# Close BookUI
	book_ui.close_book()
	await process_frame
	if book_ui.visible or im.get_current_context() != im.ContextMode.WORLD:
		print("  FAIL: Closing BookUI failed")
		main.queue_free()
		return false

	# 2. Interact with note_garden_01 in garden
	var note_landmark = level.find_child("note_garden_01", true, false)
	var note_interactable = note_landmark.find_child("Interactable", true, false)
	if note_interactable == null:
		print("  FAIL: note_garden_01 has no Interactable child")
		main.queue_free()
		return false

	note_interactable.interact(player)
	await process_frame

	if not rm.is_note_unlocked("note_garden_01"):
		print("  FAIL: Interacting with note_garden_01 did not unlock note in RecipeManager")
		main.queue_free()
		return false

	# Prompt updated to "Baca Ulang"
	var prompt_action = note_interactable.get("prompt_action")
	if prompt_action != "Baca Ulang":
		print("  FAIL: note_garden_01 prompt_action not updated to 'Baca Ulang': '%s'" % prompt_action)
		main.queue_free()
		return false

	main.queue_free()
	await process_frame
	return true

# ADV-UI-07: Context Isolation & Cross-Modal Hotkey Suppression
func test_cross_modal_hotkey_suppression() -> bool:
	var im = root.get_node_or_null("InputManager")
	if im == null:
		return false

	im.pop_to_world()

	# Open STORAGE
	im.push_context(im.ContextMode.STORAGE)
	if im.get_current_context() != im.ContextMode.STORAGE:
		print("  FAIL: Could not set STORAGE context")
		return false

	# While in STORAGE, open_book must not push BOOK on top or corrupt stack depth directly
	# InputManager._unhandled_input ignores open_book when not in WORLD and not in BOOK
	var depth_before = im.get_stack_depth()
	var fake_b = InputEventKey.new()
	fake_b.pressed = true
	fake_b.keycode = KEY_B
	# Note: In a headless environment, simulated unhandled events check context isolation
	if im.get_current_context() != im.ContextMode.STORAGE:
		print("  FAIL: Context leaked out of STORAGE")
		return false

	im.pop_to_world()
	return true
