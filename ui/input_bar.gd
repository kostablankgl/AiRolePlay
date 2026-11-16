class_name InputBar
extends HBoxContainer
const Kit = preload("res://ui/kit.gd")

signal submitted(text: String)
signal focus_changed(active: bool)
signal hide_keyboard_requested

var _edit: LineEdit
var _send: Button
var _hide: Button
const DEFAULT_PLACEHOLDER := "Свой ход, реплика или мысль…"

func _ready() -> void:
	custom_minimum_size.y = 64
	size_flags_vertical = Control.SIZE_SHRINK_END
	add_theme_constant_override("separation", 8)
	_edit = LineEdit.new()
	_edit.placeholder_text = DEFAULT_PLACEHOLDER
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.custom_minimum_size = Vector2(0, 56)
	_edit.text_submitted.connect(_on_submit)
	_edit.focus_entered.connect(func() -> void: focus_changed.emit(true))
	_edit.focus_exited.connect(func() -> void: focus_changed.emit(false))
	add_child(_edit)
	_send = Kit.button("Отправить", "AccentButton")
	_send.custom_minimum_size = Vector2(126, 56)
	_send.pressed.connect(_on_send_pressed)
	add_child(_send)
	_hide = Kit.button("⌄", "GhostButton")
	_hide.custom_minimum_size = Vector2(56, 56)
	_hide.tooltip_text = "Скрыть клавиатуру"
	_hide.pressed.connect(func() -> void:
		DisplayServer.virtual_keyboard_hide()
		_edit.release_focus()
		hide_keyboard_requested.emit()
	)
	add_child(_hide)

func _on_submit(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	_edit.clear()
	submitted.emit(t)

func _on_send_pressed() -> void:
	_on_submit(_edit.text)

func set_enabled(enabled: bool) -> void:
	_edit.editable = enabled
	_send.disabled = not enabled

func set_busy(busy: bool) -> void:
	set_state("busy" if busy else "ready")

func set_state(state: String, detail: String = "") -> void:
	match state:
		"ready":
			set_enabled(true)
			_edit.placeholder_text = DEFAULT_PLACEHOLDER
		"loading":
			set_enabled(false)
			_edit.placeholder_text = detail if detail != "" else "Загрузка модели…"
		"generating":
			set_enabled(false)
			_edit.placeholder_text = detail if detail != "" else "Мастер пишет…"
		"error":
			set_enabled(false)
			_edit.placeholder_text = detail if detail != "" else "Модель недоступна — откройте настройки"
		_:
			set_enabled(false)
			_edit.placeholder_text = detail if detail != "" else DEFAULT_PLACEHOLDER

func clear() -> void:
	_edit.clear()

func focus_input() -> void:
	_edit.grab_focus()

func has_input_focus() -> bool:
	return _edit != null and _edit.has_focus()

func hide_keyboard() -> void:
	DisplayServer.virtual_keyboard_hide()
	if _edit != null:
		_edit.release_focus()
