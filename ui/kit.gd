class_name UIKit
extends RefCounted
const Palette = preload("res://ui/app_theme.gd")

static func vbox(separation: int = 10) -> VBoxContainer:
	var n := VBoxContainer.new()
	n.add_theme_constant_override("separation", separation)
	return n

static func hbox(separation: int = 10) -> HBoxContainer:
	var n := HBoxContainer.new()
	n.add_theme_constant_override("separation", separation)
	return n

static func grid(columns: int = 2, hsep: int = 12, vsep: int = 12) -> GridContainer:
	var n := GridContainer.new()
	n.columns = columns
	n.add_theme_constant_override("h_separation", hsep)
	n.add_theme_constant_override("v_separation", vsep)
	return n

static func label(text: String, size: int = 18, color: Color = Palette.TEXT, wrap: bool = false) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	if wrap:
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return n

static func title(text: String) -> Label:
	return label(text, 32, Palette.TEXT, true)

static func h2(text: String) -> Label:
	return label(text, 23, Palette.GOLD)

static func muted(text: String, wrap: bool = false) -> Label:
	return label(text, 15, Palette.MUTED, wrap)

static func small(text: String, color: Color = Palette.MUTED) -> Label:
	return label(text, 13, color, true)

static func panel(variation: String = "CardPanel") -> PanelContainer:
	var n := PanelContainer.new()
	n.theme_type_variation = variation
	return n

static func button(text: String, variation: String = "") -> Button:
	var n := Button.new()
	n.text = text
	n.custom_minimum_size = Vector2(48, 48)
	if variation != "":
		n.theme_type_variation = variation
	return n

static func bold_font() -> Font:
	return load("res://assets/fonts/NotoSans-Bold.ttf")

static func choice_button(heading: String, description: String) -> Button:
	var n := Button.new()
	n.theme_type_variation = "ChoiceButton"
	n.alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.text = ""
	n.custom_minimum_size = Vector2(0, 76)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	n.add_child(margin)
	var box := vbox(3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var title := label(heading, 16, Palette.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bold := bold_font()
	if bold != null:
		title.add_theme_font_override("font", bold)
	box.add_child(title)
	if description != "":
		var desc := label(description, 13, Palette.MUTED, true)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(desc)
	return n

static func scroll() -> ScrollContainer:
	var n := ScrollContainer.new()
	n.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	n.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return n

static func spacer(min_height: int = 0) -> Control:
	var n := Control.new()
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if min_height > 0:
		n.custom_minimum_size = Vector2(0, min_height)
	return n

static func separator() -> HSeparator:
	return HSeparator.new()

static func chip(text: String, color: Color = Palette.GOLD) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, 14, color))
	return p

static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(child)
	return m

static func field_row(caption: String, field: Control) -> HBoxContainer:
	var row := hbox(12)
	var l := label(caption, 16, Palette.MUTED)
	l.custom_minimum_size.x = 190
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(field)
	return row

static func progress(min_value: float = 0.0, max_value: float = 100.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.min_value = min_value
	p.max_value = max_value
	p.show_percentage = false
	p.custom_minimum_size.y = 10
	return p

static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

static func shorten(text: String, max_chars: int) -> String:
	var t := text.strip_edges()
	if t.length() <= max_chars:
		return t
	var cut := t.substr(0, max_chars)
	var space := cut.rfind(" ")
	if space > max_chars / 2:
		cut = cut.substr(0, space)
	return cut + "…"

static func escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")

static func join_names(items: Array, max_items: int = 4) -> String:
	var names: Array[String] = []
	for item in items:
		if item is Dictionary:
			names.append(str(item.get("name", item.get("id", "?"))))
		else:
			names.append(str(item))
	if names.size() > max_items:
		return ", ".join(names.slice(0, max_items)) + "…"
	return ", ".join(names)
