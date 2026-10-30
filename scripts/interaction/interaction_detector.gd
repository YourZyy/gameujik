class_name InteractionDetector
extends RayCast3D

## Raycast Interaction Detector untuk 'Buku Resep 2045'
## Memenuhi spesifikasi PRD FR02, UI_UX.md § 3/4, CONTENT.md § 14, dan TEST_PLAN T18/T27/T28

const InteractableClass = preload("res://scripts/interaction/interactable.gd")

signal target_focused(interactable: Object)
signal target_unfocused()
signal interaction_performed(interactable: Object)

@export var max_interaction_distance: float = 2.0:
	set(value):
		max_interaction_distance = maxf(0.1, value)
		target_position = Vector3(0.0, 0.0, -max_interaction_distance)

@export var interaction_enabled: bool = true

var current_interactable: InteractableClass = null

func _ready() -> void:
	add_to_group("interaction_detector")
	target_position = Vector3(0.0, 0.0, -max_interaction_distance)
	collide_with_areas = true
	collide_with_bodies = true
	# Layer 1 (Environment = 1) + Layer 3 (Interactables = 4) -> mask = 5
	collision_mask = 5
	enabled = true
	
	# Cegah raycast bertabrakan dengan karakter pemain sendiri
	_exclude_player_bodies()

func _exclude_player_bodies() -> void:
	var curr: Node = get_parent()
	while curr != null:
		if curr is CollisionObject3D:
			add_exception(curr)
		curr = curr.get_parent()

func _physics_process(_delta: float) -> void:
	update_target()

func update_target() -> void:
	if not enabled or not interaction_enabled or not is_inside_tree():
		if current_interactable != null:
			_set_focused_target(null)
		return

	force_raycast_update()

	var detected: InteractableClass = null
	if is_colliding():
		var col = get_collider()
		var candidate = find_interactable(col)
		if candidate != null and candidate.is_enabled():
			detected = candidate

	if detected != current_interactable:
		_set_focused_target(detected)

func _set_focused_target(new_target: InteractableClass) -> void:
	var old_target = current_interactable
	current_interactable = new_target
	if old_target != null:
		old_target.on_unfocused()
		target_unfocused.emit()
	if new_target != null:
		new_target.on_focused()
		target_focused.emit(new_target)

func find_interactable(collider: Object) -> InteractableClass:
	if collider == null:
		return null
	if collider is InteractableClass:
		return collider as InteractableClass

	if collider is Node:
		var node := collider as Node
		# Cek jika collider memiliki anak bertipe Interactable
		if node.has_node("Interactable"):
			var child = node.get_node("Interactable")
			if child is InteractableClass:
				return child as InteractableClass
		
		# Cek parent jika collider adalah bagian dari mesh/collision landmark
		var parent = node.get_parent()
		if parent != null:
			if parent.name in ["HouseStructure", "Environment", "LevelGraybox", "World", "Main"]:
				return null
			if parent is InteractableClass:
				return parent as InteractableClass
			if parent.has_node("Interactable"):
				var sibling = parent.get_node("Interactable")
				if sibling is InteractableClass:
					return sibling as InteractableClass
			
			# Cek kakek (grandparent) untuk struktur landmark dengan StaticBody bersarang
			var grandparent = parent.get_parent()
			if grandparent != null:
				if grandparent.name in ["HouseStructure", "Environment", "LevelGraybox", "World", "Main"]:
					return null
				if grandparent is InteractableClass:
					return grandparent as InteractableClass
				if grandparent.has_node("Interactable"):
					var grand_child = grandparent.get_node("Interactable")
					if grand_child is InteractableClass:
						return grand_child as InteractableClass

	return null

func has_focused_target() -> bool:
	return current_interactable != null and current_interactable.is_enabled()

func get_current_target() -> InteractableClass:
	return current_interactable

func get_focused_interactable() -> InteractableClass:
	return current_interactable

func try_interact(player: Node3D) -> bool:
	if not interaction_enabled:
		return false
	
	var im: Node = get_node_or_null("/root/InputManager") if is_inside_tree() else null
	if im != null:
		if im.has_method("can_interact_in_world") and not im.can_interact_in_world():
			return false
		if im.has_method("is_action_suppressed") and im.is_action_suppressed(&"interact"):
			return false
	
	if has_focused_target():
		var target := current_interactable
		var success: bool = target.interact(player)
		if success:
			interaction_performed.emit(target)
			return true
	return false

func interact_with_current(player: Node3D) -> bool:
	return try_interact(player)

func clear_target() -> void:
	if current_interactable != null:
		_set_focused_target(null)

