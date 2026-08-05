extends Node

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var volume_scene: PackedScene = load("res://scenes/volume_control.tscn")
	var menu_control: VolumeControl = volume_scene.instantiate()
	var pause_control: VolumeControl = volume_scene.instantiate()
	add_child(menu_control)
	add_child(pause_control)
	await get_tree().process_frame

	GameManager.set_master_volume(37.0)
	await get_tree().process_frame
	_validate_control(menu_control, 37.0, "menu")
	_validate_control(pause_control, 37.0, "pause")

	var master_bus_index: int = AudioServer.get_bus_index("Master")
	var linear_volume: float = db_to_linear(AudioServer.get_bus_volume_db(master_bus_index))
	if not is_equal_approx(linear_volume, 0.37):
		_failures.append("Master bus did not change to 37%.")

	GameManager.set_master_volume(0.0)
	await get_tree().process_frame
	_validate_control(menu_control, 0.0, "menu")
	_validate_control(pause_control, 0.0, "pause")
	if not AudioServer.is_bus_mute(master_bus_index):
		_failures.append("Master bus was not muted at 0%.")

	GameManager.set_master_volume(100.0)
	menu_control.queue_free()
	pause_control.queue_free()
	await get_tree().process_frame

	if _failures.is_empty():
		print("Volume control validation passed for menu and pause controls.")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _validate_control(control: VolumeControl, expected: float, location: String) -> void:
	var slider: HSlider = control.get_node("VolumeSlider")
	var label: Label = control.get_node("Header/VolumePercent")
	if not is_equal_approx(slider.value, expected):
		_failures.append("The %s slider did not synchronize." % location)
	if label.text != "%d%%" % int(expected):
		_failures.append("The %s percentage did not synchronize." % location)
