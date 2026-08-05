extends Node

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var life_scene: PackedScene = load("res://scenes/life_indicator.tscn")
	var indicator: LifeIndicator = life_scene.instantiate()
	add_child(indicator)
	await get_tree().process_frame

	_validate_life_count(indicator, 3)
	_validate_life_count(indicator, 2)
	_validate_life_count(indicator, 1)
	_validate_life_count(indicator, 0)

	indicator.set_player_two(true)
	var backdrop: TextureRect = indicator.get_node("Backdrop")
	if not backdrop.texture.resource_path.ends_with("HudBackDropPlayer2.png"):
		_failures.append("Player 2 did not receive the red life backdrop.")

	indicator.set_player_two(false)
	if not backdrop.texture.resource_path.ends_with("HudBackDrop.png"):
		_failures.append("Player 1 did not receive the purple life backdrop.")

	indicator.queue_free()
	await get_tree().process_frame

	if _failures.is_empty():
		print("Life indicator validation passed for both players and all life counts.")
		get_tree().quit(0)
		return

	for failure in _failures:
		push_error(failure)
	get_tree().quit(1)


func _validate_life_count(indicator: LifeIndicator, expected_lives: int) -> void:
	indicator.set_remaining_lives(expected_lives)
	var visible_icons: int = 0
	for icon_name in ["Life1", "Life2", "Life3"]:
		var icon: TextureRect = indicator.get_node(icon_name)
		visible_icons += 1 if icon.visible else 0
	if visible_icons != expected_lives:
		_failures.append(
			"Expected %d visible lives, found %d." % [expected_lives, visible_icons]
		)
