extends SceneTree

# Verification of Regression Test with Option A and Option B fixes

const Assertions = preload("res://tests/assertions.gd")
const InputManagerClass = preload("res://scripts/core/input_manager.gd")

func _init() -> void:
	print("==================================================")
	print("[EXPLORER_R2_3] Verifying Regression Test With Fix Options")
	print("==================================================")
	call_deferred("_run")

func _run() -> void:
	await _test_with_option_a()
	await _test_with_option_b()
	print("==================================================")
	print("[EXPLORER_R2_3] Verification of Both Fixes Complete")
	print("==================================================")
	quit(0)

func _test_with_option_a() -> void:
	print("\n--- Verifying Regression Test against Option A (set_input_as_handled) ---")
	Assertions.reset()
	var main_scene = load("res://scenes/main.tscn") as PackedScene
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var book_ui = main_node.find_child("BookUI", true, false)

	# In Option A, main._unhandled_input marks the event handled.
	# We dynamically replace _unhandled_input on main_node or disable original and bind patched method:
	main_node.set_process_unhandled_input(false)

	# Patch simulated Option A handler
	var patch_script = GDScript.new()
	patch_script.source_code = """
extends Node

var target_main: Node
var im: Node
var book_ui: CanvasLayer

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_book") and not event.is_echo():
		if im != null:
			if im.get_current_context() == im.ContextMode.BOOK:
				if book_ui and book_ui.has_method("close_book"):
					book_ui.close_book()
					get_viewport().set_input_as_handled()
			elif im.is_world_context():
				if book_ui and book_ui.has_method("open_book"):
					book_ui.open_book()
					get_viewport().set_input_as_handled()
"""
	patch_script.reload()
	var patch_node = Node.new()
	patch_node.set_script(patch_script)
	patch_node.set("target_main", main_node)
	patch_node.set("im", im)
	patch_node.set("book_ui", book_ui)
	main_node.add_child(patch_node)

	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	# Run regression test logic:
	# 1. Press B to open
	var ev_press = InputEventAction.new()
	ev_press.action = "open_book"
	ev_press.pressed = true
	root.push_input(ev_press)
	await process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Option A: Context is BOOK after open")
	Assertions.assert_true(book_ui.visible, "Option A: BookUI is visible after open")

	# 2. Press B to close
	var ev_close = InputEventAction.new()
	ev_close.action = "open_book"
	ev_close.pressed = true
	root.push_input(ev_close)
	await process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Option A: Context is WORLD after close")
	Assertions.assert_false(book_ui.visible, "Option A: BookUI is hidden after close")

	main_node.queue_free()
	await process_frame
	print("Option A Result: Failed assertions = %d" % Assertions.current_suite_failed)

func _test_with_option_b() -> void:
	print("\n--- Verifying Regression Test against Option B (pure InputManager routing) ---")
	Assertions.reset()
	var main_scene = load("res://scenes/main.tscn") as PackedScene
	var main_node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame

	var im = root.get_node_or_null("InputManager")
	var book_ui = main_node.find_child("BookUI", true, false)

	# In Option B, main.gd simply does NOT intercept open_book at all!
	# InputManager._unhandled_input handles open_book, calls push_context(BOOK) and set_input_as_handled(),
	# which emits context_changed, which triggers book_ui.open_book() automatically.
	main_node.set_process_unhandled_input(false)

	im.pop_to_world()
	book_ui.visible = false
	await process_frame

	# Run regression test logic:
	# 1. Press B to open
	var ev_press = InputEventAction.new()
	ev_press.action = "open_book"
	ev_press.pressed = true
	root.push_input(ev_press)
	await process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Option B: Context is BOOK after open")
	Assertions.assert_true(book_ui.visible, "Option B: BookUI is visible after open")

	# 2. Press B to close
	var ev_close = InputEventAction.new()
	ev_close.action = "open_book"
	ev_close.pressed = true
	root.push_input(ev_close)
	await process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Option B: Context is WORLD after close")
	Assertions.assert_false(book_ui.visible, "Option B: BookUI is hidden after close")

	# 3. Test Esc (pause_menu) while in BOOK
	var ev_press_again = InputEventAction.new()
	ev_press_again.action = "open_book"
	ev_press_again.pressed = true
	root.push_input(ev_press_again)
	await process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.BOOK, "Option B: Re-opened into BOOK")

	var ev_esc = InputEventAction.new()
	ev_esc.action = "pause_menu"
	ev_esc.pressed = true
	root.push_input(ev_esc)
	await process_frame

	Assertions.assert_equal(im.get_current_context(), InputManagerClass.ContextMode.WORLD, "Option B: Esc closes book and restores WORLD")
	Assertions.assert_false(book_ui.visible, "Option B: BookUI closed on Esc")

	main_node.queue_free()
	await process_frame
	print("Option B Result: Failed assertions = %d" % Assertions.current_suite_failed)
