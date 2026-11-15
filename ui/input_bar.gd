class_name InputBar
extends HBoxContainer
const Kit = preload("res://ui/kit.gd")

signal submitted(text: String)
signal continuation_requested

var _edit: LineEdit
var _send: Button
var _continue: Button
const DEFAULT_PLACEHOLDER := "Свой ход, реплика или мысль…"

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_edit = LineEdit.new()
	_edit.placeholder_text = DEFAULT_PLACEHOLDER
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.custom_minimum_size.y = 52
	_edit.text_submitted.connect(_on_submit)
	add_child(_edit)
	_continue = Kit.button("▸ Продолжить", "GhostButton")
	_continue.custom_minimum_size = Vector2(140, 52)
	_continue.tooltip_text = "Продолжить сцену без нового действия"
	_continue.pressed.connect(func() -> void: continuation_requested.emit())
	add_child(_continue)
	_send = Kit.button("Отправить", "AccentButton")
	_send.custom_minimum_size = Vector2(140, 52)
	_send.pressed.connect(_on_send_pressed)
	add_child(_send)

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
	_continue.disabled = not enabled

func set_busy(busy: bool) -> void:
	if busy:
		set_state("busy")
	else:
		set_state("ready")

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
