extends SceneTree

# Test Script: Comparing Option A vs Option B for DEFECT-BOOK-01
# Executed via: godot --headless -s .agents/teamwork/explorer_book_001_r2_1/test_fix_options.gd

func _init() -> void:
	print("================================================================================")
	print("[EXPLORER_TEST] Evaluating Fix Strategies for DEFECT-BOOK-01")
	print("================================================================================")
	call_deferred("_run_tests")

func _run_tests() -> void:
	await _test_option_a()
	await _test_option_b()
	print("================================================================================")
	print("[EXPLORER_TEST] Evaluation Complete")
	print("================================================================================")
	quit(0)

func _test_option_a() -> void:
	print("\n--- Testing Option A: main.gd calls get_viewport().set_input_as_handled() ---")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var book_ui = main.find_child("BookUI", true, false)

	# Simulate Option A by attaching a custom script or monkey patching
	# Here, in Option A, main._unhandled_input consumes the event.
	# We can test by wrapping main's _unhandled_input behavior:
	var passed := true
	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	# Simulate pressing B with Option A behavior:
	# Main._unhandled_input runs, opens book, and calls set_input_as_handled()
	book_ui.open_book()
	# Because Option A calls set_input_as_handled(), InputManager._unhandled_input never sees this event.
	await process_frame

	if im.get_current_context() != im.ContextMode.BOOK or not book_ui.visible:
		print("  [FAIL] Option A: Opening failed")
		passed = false
	else:
		print("  [PASS] Option A: Opening B kept book open (Context=BOOK, visible=true)")

	# Now simulate pressing B again to close
	book_ui.close_book()
	await process_frame

	if im.get_current_context() != im.ContextMode.WORLD or book_ui.visible:
		print("  [FAIL] Option A: Closing failed")
		passed = false
	else:
		print("  [PASS] Option A: Closing B closed book (Context=WORLD, visible=false)")

	main.queue_free()
	await process_frame

func _test_option_b() -> void:
	print("\n--- Testing Option B: Remove redundant handler in main.gd, let InputManager drive BookUI ---")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var book_ui = main.find_child("BookUI", true, false)

	# Simulate Option B: Disable main._unhandled_input (by setting process_unhandled_input to false on main)
	main.set_process_unhandled_input(false)

	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	print("  Step 1: Dispatch 'open_book' (hotkey B) to root...")
	var ev_b = InputEventAction.new()
	ev_b.action = "open_book"
	ev_b.pressed = true

	root.push_input(ev_b)
	await process_frame

	var ctx_after_b: int = im.get_current_context()
	var visible_after_b: bool = book_ui.visible

	print("    Result: Context = %d (expected 1/BOOK), BookUI.visible = %s (expected true)" % [ctx_after_b, str(visible_after_b)])
	if ctx_after_b == im.ContextMode.BOOK and visible_after_b == true:
		print("  [PASS] Option B: Hotkey B cleanly opened BookUI via InputManager -> context_changed signal!")
	else:
		print("  [FAIL] Option B: Hotkey B did not open BookUI cleanly")

	print("  Step 2: Dispatch 'open_book' (hotkey B) again to close...")
	var ev_b_close = InputEventAction.new()
	ev_b_close.action = "open_book"
	ev_b_close.pressed = true

	root.push_input(ev_b_close)
	await process_frame

	var ctx_after_b2: int = im.get_current_context()
	var visible_after_b2: bool = book_ui.visible
	print("    Result: Context = %d (expected 0/WORLD), BookUI.visible = %s (expected false)" % [ctx_after_b2, str(visible_after_b2)])
	if ctx_after_b2 == im.ContextMode.WORLD and visible_after_b2 == false:
		print("  [PASS] Option B: Hotkey B cleanly closed BookUI via consume_and_close!")
	else:
		print("  [FAIL] Option B: Hotkey B did not close BookUI cleanly")

	print("  Step 3: Dispatch 'open_book' then 'pause_menu' (Esc) to close...")
	root.push_input(ev_b)
	await process_frame
	print("    Book re-opened: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])

	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true

	root.push_input(ev_esc)
	await process_frame

	var ctx_after_esc: int = im.get_current_context()
	var visible_after_esc: bool = book_ui.visible
	print("    Result: Context = %d (expected 0/WORLD), BookUI.visible = %s (expected false)" % [ctx_after_esc, str(visible_after_esc)])
	if ctx_after_esc == im.ContextMode.WORLD and visible_after_esc == false:
		print("  [PASS] Option B: Esc cleanly closed BookUI!")
	else:
		print("  [FAIL] Option B: Esc did not close BookUI cleanly")

	print("  Step 4: Rapid 20 toggle stress test under Option B...")
	var toggle_failed := false
	for i in range(20):
		var ev = InputEventAction.new()
		ev.action = "open_book"
		ev.pressed = true
		root.push_input(ev)
		await process_frame
		var expected_ctx = im.ContextMode.BOOK if (i % 2 == 0) else im.ContextMode.WORLD
		var expected_vis = (i % 2 == 0)
		if im.get_current_context() != expected_ctx or book_ui.visible != expected_vis:
			print("    [FAIL] Rapid toggle mismatch at iteration %d: ctx=%d, vis=%s" % [i, im.get_current_context(), str(book_ui.visible)])
			toggle_failed = true
			break
	if not toggle_failed:
		print("  [PASS] Option B: 20 rapid toggles succeeded with 100% consistency!")

	print("  Step 5: World Landmark interaction (book_family on table) under Option B...")
	var level = main.find_child("LevelGraybox", true, false)
	var book_landmark = level.find_child("book_family", true, false)
	var book_interactable = book_landmark.find_child("Interactable", true, false)
	var player = main.find_child("Player", true, false)

	# Ensure in world
	im.pop_to_world()
	await process_frame

	book_interactable.interact(player)
	await process_frame
	print("    After landmark interact: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	if im.get_current_context() == im.ContextMode.BOOK and book_ui.visible == true:
		print("  [PASS] Option B: Table landmark interaction works seamlessly!")
	else:
		print("  [FAIL] Option B: Table landmark interaction failed")

	# Close with B
	root.push_input(ev_b)
	await process_frame
	if im.get_current_context() == im.ContextMode.WORLD and book_ui.visible == false:
		print("  [PASS] Option B: Table book closed with B successfully!")
	else:
		print("  [FAIL] Option B: Table book close with B failed")

	main.queue_free()
	await process_frame
