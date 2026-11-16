class_name StoryPanel
extends PanelContainer
const Palette = preload("res://ui/app_theme.gd")
const Kit = preload("res://ui/kit.gd")

var _label: RichTextLabel
var _scroll: ScrollContainer
var _selection_btn: Button
var _hint: Label
var _built := false
var _scroll_queued := false
var _dragging := false
var _drag_last_y := 0.0
var _drag_velocity := 0.0

func _ready() -> void:
	_ensure()
	SettingsManager.changed.connect(_on_setting_changed)

func _ensure() -> void:
	if _built:
		return
	_built = true
	theme_type_variation = "CardPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var box := Kit.vbox(6)
	margin.add_child(box)
	var bar := Kit.hbox(6)
	var title := Kit.small("Сцена", Palette.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	var minus := Kit.button("А−", "GhostButton")
	minus.custom_minimum_size = Vector2(52, 36)
	minus.tooltip_text = "Мельче текст сцены"
	minus.pressed.connect(func() -> void: _change_font(-1))
	bar.add_child(minus)
	var plus := Kit.button("А+", "GhostButton")
	plus.custom_minimum_size = Vector2(52, 36)
	plus.tooltip_text = "Крупнее текст сцены"
	plus.pressed.connect(func() -> void: _change_font(1))
	bar.add_child(plus)
	_selection_btn = Kit.button("Выделение", "GhostButton")
	_selection_btn.custom_minimum_size = Vector2(124, 36)
	_selection_btn.pressed.connect(_toggle_selection)
	bar.add_child(_selection_btn)
	box.add_child(bar)
	_hint = Kit.small("", Palette.WARN)
	_hint.visible = false
	box.add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.follow_focus = true
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.gui_input.connect(_on_scroll_input)
	box.add_child(_scroll)
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 18
	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.scroll_active = false
	_label.scroll_following = false
	_label.selection_enabled = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_label.add_theme_color_override("default_color", Palette.TEXT)
	_scroll.add_child(_label)
	_refresh_typography()

func _process(delta: float) -> void:
	if _dragging or absf(_drag_velocity) < 0.5 or _scroll == null:
		return
	_scroll.scroll_vertical += int(_drag_velocity * delta)
	_drag_velocity *= pow(0.08, delta)
	if absf(_drag_velocity) < 0.5:
		_drag_velocity = 0.0

func _on_setting_changed(key: String, _value: Variant) -> void:
	if key in ["scene_font_size", "line_spacing", "ui_font_size"]:
		_refresh_typography()

func _refresh_typography() -> void:
	if _label == null:
		return
	var size := int(SettingsManager.get_value("scene_font_size", 18))
	var line := int(SettingsManager.get_value("line_spacing", 4))
	_label.add_theme_font_size_override("normal_font_size", size)
	_label.add_theme_constant_override("line_separation", line)

func _change_font(delta: int) -> void:
	var size := clampi(int(SettingsManager.get_value("scene_font_size", 18)) + delta, 14, 30)
	SettingsManager.set_value("scene_font_size", size)
	refresh_typography()
	_scroll_to_end()

func refresh_typography() -> void:
	_refresh_typography()

func _toggle_selection() -> void:
	_label.selection_enabled = not _label.selection_enabled
	_selection_btn.text = "Готово" if _label.selection_enabled else "Выделение"
	_hint.visible = _label.selection_enabled
	_hint.text = "Выделение включено: тяните по тексту. Нажмите «Готово», чтобы вернуть прокрутку."
	_label.mouse_filter = Control.MOUSE_FILTER_PASS if _label.selection_enabled else Control.MOUSE_FILTER_IGNORE
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS if _label.selection_enabled else Control.MOUSE_FILTER_STOP

func _on_scroll_input(event: InputEvent) -> void:
	if _label.selection_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragging = true
			_drag_last_y = touch.position.y
			_drag_velocity = 0.0
		else:
			_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		var dy := drag.position.y - _drag_last_y
		_drag_last_y = drag.position.y
		_scroll.scroll_vertical -= int(dy)
		_drag_velocity = -dy * 18.0
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_last_y = mb.position.y
				_drag_velocity = 0.0
			else:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var dy2 := mm.position.y - _drag_last_y
		_drag_last_y = mm.position.y
		_scroll.scroll_vertical -= int(dy2)
		_drag_velocity = -dy2 * 18.0

func set_scene(text: String) -> void:
	_ensure()
	_label.text = text.strip_edges()
	_scroll.scroll_vertical = 0
	_drag_velocity = 0.0

func set_placeholder(text: String) -> void:
	_ensure()
	_label.text = text
	_scroll_to_end()

func begin_stream() -> void:
	_ensure()
	_label.text = ""

func append_stream(text: String) -> void:
	_ensure()
	_label.text += text
	_scroll_to_end()

func current_text() -> String:
	_ensure()
	return _label.text

func scroll_to_end() -> void:
	_scroll_to_end()

func _scroll_to_end() -> void:
	if _scroll_queued:
		return
	_scroll_queued = true
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_queued = false
	if is_instance_valid(_scroll):
		var bar := _scroll.get_v_scroll_bar()
		if bar != null:
			_scroll.scroll_vertical = int(bar.max_value)
