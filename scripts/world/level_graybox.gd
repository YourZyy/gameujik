class_name LevelGraybox
extends Node3D

signal entity_recovered(entity: Node3D, target_position: Vector3)

const LANDMARK_IDS: Array[String] = [
	"zone_home",
	"spawn_home",
	"book_family",
	"station_kitchen_home",
	"storage_home",
	"bed_home",
	"zone_yard",
	"plot_home_01",
	"water_home",
	"container_starter",
	"reserve_home",
	"gate_home",
	"junction_path",
	"resource_jagung_01",
	"note_garden_01",
	"resource_temu_kunci_01",
	"npc_neighbor_01",
	"safe_return_home"
]

@onready var spawn_home: Node3D = $spawn_home if has_node("spawn_home") else null
@onready var safe_return_home: Node3D = $safe_return_home if has_node("safe_return_home") else null
@onready var fall_recovery_area: Area3D = find_child("FallRecoveryArea", true, false) as Area3D

func _ready() -> void:
	if has_method("reset_physics_interpolation"):
		reset_physics_interpolation()
	if fall_recovery_area and not fall_recovery_area.body_entered.is_connected(_on_fall_recovery_area_body_entered):
		fall_recovery_area.body_entered.connect(_on_fall_recovery_area_body_entered)

func get_landmark(landmark_id: String) -> Node3D:
	if has_node(landmark_id):
		return get_node(landmark_id) as Node3D
	return find_child(landmark_id, true, false) as Node3D

func get_spawn_point() -> Node3D:
	return get_landmark("spawn_home")

func get_safe_return_point() -> Node3D:
	return get_landmark("safe_return_home")

func get_spawn_position() -> Vector3:
	var sp = get_spawn_point()
	if sp:
		return sp.global_position if sp.is_inside_tree() else sp.position
	return Vector3(0.0, 0.0, 1.0)

func get_safe_return_position() -> Vector3:
	var srp = get_safe_return_point()
	if srp:
		return srp.global_position if srp.is_inside_tree() else srp.position
	return Vector3(0.0, 0.0, 8.0)

func get_crop_spots() -> Array[Node3D]:
	var spots: Array[Node3D] = []
	var plot = get_landmark("plot_home_01")
	if plot:
		for i in range(4):
			var spot_name = "spot_%d" % i
			var spot = plot.get_node_or_null(spot_name)
			if spot == null:
				spot = plot.find_child(spot_name, true, false)
			if spot is Node3D:
				spots.append(spot)
	return spots

func recover_entity(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return
	var target_pos = get_safe_return_position()
	if entity.is_inside_tree():
		entity.global_position = target_pos
	else:
		entity.position = target_pos
	
	if entity is CharacterBody3D:
		entity.velocity = Vector3.ZERO
	elif entity is RigidBody3D:
		entity.linear_velocity = Vector3.ZERO
		entity.angular_velocity = Vector3.ZERO
	
	if entity.has_method("reset_physics_interpolation"):
		entity.reset_physics_interpolation()
	
	entity_recovered.emit(entity, target_pos)

func check_and_recover_entity(entity: Node3D) -> bool:
	if not is_instance_valid(entity):
		return false
	var pos = entity.global_position if entity.is_inside_tree() else entity.position
	if pos.y < -5.0:
		recover_entity(entity)
		return true
	# Also check outer boundary envelope: X in [-42, 42], Z in [-37, 47]
	if pos.x < -42.0 or pos.x > 42.0 or pos.z < -37.0 or pos.z > 47.0:
		recover_entity(entity)
		return true
	return false

func _on_fall_recovery_area_body_entered(body: Node3D) -> void:
	recover_entity(body)
