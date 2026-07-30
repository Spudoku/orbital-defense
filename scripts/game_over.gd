extends Control

const MAIN_MENU_PATH = "res://scenes/control.tscn"

@onready var exit_button = $Exit

func _ready():
	exit_button.pressed.connect(_on_exit_pressed)

func _on_exit_pressed():
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
