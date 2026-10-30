class_name InteractionPrompt
extends CanvasLayer

## UI Prompt Interaksi dan Reticle untuk 'Buku Resep 2045'
## Memenuhi spesifikasi UI_UX.md § 1/2/4, UI01, dan PRD FR02

@onready var prompt_panel: PanelContainer = find_child("PromptPanel", true, false) as PanelContainer
@onready var prompt_label: Label = find_child("PromptLabel", true, false) as Label
@onready var reticle: Control = find_child("Reticle", true, false) as Control

var _is_visible: bool = false

func _ready() -> void:
	hide_prompt()

func show_prompt(text: String) -> void:
	if prompt_label != null:
		prompt_label.text = text
	_is_visible = true
	if prompt_panel != null:
		prompt_panel.visible = true
		prompt_panel.modulate.a = 1.0

func hide_prompt() -> void:
	_is_visible = false
	if prompt_panel != null:
		prompt_panel.visible = false
		prompt_panel.modulate.a = 0.0

func is_prompt_visible() -> bool:
	return _is_visible and prompt_panel != null and prompt_panel.visible

func get_prompt_text() -> String:
	return prompt_label.text if prompt_label != null else ""

func connect_detector(detector: Node) -> void:
	if detector == null:
		return
	if detector.has_signal("target_focused"):
		if not detector.target_focused.is_connected(_on_target_focused):
			detector.target_focused.connect(_on_target_focused)
	if detector.has_signal("target_unfocused"):
		if not detector.target_unfocused.is_connected(_on_target_unfocused):
			detector.target_unfocused.connect(_on_target_unfocused)

func _on_target_focused(interactable: Object) -> void:
	var text := "[E] Interaksi"
	if interactable != null:
		if interactable.has_method("get_prompt_text"):
			text = interactable.get_prompt_text()
		elif interactable.has_method("get_prompt"):
			text = interactable.get_prompt()
	show_prompt(text)

func _on_target_unfocused() -> void:
	hide_prompt()
