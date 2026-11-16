class_name ChoiceButtons
extends VBoxContainer
const Palette = preload("res://ui/app_theme.gd")
const Kit = preload("res://ui/kit.gd")

signal choice_selected(choice: Dictionary)

var _buttons: Array[Button] = []

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func set_choices(choices: Array) -> void:
	clear()
	var usable: Array = []
	for c_v in choices:
		if c_v is Dictionary and str(c_v.get("title", "")).strip_edges() != "":
			usable.append(c_v)
	var index := 1
	for c_v in choices:
		if not (c_v is Dictionary):
			continue
		var c: Dictionary = c_v
		var title := str(c.get("title", "")).strip_edges()
		var desc := str(c.get("text", "")).strip_edges()
		if title == "":
			continue
		var heading := "%d. %s" % [index, title]
		if desc == title or desc == "":
			desc = ""
		var b := Kit.choice_button(heading, desc)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_pressed.bind(c))
		add_child(b)
		_buttons.append(b)
		index += 1

func _on_pressed(choice: Dictionary) -> void:
	choice_selected.emit(choice)

func clear() -> void:
	_buttons.clear()
	for c in get_children():
		remove_child(c)
		c.queue_free()

func set_enabled(enabled: bool) -> void:
	for b in _buttons:
		if is_instance_valid(b):
			b.disabled = not enabled

func set_loading(text: String = "Мастер пишет…") -> void:
	clear()
	var p := Kit.panel("InsetPanel")
	p.custom_minimum_size = Vector2(0, 78)
	p.add_child(Kit.label(text, 18, Palette.MUTED, true))
	add_child(p)
