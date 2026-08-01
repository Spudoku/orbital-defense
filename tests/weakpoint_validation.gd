extends SceneTree

const TARGET_RADIUS: float = 52.0
const ASTEROID_VARIANT_COUNT: int = 6
const ASTEROID_TEST_WIDTHS = [1040.0, 1180.0]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var level_scene: PackedScene = load("res://scenes/keyboard_tracing_prototype.tscn")
	var level: Node2D = level_scene.instantiate()
	root.add_child(level)
	await process_frame

	var targets: Array = level.get("_targets")
	if targets.size() != 5:
		_failures.append("Expected 5 weakpoints, found %d." % targets.size())

	var asteroid: AnimatedSprite2D = level.get_node("AnimatedAsteroid")
	for asteroid_width in ASTEROID_TEST_WIDTHS:
		for variant in range(ASTEROID_VARIANT_COUNT):
			level.call("synced_asteroid_flyin", variant, Vector2(1200.0, 675.0), asteroid_width)
			level.call("_randomize_target_positions")
			level.call("_randomize_target_visuals")

			var animation_name: StringName = asteroid.animation
			var final_frame: int = asteroid.sprite_frames.get_frame_count(animation_name) - 1
			var image: Image = asteroid.sprite_frames.get_frame_texture(animation_name, final_frame).get_image()
			var image_size: Vector2 = Vector2(image.get_width(), image.get_height())
			var radius_in_pixels: float = TARGET_RADIUS / maxf(absf(asteroid.scale.x), 0.001)
			var seen_variants: Dictionary = {}

			for target_node in targets:
				var target: WeakpointTarget = target_node as WeakpointTarget
				if target == null:
					_failures.append("Target is not a WeakpointTarget.")
					continue

				var pixel_position: Vector2 = asteroid.to_local(target.global_position) + image_size * 0.5
				if not bool(level.call("_is_opaque_target_area", image, pixel_position, radius_in_pixels)):
					_failures.append(
						"Variant %d at width %.0f placed a crack outside the asteroid."
						% [variant, asteroid_width]
					)

				seen_variants[target.visual_variant] = true
				var normal_texture: Texture2D = target.get_node("Crack").texture
				target.set_completed(true)
				if target.get_node("Crack").texture == normal_texture:
					_failures.append("Variant %d did not switch to its glow texture." % target.visual_variant)
				target.set_completed(false)

			if seen_variants.size() != WeakpointTarget.VARIANT_COUNT:
				_failures.append("Asteroid variant %d did not use all crack shapes." % variant)

	level.queue_free()
	await process_frame

	if _failures.is_empty():
		print("Weakpoint validation passed for all 6 enabled asteroid variants at both size limits.")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)
