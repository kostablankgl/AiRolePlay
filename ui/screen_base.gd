class_name ScreenBase
extends Control
const Palette = preload("res://ui/app_theme.gd")
const Kit = preload("res://ui/kit.gd")

var _bg: ColorRect

func _enter_tree() -> void:
	theme = Palette.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.color = Palette.BG
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	var glow := ColorRect.new()
	glow.color = Color(0.79, 0.66, 0.42, 0.035)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 0.38
	glow.offset_right = 0
	glow.offset_bottom = 0
	add_child(glow)

func setup_page() -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var outer := Kit.vbox(14)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(outer)
	return outer

func header(text: String, back_path: String = "") -> HBoxContainer:
	var row := Kit.hbox(14)
	if back_path != "":
		var back := Kit.button("‹  Назад", "GhostButton")
		back.custom_minimum_size = Vector2(110, 46)
		back.pressed.connect(func() -> void: go(back_path))
		row.add_child(back)
	var t := Kit.label(text, 28, Palette.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	return row

func go(path: String) -> void:
	get_tree().change_scene_to_file(path)

func toast(message: String, is_error: bool = false) -> void:
	var p := Kit.panel("TopBarPanel")
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_left = -300
	p.offset_right = 300
	p.offset_top = -78
	p.offset_bottom = -20
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(Kit.label(message, 16, Palette.DANGER if is_error else Palette.TEXT, true))
	add_child(p)
	var timer := get_tree().create_timer(2.8)
	await timer.timeout
	if is_instance_valid(p):
		p.queue_free()
