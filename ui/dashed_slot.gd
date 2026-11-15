class_name DashedSlot
extends Button

func _ready() -> void:
	flat = true
	custom_minimum_size = Vector2(0, 96)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	var c := Color(0.55, 0.60, 0.66, 0.42)
	var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), c, 2.0, 6.0)
	draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, c, 2.0, 6.0)
	draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), c, 2.0, 6.0)
	draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, c, 2.0, 6.0)
