class_name StoryPanel
extends PanelContainer
const Palette = preload("res://ui/app_theme.gd")

var _label: RichTextLabel
var _scroll: ScrollContainer
var _built := false
var _scroll_queued := false

func _ready() -> void:
	_ensure()

func _ensure() -> void:
	if _built:
		return
	_built = true
	theme_type_variation = "CardPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = true
	_label.scroll_active = false
	_label.scroll_following = false
	_label.selection_enabled = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 20)
	_label.add_theme_color_override("default_color", Palette.TEXT)
	_label.add_theme_constant_override("line_separation", 7)
	_scroll.add_child(_label)

func set_scene(text: String) -> void:
	_ensure()
	_label.text = text.strip_edges()
	_scroll_to_end()

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
