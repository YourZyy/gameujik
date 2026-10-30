class_name HoldActionController
extends RefCounted

## Pengendali Aksi Tahan (Hold Action Controller) untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR07..FR10, CONTENT.md § 6, dan TEST_PLAN T06, T07, T32, T33

enum State {
	IDLE,
	HOLDING,
	COMMITTED,
	MUST_RELEASE
}

signal hold_started(action_id: String, duration: float)
signal hold_progress(action_id: String, progress: float, elapsed: float, duration: float)
signal hold_completed(action_id: String)
signal hold_cancelled(action_id: String)

var state: State = State.IDLE
var action_id: String = ""
var target_id: String = ""
var required_time: float = 0.0
var elapsed_time: float = 0.0
var button_name: StringName = &""

func start(p_action_id: String, p_target_id: String, p_duration: float, p_button: StringName) -> void:
	if state == State.MUST_RELEASE:
		return
	action_id = p_action_id
	target_id = p_target_id
	required_time = maxf(0.01, p_duration)
	elapsed_time = 0.0
	button_name = p_button
	state = State.HOLDING
	hold_started.emit(action_id, required_time)
	hold_progress.emit(action_id, 0.0, 0.0, required_time)

func tick(delta: float, is_button_pressed: bool, is_target_valid: bool) -> void:
	match state:
		State.HOLDING:
			if not is_button_pressed or not is_target_valid:
				cancel()
				return

			elapsed_time += delta
			var progress := get_progress()
			hold_progress.emit(action_id, progress, elapsed_time, required_time)

			if elapsed_time >= required_time:
				state = State.COMMITTED
				var completed_action := action_id
				hold_completed.emit(completed_action)
				state = State.MUST_RELEASE

		State.MUST_RELEASE:
			if not is_button_pressed:
				state = State.IDLE
				action_id = ""
				target_id = ""
				elapsed_time = 0.0

		State.IDLE, State.COMMITTED:
			pass

func cancel() -> void:
	if state == State.IDLE:
		return
	var cancelled_action := action_id
	state = State.IDLE
	elapsed_time = 0.0
	action_id = ""
	target_id = ""
	button_name = &""
	if cancelled_action != "":
		hold_cancelled.emit(cancelled_action)

func get_progress() -> float:
	if required_time <= 0.0:
		return 1.0
	return clampf(elapsed_time / required_time, 0.0, 1.0)

func is_holding() -> bool:
	return state == State.HOLDING

func is_active() -> bool:
	return state != State.IDLE
