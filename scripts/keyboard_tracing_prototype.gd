extends Node2D

#region constants
const TARGET_SCENE = preload("res://scenes/target_circle.tscn")
const CURSOR_SCENE = preload("res://scenes/cursor.tscn")
const MENU_SCENE_PATH = "res://scenes/control.tscn"
const STAR_BACKGROUND_TEXTURE = preload("res://assets/stars_final.png")
const PLAYER_1_COCKPIT_TEXTURE = preload("res://assets/cockpit_player_1.png")
const PLAYER_2_COCKPIT_TEXTURE = preload("res://assets/cockpit_player_2.png")

const VIEW_SIZE = Vector2(2400, 1350)
const BACKGROUND_PADDING = 1600.0
const CURSOR_BOX_SIZE = 36.0
const CURSOR_SPEED = 520.0
const LASER_RADIUS = 30.0
const LINE_POINT_MIN_DISTANCE = 4.0
const MAX_ENERGY = 100.0
const ENERGY_DRAIN_PER_SECOND = 10.0
const ASTEROID_TIME_LIMIT = 20.0
const ASTEROID_MISS_ENERGY_PENALTY = 25.0


# target-related constants
const TARGET_COUNT = 5
const TARGET_SPAWN_MARGIN = 55.0
const TARGET_SPAWN_TOP = 130.0
const TARGET_MINIMUM_SPACING = 100.0
const TARGET_SPAWN_ATTEMPTS = 50
const OFFSCREEN_BUBBLE_EDGE_MARGIN = 56.0
const OFFSCREEN_BUBBLE_RADIUS = 17.0
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
var _laser_active: bool = false
var _round_flash: float = 0.0
var _targets: Array[Area2D] = []
var _current_line: Line2D = null
var _last_laser_collision_position: Vector2 = Vector2.ZERO
var _has_last_laser_collision_position: bool = false

var updated_roles = false # this is to check if controls have been properly assigned

var game_state: GameState = GameState.Playing

#region onready_vars
@onready var _targets_root: Node2D = $Targets
@onready var _lines: Node2D = $LaserLines
# @onready var _camera: Camera2D = $Camera2D
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _target_label: Label = $HUD/TargetLabel
@onready var _timer_label: Label = $HUD/TimerLabel
@onready var _miss_label: Label = $HUD/MissLabel
@onready var _energy_display: EnergyDisplay = $HUD/EnergyDisplay
@onready var _cockpit_frame: TextureRect = $HUD/CockpitFrame
@onready var clientLabel: Label = $HUD/ClientLabel

@onready var targets_spawner = $MultiplayerSpawner_targets
@onready var cursor_spawner = $MultiplayerSpawner_cursor
#endregion


func _ready() -> void:
	_update_hud()
	_update_cockpit_frame()
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

	if not is_instance_valid(_cursor):
		return

	if game_state == GameState.Playing:
		_update_cockpit_frame()

		# input: handled by clients
		_move_cursor(delta)

		# camera position: handled by server
		# _camera.position = _cursor_position

		var laser_pressed: bool = Input.is_action_pressed("fire_laser")
		request_laser_state.rpc(laser_pressed)

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
	elif game_state == GameState.Paused:
		# Handle paused state logic
		pass
	elif game_state == GameState.Ended:
		game_end()
		pass


#region gamelogic
func _new_asteroid_round() -> void:
	_reset_targets()
	_clear_laser_line()

	if multiplayer.is_server():
		# TODO: set a timer and wait for asteroid animation
		# to end
		return


# target logic: handle as server
func _reset_targets() -> void:
	if not multiplayer.is_server():
		return

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
	if not multiplayer.is_server():
		return

	score += 1
	energy = MAX_ENERGY
	_round_flash = 1.0

	_new_asteroid_round()
	

func _miss_asteroid() -> void:
	if not multiplayer.is_server():
		return

	missed_asteroids += 1
	score = maxi(0, score - 1)
	energy = maxf(0.0, energy - ASTEROID_MISS_ENERGY_PENALTY)
	_round_flash = 1.0

	_new_asteroid_round()

# server only
func _randomize_target_positions() -> void:
	if not multiplayer.is_server():
		return
	var placed_positions: Array[Vector2] = []

	for target in _targets:
		var new_position: Vector2 = target.position

		for attempt in range(TARGET_SPAWN_ATTEMPTS):
			new_position = Vector2(
				randf_range(TARGET_SPAWN_MARGIN, VIEW_SIZE.x - TARGET_SPAWN_MARGIN),
				randf_range(TARGET_SPAWN_TOP, VIEW_SIZE.y - TARGET_SPAWN_MARGIN)
			)

			if _is_position_clear(new_position, placed_positions):
				break

		target.position = new_position
		placed_positions.append(new_position)

# server only
func _is_position_clear(candidate: Vector2, placed_positions: Array[Vector2]) -> bool:
	var screen_size: Vector2 = get_viewport_rect().size
	var candidate_screen_position: Vector2 = candidate - _cursor.position + screen_size * 0.5
	if _energy_display.get_global_rect().grow(TARGET_SPAWN_MARGIN).has_point(candidate_screen_position):
		return false

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


#region rendering
# rendering: handled by clients
func _draw() -> void:
	if game_state != GameState.Playing:
		return
	if _cursor == null:
		return

	var screen_size: Vector2 = get_viewport_rect().size
	var visible_rect: Rect2 = Rect2(_cursor.position - screen_size * 0.5, screen_size)
	draw_rect(visible_rect, Color.BLACK, true)
	draw_texture_rect(STAR_BACKGROUND_TEXTURE, visible_rect, false)
	_draw_laser()
	_draw_offscreen_target_bubbles()
	_draw_cursor_box()

func _update_laser_line() -> void:
	# Safe guard against freed cursor
	if not is_instance_valid(_cursor):
		return

	if _current_line == null:
		_current_line = Line2D.new()
		_current_line.default_color = Color.AQUA
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

	draw_circle(_cursor.position, LASER_RADIUS, Color(0.26, 0.86, 1.0, 0.16))
	draw_arc(_cursor.position, LASER_RADIUS, 0.0, TAU, 48, Color(0.26, 0.86, 1.0, 0.85), 3.0)
	draw_line(Vector2(_cursor.position.x - LASER_RADIUS, _cursor.position.y), Vector2(_cursor.position.x + LASER_RADIUS, _cursor.position.y), Color(0.86, 0.96, 1.0, 0.65), 2.0)
	draw_line(Vector2(_cursor.position.x, _cursor.position.y - LASER_RADIUS), Vector2(_cursor.position.x, _cursor.position.y + LASER_RADIUS), Color(0.86, 0.96, 1.0, 0.65), 2.0)

	if _round_flash > 0.0:
		draw_arc(_cursor.position, 95.0 + 20.0 * _round_flash, 0.0, TAU, 64, Color(0.24, 1.0, 0.66, _round_flash), 5.0)

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

		draw_circle(bubble_position, OFFSCREEN_BUBBLE_RADIUS + 8.0, TARGET_RED_GLOW)
		draw_circle(bubble_position, OFFSCREEN_BUBBLE_RADIUS, Color(1.0, 0.18, 0.22, 0.34))
		draw_arc(bubble_position, OFFSCREEN_BUBBLE_RADIUS, 0.0, TAU, 32, TARGET_RED_RING, 2.5)
		draw_line(
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

	draw_rect(box, fill_color, true)
	draw_rect(box, line_color, false, 2.0)

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
	
	# print("Game manager players: " + str(GameManager.player1) + "; " + str(GameManager.player2))
	
	# player 1: horizontal input
	if my_id == GameManager.player1:
		movement.x = Input.get_axis("move_left", "move_right")
	if my_id == GameManager.player2:
		movement.y = Input.get_axis("move_up", "move_down")

	if not updated_roles and clientLabel != null:
		if GameManager.player1 != 0 and GameManager.player2 != 0: # if I don't do this, then there is a race condition where player1/player2 aren't initialized
			if my_id == GameManager.player1:
				clientLabel.text = "Player 1: horizontal controls"
			elif my_id == GameManager.player2:
				clientLabel.text = "Player 2: vertical controls"
			else:
				clientLabel.text = "Controls not assigned"
			updated_roles = true

	if movement == Vector2.ZERO or energy <= 0.0:
		if energy <= 0.0:
			game_state = GameState.Ended
			set_process(false) # 👈 STOP PROCESS IMMEDIATELY to prevent loop spam!
			# this should trigger game ending
			game_end()
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

	var any_button_down: bool = false
	for peer_id in GameManager._active_laser_peers:
		if GameManager._active_laser_peers[peer_id] == true:
			any_button_down = true
			break

	if _laser_active != any_button_down:
		_laser_active = any_button_down
		sync_laser_active.rpc(any_button_down)


@rpc("authority", "call_local", "unreliable")
func sync_laser_active(active: bool) -> void:
	_laser_active = active
#endregion
