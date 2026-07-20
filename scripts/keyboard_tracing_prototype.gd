extends Node2D

#region constants
const TARGET_SCENE = preload("res://scenes/target_circle.tscn")
const CURSOR_SCENE = preload("res://scenes/cursor.tscn")
const MENU_SCENE = preload("res://scenes/control.tscn")

const VIEW_SIZE = Vector2(1920, 1080)
const CURSOR_BOX_SIZE = 36.0
const CURSOR_SPEED = 280.0
const LASER_RADIUS = 30.0
const LINE_POINT_MIN_DISTANCE = 4.0
const MAX_ENERGY = 100.0
const ENERGY_DRAIN_PER_SECOND = 10.0

# target-related constants
const TARGET_COUNT = 5
const TARGET_SPAWN_MARGIN = 55.0
const TARGET_SPAWN_TOP = 130.0
const TARGET_MINIMUM_SPACING = 100.0
const TARGET_SPAWN_ATTEMPTS = 50
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

@export var _cursor_position: Vector2 # tracked on the server...
@export var score: int = 0
@export var energy: float = MAX_ENERGY
@export var completed_targets: int = 0
var _laser_active: bool = false
var _laser_was_active: bool = false
var _laser_state: bool = false
var _laser_pressing: bool = false
var laser_animation: AnimatedSprite2D = null
var _round_flash: float = 0.0
var _targets: Array[Area2D] = []
var _current_line: Line2D = null
var children: Array[Node] = [] # this is to store the children of the cursor node

var updated_roles = false # this is to check if controls have been properly assigned

var game_state: GameState = GameState.Playing

#region onready_vars
@onready var _targets_root: Node2D = $Targets
@onready var _lines: Node2D = $LaserLines
# @onready var _camera: Camera2D = $Camera2D
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _target_label: Label = $HUD/TargetLabel
@onready var _energy_display: EnergyDisplay = $HUD/EnergyDisplay
@onready var clientLabel: Label = $HUD/ClientLabel

@onready var targets_spawner = $MultiplayerSpawner_targets
@onready var cursor_spawner = $MultiplayerSpawner_cursor
#endregion


func _ready() -> void:
	_update_hud()
	cursor_spawner.spawned.connect(connect_cursor)

	# handling things only the server should...
	if multiplayer.is_server():
		# assign_controls()
		# _camera.position = _cursor_position
		instantiate_targets()

		instantiate_cursor()
		_reset_targets()
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
	laser_animation = null
	call_deferred("_ensure_laser_animation")

# ensure that the laser animation node is valid and ready to use
func _ensure_laser_animation() -> void:
	if not is_instance_valid(_cursor):
		laser_animation = null
		return

	if laser_animation != null and is_instance_valid(laser_animation):
		return

	laser_animation = _get_laser_animation_node()
	if laser_animation != null:
		laser_animation.visible = false
		laser_animation.stop()

func _play_laser_animation(animation_name: String) -> void:
	_ensure_laser_animation()
	if laser_animation == null:
		return

	laser_animation.visible = true
	laser_animation.stop()
	laser_animation.play(animation_name)
	laser_animation.frame = 0

# get the laser animation node from the cursor node
func _get_laser_animation_node() -> AnimatedSprite2D:
	for i in range(_cursor.get_child_count()):
		var child = _cursor.get_child(i)
		if child.name == "Camera2D":
			for grandchild in child.get_children():
				if grandchild.name == "Laser" and grandchild is AnimatedSprite2D:
					return grandchild as AnimatedSprite2D

	return null


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
func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	if not is_instance_valid(_cursor):
		return

	if game_state == GameState.Playing:
		# input: handled by clients
		_move_cursor(delta)

		# camera position: handled by server
		# _camera.position = _cursor_position

		# game logic: handled by server
		# synchronize laser activation via the server so all clients see the same animation
		var local_pressing: bool = Input.is_key_pressed(KEY_SPACE)
		if local_pressing != _laser_pressing:
			_laser_pressing = local_pressing
			_request_laser_state.rpc(_laser_pressing)

		_laser_was_active = _laser_active
		_laser_active = _laser_state

		# handle laser animation state changes
		if _laser_active and not _laser_was_active:
			_on_laser_active_true()
		elif not _laser_active and _laser_was_active:
			_on_laser_active_false()
		elif _laser_active:
			_on_laser_active_hold()
		else:
			_on_laser_inactive()

		if _laser_active:
			_check_target_hits()
			_update_laser_line()
		else:
			_clear_laser_line()

		if not _targets.is_empty() and _all_targets_completed():
			score += 1
			energy = MAX_ENERGY
			_round_flash = 1.0
			_reset_targets()
			_clear_laser_line()

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
# target logic: handle as server
func _reset_targets() -> void:
	if not multiplayer.is_server():
		return

	_randomize_target_positions()
	completed_targets = 0
	for target in _targets:
		_set_target_completed(target, false)

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
	var candidate_screen_position: Vector2 = candidate - _cursor.position + VIEW_SIZE * 0.5
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

# server only
func _check_target_hits() -> void:
	if not multiplayer.is_server():
		return

	for target in _targets:
		if _is_target_completed(target):
			continue

		var target_radius: float = _get_target_radius(target)
		
		var distance_to_target: float = _cursor_position.distance_to(target.global_position)
		# print("checking target " + str(target.name) + " at position " + str(target.global_position) + "; distance: " + str(distance_to_target))
		if distance_to_target <= LASER_RADIUS + target_radius:
			_set_target_completed(target, true)

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
	print("target completed!")

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
		# GameManager.clear_game_state()
		# Check if this server is a headless dedicated server (like on Railway)
		if DisplayServer.get_name() == "headless":
			print("Dedicated server: freeing level...")
			queue_free() # Safely destroy the level node on the cloud machine
		else:
			print("Host-client server: returning to menu...")
			back_to_menu() # Local host-client needs to restore their menu!
			queue_free()
		
	else:
		back_to_menu()
		# clear game manager fields
		
	
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
		var new_menu = MENU_SCENE.instantiate()
		get_tree().root.add_child(new_menu)
	pass

func disconnect_all_players() -> void:
	if not multiplayer.is_server():
		return

	for player in multiplayer.get_peers():
		multiplayer.disconnect_peer(player)


#endregion


#region rendering
# rendering: handled by clients
func _draw() -> void:
	if game_state == GameState.Ended:
		return
	if _cursor == null:
		return
	_draw_laser()
	_draw_cursor_box()

func _update_laser_line() -> void:
	# Safe guard against freed cursor
	if not is_instance_valid(_cursor):
		return

	if _current_line == null:
		_current_line = Line2D.new()
		_current_line.default_color = Color.DODGER_BLUE
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
func _draw_cursor_box() -> void:
	var box_size: Vector2 = Vector2(CURSOR_BOX_SIZE, CURSOR_BOX_SIZE)
	var box: Rect2 = Rect2(_cursor.position - box_size * 0.5, box_size)
	var fill_color: Color = Color(0.24, 1.0, 0.74, 0.14)
	var line_color: Color = Color(0.24, 1.0, 0.74, 1.0)

	draw_rect(box, fill_color, true)
	draw_rect(box, line_color, false, 2.0)
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
		if Input.is_key_pressed(KEY_LEFT):
			movement.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			movement.x += 1.0
	if my_id == GameManager.player2:
		movement.y = Input.get_axis("move_up", "move_down")

	if not updated_roles and clientLabel != null:
		if GameManager.player1 != 0 and GameManager.player2 != 0: # if I don't do this, then there is a race condition where player1/player2 aren't initialized
			if my_id == GameManager.player1:
				clientLabel.text = clientLabel.text + "\n You are player 1! You handle horizontal controls!"
			elif my_id == GameManager.player2:
				clientLabel.text = clientLabel.text + "\n You are player 2! You handle vertical controls!"
			else:
				clientLabel.text = clientLabel.text + "\n You have not been assigned controls!"
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
			# 2 players...
			var value = randf()
			var p1: int
			var p2: int

			# randomly assign control schemes
			if value > 0.5:
				p1 = GameManager.player_ids[0]
				p2 = GameManager.player_ids[1]
				pass
			else:
				p2 = GameManager.player_ids[0]
				p1 = GameManager.player_ids[1]
				pass
			
			
			GameManager.sync_controls.rpc(p1, p2)
			print("Player 1: " + str(GameManager.player1) + "; Player 2: " + str(GameManager.player2))
			pass
		_:
			print("Unexpected number of players (%d); shutting game down..." % player_count)
			pass

	pass
	

# move cursor based on input from client
# TODO: fix this so that movement is always processed, but ONLY on the server;
# currently it only handles the movement if the host calls this function
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
	pass

# laser animation functions 
# activation: handled by clients, but synchronized via server
@rpc("any_peer", "call_local", "unreliable")
func _request_laser_state(active: bool) -> void:
	if not multiplayer.is_server():
		return
	_sync_laser_state.rpc(active)

@rpc("any_peer", "call_local", "unreliable")
func _sync_laser_state(active: bool) -> void:
	_laser_state = active

func _on_laser_active_true() -> void:
	_play_laser_animation("laser_start")

func _on_laser_active_hold() -> void:
	_ensure_laser_animation()
	if laser_animation == null:
		return
	if laser_animation.is_playing() and laser_animation.animation == "laser_start":
		return
	if laser_animation.animation != "laser_hold":
		_play_laser_animation("laser_hold")

func _on_laser_active_false() -> void:
	_play_laser_animation("laser_end")


func _on_laser_inactive() -> void:
	_ensure_laser_animation()
	if laser_animation == null:
		return
	if laser_animation.animation == "laser_end" and not laser_animation.is_playing():
		laser_animation.visible = false
