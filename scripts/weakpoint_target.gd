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
const NORMAL_OUTLINE_COLOR := Color(1.0, 0.28, 0.08, 0.95)
const COMPLETED_OUTLINE_COLOR := Color(1.0, 0.82, 0.22, 1.0)
const OUTLINE_PATHS = [
	[
		[Vector2(-7, -25), Vector2(-5, -22), Vector2(-1, -18), Vector2(2, -14), Vector2(2, -8), Vector2(1, -2), Vector2(0, 4), Vector2(-2, 10), Vector2(-1, 17)],
		[Vector2(-1, 2), Vector2(-7, 0), Vector2(-12, -4), Vector2(-16, -8), Vector2(-22, -10), Vector2(-26, -13)],
		[Vector2(0, 1), Vector2(6, -3), Vector2(12, -7), Vector2(18, -11), Vector2(24, -13)],
	],
	[
		[Vector2(-7, -11), Vector2(-6, -3), Vector2(-4, 2), Vector2(1, 6), Vector2(7, 10), Vector2(13, 14), Vector2(19, 19), Vector2(22, 25), Vector2(22, 31)],
		[Vector2(21, 23), Vector2(30, 25)],
	],
	[
		[Vector2(-2, -22), Vector2(-2, -8), Vector2(-2, 8), Vector2(1, 15), Vector2(6, 18)],
		[Vector2(17, 1), Vector2(14, 8), Vector2(10, 15), Vector2(6, 18)],
		[Vector2(6, 18), Vector2(14, 20), Vector2(22, 23)],
	],
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
@onready var _outline_segments: Array[Line2D] = [
	$OutlineMain,
	$OutlineBranchA,
	$OutlineBranchB,
]

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
	_crack.modulate = Color.WHITE
	_refresh_outline()
	set_process(completed and not Engine.is_editor_hint())


func _refresh_outline() -> void:
	var paths: Array = OUTLINE_PATHS[visual_variant]
	var outline_color: Color = COMPLETED_OUTLINE_COLOR if completed else NORMAL_OUTLINE_COLOR

	for index in range(_outline_segments.size()):
		var segment := _outline_segments[index]
		segment.default_color = outline_color
		segment.points = PackedVector2Array(paths[index]) if index < paths.size() else PackedVector2Array()
