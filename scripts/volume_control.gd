extends VBoxContainer
class_name VolumeControl

@onready var _volume_slider: HSlider = $VolumeSlider
@onready var _volume_percent: Label = $Header/VolumePercent


func _ready() -> void:
	if not GameManager.master_volume_changed.is_connected(_sync_volume):
		GameManager.master_volume_changed.connect(_sync_volume)
	_sync_volume(GameManager.master_volume_percent)


func _on_volume_slider_value_changed(value: float) -> void:
	GameManager.set_master_volume(value)


func _sync_volume(volume_percent: float) -> void:
	_volume_slider.set_value_no_signal(volume_percent)
	_volume_percent.text = "%d%%" % int(round(volume_percent))
