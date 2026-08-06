extends Control
class_name LifeIndicator

const MAX_LIVES: int = 3
const X_HEALTH_TEXTURE = preload("res://assets/hud/life/Health_X.png")

@export var player_1_backdrop: Texture2D
@export var player_2_backdrop: Texture2D

@onready var _backdrop: TextureRect = $Backdrop
@onready var _life_icons: Array[TextureRect] = [$Life1, $Life2, $Life3]

var _remaining_lives: int = MAX_LIVES


func _ready() -> void:
	set_player_two(false)
	set_remaining_lives(_remaining_lives)


func set_remaining_lives(remaining_lives: int) -> void:
	_remaining_lives = clampi(remaining_lives, 0, MAX_LIVES)
	for icon_index in range(_life_icons.size()):
		if icon_index >= _remaining_lives:
			_life_icons[icon_index].texture = X_HEALTH_TEXTURE


func set_player_two(is_player_two: bool) -> void:
	_backdrop.texture = player_2_backdrop if is_player_two else player_1_backdrop


func get_remaining_lives() -> int:
	return _remaining_lives
