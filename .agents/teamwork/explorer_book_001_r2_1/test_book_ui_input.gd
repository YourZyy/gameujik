extends SceneTree

# Test comparing BookUI with and without _unhandled_input

func _init() -> void:
	print("[TEST] Testing BookUI behavior with and without _unhandled_input...")
	call_deferred("_run")

func _run() -> void:
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	# Option B: main._unhandled_input disabled
	main.set_process_unhandled_input(false)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var book_ui = main.find_child("BookUI", true, false)

	# --- Test Case 1: BookUI with its own _unhandled_input ---
	print("--- Case 1: BookUI with _unhandled_input ---")
	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	# Open via B
	var ev_b = InputEventAction.new()
	ev_b.action = "open_book"
	ev_b.pressed = true
	root.push_input(ev_b)
	await process_frame

	print("  1.1 Open B: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	assert(im.get_current_context() == im.ContextMode.BOOK and book_ui.visible == true)

	# Close via Esc
	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true
	root.push_input(ev_esc)
	await process_frame

	print("  1.2 Close Esc: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	assert(im.get_current_context() == im.ContextMode.WORLD and book_ui.visible == false)

	# --- Test Case 2: BookUI WITHOUT _unhandled_input (letting InputManager handle everything) ---
	print("\n--- Case 2: BookUI WITHOUT _unhandled_input (InputManager pure routing) ---")
	book_ui.set_process_unhandled_input(false)
	await process_frame

	# Open via B
	root.push_input(ev_b)
	await process_frame
	print("  2.1 Open B: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	assert(im.get_current_context() == im.ContextMode.BOOK and book_ui.visible == true)

	# Close via B
	root.push_input(ev_b)
	await process_frame
	print("  2.2 Close B: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	assert(im.get_current_context() == im.ContextMode.WORLD and book_ui.visible == false)

	# Open via B again
	root.push_input(ev_b)
	await process_frame
	print("  2.3 Re-open B: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	assert(im.get_current_context() == im.ContextMode.BOOK and book_ui.visible == true)

	# Close via Esc
	root.push_input(ev_esc)
	await process_frame
	print("  2.4 Close Esc: Context=%d, visible=%s" % [im.get_current_context(), str(book_ui.visible)])
	assert(im.get_current_context() == im.ContextMode.WORLD and book_ui.visible == false)

	main.queue_free()
	await process_frame
	print("\n[TEST] Both Case 1 and Case 2 succeed completely!")
	quit(0)
