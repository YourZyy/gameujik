extends SceneTree

# Verification of Option B vs Option A

func _init() -> void:
	print("[VERIFY] Testing Option B with set_process_unhandled_input(false) AFTER add_child...")
	call_deferred("_run")

func _run() -> void:
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	# Calling set_process_unhandled_input(false) AFTER add_child and ready
	main.set_process_unhandled_input(false)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var book_ui = main.find_child("BookUI", true, false)

	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	# Test 5.1: Dispatch 'open_book' (hotkey B)
	print("  Testing Hotkey B dispatch...")
	var ev_b = InputEventAction.new()
	ev_b.action = "open_book"
	ev_b.pressed = true
	root.push_input(ev_b)
	await process_frame

	var final_context: int = im.get_current_context()
	var final_book_visible: bool = book_ui.visible

	print("  Observed: Context = %d (expected 1), BookUI.visible = %s (expected true)" % [final_context, str(final_book_visible)])
	assert(final_context == im.ContextMode.BOOK, "Context must be BOOK")
	assert(final_book_visible == true, "BookUI must be visible")
	print("  >>> PASS: Hotkey B successfully opened BookUI and remained open!")

	# Test 5.2: Esc closes book
	print("  Testing Esc close...")
	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true
	root.push_input(ev_esc)
	await process_frame

	assert(im.get_current_context() == im.ContextMode.WORLD, "Context must be WORLD")
	assert(book_ui.visible == false, "BookUI must be closed")
	print("  >>> PASS: Esc successfully closed BookUI and restored WORLD context!")

	main.queue_free()
	await process_frame
	print("[VERIFY] All Option B checks verified successfully!")
	quit(0)
