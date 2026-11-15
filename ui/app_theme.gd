class_name AppTheme
extends RefCounted

const BG := Color("14161a")
const BG_SOFT := Color("191c22")
const PANEL := Color("1e2229")
const PANEL_LIGHT := Color("252a33")
const BORDER := Color("343b46")
const TEXT := Color("ece9e2")
const MUTED := Color("9aa3ad")
const GOLD := Color("c9a86a")
const GOLD_DARK := Color("8f7444")
const OK := Color("7fb385")
const WARN := Color("d8a657")
const DANGER := Color("c46a63")
const BLUE := Color("7aa2c9")

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme

static func _box(color: Color, radius: int = 10, border: int = 0, border_color: Color = BORDER, margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border
	sb.border_width_top = border
	sb.border_width_right = border
	sb.border_width_bottom = border
	sb.border_color = border_color
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb

static func _build() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 18
	var regular: Font = load("res://assets/fonts/NotoSans-Regular.ttf")
	if regular != null:
		regular.fallbacks = [ThemeDB.fallback_font]
		t.default_font = regular

	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_constant("line_separation", "RichTextLabel", 6)
	t.set_stylebox("normal", "RichTextLabel", _box(Color(0, 0, 0, 0), 8, 0, BORDER, 2))

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 14, 1, BORDER, 16))

	t.set_stylebox("normal", "Button", _box(PANEL_LIGHT, 10, 1, BORDER, 12))
	t.set_stylebox("hover", "Button", _box(Color("2d3440"), 10, 1, GOLD_DARK, 12))
	t.set_stylebox("pressed", "Button", _box(Color("3a3324"), 10, 1, GOLD, 12))
	t.set_stylebox("disabled", "Button", _box(Color("20242b"), 10, 1, Color("2b313a"), 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color("fff6df"))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("6d757f"))
	t.set_font_size("font_size", "Button", 18)
	t.set_constant("h_separation", "Button", 8)

	t.set_type_variation("AccentButton", "Button")
	t.set_stylebox("normal", "AccentButton", _box(GOLD, 10, 0, GOLD, 12))
	t.set_stylebox("hover", "AccentButton", _box(Color("ddc08a"), 10, 0, GOLD, 12))
	t.set_stylebox("pressed", "AccentButton", _box(GOLD_DARK, 10, 0, GOLD, 12))
	t.set_stylebox("disabled", "AccentButton", _box(Color("575047"), 10, 0, Color("575047"), 12))
	t.set_color("font_color", "AccentButton", Color("1a1710"))
	t.set_color("font_hover_color", "AccentButton", Color("120f09"))
	t.set_color("font_pressed_color", "AccentButton", Color("120f09"))
	t.set_color("font_disabled_color", "AccentButton", Color("2a2722"))

	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", _box(Color(0, 0, 0, 0), 8, 0, BORDER, 8))
	t.set_stylebox("hover", "GhostButton", _box(Color("252a33"), 8, 0, BORDER, 8))
	t.set_stylebox("pressed", "GhostButton", _box(Color("333029"), 8, 0, BORDER, 8))
	t.set_color("font_color", "GhostButton", MUTED)
	t.set_color("font_hover_color", "GhostButton", TEXT)
	t.set_color("font_pressed_color", "GhostButton", GOLD)

	t.set_type_variation("ChoiceButton", "Button")
	t.set_stylebox("normal", "ChoiceButton", _box(PANEL_LIGHT, 12, 1, BORDER, 14))
	t.set_stylebox("hover", "ChoiceButton", _box(Color("313944"), 12, 1, GOLD, 14))
	t.set_stylebox("pressed", "ChoiceButton", _box(Color("3a3324"), 12, 1, GOLD, 14))
	t.set_stylebox("disabled", "ChoiceButton", _box(Color("20242b"), 12, 1, Color("2b313a"), 14))
	t.set_color("font_color", "ChoiceButton", TEXT)
	t.set_color("font_hover_color", "ChoiceButton", Color("fff6df"))

	t.set_type_variation("ItemSlot", "Button")
	t.set_stylebox("normal", "ItemSlot", _box(PANEL_LIGHT, 10, 1, BORDER, 8))
	t.set_stylebox("hover", "ItemSlot", _box(Color("313944"), 10, 1, GOLD_DARK, 8))
	t.set_stylebox("pressed", "ItemSlot", _box(Color("3a3324"), 10, 1, GOLD, 8))
	t.set_stylebox("disabled", "ItemSlot", _box(Color("20242b"), 10, 1, Color("2b313a"), 8))

	t.set_type_variation("RowButton", "Button")
	t.set_stylebox("normal", "RowButton", _box(PANEL, 10, 1, Color("2c333d"), 10))
	t.set_stylebox("hover", "RowButton", _box(PANEL_LIGHT, 10, 1, GOLD_DARK, 10))
	t.set_stylebox("pressed", "RowButton", _box(Color("3a3324"), 10, 1, GOLD, 10))
	t.set_color("font_color", "RowButton", TEXT)

	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("normal", "DangerButton", _box(Color("3a2222"), 10, 1, Color("6d3a37"), 12))
	t.set_stylebox("hover", "DangerButton", _box(Color("4a2826"), 10, 1, DANGER, 12))
	t.set_stylebox("pressed", "DangerButton", _box(Color("5a2e2a"), 10, 1, DANGER, 12))
	t.set_color("font_color", "DangerButton", Color("e9b7b3"))

	t.set_type_variation("CardPanel", "PanelContainer")
	t.set_stylebox("panel", "CardPanel", _box(PANEL, 14, 1, BORDER, 16))
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", _box(BG_SOFT, 12, 1, Color("2c333d"), 14))
	t.set_type_variation("TopBarPanel", "PanelContainer")
	t.set_stylebox("panel", "TopBarPanel", _box(Color("191c22"), 12, 1, Color("2b313a"), 10))

	t.set_stylebox("normal", "LineEdit", _box(BG_SOFT, 10, 1, BORDER, 12))
	t.set_stylebox("focus", "LineEdit", _box(BG_SOFT, 10, 2, GOLD_DARK, 12))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color("6f7883"))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color("3d4a5a"))
	t.set_constant("minimum_character_width", "LineEdit", 12)

	t.set_stylebox("normal", "TextEdit", _box(BG_SOFT, 10, 1, BORDER, 12))
	t.set_stylebox("focus", "TextEdit", _box(BG_SOFT, 10, 2, GOLD_DARK, 12))
	t.set_color("font_color", "TextEdit", TEXT)
	t.set_color("caret_color", "TextEdit", GOLD)

	t.set_stylebox("normal", "SpinBox", _box(BG_SOFT, 10, 1, BORDER, 8))

	t.set_stylebox("panel", "PopupMenu", _box(PANEL, 12, 1, BORDER, 8))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color("1a1710"))
	t.set_stylebox("hover", "PopupMenu", _box(GOLD, 6, 0, GOLD, 8))
	t.set_constant("v_separation", "PopupMenu", 8)

	t.set_stylebox("panel", "TabContainer", _box(PANEL, 12, 1, BORDER, 10))
	t.set_stylebox("tab_selected", "TabContainer", _box(GOLD, 8, 0, GOLD, 8))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color("242931"), 8, 0, BORDER, 8))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color("2d3440"), 8, 0, GOLD_DARK, 8))
	t.set_color("font_selected_color", "TabContainer", Color("1a1710"))
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font_size("font_size", "TabContainer", 17)

	t.set_stylebox("tab_selected", "TabBar", _box(GOLD, 8, 0, GOLD, 8))
	t.set_stylebox("tab_unselected", "TabBar", _box(Color("242931"), 8, 0, BORDER, 8))
	t.set_stylebox("tab_hovered", "TabBar", _box(Color("2d3440"), 8, 0, GOLD_DARK, 8))
	t.set_color("font_selected_color", "TabBar", Color("1a1710"))
	t.set_color("font_unselected_color", "TabBar", MUTED)
	t.set_color("font_hovered_color", "TabBar", TEXT)
	t.set_font_size("font_size", "TabBar", 17)

	t.set_stylebox("background", "ProgressBar", _box(Color("2a3038"), 6, 0, BORDER, 3))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, 6, 0, GOLD, 3))
	t.set_color("font_color", "ProgressBar", TEXT)

	t.set_stylebox("separator", "HSeparator", _box(Color("2c333d"), 0, 0, Color("2c333d"), 0))
	t.set_constant("separation", "HSeparator", 8)
	t.set_stylebox("separator", "VSeparator", _box(Color("2c333d"), 0, 0, Color("2c333d"), 0))

	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color("fff6df"))
	t.set_stylebox("normal", "CheckBox", _box(Color(0, 0, 0, 0), 6, 0, BORDER, 6))
	t.set_stylebox("hover", "CheckBox", _box(Color("252a33"), 6, 0, BORDER, 6))

	t.set_stylebox("normal", "OptionButton", _box(PANEL_LIGHT, 10, 1, BORDER, 10))

	t.set_stylebox("panel", "ScrollContainer", _box(Color(0, 0, 0, 0), 0, 0, BORDER, 0))

	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("panel", "TooltipPanel", _box(PANEL_LIGHT, 8, 1, BORDER, 8))

	return t
