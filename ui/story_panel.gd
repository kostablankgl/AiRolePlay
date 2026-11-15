class_name StoryPanel
extends PanelContainer
const Palette = preload("res://ui/app_theme.gd")

var _label: RichTextLabel
var _built := false

func _ready() -> void:
	_ensure()

func _ensure() -> void:
	if _built:
		return
	_built = true
	theme_type_variation = "CardPanel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = false
	_label.fit_content = false
	_label.scroll_active = true
	_label.scroll_following = true
	_label.selection_enabled = true
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_size_override("normal_font_size", 20)
	_label.add_theme_color_override("default_color", Palette.TEXT)
	_label.add_theme_constant_override("line_separation", 7)
	margin.add_child(_label)

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

func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_label):
		_label.scroll_to_line(maxi(0, _label.get_line_count() - 1))
