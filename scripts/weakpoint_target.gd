@tool
extends Area2D
class_name WeakpointTarget

const NORMAL_TEXTURES = [
	preload("res://assets/weakpoints/crack_1_normal.png"),
	preload("res://assets/weakpoints/crack_2_normal.png"),
	preload("res://assets/weakpoints/crack_4_normal.png"),
]
const GLOW_TEXTURES = [
	preload("res://assets/weakpoints/crack_1_glow.png"),
	preload("res://assets/weakpoints/crack_2_glow.png"),
	preload("res://assets/weakpoints/crack_4_glow.png"),
]
const VARIANT_COUNT: int = 3
const GLOW_PULSE_SPEED: float = 5.0
const TARGET_ALPHA: float = 0.46
const COMPLETED_TARGET_ALPHA: float = 0.2
const CRACK_VISUAL_OFFSETS = [
	Vector2(-1.0, 6.0),
	Vector2(-14.0, -12.0),
	Vector2(-12.0, -1.0),
]

@export_range(0, VARIANT_COUNT - 1, 1) var visual_variant: int = 0:
	set(value):
		visual_variant = clampi(value, 0, VARIANT_COUNT - 1)
		_refresh_visual()

@export var completed: bool = false:
	set(value):
		completed = value
		_glow_time = 0.0
		_refresh_visual()

@onready var _crack: Sprite2D = $Crack
@onready var _target_overlay: Sprite2D = $TargetOverlay

var _glow_time: float = 0.0


func _ready() -> void:
	_refresh_visual()


func _process(delta: float) -> void:
	if not completed or Engine.is_editor_hint():
		return

	_glow_time += delta
	var glow_alpha: float = 0.82 + sin(_glow_time * GLOW_PULSE_SPEED) * 0.18
	_crack.modulate = Color(1.0, 1.0, 1.0, glow_alpha)


func set_completed(value: bool) -> void:
	completed = value


func _refresh_visual() -> void:
	if not is_node_ready() or _crack == null:
		return

	_crack.texture = GLOW_TEXTURES[visual_variant] if completed else NORMAL_TEXTURES[visual_variant]
	_crack.position = CRACK_VISUAL_OFFSETS[visual_variant]
	_crack.modulate = Color.WHITE
	_target_overlay.modulate = Color(1.0, 1.0, 1.0, COMPLETED_TARGET_ALPHA if completed else TARGET_ALPHA)
	set_process(completed and not Engine.is_editor_hint())
