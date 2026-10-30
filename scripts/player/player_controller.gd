class_name PlayerController
extends CharacterBody3D

const PlayerConfig = preload("res://scripts/player/player_config.gd")
const HoldActionControllerClass = preload("res://scripts/gardening/hold_action_controller.gd")

## Controller First-Person untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR01, FR02 dan CONTENT.md § 14

signal recovered_to_safe_position(target_position: Vector3)

@export_group("Movement")
@export var move_speed: float = PlayerConfig.DEFAULT_MOVE_SPEED
@export var movement_enabled: bool = true

@export_group("Look & Camera")
@export var look_enabled: bool = true
@export var mouse_sensitivity: float = PlayerConfig.DEFAULT_MOUSE_SENSITIVITY
@export var mouse_sensitivity_multiplier: float = 1.0:
	set(value):
		mouse_sensitivity_multiplier = clampf(value, 0.1, 5.0)
		mouse_sensitivity = PlayerConfig.DEFAULT_MOUSE_SENSITIVITY * mouse_sensitivity_multiplier
@export var fov: float = PlayerConfig.DEFAULT_FOV:
	set(value):
		fov = clampf(value, PlayerConfig.MIN_FOV, PlayerConfig.MAX_FOV)
		if camera:
			camera.fov = fov
@export var min_pitch_deg: float = PlayerConfig.MIN_PITCH_DEG
@export var max_pitch_deg: float = PlayerConfig.MAX_PITCH_DEG

@export_group("Game Feel")
@export var head_bob_enabled: bool = false
@export var bob_frequency: float = PlayerConfig.DEFAULT_BOB_FREQUENCY
@export var bob_amplitude_v: float = PlayerConfig.DEFAULT_BOB_AMPLITUDE_V
@export var bob_amplitude_h: float = PlayerConfig.DEFAULT_BOB_AMPLITUDE_H
@export var trauma_decay: float = PlayerConfig.DEFAULT_TRAUMA_DECAY
@export var max_shake_offset: Vector3 = PlayerConfig.MAX_SHAKE_OFFSET
@export var max_shake_roll: float = PlayerConfig.MAX_SHAKE_ROLL_RAD

@export_group("Recovery & Safety")
@export var fall_recovery_threshold: float = PlayerConfig.FALL_RECOVERY_Y_THRESHOLD
@export var default_safe_return_position: Vector3 = PlayerConfig.DEFAULT_SAFE_RETURN_POSITION

@export_group("Input")
@export var auto_capture_mouse: bool = true

@onready var head: Node3D = $Head if has_node("Head") else ($CameraPivot if has_node("CameraPivot") else null)
@onready var camera: Camera3D = find_child("Camera3D", true, false) as Camera3D
@onready var collision_shape: CollisionShape3D = find_child("CollisionShape3D", true, false) as CollisionShape3D
@onready var interaction_detector: RayCast3D = find_child("InteractionDetector", true, false) as RayCast3D
@onready var interaction_prompt: CanvasLayer = find_child("InteractionPrompt", true, false) as CanvasLayer

var camera_pitch: float = 0.0
var _mouse_captured: bool = false
var hold_controller = HoldActionControllerClass.new()
var _was_lmb_pressed: bool = false

# Game Feel State
var trauma: float = 0.0
var _shake_timer: float = 0.0
var _shake_offset: Vector3 = Vector3.ZERO
var _shake_roll: float = 0.0
var _bob_timer: float = 0.0
var _bob_offset: Vector3 = Vector3.ZERO
var _camera_base_pos: Vector3 = Vector3.ZERO
var _step_distance_accumulator: float = 0.0
const STEP_DISTANCE_INTERVAL: float = 1.8

func _ready() -> void:
	floor_constant_speed = true
	floor_snap_length = 0.2
	floor_stop_on_slope = true
	collision_layer = PlayerConfig.LAYER_PLAYER
	collision_mask = PlayerConfig.DEFAULT_PLAYER_COLLISION_MASK

	if camera:
		camera.fov = fov
		camera.current = true
		_camera_base_pos = camera.position
	
	if auto_capture_mouse and DisplayServer.get_name() != "headless":
		capture_mouse()

	# Register to InputManager autoload if present
	var im: Node = get_node_or_null("/root/InputManager") if is_inside_tree() else null
	if im != null and im.has_method("register_player"):
		im.register_player(self)

	# Locate or instance InteractionPrompt / HUD UI and connect to detector
	if interaction_prompt == null and is_inside_tree():
		interaction_prompt = get_tree().root.find_child("HUD", true, false) as CanvasLayer
		if interaction_prompt == null:
			interaction_prompt = get_tree().root.find_child("InteractionPrompt", true, false) as CanvasLayer
	if interaction_prompt == null:
		var prompt_scene = load("res://scenes/ui/interaction_prompt.tscn") as PackedScene
		if prompt_scene != null:
			interaction_prompt = prompt_scene.instantiate() as CanvasLayer
			add_child(interaction_prompt)

	if interaction_detector != null and interaction_prompt != null:
		if interaction_prompt.has_method("connect_detector"):
			interaction_prompt.connect_detector(interaction_detector)

	hold_controller.hold_progress.connect(func(act, prog, el, dur):
		if interaction_prompt != null and interaction_prompt.has_method("show_hold_progress"):
			interaction_prompt.show_hold_progress(act, prog, el, dur)
	)
	hold_controller.hold_completed.connect(func(act):
		if interaction_prompt != null and interaction_prompt.has_method("hide_hold_progress"):
			interaction_prompt.hide_hold_progress()
		_on_hold_action_completed(act)
	)
	hold_controller.hold_cancelled.connect(func(_act):
		if interaction_prompt != null and interaction_prompt.has_method("hide_hold_progress"):
			interaction_prompt.hide_hold_progress()
	)

	# Load and connect to SaveManager settings
	var sm: Node = get_node_or_null("/root/SaveManager") if is_inside_tree() else null
	if sm != null:
		var saved_fov = sm.get_setting("video", "fov", fov)
		if saved_fov != null:
			self.fov = float(saved_fov)
		var saved_sens = sm.get_setting("gameplay", "mouse_sensitivity_multiplier", mouse_sensitivity_multiplier)
		if saved_sens != null:
			self.mouse_sensitivity_multiplier = float(saved_sens)
		var saved_bob = sm.get_setting("gameplay", "head_bob", head_bob_enabled)
		if saved_bob != null:
			self.head_bob_enabled = bool(saved_bob)
		if sm.has_signal("setting_changed") and not sm.setting_changed.is_connected(_on_save_manager_setting_changed):
			sm.setting_changed.connect(_on_save_manager_setting_changed)

func _on_save_manager_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == "video" and key == "fov":
		self.fov = float(value)
	elif section == "gameplay" and (key == "mouse_sensitivity_multiplier" or key == "mouse_sensitivity"):
		self.mouse_sensitivity_multiplier = float(value)
	elif section == "gameplay" and key == "head_bob":
		self.head_bob_enabled = bool(value)

func capture_mouse() -> void:
	_mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_mouse() -> void:
	_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func is_mouse_captured() -> bool:
	if DisplayServer.get_name() == "headless":
		return _mouse_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	var im: Node = get_node_or_null("/root/InputManager") if is_inside_tree() else null

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if im != null and not im.is_world_context():
			return
		if not is_mouse_captured():
			capture_mouse()
			get_viewport().set_input_as_handled()
			return

	# Tool Hotkeys (1-4 toggle)
	if event.is_action_pressed("tool_1") and not event.is_echo():
		if im != null and im.is_world_context():
			_handle_tool_toggle("tool_hoe")
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("tool_2") and not event.is_echo():
		if im != null and im.is_world_context():
			_handle_tool_toggle("tool_seed")
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("tool_3") and not event.is_echo():
		if im != null and im.is_world_context():
			_handle_tool_toggle("tool_fertilizer")
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("tool_4") and not event.is_echo():
		if im != null and im.is_world_context():
			_handle_tool_toggle("tool_watering_can")
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("action_tool_cancel") and not event.is_echo():
		if hold_controller.is_active():
			hold_controller.cancel()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("interact") and not event.is_echo():
		if im != null and not im.is_world_context():
			return
		if movement_enabled and interaction_detector != null:
			var cur_t = interaction_detector.get_current_target()
			if cur_t != null and str(cur_t.get("interaction_id")) == "landmark_water":
				# water_home is a 2s hold action, do not trigger instant interact
				get_viewport().set_input_as_handled()
				return
			if cur_t != null and str(cur_t.get("interaction_id")) == "landmark_plot":
				if _handle_plot_harvest_on_plot():
					get_viewport().set_input_as_handled()
					return
			if interaction_detector.has_method("try_interact"):
				if interaction_detector.try_interact(self):
					get_viewport().set_input_as_handled()
					return

	if event.is_action_pressed("pause_menu"):
		if im == null:
			release_mouse()
		return

	if event is InputEventMouseMotion and (is_mouse_captured() or DisplayServer.get_name() == "headless"):
		var motion: Vector2 = event.screen_relative if event.screen_relative != Vector2.ZERO else event.relative
		handle_mouse_look(motion)

func handle_mouse_look(relative_motion: Vector2) -> void:
	if not look_enabled:
		return

	# Horizontal mouse movement: yaw (rotasi badan Player terhadap sumbu Y)
	rotate_y(-relative_motion.x * mouse_sensitivity)
	
	# Vertical mouse movement: pitch (rotasi Head/Camera terhadap sumbu X)
	camera_pitch -= relative_motion.y * mouse_sensitivity
	var min_rad := deg_to_rad(min_pitch_deg)
	var max_rad := deg_to_rad(max_pitch_deg)
	camera_pitch = clampf(camera_pitch, min_rad, max_rad)
	if head:
		head.rotation.x = camera_pitch

func apply_pitch_degrees(pitch_deg: float) -> void:
	var min_rad := deg_to_rad(min_pitch_deg)
	var max_rad := deg_to_rad(max_pitch_deg)
	camera_pitch = clampf(deg_to_rad(pitch_deg), min_rad, max_rad)
	if head:
		head.rotation.x = camera_pitch

func get_pitch_degrees() -> float:
	return rad_to_deg(camera_pitch)

func get_pitch_radians() -> float:
	return camera_pitch

func get_yaw_degrees() -> float:
	return rad_to_deg(rotation.y)

func get_yaw_radians() -> float:
	return rotation.y

func calculate_movement_velocity(input_dir: Vector2, current_vel: Vector3, delta: float, on_floor: bool = true) -> Vector3:
	var direction := Vector3.ZERO
	if input_dir != Vector2.ZERO:
		var local_dir := Vector3(input_dir.x, 0.0, input_dir.y).normalized()
		direction = (transform.basis * local_dir).normalized()
	
	var target_x := direction.x * move_speed
	var target_z := direction.z * move_speed
	
	var target_y := current_vel.y
	if not on_floor:
		var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		target_y -= gravity * delta
	else:
		if target_y < 0.0:
			target_y = 0.0
	
	return Vector3(target_x, target_y, target_z)

func _physics_process(delta: float) -> void:
	var cur_y := global_position.y if is_inside_tree() else position.y
	if cur_y < fall_recovery_threshold:
		trigger_recovery()
		return

	var input_dir := Vector2.ZERO
	if movement_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	velocity = calculate_movement_velocity(input_dir, velocity, delta, is_on_floor() if is_inside_tree() else true)
	if is_inside_tree():
		move_and_slide()
		if is_on_floor() and velocity.length() > 0.5 and movement_enabled:
			_step_distance_accumulator += velocity.length() * delta
			if _step_distance_accumulator >= STEP_DISTANCE_INTERVAL:
				_step_distance_accumulator = 0.0
				var am = get_node_or_null("/root/AudioManager")
				if am and am.has_method("play_footstep"):
					am.play_footstep()

	_update_hold_action(delta)

func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	_update_camera_shake(delta)
	_update_head_bob(delta)
	_apply_camera_offsets()

func _update_camera_shake(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(trauma - trauma_decay * delta, 0.0)
		var shake := trauma * trauma
		_shake_timer += delta * 25.0
		_shake_offset = Vector3(
			sin(_shake_timer * 1.1) * max_shake_offset.x * shake,
			cos(_shake_timer * 1.3) * max_shake_offset.y * shake,
			0.0
		)
		_shake_roll = sin(_shake_timer * 0.9) * max_shake_roll * shake
	else:
		_shake_offset = Vector3.ZERO
		_shake_roll = 0.0

func _update_head_bob(delta: float) -> void:
	if head_bob_enabled and is_on_floor() and velocity.length() > 0.1:
		_bob_timer += velocity.length() * delta * bob_frequency
		_bob_offset = Vector3(
			cos(_bob_timer) * bob_amplitude_h,
			sin(_bob_timer * 2.0) * bob_amplitude_v,
			0.0
		)
	else:
		_bob_offset = _bob_offset.lerp(Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0))

func _apply_camera_offsets() -> void:
	if camera:
		camera.position = _camera_base_pos + _bob_offset + _shake_offset
		camera.rotation.z = _shake_roll

func teleport_to(target_position: Vector3, rot_y_rad: float = 0.0) -> void:
	if is_inside_tree():
		global_position = target_position
	else:
		position = target_position
	
	velocity = Vector3.ZERO
	rotation.y = rot_y_rad
	camera_pitch = 0.0
	if head:
		head.rotation.x = 0.0
	
	# Reset camera shake trauma & offsets
	trauma = 0.0
	_shake_offset = Vector3.ZERO
	_shake_roll = 0.0
	_bob_offset = Vector3.ZERO
	if camera:
		camera.position = _camera_base_pos
		camera.rotation.z = 0.0
	
	if has_method("reset_physics_interpolation"):
		reset_physics_interpolation()
	
	recovered_to_safe_position.emit(target_position)

func trigger_recovery() -> void:
	var target_pos := default_safe_return_position
	
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("get_safe_return_position"):
		target_pos = parent_node.get_safe_return_position()
	elif is_inside_tree() and get_tree() and get_tree().current_scene:
		var lvl = get_tree().current_scene.find_child("LevelGraybox", true, false)
		if lvl and lvl.has_method("get_safe_return_position"):
			target_pos = lvl.get_safe_return_position()
	
	teleport_to(target_pos, 0.0)

# --- Gardening Tool & Hold Action Integration ---

func _handle_tool_toggle(tool_id: String) -> void:
	if hold_controller.is_active():
		hold_controller.cancel()
	var gm = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else (get_node_or_null("/root/GardenManager") if is_inside_tree() else null)
	if gm != null and gm.has_method("select_tool"):
		gm.select_tool(tool_id)

func _update_hold_action(delta: float) -> void:
	var im: Node = get_node_or_null("/root/InputManager") if is_inside_tree() else null
	if im != null and not im.is_world_context():
		if hold_controller.is_active():
			hold_controller.cancel()
		return

	var target_node = interaction_detector.get_current_target() if (interaction_detector != null and interaction_detector.has_method("get_current_target")) else null
	var target_id := str(target_node.get("interaction_id")) if target_node != null else ""

	var gm = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else (get_node_or_null("/root/GardenManager") if is_inside_tree() else null)
	var active_tool: String = str(gm.get("active_tool")) if gm != null else ""

	var is_lmb_pressed: bool = Input.is_action_pressed("action_tool_use") or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_mouse_captured())
	var is_lmb_just_pressed: bool = Input.is_action_just_pressed("action_tool_use") or (is_lmb_pressed and not _was_lmb_pressed)
	var is_interact_pressed: bool = Input.is_action_pressed("interact")
	var is_interact_just_pressed: bool = Input.is_action_just_pressed("interact")

	if hold_controller.state == HoldActionControllerClass.State.MUST_RELEASE:
		var button_still_down := false
		if hold_controller.button_name == &"action_tool_use":
			button_still_down = is_lmb_pressed
		elif hold_controller.button_name == &"interact":
			button_still_down = is_interact_pressed
		hold_controller.tick(delta, button_still_down, true)
		_was_lmb_pressed = is_lmb_pressed
		return

	# Invariant guard: Cancel active hold immediately if target landmark or active tool is no longer compatible
	if hold_controller.is_holding():
		var is_compat := false
		if hold_controller.action_id == "refill":
			is_compat = (target_id == "landmark_water")
		elif target_id == "landmark_plot":
			match hold_controller.action_id:
				"hoe": is_compat = (active_tool == "tool_hoe")
				"fertilize": is_compat = (active_tool == "tool_fertilizer")
				"water": is_compat = (active_tool == "tool_watering_can")
		if not is_compat:
			hold_controller.cancel()

	# 1. Refill watering can at water_home (2.0s hold E)
	if target_id == "landmark_water":
		if hold_controller.is_holding() and hold_controller.action_id == "refill":
			hold_controller.tick(delta, is_interact_pressed, target_id == "landmark_water")
		elif is_interact_just_pressed and not hold_controller.is_active():
			if gm != null:
				var check: Dictionary = gm.can_refill_water()
				if check.get("success", false):
					hold_controller.start("refill", "water_home", 2.0, &"interact")
				else:
					gm.action_failed.emit(check.get("reason", "Kondisi cukup. Air sudah penuh."))

	# 2. Plot actions at plot_home_01 (tool hold or seed plant)
	elif target_id == "landmark_plot":
		if active_tool == "tool_seed":
			if is_lmb_just_pressed and is_mouse_captured():
				_handle_plant_seed_on_plot()
		elif active_tool == "tool_hoe":
			if hold_controller.is_holding() and hold_controller.action_id == "hoe":
				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
				if gm != null and gm.can_hoe_plot("plot_home_01")["success"]:
					hold_controller.start("hoe", "plot_home_01", 2.0, &"action_tool_use")
		elif active_tool == "tool_fertilizer":
			if hold_controller.is_holding() and hold_controller.action_id == "fertilize":
				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
				if gm != null and gm.can_fertilize_plot("plot_home_01")["success"]:
					hold_controller.start("fertilize", "plot_home_01", 1.0, &"action_tool_use")
		elif active_tool == "tool_watering_can":
			if hold_controller.is_holding() and hold_controller.action_id == "water":
				hold_controller.tick(delta, is_lmb_pressed, target_id == "landmark_plot")
			elif is_lmb_just_pressed and not hold_controller.is_active() and is_mouse_captured():
				if gm != null and gm.can_water_plot("plot_home_01")["success"]:
					hold_controller.start("water", "plot_home_01", 2.0, &"action_tool_use")
		else:
			if hold_controller.is_holding():
				hold_controller.cancel()
	else:
		if hold_controller.is_holding():
			hold_controller.cancel()

	_was_lmb_pressed = is_lmb_pressed

func _on_hold_action_completed(action: String) -> void:
	var gm = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else (get_node_or_null("/root/GardenManager") if is_inside_tree() else null)
	if gm == null:
		return
	match action:
		"hoe":
			gm.hoe_plot("plot_home_01")
		"fertilize":
			gm.fertilize_plot("plot_home_01")
		"water":
			gm.water_plot("plot_home_01")
		"refill":
			gm.refill_water()

func _handle_plant_seed_on_plot() -> void:
	var gm = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else (get_node_or_null("/root/GardenManager") if is_inside_tree() else null)
	if gm == null or interaction_detector == null:
		return
	var hit_pt: Vector3 = interaction_detector.get_collision_point()
	var col = interaction_detector.get_collider()
	if col == null:
		return
	var plot_node: Node3D = null
	var curr: Node = col as Node
	while curr != null:
		if curr.name == "plot_home_01":
			plot_node = curr as Node3D
			break
		curr = curr.get_parent()
	if plot_node == null and is_inside_tree() and get_tree().current_scene != null:
		plot_node = get_tree().current_scene.find_child("plot_home_01", true, false) as Node3D
	if plot_node == null:
		return
	var local_pt: Vector3 = plot_node.to_local(hit_pt)
	var spot_id: String = ""
	if local_pt.x < 0.0:
		spot_id = "slot_01" if local_pt.z < 0.0 else "slot_03"
	else:
		spot_id = "slot_02" if local_pt.z < 0.0 else "slot_04"
	gm.plant_seed("plot_home_01", spot_id, "seed_bayam")

func _handle_plot_harvest_on_plot() -> bool:
	var gm = Engine.get_singleton("GardenManager") if Engine.has_singleton("GardenManager") else (get_node_or_null("/root/GardenManager") if is_inside_tree() else null)
	if gm == null or interaction_detector == null:
		return false
	var hit_pt: Vector3 = interaction_detector.get_collision_point()
	var col = interaction_detector.get_collider()
	if col == null:
		return false
	var plot_node: Node3D = null
	var curr: Node = col as Node
	while curr != null:
		if curr.name == "plot_home_01":
			plot_node = curr as Node3D
			break
		curr = curr.get_parent()
	if plot_node == null and is_inside_tree() and get_tree().current_scene != null:
		plot_node = get_tree().current_scene.find_child("plot_home_01", true, false) as Node3D
	if plot_node == null:
		return false
	var local_pt: Vector3 = plot_node.to_local(hit_pt)
	var spot_id: String = gm.get_spot_id_from_local_coords(local_pt) if gm.has_method("get_spot_id_from_local_coords") else ("slot_01" if local_pt.x < 0.0 and local_pt.z < 0.0 else "slot_02")
	var spot: Dictionary = gm.get_spot("plot_home_01", spot_id) if gm.has_method("get_spot") else {}
	if bool(spot.get("is_occupied", false)) and spot.get("crop_data") != null:
		var crop: Dictionary = spot["crop_data"]
		if bool(crop.get("is_ready_to_harvest", false)):
			gm.harvest_crop("plot_home_01", spot_id)
			return true
	return false

# ==============================================================================
# Save / Load Snapshot & Coordinate Bounds Sanitization (SAVE-001 / T22)
# ==============================================================================

func get_save_snapshot() -> Dictionary:
	var pos := global_position if is_inside_tree() else position
	return {
		"position": [pos.x, pos.y, pos.z],
		"rotation_y": rotation.y,
		"camera_pitch": camera_pitch
	}

func load_save_snapshot(data: Dictionary) -> bool:
	if not (data is Dictionary) or data.is_empty():
		return false

	var raw_pos = data.get("position", [default_safe_return_position.x, default_safe_return_position.y, default_safe_return_position.z])
	var target_pos := default_safe_return_position
	var is_coord_valid := false

	if raw_pos is Array and raw_pos.size() >= 3:
		var px: float = float(raw_pos[0])
		var py: float = float(raw_pos[1])
		var pz: float = float(raw_pos[2])
		if not (is_nan(px) or is_nan(py) or is_nan(pz) or is_inf(px) or is_inf(py) or is_inf(pz)):
			# Boundaries check: X in [-42, 42], Z in [-37, 47], Y in [-5.0, 50.0]
			if px >= -42.0 and px <= 42.0 and pz >= -37.0 and pz <= 47.0 and py >= -5.0 and py <= 50.0:
				target_pos = Vector3(px, py, pz)
				is_coord_valid = true

	if not is_coord_valid:
		print("[PlayerController] Koordinat pemain out-of-bounds/NaN/Inf (%s). Dialihkan ke titik aman: %s" % [str(raw_pos), str(default_safe_return_position)])
		target_pos = default_safe_return_position

	var rot_y: float = float(data.get("rotation_y", 0.0))
	if is_nan(rot_y) or is_inf(rot_y):
		rot_y = 0.0

	var pitch: float = float(data.get("camera_pitch", 0.0))
	if is_nan(pitch) or is_inf(pitch):
		pitch = 0.0

	teleport_to(target_pos, rot_y)
	camera_pitch = clampf(pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	if head:
		head.rotation.x = camera_pitch

	return true

