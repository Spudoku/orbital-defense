extends SceneTree

const GAMEPLAY_SCENE_PATH = "res://scenes/keyboard_tracing_prototype.tscn"
const FRAME_SIZE = Vector2(762.0, 428.0)
const SOURCE_FRAME_COUNT = 43
const GRID_COLUMNS = 11
const MAX_TEXTURE_DIMENSION = 16384.0

const ANIMATION_DATA = {
	"blue_flyin_1": ["res://assets/Asteroids Assets/MovingBlue/asteroidblue1_flyin_sheet", 43, true],
	"blue_flyin_2": ["res://assets/Asteroids Assets/MovingBlue/asteroidblue2_flyin_sheet", 43, true],
	"blue_flyin_3": ["res://assets/Asteroids Assets/MovingBlue/asteroidblue3_flyin_sheet", 43, true],
	"blue_flyin_4": ["res://assets/Asteroids Assets/MovingBlue/asteroidblue4_flyin_sheet", 43, true],
	"brown_flyin_1": ["res://assets/Asteroids Assets/MovingBrown/asteroidbrown1_flyin_sheet", 43, true],
	"brown_flyin_2": ["res://assets/Asteroids Assets/MovingBrown/asteroidbrown2_flyin_sheet", 43, true],
	"brown_flyin_3": ["res://assets/Asteroids Assets/MovingBrown/asteroidbrown3_flyin_sheet", 129, false],
	"brown_flyin_4": ["res://assets/Asteroids Assets/MovingBrown/asteroidbrown4_flyin_sheet", 43, false],
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gameplay_scene: PackedScene = load(GAMEPLAY_SCENE_PATH)
	var gameplay: Node = gameplay_scene.instantiate()
	var asteroid: AnimatedSprite2D = gameplay.get_node("AnimatedAsteroid")
	var sprite_frames: SpriteFrames = asteroid.sprite_frames

	var validated_timeline_frames: int = 0
	for animation_name: String in ANIMATION_DATA:
		var animation_data: Array = ANIMATION_DATA[animation_name]
		validated_timeline_frames += _validate_animation(
			sprite_frames,
			animation_name,
			animation_data[1],
			animation_data[2]
		)

	gameplay.free()
	if _failures.is_empty():
		print(
			"Fly-in texture validation passed for all %d timeline frame references."
			% validated_timeline_frames
		)
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _validate_animation(
	sprite_frames: SpriteFrames,
	animation_name: String,
	expected_count: int,
	expect_sequential_frames: bool
) -> int:
	var actual_count: int = sprite_frames.get_frame_count(animation_name)
	if actual_count != expected_count:
		_failures.append(
			"%s has %d timeline frames instead of %d."
			% [animation_name, actual_count, expected_count]
		)

	for frame_index in range(actual_count):
		var texture: Texture2D = sprite_frames.get_frame_texture(animation_name, frame_index)
		var atlas_texture: AtlasTexture = texture as AtlasTexture
		if atlas_texture == null:
			_failures.append(
				"%s timeline frame %d is not an AtlasTexture."
				% [animation_name, frame_index]
			)
			continue

		if atlas_texture.get_size() != FRAME_SIZE:
			_failures.append(
				"%s frame %d has size %s." % [animation_name, frame_index, atlas_texture.get_size()]
			)

		var atlas_path: String = atlas_texture.atlas.resource_path
		if not _is_flyin_grid(atlas_path):
			_failures.append(
				"%s timeline frame %d uses unexpected atlas %s."
				% [animation_name, frame_index, atlas_path]
			)
			continue

		var region_position: Vector2 = atlas_texture.region.position
		if (
			not is_zero_approx(fmod(region_position.x, FRAME_SIZE.x))
			or not is_zero_approx(fmod(region_position.y, FRAME_SIZE.y))
		):
			_failures.append(
				"%s timeline frame %d has unaligned region position %s."
				% [animation_name, frame_index, region_position]
			)
		else:
			var column: int = roundi(region_position.x / FRAME_SIZE.x)
			var row: int = roundi(region_position.y / FRAME_SIZE.y)
			var source_frame_index: int = row * GRID_COLUMNS + column
			if source_frame_index < 0 or source_frame_index >= SOURCE_FRAME_COUNT:
				_failures.append(
					"%s timeline frame %d points outside the 43 source frames."
					% [animation_name, frame_index]
				)
			elif expect_sequential_frames and source_frame_index != frame_index:
				_failures.append(
					"%s timeline frame %d points to source frame %d."
					% [animation_name, frame_index, source_frame_index]
				)

		var atlas_size: Vector2 = atlas_texture.atlas.get_size()
		if atlas_size.x > MAX_TEXTURE_DIMENSION or atlas_size.y > MAX_TEXTURE_DIMENSION:
			_failures.append(
				"%s frame %d uses oversized atlas %s." % [animation_name, frame_index, atlas_size]
			)

	return actual_count


func _is_flyin_grid(atlas_path: String) -> bool:
	for animation_name: String in ANIMATION_DATA:
		var animation_data: Array = ANIMATION_DATA[animation_name]
		var sheet_base_path: String = animation_data[0]
		if atlas_path == sheet_base_path + ".png":
			return true
	return false
