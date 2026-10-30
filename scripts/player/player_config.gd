class_name PlayerConfig
extends Resource

## Acuan spesifikasi CONTENT.md § 14 dan PRD FR01-FR02

const DEFAULT_MOVE_SPEED: float = 3.0 # meter/detik
const DEFAULT_EYE_HEIGHT: float = 1.6 # meter dari posisi kaki
const DEFAULT_CAPSULE_RADIUS: float = 0.4 # meter
const DEFAULT_CAPSULE_HEIGHT: float = 1.8 # meter
const DEFAULT_COLLISION_CENTER_Y: float = 0.9 # meter (height / 2, kaki tepat di Y = 0)

const DEFAULT_FOV: float = 80.0 # derajat
const MIN_FOV: float = 60.0
const MAX_FOV: float = 100.0

# Sensitivitas mouse: dasar 0.1° rotasi per piksel mouse * pengali 1.0x
# 0.1 deg = 0.00174532925 rad
const BASE_MOUSE_SENSITIVITY_DEG_PER_PIXEL: float = 0.1
const DEFAULT_MOUSE_SENSITIVITY: float = 0.00174532925 # rad per pixel

const MIN_PITCH_DEG: float = -85.0 # derajat
const MAX_PITCH_DEG: float = 85.0 # derajat
const MIN_PITCH_RAD: float = -1.4835298641951802 # deg_to_rad(-85.0)
const MAX_PITCH_RAD: float = 1.4835298641951802 # deg_to_rad(85.0)

const FALL_RECOVERY_Y_THRESHOLD: float = -5.0
const DEFAULT_SAFE_RETURN_POSITION: Vector3 = Vector3(0.0, 0.0, 8.0)
const DEFAULT_SPAWN_POSITION: Vector3 = Vector3(0.0, 0.0, 1.0)

# Collision Layers (matching project.godot layer names)
const LAYER_ENVIRONMENT: int = 1 << 0  # 1
const LAYER_PLAYER: int = 1 << 1       # 2
const LAYER_INTERACTABLES: int = 1 << 2 # 4
const LAYER_TRIGGERS: int = 1 << 3     # 8
const DEFAULT_PLAYER_COLLISION_MASK: int = LAYER_ENVIRONMENT | LAYER_INTERACTABLES | LAYER_TRIGGERS # 13

# Game Feel: Camera Shake & Head Bob
const DEFAULT_TRAUMA_DECAY: float = 1.5
const MAX_SHAKE_OFFSET: Vector3 = Vector3(0.05, 0.05, 0.0)
const MAX_SHAKE_ROLL_RAD: float = 0.035 # ~2.0 degrees

const DEFAULT_BOB_FREQUENCY: float = 2.4 # cycles per meter of movement
const DEFAULT_BOB_AMPLITUDE_V: float = 0.03 # 3cm vertical bob
const DEFAULT_BOB_AMPLITUDE_H: float = 0.015 # 1.5cm horizontal sway
