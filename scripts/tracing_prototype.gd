extends Node2D

const VIEW_SIZE = Vector2(960, 640)
const CURSOR_BOX_SIZE = 36.0

var _hud: CanvasLayer
var _title_label: Label


func _ready() -> void:
	_build_hud()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.015, 0.018, 0.032), true)
	_draw_grid()
	_draw_cursor_box(get_global_mouse_position())


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	_title_label = Label.new()
	_title_label.position = Vector2(24, 18)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0))
	_title_label.text = "Cursor Trace Prototype"
	_hud.add_child(_title_label)


func _draw_grid() -> void:
	var grid_color := Color(0.12, 0.19, 0.25, 0.28)
	for x in range(0, int(VIEW_SIZE.x) + 1, 40):
		draw_line(Vector2(x, 0), Vector2(x, VIEW_SIZE.y), grid_color, 1.0)
	for y in range(0, int(VIEW_SIZE.y) + 1, 40):
		draw_line(Vector2(0, y), Vector2(VIEW_SIZE.x, y), grid_color, 1.0)


func _draw_cursor_box(mouse_position: Vector2) -> void:
	var box_size := Vector2(CURSOR_BOX_SIZE, CURSOR_BOX_SIZE)
	var box := Rect2(mouse_position - box_size * 0.5, box_size)
	var fill_color := Color(0.24, 1.0, 0.74, 0.16)
	var line_color := Color(0.24, 1.0, 0.74, 1.0)

	draw_rect(box, fill_color, true)
	draw_rect(box, line_color, false, 2.0)
