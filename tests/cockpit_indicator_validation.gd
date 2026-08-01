extends SceneTree

const SCREEN_SIZE = Vector2(1920.0, 1080.0)
const AIM_CLEAR_RADIUS: float = 220.0
const COCKPIT_TEXTURES = [
	preload("res://assets/cockpit_player_1.png"),
	preload("res://assets/cockpit_player_2.png"),
]
const HIDDEN_TARGET_POSITIONS = [
	Vector2(-400.0, 540.0),
	Vector2(2320.0, 540.0),
	Vector2(960.0, -400.0),
	Vector2(960.0, 1480.0),
	Vector2(-400.0, -400.0),
	Vector2(2320.0, -400.0),
	Vector2(-400.0, 1480.0),
	Vector2(2320.0, 1480.0),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_scene: PackedScene = load("res://scenes/keyboard_tracing_prototype.tscn")
	var level: Node2D = level_scene.instantiate()
	root.add_child(level)
	await process_frame

	var cockpit_frame: TextureRect = level.get_node("HUD/CockpitFrame")
	for cockpit_index in range(COCKPIT_TEXTURES.size()):
		cockpit_frame.texture = COCKPIT_TEXTURES[cockpit_index]

		var view_center: Vector2 = SCREEN_SIZE * Vector2(0.5, 0.43)
		if not bool(level.call("_is_cockpit_view_point", view_center, SCREEN_SIZE)):
			_failures.append("Cockpit %d does not recognize its central window." % (cockpit_index + 1))
		if bool(level.call("_is_cockpit_view_point", Vector2(200.0, 350.0), SCREEN_SIZE)):
			_failures.append("Cockpit %d incorrectly includes a side window." % (cockpit_index + 1))
		if bool(level.call("_is_cockpit_view_point", Vector2(960.0, 960.0), SCREEN_SIZE)):
			_failures.append("Cockpit %d incorrectly includes the control panel." % (cockpit_index + 1))

		for target_position in HIDDEN_TARGET_POSITIONS:
			var indicator_position: Vector2 = level.call(
				"_find_cockpit_indicator_position",
				target_position,
				SCREEN_SIZE
			)
			if not bool(level.call("_is_cockpit_view_point", indicator_position, SCREEN_SIZE)):
				_failures.append(
					"Cockpit %d placed an indicator outside its viewing window." % (cockpit_index + 1)
				)
			if indicator_position.distance_to(view_center) < AIM_CLEAR_RADIUS:
				_failures.append(
					"Cockpit %d placed an indicator too close to the aiming crosshair." % (cockpit_index + 1)
				)

	level.queue_free()
	await process_frame

	if _failures.is_empty():
		print("Cockpit indicator validation passed for both player views.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
