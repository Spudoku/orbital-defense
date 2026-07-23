extends CanvasLayer
class_name PauseMenu

signal resume_requested

@onready var _resume_button: Button = $Screen/Center/Panel/Margin/Content/ResumeButton


func _ready() -> void:
	set_pause_visible(false)


func set_pause_visible(paused: bool) -> void:
	visible = paused
	if paused:
		_resume_button.grab_focus()


func _on_resume_button_pressed() -> void:
	resume_requested.emit()
