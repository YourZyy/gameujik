class_name SettingsMenu
extends PanelContainer

## SettingsMenu — Panel Pengaturan Terpadu untuk Buku Resep 2045
## Memenuhi spesifikasi UI_UX.md § 3, § 5, CONTENT.md § 14, PRD FR16, FR21, dan TEST_PLAN T21, T51, T52

signal closed()
signal settings_applied()

# Kendali
@onready var slider_sens: HSlider = find_child("SliderSens", true, false) as HSlider
@onready var label_sens_val: Label = find_child("LabelSensVal", true, false) as Label
@onready var check_head_bob: CheckBox = find_child("CheckHeadBob", true, false) as CheckBox

# Tampilan / Video
@onready var slider_fov: HSlider = find_child("SliderFOV", true, false) as HSlider
@onready var label_fov_val: Label = find_child("LabelFOVVal", true, false) as Label
@onready var slider_ui_scale: HSlider = find_child("SliderUIScale", true, false) as HSlider
@onready var label_ui_scale_val: Label = find_child("LabelUIScaleVal", true, false) as Label
@onready var option_window_mode: OptionButton = find_child("OptionWindowMode", true, false) as OptionButton

# Audio
@onready var slider_master: HSlider = find_child("SliderMaster", true, false) as HSlider
@onready var label_master_val: Label = find_child("LabelMasterVal", true, false) as Label
@onready var slider_music: HSlider = find_child("SliderMusic", true, false) as HSlider
@onready var label_music_val: Label = find_child("LabelMusicVal", true, false) as Label
@onready var slider_sfx: HSlider = find_child("SliderSFX", true, false) as HSlider
@onready var label_sfx_val: Label = find_child("LabelSFXVal", true, false) as Label

# Aksesibilitas
@onready var check_subtitles: CheckBox = find_child("CheckSubtitles", true, false) as CheckBox

# Aksi
@onready var btn_save_apply: Button = find_child("BtnSaveApply", true, false) as Button
@onready var btn_reset_defaults: Button = find_child("BtnResetDefaults", true, false) as Button
@onready var btn_back: Button = find_child("BtnBack", true, false) as Button

# Status
@onready var status_label: Label = find_child("SettingsStatusLabel", true, false) as Label

var _focus_style: StyleBoxFlat = null

func _ready() -> void:
	_init_window_mode_options()
	_create_focus_style()
	_connect_widget_signals()
	_setup_focus_chain()
	load_current_settings()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("hook_control_tree"):
		am.hook_control_tree(self)

func _init_window_mode_options() -> void:
	if option_window_mode != null:
		option_window_mode.clear()
		option_window_mode.add_item("Jendela", 0)
		option_window_mode.add_item("Layar Penuh", 3)

func _create_focus_style() -> void:
	_focus_style = StyleBoxFlat.new()
	_focus_style.draw_center = false
	_focus_style.border_width_left = 2
	_focus_style.border_width_top = 2
	_focus_style.border_width_right = 2
	_focus_style.border_width_bottom = 2
	_focus_style.border_color = Color(1.0, 0.85, 0.3, 1.0) # Warm gold accent
	_focus_style.set_corner_radius_all(4)

func _connect_widget_signals() -> void:
	if slider_sens:
		slider_sens.value_changed.connect(func(v): _update_slider_label(label_sens_val, "%.1fx" % v))
	if slider_fov:
		slider_fov.value_changed.connect(func(v): _update_slider_label(label_fov_val, "%d°" % int(v)))
	if slider_ui_scale:
		slider_ui_scale.value_changed.connect(func(v): _update_slider_label(label_ui_scale_val, "%d%%" % int(v * 100)))
	if slider_master:
		slider_master.value_changed.connect(func(v): _update_slider_label(label_master_val, "%d%%" % int(v * 100)))
	if slider_music:
		slider_music.value_changed.connect(func(v): _update_slider_label(label_music_val, "%d%%" % int(v * 100)))
	if slider_sfx:
		slider_sfx.value_changed.connect(func(v): _update_slider_label(label_sfx_val, "%d%%" % int(v * 100)))

	if btn_save_apply:
		btn_save_apply.pressed.connect(save_and_apply)
	if btn_reset_defaults:
		btn_reset_defaults.pressed.connect(reset_to_defaults)
	if btn_back:
		btn_back.pressed.connect(close_settings)

func _setup_focus_chain() -> void:
	var interactive_controls: Array[Control] = [
		slider_sens,
		check_head_bob,
		slider_fov,
		slider_ui_scale,
		option_window_mode,
		slider_master,
		slider_music,
		slider_sfx,
		check_subtitles,
		btn_reset_defaults,
		btn_save_apply,
		btn_back
	]

	var valid_controls: Array[Control] = []
	for c in interactive_controls:
		if c != null:
			c.focus_mode = Control.FOCUS_ALL
			c.add_theme_stylebox_override("focus", _focus_style)
			valid_controls.append(c)

	# Circular focus linking
	if valid_controls.size() > 1:
		for i in range(valid_controls.size()):
			var cur := valid_controls[i]
			var prev := valid_controls[(i - 1 + valid_controls.size()) % valid_controls.size()]
			var next := valid_controls[(i + 1) % valid_controls.size()]
			cur.focus_neighbor_top = prev.get_path()
			cur.focus_neighbor_bottom = next.get_path()

func grab_initial_focus() -> void:
	if slider_sens and slider_sens.is_visible_in_tree():
		slider_sens.grab_focus()
	elif btn_back and btn_back.is_visible_in_tree():
		btn_back.grab_focus()

func load_current_settings() -> void:
	var sm := _get_save_manager()
	var cfg: Dictionary = {}
	if sm != null:
		cfg = sm.load_settings()
	else:
		cfg = _get_fallback_default_settings()

	var gp: Dictionary = cfg.get("gameplay", {})
	var vd: Dictionary = cfg.get("video", {})
	var au: Dictionary = cfg.get("audio", {})
	var ac: Dictionary = cfg.get("accessibility", {})

	if slider_sens:
		slider_sens.value = float(gp.get("mouse_sensitivity_multiplier", 1.0))
		_update_slider_label(label_sens_val, "%.1fx" % slider_sens.value)
	if check_head_bob:
		check_head_bob.button_pressed = bool(gp.get("head_bob", false))

	if slider_fov:
		slider_fov.value = float(vd.get("fov", 80.0))
		_update_slider_label(label_fov_val, "%d°" % int(slider_fov.value))
	if slider_ui_scale:
		slider_ui_scale.value = float(vd.get("ui_scale", 1.0))
		_update_slider_label(label_ui_scale_val, "%d%%" % int(slider_ui_scale.value * 100))
	if option_window_mode:
		var mode_val: int = int(vd.get("window_mode", 0))
		option_window_mode.select(0 if mode_val == 0 else 1)

	if slider_master:
		slider_master.value = float(au.get("master_volume", 0.7))
		_update_slider_label(label_master_val, "%d%%" % int(slider_master.value * 100))
	if slider_music:
		slider_music.value = float(au.get("music_volume", 0.4))
		_update_slider_label(label_music_val, "%d%%" % int(slider_music.value * 100))
	if slider_sfx:
		slider_sfx.value = float(au.get("sfx_volume", 0.7))
		_update_slider_label(label_sfx_val, "%d%%" % int(slider_sfx.value * 100))

	if check_subtitles:
		check_subtitles.button_pressed = bool(ac.get("subtitles", true))

	if status_label:
		status_label.text = ""

func save_and_apply() -> void:
	var win_mode: int = 0
	if option_window_mode:
		var idx := option_window_mode.selected
		win_mode = option_window_mode.get_item_id(idx)

	var new_settings: Dictionary = {
		"gameplay": {
			"mouse_sensitivity_multiplier": slider_sens.value if slider_sens else 1.0,
			"head_bob": check_head_bob.button_pressed if check_head_bob else false
		},
		"video": {
			"fov": slider_fov.value if slider_fov else 80.0,
			"ui_scale": slider_ui_scale.value if slider_ui_scale else 1.0,
			"window_mode": win_mode
		},
		"audio": {
			"master_volume": slider_master.value if slider_master else 0.7,
			"music_volume": slider_music.value if slider_music else 0.4,
			"sfx_volume": slider_sfx.value if slider_sfx else 0.7
		},
		"accessibility": {
			"subtitles": check_subtitles.button_pressed if check_subtitles else true
		}
	}

	var sm := _get_save_manager()
	if sm != null:
		var err: Error = sm.save_settings(new_settings)
		if err == OK:
			if status_label:
				status_label.text = "Pengaturan berhasil disimpan dan diterapkan."
				status_label.modulate = Color(0.4, 1.0, 0.4)
		else:
			if status_label:
				status_label.text = "Gagal menyimpan pengaturan ke disk."
				status_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		if status_label:
			status_label.text = "Pengaturan diterapkan ke sesi lokal."
			status_label.modulate = Color(0.4, 1.0, 0.4)

	settings_applied.emit()

func reset_to_defaults() -> void:
	var sm := _get_save_manager()
	var defs: Dictionary = sm.get_default_settings() if sm != null else _get_fallback_default_settings()

	var gp: Dictionary = defs.get("gameplay", {})
	var vd: Dictionary = defs.get("video", {})
	var au: Dictionary = defs.get("audio", {})
	var ac: Dictionary = defs.get("accessibility", {})

	if slider_sens:
		slider_sens.value = float(gp.get("mouse_sensitivity_multiplier", 1.0))
		_update_slider_label(label_sens_val, "%.1fx" % slider_sens.value)
	if check_head_bob:
		check_head_bob.button_pressed = bool(gp.get("head_bob", false))

	if slider_fov:
		slider_fov.value = float(vd.get("fov", 80.0))
		_update_slider_label(label_fov_val, "%d°" % int(slider_fov.value))
	if slider_ui_scale:
		slider_ui_scale.value = float(vd.get("ui_scale", 1.0))
		_update_slider_label(label_ui_scale_val, "%d%%" % int(slider_ui_scale.value * 100))
	if option_window_mode:
		option_window_mode.select(0)

	if slider_master:
		slider_master.value = float(au.get("master_volume", 0.7))
		_update_slider_label(label_master_val, "%d%%" % int(slider_master.value * 100))
	if slider_music:
		slider_music.value = float(au.get("music_volume", 0.4))
		_update_slider_label(label_music_val, "%d%%" % int(slider_music.value * 100))
	if slider_sfx:
		slider_sfx.value = float(au.get("sfx_volume", 0.7))
		_update_slider_label(label_sfx_val, "%d%%" % int(slider_sfx.value * 100))

	if check_subtitles:
		check_subtitles.button_pressed = bool(ac.get("subtitles", true))

	if status_label:
		status_label.text = "Nilai default dimuat. Tekan Simpan untuk menerapkan."
		status_label.modulate = Color(1.0, 0.85, 0.3)

func close_settings() -> void:
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("pause_menu") and not event.is_echo():
		close_settings()
		get_viewport().set_input_as_handled()

func _update_slider_label(lbl: Label, text: String) -> void:
	if lbl != null:
		lbl.text = text

func _get_save_manager() -> Node:
	if Engine.has_singleton("SaveManager"):
		return Engine.get_singleton("SaveManager")
	var tree: SceneTree = get_tree() if is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	if tree != null and tree.root != null and tree.root.has_node("SaveManager"):
		return tree.root.get_node("SaveManager")
	return null

func _get_fallback_default_settings() -> Dictionary:
	return {
		"gameplay": {
			"mouse_sensitivity_multiplier": 1.0,
			"head_bob": false
		},
		"video": {
			"fov": 80.0,
			"ui_scale": 1.0,
			"window_mode": 0
		},
		"audio": {
			"master_volume": 0.7,
			"music_volume": 0.4,
			"sfx_volume": 0.7
		},
		"accessibility": {
			"subtitles": true
		}
	}
