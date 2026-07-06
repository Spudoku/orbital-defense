extends Node2D

const VIEW_SIZE = Vector2(960, 640)
const CURSOR_BOX_SIZE = 36.0
const CURSOR_SPEED = 280.0
const LASER_RADIUS = 30.0
const LINE_POINT_MIN_DISTANCE = 4.0
const MAX_ENERGY = 100.0
const ENERGY_DRAIN_PER_SECOND = 15.0
const TARGET_SPAWN_MARGIN = 55.0
const TARGET_SPAWN_TOP = 130.0
const TARGET_MINIMUM_SPACING = 100.0
const TARGET_SPAWN_ATTEMPTS = 50
const TARGET_RED_FILL = Color(1.0, 0.18, 0.22, 0.9)
const TARGET_RED_GLOW = Color(1.0, 0.18, 0.22, 0.18)
const TARGET_RED_RING = Color(1.0, 0.55, 0.40, 0.75)
const TARGET_DONE_FILL = Color(0.24, 1.0, 0.66, 0.9)
const TARGET_DONE_GLOW = Color(0.24, 1.0, 0.66, 0.18)
const TARGET_DONE_RING = Color(0.86, 0.96, 1.0, 0.55)

var cursor_position: Vector2 = VIEW_SIZE * 0.5
var score: int = 0
var energy: float = MAX_ENERGY
var _laser_active: bool = false
var _round_flash: float = 0.0
var _targets: Array[Area2D] = []
var _current_line: Line2D = null

@onready var _targets_root: Node2D = $Targets
@onready var _lines: Node2D = $LaserLines
@onready var _camera: Camera2D = $Camera2D
@onready var _score_label: Label = $HUD/ScoreLabel
@onready var _target_label: Label = $HUD/TargetLabel
@onready var _energy_display: EnergyDisplay = $HUD/EnergyDisplay


func _ready() -> void:
	_camera.position = cursor_position
	_collect_targets()
	_reset_targets()
	_update_hud()


func _process(delta: float) -> void:
	_move_cursor(delta)
	_camera.position = cursor_position
	_laser_active = Input.is_key_pressed(KEY_SPACE)

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

	_round_flash = maxf(0.0, _round_flash - delta * 2.0)
	_update_hud()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.015, 0.018, 0.032), true)
	_draw_grid()
	_draw_laser()
	_draw_cursor_box()


func _move_cursor(delta: float) -> void:
	var movement: Vector2 = Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		movement.y += 1.0

	if movement == Vector2.ZERO or energy <= 0.0:
		return

	var next_position: Vector2 = cursor_position + movement.normalized() * CURSOR_SPEED * delta
	next_position.x = clampf(next_position.x, CURSOR_BOX_SIZE * 0.5, VIEW_SIZE.x - CURSOR_BOX_SIZE * 0.5)
	next_position.y = clampf(next_position.y, CURSOR_BOX_SIZE * 0.5, VIEW_SIZE.y - CURSOR_BOX_SIZE * 0.5)

	if next_position == cursor_position:
		return

	energy = maxf(0.0, energy - ENERGY_DRAIN_PER_SECOND * delta)
	cursor_position = next_position


func _collect_targets() -> void:
	_targets.clear()
	for child in _targets_root.get_children():
		var target: Area2D = child as Area2D
		if target != null:
			_targets.append(target)


func _reset_targets() -> void:
	_randomize_target_positions()
	for target in _targets:
		_set_target_completed(target, false)


func _randomize_target_positions() -> void:
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


func _is_position_clear(candidate: Vector2, placed_positions: Array[Vector2]) -> bool:
	var candidate_screen_position: Vector2 = candidate - _camera.position + VIEW_SIZE * 0.5
	if _energy_display.get_global_rect().grow(TARGET_SPAWN_MARGIN).has_point(candidate_screen_position):
		return false

	for placed_position in placed_positions:
		if candidate.distance_to(placed_position) < TARGET_MINIMUM_SPACING:
			return false
	return true


func _update_laser_line() -> void:
	if _current_line == null:
		_current_line = Line2D.new()
		_current_line.default_color = Color.AQUA
		_current_line.width = 10.0
		_current_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_current_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_lines.add_child(_current_line)
		_current_line.add_point(cursor_position)
		return

	var last_point_index: int = _current_line.get_point_count() - 1
	var last_point: Vector2 = _current_line.get_point_position(last_point_index)
	if last_point.distance_to(cursor_position) >= LINE_POINT_MIN_DISTANCE:
		_current_line.add_point(cursor_position)


func _clear_laser_line() -> void:
	if _current_line == null:
		return

	_current_line.queue_free()
	_current_line = null


func _check_target_hits() -> void:
	for target in _targets:
		if _is_target_completed(target):
			continue

		var target_radius: float = _get_target_radius(target)
		var distance_to_target: float = cursor_position.distance_to(target.global_position)
		if distance_to_target <= LASER_RADIUS + target_radius:
			_set_target_completed(target, true)


func _all_targets_completed() -> bool:
	for target in _targets:
		if not _is_target_completed(target):
			return false
	return true


func _is_target_completed(target: Area2D) -> bool:
	return bool(target.get_meta("completed", false))


func _set_target_completed(target: Area2D, completed: bool) -> void:
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


func _get_target_radius(target: Area2D) -> float:
	for child in target.get_children():
		var collision_shape: CollisionShape2D = child as CollisionShape2D
		if collision_shape == null:
			continue

		var circle: CircleShape2D = collision_shape.shape as CircleShape2D
		if circle != null:
			return circle.radius * maxf(target.global_scale.x, target.global_scale.y)

	return 22.0


func _update_hud() -> void:
	_score_label.text = "Score: %d" % score
	_target_label.text = "Targets: %d/%d" % [_count_completed_targets(), _targets.size()]
	_energy_display.set_energy(energy, MAX_ENERGY)


func _count_completed_targets() -> int:
	var completed_count: int = 0
	for target in _targets:
		if _is_target_completed(target):
			completed_count += 1
	return completed_count


func _draw_grid() -> void:
	var grid_color: Color = Color(0.12, 0.19, 0.25, 0.28)
	for x in range(0, int(VIEW_SIZE.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, VIEW_SIZE.y), grid_color, 1.0)
	for y in range(0, int(VIEW_SIZE.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(VIEW_SIZE.x, y), grid_color, 1.0)


func _draw_laser() -> void:
	if not _laser_active:
		return

	draw_circle(cursor_position, LASER_RADIUS, Color(0.26, 0.86, 1.0, 0.16))
	draw_arc(cursor_position, LASER_RADIUS, 0.0, TAU, 48, Color(0.26, 0.86, 1.0, 0.85), 3.0)
	draw_line(Vector2(cursor_position.x - LASER_RADIUS, cursor_position.y), Vector2(cursor_position.x + LASER_RADIUS, cursor_position.y), Color(0.86, 0.96, 1.0, 0.65), 2.0)
	draw_line(Vector2(cursor_position.x, cursor_position.y - LASER_RADIUS), Vector2(cursor_position.x, cursor_position.y + LASER_RADIUS), Color(0.86, 0.96, 1.0, 0.65), 2.0)

	if _round_flash > 0.0:
		draw_arc(cursor_position, 95.0 + 20.0 * _round_flash, 0.0, TAU, 64, Color(0.24, 1.0, 0.66, _round_flash), 5.0)


func _draw_cursor_box() -> void:
	var box_size: Vector2 = Vector2(CURSOR_BOX_SIZE, CURSOR_BOX_SIZE)
	var box: Rect2 = Rect2(cursor_position - box_size * 0.5, box_size)
	var fill_color: Color = Color(0.24, 1.0, 0.74, 0.14)
	var line_color: Color = Color(0.24, 1.0, 0.74, 1.0)

	draw_rect(box, fill_color, true)
	draw_rect(box, line_color, false, 2.0)
