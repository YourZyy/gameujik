extends Node

## Pengendali Konteks Input dan Mouse untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR02, UI_UX.md § 3/4, PROTOTYPE.md § 5, dan TEST_PLAN T18/T28

enum ContextMode {
	WORLD,
	BOOK,
	STORAGE,
	KITCHEN,
	DIALOGUE,
	PAUSE
}

# Alias enum Context untuk fleksibilitas pemanggilan
const Context = ContextMode

signal context_changed(new_context: ContextMode, old_context: ContextMode)
signal context_pushed(pushed_context: ContextMode)
signal context_popped(popped_context: ContextMode)
signal simulation_state_changed(is_paused: bool)

var _context_stack: Array[ContextMode] = [ContextMode.WORLD]
var _player: Node = null
var _suppressed_actions: Dictionary = {}
var _last_closed_frame: int = -1
var _mouse_captured_state: bool = true

@export var auto_pause_on_focus_loss: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_mouse_mode()

func register_player(player: Node) -> void:
	_player = player
	_sync_player_gating()

func bind_player(player: Node) -> void:
	register_player(player)

func get_current_context() -> ContextMode:
	if _context_stack.is_empty():
		return ContextMode.WORLD
	return _context_stack.back()

func is_world_context() -> bool:
	return get_current_context() == ContextMode.WORLD

func is_world() -> bool:
	return is_world_context()

func is_modal_active() -> bool:
	return not is_world_context()

func is_simulation_paused() -> bool:
	var ctx := get_current_context()
	return ctx in [ContextMode.BOOK, ContextMode.STORAGE, ContextMode.DIALOGUE, ContextMode.PAUSE]

func get_stack_depth() -> int:
	return _context_stack.size()

func push_context(mode: ContextMode) -> void:
	if mode == ContextMode.WORLD:
		return
	if get_current_context() == mode:
		return
	
	var old_mode := get_current_context()
	_context_stack.append(mode)
	
	_sync_mouse_mode()
	_sync_player_gating()
	
	context_pushed.emit(mode)
	context_changed.emit(mode, old_mode)
	simulation_state_changed.emit(is_simulation_paused())

func pop_context() -> ContextMode:
	if _context_stack.size() <= 1:
		return ContextMode.WORLD
	
	var popped := _context_stack.pop_back() as ContextMode
	var new_mode := get_current_context()
	
	if new_mode == ContextMode.WORLD:
		_last_closed_frame = Engine.get_process_frames()
	
	_sync_mouse_mode()
	_sync_player_gating()
	
	context_popped.emit(popped)
	context_changed.emit(new_mode, popped)
	simulation_state_changed.emit(is_simulation_paused())
	return popped

func set_context(mode: ContextMode) -> void:
	var old_mode := get_current_context()
	if mode == ContextMode.WORLD:
		_context_stack = [ContextMode.WORLD]
		_last_closed_frame = Engine.get_process_frames()
	else:
		_context_stack = [ContextMode.WORLD, mode]
	
	_sync_mouse_mode()
	_sync_player_gating()
	
	context_changed.emit(mode, old_mode)
	simulation_state_changed.emit(is_simulation_paused())

func pop_to_world() -> void:
	if _context_stack.size() <= 1:
		return
	var old_mode := get_current_context()
	_context_stack = [ContextMode.WORLD]
	_last_closed_frame = Engine.get_process_frames()
	
	_sync_mouse_mode()
	_sync_player_gating()
	
	context_changed.emit(ContextMode.WORLD, old_mode)
	simulation_state_changed.emit(false)

func can_interact_in_world() -> bool:
	if not is_world_context():
		return false
	if Engine.get_process_frames() == _last_closed_frame:
		return false
	return true

func suppress_action_until_released(action: StringName) -> void:
	_suppressed_actions[action] = true

func is_action_suppressed(action: StringName) -> bool:
	if _suppressed_actions.has(action):
		if Engine.get_process_frames() == _last_closed_frame:
			return true
		if Input.is_action_just_released(action) or not Input.is_action_pressed(action):
			_suppressed_actions.erase(action)
			return false
		return true
	return false

func consume_and_close(action: StringName = &"") -> void:
	if action != &"":
		suppress_action_until_released(action)
	pop_context()

func _sync_mouse_mode() -> void:
	var in_world := is_world_context()
	_mouse_captured_state = in_world
	if DisplayServer.get_name() != "headless":
		if in_world:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _sync_player_gating() -> void:
	if not is_instance_valid(_player):
		return
	var in_world := is_world_context()
	if "movement_enabled" in _player:
		_player.movement_enabled = in_world
	if "look_enabled" in _player:
		_player.look_enabled = in_world
	if in_world:
		if _player.has_method("capture_mouse"):
			_player.capture_mouse()
	else:
		if _player.has_method("release_mouse"):
			_player.release_mouse()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if auto_pause_on_focus_loss and get_current_context() != ContextMode.PAUSE:
			push_context(ContextMode.PAUSE)

func _unhandled_input(event: InputEvent) -> void:
	if is_world_context():
		if event.is_action_pressed("pause_menu") and not event.is_echo():
			push_context(ContextMode.PAUSE)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_book") and not event.is_echo():
			push_context(ContextMode.BOOK)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_inventory") and not event.is_echo():
			push_context(ContextMode.STORAGE)
			get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed("pause_menu") and not event.is_echo():
			consume_and_close(&"pause_menu")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_book") and get_current_context() == ContextMode.BOOK and not event.is_echo():
			consume_and_close(&"open_book")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_inventory") and get_current_context() == ContextMode.STORAGE and not event.is_echo():
			consume_and_close(&"open_inventory")
			get_viewport().set_input_as_handled()
