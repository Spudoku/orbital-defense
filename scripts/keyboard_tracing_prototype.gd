extends Node2D

#region constants
const TARGET_SCENE = preload("res://scenes/target_circle.tscn")
const CURSOR_SCENE = preload("res://scenes/cursor.tscn")
const GAME_OVER_PATH = "res://scenes/game_over.tscn"
const MENU_SCENE_PATH = "res://scenes/control.tscn"
# const STAR_BACKGROUND_TEXTURE = preload("res://assets/stars_final.png")
const PLAYER_1_COCKPIT_TEXTURE = preload("res://assets/cockpit_player_1.png")
const PLAYER_2_COCKPIT_TEXTURE = preload("res://assets/cockpit_player_2.png")


const ASTEROID_FLYIN_ANIMATIONS = [
	"blue_flyin_1",
	"blue_flyin_2",
	"blue_flyin_3",
	"blue_flyin_4",
	"brown_flyin_1",
	"brown_flyin_2",
	# "brown_flyin_3",
	# "brown_flyin_4",
]

const ASTEROID_EXPLODE_ANIMATIONS = [
	"blue_explode_1",
	"blue_explode_2",
	"blue_explode_3",
	"blue_explode_4",
	"brown_explode_1",
	"brown_explode_2",
	# "brown_explode_3",
	# "brown_explode_4",
]

const VIEW_SIZE = Vector2(2400, 1350)
const BACKGROUND_PADDING = 1600.0
const CURSOR_BOX_SIZE = 36.0
const CURSOR_SPEED = 520.0
const LASER_RADIUS = 30.0
const LINE_POINT_MIN_DISTANCE = 4.0
const MAX_ENERGY = 100.0
const ENERGY_DRAIN_PER_SECOND = 15.0
const ASTEROID_TIME_LIMIT = 20.0
const ASTEROID_MISS_ENERGY_PENALTY = 25.0


# target-related constants
const TARGET_COUNT = 5
const TARGET_SPAWN_MARGIN = 55.0
const TARGET_SPAWN_TOP = 130.0
const TARGET_MINIMUM_SPACING = 100.0
const TARGET_PLACEMENT_RADIUS = 32.0
const TARGET_ALPHA_THRESHOLD = 0.8
const TARGET_ALPHA_SAMPLE_COUNT = 16
const OFFSCREEN_BUBBLE_EDGE_MARGIN = 56.0
const OFFSCREEN_BUBBLE_RADIUS = 17.0
const ASTEROID_WIDTH_MIN = 960.0
const ASTEROID_WIDTH_MAX = 1100.0
# target colors
const TARGET_RED_FILL = Color(1.0, 0.18, 0.22, 0.9)
const TARGET_RED_GLOW = Color(1.0, 0.18, 0.22, 0.18)
const TARGET_RED_RING = Color(1.0, 0.55, 0.40, 0.75)
const TARGET_DONE_FILL = Color(0.24, 1.0, 0.66, 0.9)
const TARGET_DONE_GLOW = Color(0.24, 1.0, 0.66, 0.18)
const TARGET_DONE_RING = Color(0.86, 0.96, 1.0, 0.55)

enum GameState {
	Playing = 0,
	Paused = 1,
	Ended = 2
}
#endregion

var _cursor: Node2D
@export var _cursor_position: Vector2
@export var score: int = 0
@export var energy: float = MAX_ENERGY
@export var completed_targets: int = 0
@export var asteroid_time_remaining: float = ASTEROID_TIME_LIMIT
@export var missed_asteroids: int = 0


@export var asteroid_variant: int = 0
var asteroid_anim_name
var scale_factor


@export var asteroid_position: Vector2 = VIEW_SIZE * 0.5
@export var asteroid_width: float = ASTEROID_WIDTH_MIN
var _laser_active: bool = false
var _laser_was_active: bool = false
var _laser_state: bool = false
var _local_laser_active: bool = false
var _local_laser_was_active: bool = false
var _round_flash: float = 0.0
var _targets: Array[Area2D] = []
var _current_line: Line2D = null
var _last_laser_collision_position: Vector2 = Vector2.ZERO
var _has_last_laser_collision_position: bool = false
var _asteroid_visual_initialized: bool = false
var _last_asteroid_variant: int = -1

var _last_asteroid_position: Vector2 = Vector2.ZERO
var _last_asteroid_width: float = 0.0
var children: Array[Node] = [] # this is to store the children of the cursor node
var laser_animation_1: AnimatedSprite2D = null
var laser_animation_2: AnimatedSprite2D = null

var updated_roles = false # this is to check if controls have been properly assigned

var game_state: GameState = GameState.Playing

#region onready_vars
@onready var _targets_root: Node2D = $Targets
@onready var _lines: Node2D = $LaserLines

@onready var _asteroid_animation: AnimatedSprite2D = $AnimatedAsteroid

@onready var _aim_overlay: Node2D = $AimOverlay
# @onready var _camera: Camera2D = $Camera2D
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _target_label: Label = $HUD/TargetLabel
@onready var _timer_label: Label = $HUD/TimerLabel
@onready var _miss_label: Label = $HUD/MissLabel
@onready var _energy_display: EnergyDisplay = $HUD/EnergyDisplay
@onready var _cockpit_frame: TextureRect = $HUD/CockpitFrame
@onready var clientLabel: Label = $HUD/ClientLabel
@onready var _pause_menu: PauseMenu = $PauseMenu
# @onready var _background_frame: Sprite2D = $Background

@onready var targets_spawner = $MultiplayerSpawner_targets
@onready var cursor_spawner = $MultiplayerSpawner_cursor

@onready var explosion_sound = $ExplosionSound
#endregion


func _ready() -> void:
	if not _aim_overlay.draw.is_connected(_draw_aim_overlay):
		_aim_overlay.draw.connect(_draw_aim_overlay)
	if not _pause_menu.resume_requested.is_connected(_on_pause_resume_requested):
		_pause_menu.resume_requested.connect(_on_pause_resume_requested)
	_pause_menu.set_pause_visible(false)
	# _apply_asteroid_visual(true)
	_update_hud()
	_update_cockpit_frame()
	# _background_frame.texture = STAR_BACKGROUND_TEXTURE
	cursor_spawner.spawned.connect(connect_cursor)


	if not multiplayer.peer_disconnected.is_connected(player_disconnected):
		multiplayer.peer_disconnected.connect(player_disconnected)

	# 1. Connect target spawner to register nodes on clients when instantiated by server
	targets_spawner.spawned.connect(_on_target_spawned)

	# handling things only the server should...
	if multiplayer.is_server():
		instantiate_targets()

		instantiate_cursor()
		_new_asteroid_round()
		get_tree().create_timer(0.1).timeout.connect(assign_controls)
		for player in GameManager.Players:
			print("Player connected: %d" % player)
			
			pass

		game_state = GameState.Playing
	
	# spawn players?

	
# create new cursor node
func instantiate_cursor() -> void:
	_cursor = CURSOR_SCENE.instantiate()
	_cursor.position = VIEW_SIZE * 0.5

	if multiplayer.is_server():
		_cursor_position = _cursor.position
	# _camera.position = _cursor_position

	children = _cursor.get_children()
	
	add_child(_cursor)

# set _cursor to the cursor node
func connect_cursor(node: Node) -> void:
	print("Connecting cursor...")
	_cursor = node
	pass

# create laser-target Nodes
func instantiate_targets() -> void:
	if not multiplayer.is_server():
		return
	
	_targets.clear()
	for i in range(TARGET_COUNT):
		var new_target = TARGET_SCENE.instantiate()
		new_target.name = "Target_%d" % ResourceUID.create_id()
		print("Instantiating target: %s" % new_target.name)
		_targets_root.add_child(new_target)
		_targets.append(new_target)
	pass


# main game loop powering everything
# process handles the following logic:
# handle input
# render the laser
# if all asteroids are completed, start a new round
func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	# _apply_asteroid_visual()

	if not is_instance_valid(_cursor):
		return

	if game_state == GameState.Playing:
		_update_cockpit_frame()

		# input: handled by clients
		_move_cursor(delta)

		# camera position: handled by server
		# _camera.position = _cursor_position

		if missed_asteroids >= 3:
			check_game_over()

		# laser animations 
		var local_laser_pressed: bool = Input.is_action_pressed("fire_laser")
		request_laser_state.rpc(local_laser_pressed)


		var previous_laser_active: bool = _laser_active
		_laser_active = local_laser_pressed or _laser_state
		_laser_was_active = previous_laser_active

		var previous_local_laser_active: bool = _local_laser_active
		_local_laser_active = local_laser_pressed
		_local_laser_was_active = previous_local_laser_active

		var my_laser_animation: AnimatedSprite2D = _get_player_laser_animation()
		if _local_laser_active and not _local_laser_was_active:
			_on_laser_active_true(my_laser_animation)
		elif not _local_laser_active and _local_laser_was_active:
			_on_laser_active_false(my_laser_animation)
		elif _local_laser_active:
			_on_laser_active_hold(my_laser_animation)
		else:
			_on_laser_inactive(my_laser_animation)

		if _laser_active:
			_check_target_hits()
			_update_laser_line()
		else:
			_clear_laser_line()
			_reset_laser_collision()

		if multiplayer.is_server() and not _targets.is_empty():
			_update_asteroid_timer(delta)
			if _all_targets_completed():
				_complete_asteroid()
			elif asteroid_time_remaining <= 0.0:
				_miss_asteroid()

		_round_flash = maxf(0.0, _round_flash - delta * 2.0)

		# rendering: handled by clients
		_update_hud()
		queue_redraw()
		_aim_overlay.queue_redraw()
	elif game_state == GameState.Paused:
		# Handle paused state logic
		pass
	elif game_state == GameState.Ended:
		game_end()
		pass


func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.Ended:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		_request_pause_toggle.rpc_id(1)
		get_viewport().set_input_as_handled()


func _on_pause_resume_requested() -> void:
	_request_pause_toggle.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_pause_toggle() -> void:
	if not multiplayer.is_server():
		return

	_set_pause_state.rpc(game_state != GameState.Paused)


@rpc("authority", "call_local", "reliable")
func _set_pause_state(paused: bool) -> void:
	if game_state == GameState.Ended:
		return

	game_state = GameState.Paused if paused else GameState.Playing
	_pause_menu.set_pause_visible(paused)

	if paused:
		_laser_active = false
		_clear_laser_line()
		_reset_laser_collision()
		GameManager._active_laser_peers.clear()

	queue_redraw()
	_aim_overlay.queue_redraw()


#region gamelogic
@rpc("authority", "call_local", "reliable")
func _new_asteroid_round() -> void:
	_clear_laser_line()
	sync_end_asteroid_round.rpc()
	# _asteroid.visible = false
	_asteroid_animation.visible = false
	# hide targets
	
	_reset_targets()

	var sprite_frames = _asteroid_animation.sprite_frames
	asteroid_anim_name = ASTEROID_FLYIN_ANIMATIONS[asteroid_variant]
	
	var total_frames = sprite_frames.get_frame_count(asteroid_anim_name)
	var total_time = total_frames / sprite_frames.get_animation_speed(asteroid_anim_name)


	await get_tree().create_timer(total_time + 0.25).timeout
	
	
	# _asteroid.visible = false
	_asteroid_animation.visible = true
	sync_new_asteroid_round.rpc()


# target logic: handle as server
func _reset_targets() -> void:
	if not multiplayer.is_server():
		return

	
	_randomize_asteroid()
	_randomize_target_positions()
	completed_targets = 0
	asteroid_time_remaining = ASTEROID_TIME_LIMIT
	_reset_laser_collision()
	for target in _targets:
		_set_target_completed(target, false)


func _update_asteroid_timer(delta: float) -> void:
	if not multiplayer.is_server():
		return

	asteroid_time_remaining = maxf(0.0, asteroid_time_remaining - delta)


func _complete_asteroid() -> void:
	print("asteroid completed!")
	_clear_laser_line()
	sync_end_asteroid_round.rpc()
	# TODO: play asteroid explosion effects
		# determine which asteroid it is
		# play corresponding animation
		# play sound effect

	# compute animation stuff
	
	asteroid_anim_name = ASTEROID_EXPLODE_ANIMATIONS[asteroid_variant]
	var cur_sprite_frames = _asteroid_animation.sprite_frames

	var frame_count = cur_sprite_frames.get_frame_count(asteroid_anim_name)
	

	var texture_size: Vector2 = cur_sprite_frames.get_frame_texture(asteroid_anim_name, frame_count - 1).get_size()
	scale_factor = asteroid_width / texture_size.x

	
	var sprite_frames = _asteroid_animation.sprite_frames

	var total_frames = sprite_frames.get_frame_count(asteroid_anim_name)
	var total_time = total_frames / sprite_frames.get_animation_speed(asteroid_anim_name)
	_asteroid_animation.scale = Vector2.ONE * scale_factor * 2
	_asteroid_animation.play(asteroid_anim_name)

	
	await get_tree().create_timer(total_time).timeout

	sync_asteroid_explode.rpc(asteroid_variant, asteroid_width)
	# TODO: play explode animation
	_asteroid_animation.visible = false
	await get_tree().create_timer(1).timeout

	set_process(true)

	if multiplayer.is_server():
		score += 1
		energy = MAX_ENERGY
		_round_flash = 1.0

		_new_asteroid_round()


func _miss_asteroid() -> void:
	_clear_laser_line()
	# for target in _targets:
	# 	target.visible = false
	# set_process(false)
	sync_end_asteroid_round.rpc()
	var animation_length = 0.5
	await get_tree().create_timer(animation_length).timeout
	print("asteroid missed!")
	# TODO: play asteroid miss effects?
	# set_process(true)
	
	if multiplayer.is_server():
		missed_asteroids += 1
		score = maxi(0, score - 1)
		energy = MAX_ENERGY - ASTEROID_MISS_ENERGY_PENALTY
		_round_flash = 1.0

		_new_asteroid_round()

# server only
func _randomize_asteroid() -> void:
	if not multiplayer.is_server():
		return

	var next_variant: int = randi_range(0, ASTEROID_FLYIN_ANIMATIONS.size() - 1)
	if ASTEROID_FLYIN_ANIMATIONS.size() > 1 and next_variant == asteroid_variant:
		next_variant = (next_variant + randi_range(1, ASTEROID_FLYIN_ANIMATIONS.size() - 1)) % ASTEROID_FLYIN_ANIMATIONS.size()

	asteroid_variant = next_variant
	asteroid_width = randf_range(ASTEROID_WIDTH_MIN, ASTEROID_WIDTH_MAX)

	# var texture: Texture2D = ASTEROID_TEXTURES[asteroid_variant]

	asteroid_anim_name = ASTEROID_FLYIN_ANIMATIONS[asteroid_variant]
	var cur_sprite_frames = _asteroid_animation.sprite_frames

	var frame_count = cur_sprite_frames.get_frame_count(asteroid_anim_name)
	

	var texture_size: Vector2 = cur_sprite_frames.get_frame_texture(asteroid_anim_name, frame_count - 1).get_size()


	scale_factor = asteroid_width / texture_size.x

	var display_size: Vector2 = texture_size * scale_factor
	var minimum_position: Vector2 = Vector2(
		display_size.x * 0.5 + TARGET_SPAWN_MARGIN,
		display_size.y * 0.5 + TARGET_SPAWN_TOP
	)
	var maximum_position: Vector2 = Vector2(
		VIEW_SIZE.x - display_size.x * 0.5 - TARGET_SPAWN_MARGIN,
		VIEW_SIZE.y - display_size.y * 0.5 - TARGET_SPAWN_MARGIN
	)

	asteroid_position = Vector2(
		randf_range(minimum_position.x, maximum_position.x),
		randf_range(minimum_position.y, maximum_position.y)
	)

	
	_asteroid_visual_initialized = true
	_last_asteroid_variant = asteroid_variant
	_last_asteroid_position = asteroid_position
	_last_asteroid_width = asteroid_width

	synced_asteroid_flyin.rpc(next_variant, asteroid_position, asteroid_width)


@rpc("authority", "call_local", "reliable")
func synced_asteroid_flyin(variant: int, pos: Vector2, width: float) -> void:
	asteroid_variant = variant
	asteroid_position = pos
	asteroid_width = width

	asteroid_anim_name = ASTEROID_FLYIN_ANIMATIONS[asteroid_variant]
	var cur_sprite_frames = _asteroid_animation.sprite_frames
	var frame_count = cur_sprite_frames.get_frame_count(asteroid_anim_name)
	var texture_size: Vector2 = cur_sprite_frames.get_frame_texture(asteroid_anim_name, frame_count - 1).get_size()
	print("texture size: " + str(texture_size))
	scale_factor = asteroid_width / texture_size.x

	_asteroid_animation.position = asteroid_position
	_asteroid_animation.scale = Vector2.ONE * scale_factor * 2
	_asteroid_animation.visible = true
	_asteroid_animation.play(asteroid_anim_name)
	pass

#handle visual effects of an asteroid round ending
# and handle process
@rpc("authority", "call_local", "reliable")
func sync_end_asteroid_round():
	for target in _targets:
		target.visible = false
	set_process(false)

	pass
@rpc("authority", "call_local", "reliable")
func sync_new_asteroid_round():
	for target in _targets:
		target.visible = true
	set_process(true)

@rpc("authority", "call_local", "reliable")
func sync_asteroid_explode(variant: int, width: float) -> void:
	asteroid_anim_name = ASTEROID_EXPLODE_ANIMATIONS[variant]
	var cur_sprite_frames = _asteroid_animation.sprite_frames
	var frame_count = cur_sprite_frames.get_frame_count(asteroid_anim_name)
	var texture_size: Vector2 = cur_sprite_frames.get_frame_texture(asteroid_anim_name, frame_count - 1).get_size()
	print("texture size: " + str(texture_size))
	scale_factor = width / texture_size.x

	_asteroid_animation.scale = Vector2.ONE * scale_factor * 2
	_asteroid_animation.play(asteroid_anim_name)
	explosion_sound.play()
	pass

# server only
func _randomize_target_positions() -> void:
	if not multiplayer.is_server():
		return

	var candidates: Array[Vector2] = _build_asteroid_target_candidates()
	var placed_positions: Array[Vector2] = []

	if candidates.size() < TARGET_COUNT:
		push_error("The selected asteroid does not have enough safe target positions.")
		return

	for target in _targets:
		var selected_position: Vector2 = Vector2.ZERO
		var found_position: bool = false

		for candidate in candidates:
			if _is_position_clear(candidate, placed_positions):
				selected_position = candidate
				found_position = true
				break

		# The HUD check is optional, but spacing and asteroid containment are not.
		if not found_position:
			for candidate in candidates:
				if _is_position_spaced(candidate, placed_positions):
					selected_position = candidate
					found_position = true
					break

		if not found_position:
			push_error("Could not place all targets on the selected asteroid.")
			return

		target.position = selected_position
		placed_positions.append(selected_position)
		candidates.erase(selected_position)


func _build_asteroid_target_candidates() -> Array[Vector2]:
	var candidates: Array[Vector2] = []
	# var image: Image = _asteroid.texture.get_image()

	# animation

	var cur_sprite_frames = _asteroid_animation.sprite_frames
	
	asteroid_anim_name = ASTEROID_FLYIN_ANIMATIONS[asteroid_variant]
	print("using animation " + str(asteroid_anim_name))
	var frame_count = cur_sprite_frames.get_frame_count(asteroid_anim_name)
	var image = cur_sprite_frames.get_frame_texture(asteroid_anim_name, frame_count - 1).get_image()

	if image == null or image.is_empty():
		return candidates

	var asteroid_scale: float = maxf(absf(_asteroid_animation.scale.x), 0.001)
	var radius_in_pixels: float = TARGET_PLACEMENT_RADIUS / asteroid_scale
	var scan_step: int = maxi(8, floori(radius_in_pixels * 0.7))
	var scan_margin: int = ceili(radius_in_pixels)
	var image_size: Vector2 = Vector2(image.get_width(), image.get_height())

	for y in range(scan_margin, image.get_height() - scan_margin, scan_step):
		for x in range(scan_margin, image.get_width() - scan_margin, scan_step):
			var pixel_position: Vector2 = Vector2(x, y)
			if not _is_opaque_target_area(image, pixel_position, radius_in_pixels):
				continue

			var asteroid_local_position: Vector2 = pixel_position - image_size * 0.5
			candidates.append(_asteroid_animation.to_global(asteroid_local_position))

	candidates.shuffle()
	print("found %d candidates", candidates.size())
	return candidates


func _is_opaque_target_area(image: Image, center: Vector2, radius: float) -> bool:
	if not _is_opaque_asteroid_pixel(image, center):
		return false

	for radius_ratio in [0.45, 0.75, 1.0]:
		for sample_index in range(TARGET_ALPHA_SAMPLE_COUNT):
			var angle: float = TAU * float(sample_index) / float(TARGET_ALPHA_SAMPLE_COUNT)
			var sample_position: Vector2 = center + Vector2.from_angle(angle) * radius * radius_ratio
			if not _is_opaque_asteroid_pixel(image, sample_position):
				return false

	return true


func _is_opaque_asteroid_pixel(image: Image, pixel_position: Vector2) -> bool:
	var pixel_x: int = roundi(pixel_position.x)
	var pixel_y: int = roundi(pixel_position.y)
	if pixel_x < 0 or pixel_y < 0 or pixel_x >= image.get_width() or pixel_y >= image.get_height():
		return false

	return image.get_pixel(pixel_x, pixel_y).a >= TARGET_ALPHA_THRESHOLD

# server only
func _is_position_clear(candidate: Vector2, placed_positions: Array[Vector2]) -> bool:
	var screen_size: Vector2 = get_viewport_rect().size
	var candidate_screen_position: Vector2 = candidate - _cursor.position + screen_size * 0.5
	if _energy_display.get_global_rect().grow(TARGET_SPAWN_MARGIN).has_point(candidate_screen_position):
		return false

	return _is_position_spaced(candidate, placed_positions)


func _is_position_spaced(candidate: Vector2, placed_positions: Array[Vector2]) -> bool:
	for placed_position in placed_positions:
		if candidate.distance_to(placed_position) < TARGET_MINIMUM_SPACING:
			return false
	return true


# server only?
func _clear_laser_line() -> void:
	if _current_line == null:
		return

	_current_line.queue_free()
	_current_line = null


func _reset_laser_collision() -> void:
	_has_last_laser_collision_position = false

# server only
func _check_target_hits() -> void:
	if not multiplayer.is_server():
		return

	for target in _targets:
		if _is_target_completed(target):
			continue

		if _laser_hits_target(target):
			_set_target_completed(target, true)

	_last_laser_collision_position = _cursor_position
	_has_last_laser_collision_position = true


func _laser_hits_target(target: Area2D) -> bool:
	var target_radius: float = _get_target_radius(target)
	var hit_radius: float = LASER_RADIUS + target_radius
	var target_position: Vector2 = target.global_position

	if _cursor_position.distance_to(target_position) <= hit_radius:
		return true

	if not _has_last_laser_collision_position:
		return false

	return _distance_to_segment(target_position, _last_laser_collision_position, _cursor_position) <= hit_radius


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment: Vector2 = segment_end - segment_start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared == 0.0:
		return point.distance_to(segment_start)

	var progress: float = clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point: Vector2 = segment_start + segment * progress
	return point.distance_to(closest_point)

# server only
func _all_targets_completed() -> bool:
	if not multiplayer.is_server():
		return false
	for target in _targets:
		if not _is_target_completed(target):
			return false
	return true

# server only
func _is_target_completed(target: Area2D) -> bool:
	if not multiplayer.is_server():
		return false
	return bool(target.get_meta("completed", false))

# server only
func _set_target_completed(target: Area2D, completed: bool) -> void:
	if not multiplayer.is_server():
		return
	target.set_meta("completed", completed)

	var fill: Polygon2D = target.get_node_or_null("Fill") as Polygon2D
	var glow: Polygon2D = target.get_node_or_null("Glow") as Polygon2D
	var ring: Line2D = target.get_node_or_null("Ring") as Line2D

	if fill != null:
		fill.color = TARGET_DONE_FILL if completed else TARGET_RED_FILL
	if glow != null:
		glow.color = TARGET_DONE_GLOW if completed else TARGET_RED_GLOW
	if ring != null:
		ring.default_color = TARGET_DONE_RING if completed else TARGET_RED_RING

	completed_targets += 1 if completed else 0

# server only
func _get_target_radius(target: Area2D) -> float:
	for child in target.get_children():
		var collision_shape: CollisionShape2D = child as CollisionShape2D
		if collision_shape == null:
			continue

		var circle: CircleShape2D = collision_shape.shape as CircleShape2D
		if circle != null:
			return circle.radius * maxf(target.global_scale.x, target.global_scale.y)

	return 22.0

# handle for each client
# need to get score from server though
@rpc("any_peer", "call_local")
func _update_hud() -> void:
	_score_label.text = "Score: %d" % score
	_target_label.text = "Targets: %d/%d" % [completed_targets, TARGET_COUNT]
	_timer_label.text = "Asteroid: %.1fs" % asteroid_time_remaining
	_miss_label.text = "Missed: %d" % missed_asteroids
	_energy_display.set_energy(energy, MAX_ENERGY)


@rpc("any_peer", "call_local")
func game_end() -> void:
		# send all clients back to main menu
	set_process(false)
	set_physics_process(false)
	GameManager.clear_game_state()
	print("Game manager state: " + str(GameManager.game_in_progress))
	

	# handle things as the server
	if multiplayer.is_server():
		disconnect_all_players()
		if DisplayServer.get_name() == "headless":
			print("Dedicated server: freeing level...")
			queue_free()
		else:
			print("Host-client server: returning to menu...")
			back_to_menu()
			queue_free()
	else:
		back_to_menu()

	pass

func back_to_menu() -> void:
	print("Going back to menu...")
	queue_redraw()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	# TODO: Implement menu navigation
	# disable the Level node
	# re-enable (or re-create) menu node
	var menu = get_tree().root.get_node_or_null("Control")
	if menu:
		print("Found valid menu!")
		menu.visible = true
		menu.process_mode = Node.PROCESS_MODE_INHERIT
		# Force a visual reset on the buttons

		if menu.has_method("init_menu"):
			menu.init_menu()
	else:
		# Fallback if the menu was somehow lost
		print("Menu not found, instantiate new one...")
		var menu_scene: PackedScene = load(MENU_SCENE_PATH)
		var new_menu = menu_scene.instantiate()
		get_tree().root.add_child(new_menu)
	pass

func disconnect_all_players() -> void:
	if not multiplayer.is_server():
		return

	for player in multiplayer.get_peers():
		multiplayer.disconnect_peer(player)

func player_disconnected(id):
	GameManager.Players.erase(id)
	GameManager.player_ids.erase(id)
	print("Player disconnected: %d" % id)

	#TODO: restart server game state if all players disconnected

	if GameManager.Players.size() == 0:
		print("All players disconnected, returning to menu...")
		back_to_menu()
	else:
		print("Remaining players: %s" % str(GameManager.Players.keys()))
		updated_roles = false
		assign_controls() # reassign controls if a player disconnects
	pass

#endregion

#region Game Over
# Trigger this function on the server when the lose condition is met
func check_game_over():
	# Ensure only the server (Peer ID 1) runs this check
	if multiplayer.is_server():
		game_state = GameState.Ended
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		trigger_game_over.rpc()

@rpc("authority", "call_local", "reliable")
func trigger_game_over() -> void:
	# Disable the gameplay camera and scene processing before swapping to the game-over screen.
	if is_instance_valid(self):
		_disable_gameplay_cameras(self)
		process_mode = Node.PROCESS_MODE_DISABLED

		for child in get_children():
			if child is Node:
				if child is Sprite2D or child is CanvasLayer:
					child.visible = false
				child.process_mode = Node.PROCESS_MODE_DISABLED

	get_tree().change_scene_to_file(GAME_OVER_PATH)

func _disable_gameplay_cameras(node: Node) -> void:
	for child in node.get_children():
		if child is Camera2D:
			child.enabled = false
		child.process_mode = Node.PROCESS_MODE_DISABLED
		_disable_gameplay_cameras(child)

#endregion

#region rendering
# rendering: handled by clients
func _draw() -> void:
	if game_state == GameState.Ended:
		return
	if _cursor == null:
		return

	# var screen_size: Vector2 = get_viewport_rect().size
	# var visible_rect: Rect2 = Rect2(_cursor.position - screen_size * 0.5, screen_size)
	# draw_rect(visible_rect, Color.BLACK, true)
	# draw_texture_rect(STAR_BACKGROUND_TEXTURE, visible_rect, false)


func _draw_aim_overlay() -> void:
	if game_state != GameState.Playing:
		return
	if not is_instance_valid(_cursor):
		return

	_draw_laser()
	_draw_offscreen_target_bubbles()
	_draw_cursor_box()

func _update_laser_line() -> void:
	# Safe guard against freed cursor
	if not is_instance_valid(_cursor):
		return

	if _current_line == null:
		_current_line = Line2D.new()
		if multiplayer.get_unique_id() == GameManager.player1:
			_current_line.default_color = Color.DODGER_BLUE
		elif multiplayer.get_unique_id() == GameManager.player2:
			_current_line.default_color = Color.RED
		_current_line.width = 10.0
		_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_lines.add_child(_current_line)
		_current_line.add_point(_cursor.position)
		return

	var last_point_index: int = _current_line.get_point_count() - 1
	var last_point: Vector2 = _current_line.get_point_position(last_point_index)
	if last_point.distance_to(_cursor.position) >= LINE_POINT_MIN_DISTANCE:
		_current_line.add_point(_cursor.position)

# rendering: handled by clients
func _draw_grid() -> void:
	var grid_color: Color = Color(0.12, 0.19, 0.25, 0.28)
	var start: Vector2 = Vector2(-BACKGROUND_PADDING, -BACKGROUND_PADDING)
	var end: Vector2 = VIEW_SIZE + Vector2(BACKGROUND_PADDING, BACKGROUND_PADDING)

	for x in range(int(start.x), int(end.x) + 1, 40):
		draw_line(Vector2(x, start.y), Vector2(x, end.y), grid_color, 1.0)
	for y in range(int(start.y), int(end.y) + 1, 40):
		draw_line(Vector2(start.x, y), Vector2(end.x, y), grid_color, 1.0)

# rendering: handled by clients
func _draw_laser() -> void:
	if not _laser_active:
		return

	_aim_overlay.draw_circle(_cursor.position, LASER_RADIUS, Color(0.26, 0.86, 1.0, 0.16))
	_aim_overlay.draw_arc(_cursor.position, LASER_RADIUS, 0.0, TAU, 48, Color(0.26, 0.86, 1.0, 0.85), 3.0)
	_aim_overlay.draw_line(Vector2(_cursor.position.x - LASER_RADIUS, _cursor.position.y), Vector2(_cursor.position.x + LASER_RADIUS, _cursor.position.y), Color(0.86, 0.96, 1.0, 0.65), 2.0)
	_aim_overlay.draw_line(Vector2(_cursor.position.x, _cursor.position.y - LASER_RADIUS), Vector2(_cursor.position.x, _cursor.position.y + LASER_RADIUS), Color(0.86, 0.96, 1.0, 0.65), 2.0)

	if _round_flash > 0.0:
		_aim_overlay.draw_arc(_cursor.position, 95.0 + 20.0 * _round_flash, 0.0, TAU, 64, Color(0.24, 1.0, 0.66, _round_flash), 5.0)

# rendering: handled by clients
func _draw_offscreen_target_bubbles() -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	var visible_rect: Rect2 = Rect2(_cursor.position - screen_size * 0.5, screen_size)
	var bubble_rect: Rect2 = visible_rect.grow(-OFFSCREEN_BUBBLE_EDGE_MARGIN)

	for target in _targets:
		if _is_target_completed_for_display(target):
			continue

		var target_position: Vector2 = target.global_position
		var target_radius: float = _get_target_radius(target)
		if visible_rect.grow(target_radius).has_point(target_position):
			continue

		var bubble_position: Vector2 = Vector2(
			clampf(target_position.x, bubble_rect.position.x, bubble_rect.position.x + bubble_rect.size.x),
			clampf(target_position.y, bubble_rect.position.y, bubble_rect.position.y + bubble_rect.size.y)
		)
		var target_direction: Vector2 = (target_position - bubble_position).normalized()

		_aim_overlay.draw_circle(bubble_position, OFFSCREEN_BUBBLE_RADIUS + 8.0, TARGET_RED_GLOW)
		_aim_overlay.draw_circle(bubble_position, OFFSCREEN_BUBBLE_RADIUS, Color(1.0, 0.18, 0.22, 0.34))
		_aim_overlay.draw_arc(bubble_position, OFFSCREEN_BUBBLE_RADIUS, 0.0, TAU, 32, TARGET_RED_RING, 2.5)
		_aim_overlay.draw_line(
			bubble_position,
			bubble_position + target_direction * (OFFSCREEN_BUBBLE_RADIUS - 5.0),
			Color(1.0, 0.84, 0.78, 0.9),
			3.0
		)

func _is_target_completed_for_display(target: Area2D) -> bool:
	if bool(target.get_meta("completed", false)):
		return true

	var fill: Polygon2D = target.get_node_or_null("Fill") as Polygon2D
	return fill != null and fill.color == TARGET_DONE_FILL

func _update_cockpit_frame() -> void:
	var my_id: int = multiplayer.get_unique_id()
	if my_id == GameManager.player2 and my_id != GameManager.player1:
		_cockpit_frame.texture = PLAYER_2_COCKPIT_TEXTURE
	else:
		_cockpit_frame.texture = PLAYER_1_COCKPIT_TEXTURE

# rendering: handled by clients
func _draw_cursor_box() -> void:
	var box_size: Vector2 = Vector2(CURSOR_BOX_SIZE, CURSOR_BOX_SIZE)
	var box: Rect2 = Rect2(_cursor.position - box_size * 0.5, box_size)
	var fill_color: Color = Color(0.24, 1.0, 0.74, 0.14)
	var line_color: Color = Color(0.24, 1.0, 0.74, 1.0)

	_aim_overlay.draw_rect(box, fill_color, true)
	_aim_overlay.draw_rect(box, line_color, false, 2.0)

func _on_target_spawned(node: Node) -> void:
	var target = node as Area2D
	if target and not _targets.has(target):
		_targets.append(target)
#endregion

#region input
# input: handled by clients
@rpc("any_peer", "call_local", "unreliable")
func _move_cursor(delta: float) -> void:
	if _cursor == null:
		return
	var movement: Vector2 = Vector2.ZERO

	var my_id = multiplayer.get_unique_id()

	# player 1: horizontal input
	if my_id == GameManager.player1:
		movement.x = Input.get_axis("move_left", "move_right")
	if my_id == GameManager.player2:
		movement.y = Input.get_axis("move_up", "move_down")

	if not updated_roles and clientLabel != null:
		if GameManager.player1 != 0 and GameManager.player2 != 0: # if I don't do this, then there is a race condition where player1/player2 aren't initialized
			if GameManager.player1 != GameManager.player2:
				if my_id == GameManager.player1:
					clientLabel.text = "Player 1: horizontal controls"
				elif my_id == GameManager.player2:
					clientLabel.text = "Player 2: vertical controls"
				else:
					clientLabel.text = "Controls not assigned"
			else:
				if my_id == GameManager.player1:
					clientLabel.text = "Player 1: horizontal and vertical controls"
				else:
					clientLabel.text = "Controls not assigned"
			updated_roles = true

	if movement == Vector2.ZERO or energy <= 0.0:
		if energy <= 0.0:
			_miss_asteroid()
		return

	
	_request_movement.rpc(movement, delta)

# set controls based on multiplayer ids in game_manager
func assign_controls() -> void:
	print("attempting to assign controls")
	if not multiplayer.is_server():
		print("Only the server can handle authority...")
		return

	var player_count = GameManager.Players.size()

	match player_count:
		1:
			# singleplayer mode; assign both control schemes to 
			# the player
			GameManager.sync_controls.rpc(GameManager.player_ids[0], GameManager.player_ids[0])
			print("There is exactly one player, who will control both horizontal and vertical axes.")
			print("Player 1: " + str(GameManager.player1) + "; Player 2: " + str(GameManager.player2))

			pass
		2:
			# First connected player controls horizontal movement.
			# Second connected player controls vertical movement.
			var first_joined_player: int = GameManager.player_ids[player_count - 1]
			var second_joined_player: int = GameManager.player_ids[player_count - 2]
			GameManager.sync_controls.rpc(first_joined_player, second_joined_player)
			print("Player 1: " + str(GameManager.player1) + "; Player 2: " + str(GameManager.player2))
			pass
		_:
			print("Unexpected number of players (%d); shutting game down..." % player_count)
			pass

	pass
	

# move cursor based on input from client
@rpc("any_peer", "call_local", "unreliable")
func _request_movement(movement: Vector2, delta: float) -> void:
	if not multiplayer.is_server():
		return
	

	var next_position: Vector2 = _cursor.position + movement.normalized() * CURSOR_SPEED * delta
	next_position.x = clampf(next_position.x, CURSOR_BOX_SIZE * 0.5, VIEW_SIZE.x - CURSOR_BOX_SIZE * 0.5)
	next_position.y = clampf(next_position.y, CURSOR_BOX_SIZE * 0.5, VIEW_SIZE.y - CURSOR_BOX_SIZE * 0.5)

	if next_position == _cursor.position:
		return
	
	energy = maxf(0.0, energy - ENERGY_DRAIN_PER_SECOND * delta)
	_cursor.position = next_position
	_cursor_position = _cursor.position
	pass


@rpc("any_peer", "call_local", "unreliable")
func request_laser_state(pressed: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	GameManager._active_laser_peers[sender_id] = pressed
	sync_laser_active.rpc(sender_id, pressed)

		
@rpc("authority", "call_local", "unreliable")
func sync_laser_active(peer_id: int, active: bool) -> void:
	GameManager._active_laser_peers[peer_id] = active
	# check if any player is firing
	var any_active = false
	for pid in GameManager._active_laser_peers:
		if GameManager._active_laser_peers[pid] == true:
			any_active = true
			break

	_laser_active = any_active
#endregion


#region Laser Animations
func _get_laser1_animation_node() -> AnimatedSprite2D:
	for i in range(_cursor.get_child_count()):
		var child = _cursor.get_child(i)
		if child.name == "Camera2D":
			for grandchild in child.get_children():
				if grandchild.name == "Laser1" and grandchild is AnimatedSprite2D:
					return grandchild as AnimatedSprite2D

	return null

func _get_laser2_animation_node() -> AnimatedSprite2D:
	for i in range(_cursor.get_child_count()):
		var child = _cursor.get_child(i)
		if child.name == "Camera2D":
			for grandchild in child.get_children():
				if grandchild.name == "Laser2" and grandchild is AnimatedSprite2D:
					return grandchild as AnimatedSprite2D

	return null

func _get_player_laser_animation() -> AnimatedSprite2D:
	if not is_instance_valid(_cursor):
		return null

	var my_id = multiplayer.get_unique_id()
	if my_id == GameManager.player1:
		if laser_animation_1 == null or not is_instance_valid(laser_animation_1):
			laser_animation_1 = _get_laser1_animation_node()
		return laser_animation_1
	elif my_id == GameManager.player2:
		if laser_animation_2 == null or not is_instance_valid(laser_animation_2):
			laser_animation_2 = _get_laser2_animation_node()
		return laser_animation_2

	return null

func _on_laser_active_true(laser_animation: AnimatedSprite2D) -> void:
	if laser_animation == null or not is_instance_valid(laser_animation):
		return
	laser_animation.visible = true
	laser_animation.stop()
	laser_animation.frame = 0
	laser_animation.play("laser_start")

func _on_laser_active_hold(laser_animation: AnimatedSprite2D) -> void:
	if laser_animation == null or not is_instance_valid(laser_animation):
		return
	if laser_animation.animation == "laser_start" and laser_animation.is_playing():
		return
	laser_animation.visible = true
	if laser_animation.animation != "laser_held":
		laser_animation.stop()
		laser_animation.frame = 0
		laser_animation.play("laser_held")


func _on_laser_active_false(laser_animation: AnimatedSprite2D) -> void:
	if laser_animation == null or not is_instance_valid(laser_animation):
		return
	laser_animation.visible = true
	laser_animation.stop()
	laser_animation.frame = 0
	laser_animation.play("laser_end")


func _on_laser_inactive(laser_animation: AnimatedSprite2D) -> void:
	if laser_animation == null or not is_instance_valid(laser_animation):
		return
	if not laser_animation.is_playing():
		laser_animation.visible = false

#endregion
