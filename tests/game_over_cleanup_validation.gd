extends SceneTree

const GAMEPLAY_SCENE_PATH = "res://scenes/keyboard_tracing_prototype.tscn"
const GAMEPLAY_ASSET_NAMES = ["Level", "CockpitFrame", "Targets", "LifeIndicator"]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gameplay_scene: PackedScene = load(GAMEPLAY_SCENE_PATH)
	var gameplay: Node = gameplay_scene.instantiate()
	root.add_child(gameplay)
	await process_frame

	gameplay.trigger_game_over()
	await scene_changed
	await process_frame

	_validate_current_scene("GameOver")
	_validate_gameplay_removed("after opening Game Over")

	var game_over: Node = current_scene
	game_over._on_exit_pressed()
	await scene_changed
	await process_frame

	_validate_current_scene("Control")
	_validate_gameplay_removed("after returning to the main menu")

	if _failures.is_empty():
		print("Game-over cleanup validation passed; no gameplay assets survived.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _validate_current_scene(expected_name: String) -> void:
	if current_scene == null or current_scene.name != expected_name:
		var actual_name: String = "none" if current_scene == null else str(current_scene.name)
		_failures.append(
			"Expected current scene %s, found %s." % [expected_name, actual_name]
		)


func _validate_gameplay_removed(context: String) -> void:
	for node_name in GAMEPLAY_ASSET_NAMES:
		if root.find_child(node_name, true, false) != null:
			_failures.append("%s still existed %s." % [node_name, context])
