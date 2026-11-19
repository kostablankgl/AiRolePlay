class_name DragDivider
extends PanelContainer

signal dragged(relative: Vector2)
signal drag_finished

const Palette = preload("res://ui/app_theme.gd")

@export_enum("horizontal", "vertical") var drag_axis := 0

var _dragging := false
var _last_global := Vector2.ZERO
var _mark: Label

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HSIZE if drag_axis == 0 else Control.CURSOR_VSIZE
	theme_type_variation = "DividerHandle"
	if drag_axis == 0:
		custom_minimum_size = Vector2(22, 0)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		custom_minimum_size = Vector2(0, 22)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_text = "Потяните, чтобы изменить размер"
	_mark = Label.new()
	_mark.text = "⋮" if drag_axis == 0 else "⋯"
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mark.add_theme_font_size_override("font_size", 18)
	_mark.add_theme_color_override("font_color", Palette.MUTED)
	add_child(_mark)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_start_drag(_to_global_point(touch.position))
		elif _dragging:
			_end_drag()
		accept_event()
	elif event is InputEventScreenDrag:
		if _dragging:
			_drag_to(_to_global_point((event as InputEventScreenDrag).position))
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag(_to_global_point(mb.position))
			elif _dragging:
				_end_drag()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_drag_to(_to_global_point((event as InputEventMouseMotion).position))
		accept_event()

func _to_global_point(local_point: Vector2) -> Vector2:
	return get_global_transform() * local_point

func _drag_to(global_point: Vector2) -> void:
	var delta := global_point - _last_global
	_last_global = global_point
	if delta != Vector2.ZERO:
		dragged.emit(delta)

func _start_drag(global_point: Vector2) -> void:
	_dragging = true
	_last_global = global_point
	_mark.add_theme_color_override("font_color", Palette.GOLD)

func _end_drag() -> void:
	_dragging = false
	_mark.add_theme_color_override("font_color", Palette.MUTED)
	drag_finished.emit()
