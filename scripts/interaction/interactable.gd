class_name Interactable
extends Area3D

## Komponen Interaksi Dunia untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR02, UI_UX.md § 3/4, dan CONTENT.md § 14

signal interacted(player: Node3D)
signal focused()
signal unfocused()

@export var interaction_id: String = ""
@export var target_name: String = ""
@export var prompt_action: String = "Periksa"
@export var enabled: bool = true
@export var is_interactable: bool = true
@export var interaction_type: String = "inspect"
@export var hold_time: float = 0.0

func _ready() -> void:
	# Layer 3: interactables (bitmask 1 << 2 = 4)
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true

func is_enabled() -> bool:
	return enabled and is_interactable

func interact(player: Node3D) -> bool:
	if not is_enabled():
		return false
	interacted.emit(player)
	return true

func get_prompt_text() -> String:
	if target_name.strip_edges() != "":
		return "[E] %s %s" % [prompt_action.strip_edges(), target_name.strip_edges()]
	return "[E] %s" % prompt_action.strip_edges()

func get_prompt() -> String:
	return get_prompt_text()

func set_prompt(new_prompt: String) -> void:
	var clean := new_prompt.strip_edges()
	if clean.begins_with("[E] "):
		clean = clean.trim_prefix("[E] ").strip_edges()
	prompt_action = clean
	target_name = ""

func set_enabled(val: bool) -> void:
	enabled = val
	is_interactable = val

func set_interactable(val: bool) -> void:
	is_interactable = val
	enabled = val

func on_focused() -> void:
	focused.emit()

func on_unfocused() -> void:
	unfocused.emit()

