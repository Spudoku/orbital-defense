extends CanvasLayer
class_name PauseMenu

signal resume_requested
signal main_menu_requested
signal disconnect_notice_dismissed

@onready var _screen: Control = $Screen
@onready var _resume_button: Button = $Screen/Center/Panel/Margin/Content/ResumeButton
@onready var _disconnect_notice: Control = $DisconnectNotice
@onready var _disconnect_label: Label = $DisconnectNotice/Center/Panel/Margin/Content/Message


func _ready() -> void:
	visible = true
	_disconnect_notice.visible = false
	set_pause_visible(false)


func set_pause_visible(paused: bool) -> void:
	_screen.visible = paused
	if paused:
		_disconnect_notice.visible = false
		_resume_button.grab_focus()


func show_disconnect_notice(player_name: String) -> void:
	visible = true
	_screen.visible = false
	_disconnect_label.text = "%s exited the game" % player_name
	_disconnect_notice.visible = true


func _on_resume_button_pressed() -> void:
	resume_requested.emit()


func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()


func _on_disconnect_notice_pressed() -> void:
	_disconnect_notice.visible = false
	disconnect_notice_dismissed.emit()
