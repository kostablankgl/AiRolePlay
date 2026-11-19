extends "res://ui/screen_base.gd"

const StoryPanelType = preload("res://ui/story_panel.gd")
const StatusPanelType = preload("res://ui/status_panel.gd")
const ChoiceButtonsType = preload("res://ui/choice_buttons.gd")
const InputBarType = preload("res://ui/input_bar.gd")
const DragDividerType = preload("res://ui/drag_divider.gd")

var story
var status_panel
var choices
var input_bar
var _world_title: Label
var _world_sub: Label
var _date_label: Label
var _model_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _menu: PopupMenu
var _menu_btn: Button
var _generating := false
var _pending_action := ""
var _pending_continuation := false
var _pending_intro := false
var _stream_buffer := ""
var _shown_partial := ""
var _last_scene := ""
var _last_choices: Array = []
var _save_flash: Label
var _name_retry_used := false
var _middle: HBoxContainer
var _left_col: VBoxContainer
var _right_col: VBoxContainer
var _choices_panel: PanelContainer
var _wide_divider: DragDivider
var _tall_divider: DragDivider
var _layout_guard := false
var _kb_height_px: int = -1
var _kb_fallback := false
var _input_focused := false
var _focus_serial := 0

func _ready() -> void:
	if not GameState.is_loaded():
		go.call_deferred("res://scenes/main_menu.tscn")
		return
	_build()
	_connect_ai()
	GameState.state_changed.connect(_on_state_changed)
	_refresh_header()
	var turn := GameState.turn_number()
	if turn == 0:
		_pending_intro = true
		story.set_placeholder(GameState.current_scene)
		choices.set_loading("Загружаю модель…")
		_set_input_state("loading")
		_show_banner("Подготавливаю модель…", Palette.WARN)
	else:
		story.set_scene(GameState.current_scene)
		choices.set_choices(GameState.current_choices)
		_set_input_state("loading")
		_show_banner("Загружаю модель…", Palette.WARN)
	AIConnector.initialize()

func _build() -> void:
	var outer := setup_page(6, 6, 6)
	var top := Kit.panel("TopBarPanel")
	top.custom_minimum_size.y = 56
	var top_row := Kit.hbox(6)
	top.add_child(top_row)
	_menu_btn = Kit.button("☰", "GhostButton")
	_menu_btn.custom_minimum_size = Vector2(48, 44)
	_menu_btn.pressed.connect(_open_menu)
	top_row.add_child(_menu_btn)
	var titles := Kit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_title = Kit.label("", 20, Palette.TEXT)
	_world_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_world_title.clip_text = true
	_world_sub = Kit.small("", Palette.MUTED)
	_world_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_world_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_world_sub.clip_text = true
	titles.add_child(_world_title)
	titles.add_child(_world_sub)
	top_row.add_child(titles)
	_date_label = Kit.label("", 14, Palette.MUTED)
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_date_label)
	_model_label = Kit.label("ИИ: —", 13, Palette.MUTED)
	_model_label.custom_minimum_size.x = 150
	_model_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_model_label.clip_text = true
	_model_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_model_label)
	_save_flash = Kit.small("", Palette.MUTED)
	_save_flash.custom_minimum_size.x = 92
	_save_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_save_flash)
	var settings_btn := Kit.button("⚙", "GhostButton")
	settings_btn.custom_minimum_size = Vector2(48, 44)
	settings_btn.tooltip_text = "Настройки"
	settings_btn.pressed.connect(_open_settings)
	top_row.add_child(settings_btn)
	outer.add_child(top)

	var saved_width := int(SettingsManager.get_value("game_panel_width", 340))
	var saved_choices := int(SettingsManager.get_value("game_choices_height", 300))
	_middle = Kit.hbox(0)
	_middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.resized.connect(_clamp_layout)
	outer.add_child(_middle)
	_left_col = Kit.vbox(6)
	_left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_child(_left_col)
	var left := _left_col
	_banner = Kit.panel("InsetPanel")
	_banner.visible = false
	var brow := Kit.hbox(8)
	_banner_label = Kit.small("", Palette.WARN)
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(_banner_label)
	var retry := Kit.button("Повторить", "GhostButton")
	retry.custom_minimum_size = Vector2(110, 38)
	retry.pressed.connect(func() -> void:
		_show_banner("Пробую снова…", Palette.WARN)
		AIConnector.initialize()
	)
	brow.add_child(retry)
	_banner.add_child(brow)
	left.add_child(_banner)
	story = StoryPanelType.new()
	story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(story)
	input_bar = InputBarType.new()
	left.add_child(input_bar)
	input_bar.submitted.connect(_on_free_text)
	input_bar.focus_changed.connect(_on_input_focus)
	input_bar.hide_keyboard_requested.connect(_sync_keyboard)

	_wide_divider = DragDividerType.new()
	_wide_divider.drag_axis = 0
	_wide_divider.dragged.connect(_on_wide_drag)
	_wide_divider.drag_finished.connect(_save_layout)
	_middle.add_child(_wide_divider)

	_right_col = Kit.vbox(0)
	_right_col.custom_minimum_size = Vector2(saved_width, 0)
	_right_col.size_flags_horizontal = Control.SIZE_FILL
	_right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle.add_child(_right_col)
	var right := _right_col
	status_panel = StatusPanelType.new()
	status_panel.custom_minimum_size = Vector2(0, 160)
	status_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(status_panel)

	_tall_divider = DragDividerType.new()
	_tall_divider.drag_axis = 1
	_tall_divider.dragged.connect(_on_tall_drag)
	_tall_divider.drag_finished.connect(_save_layout)
	right.add_child(_tall_divider)

	_choices_panel = Kit.panel("CardPanel")
	_choices_panel.custom_minimum_size = Vector2(0, saved_choices)
	_choices_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_panel.size_flags_vertical = Control.SIZE_FILL
	var cbox := Kit.vbox(8)
	cbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choices_panel.add_child(cbox)
	var choice_title := Kit.label("Что вы сделаете?", 13, Palette.GOLD)
	choice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cbox.add_child(choice_title)
	var choices_scroll := Kit.scroll()
	choices_scroll.get_v_scroll_bar().custom_minimum_size.x = 14
	cbox.add_child(choices_scroll)
	choices = ChoiceButtonsType.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.add_child(choices)
	choices.choice_selected.connect(_on_choice)
	right.add_child(_choices_panel)
	_clamp_layout.call_deferred()

	_menu = PopupMenu.new()
	_menu.add_item("Сохранить", 0)
	_menu.add_item("Настройки", 1)
	_menu.add_item("Перезагрузить модель", 2)
	_menu.add_item("В главное меню", 3)
	_menu.id_pressed.connect(_on_menu_pressed)
	add_child(_menu)

func _connect_ai() -> void:
	AIConnector.status_changed.connect(_on_ai_status)
	AIConnector.load_started.connect(_on_load_started)
	AIConnector.model_loaded.connect(_on_model_loaded)
	AIConnector.model_failed.connect(_on_model_failed)
	AIConnector.generation_started.connect(_on_generation_started)
	AIConnector.token_received.connect(_on_token)
	AIConnector.generation_finished.connect(_on_generation_finished)
	AIConnector.generation_failed.connect(_on_generation_failed)
	AIConnector.copy_progress.connect(_on_copy_progress)
	AIConnector.load_progress.connect(_on_load_progress)

func _set_input_state(state: String, detail: String = "") -> void:
	if input_bar != null:
		input_bar.set_state(state, detail)

func _show_banner(text: String, color: Color) -> void:
	if _banner == null:
		return
	_banner.visible = true
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)

func _set_model_state(text: String, color: Color) -> void:
	_model_label.text = text
	_model_label.add_theme_color_override("font_color", color)

func _on_ai_status(text: String) -> void:
	if text.to_lower().contains("ошиб") or text.to_lower().contains("не удалось"):
		_set_model_state("ИИ: ошибка", Palette.DANGER)
		return
	_refresh_model_label()

func _refresh_model_label() -> void:
	if AIConnector.is_openrouter():
		if AIConnector.is_ready():
			_set_model_state("ИИ: облако · OpenRouter", Palette.BLUE)
		elif AIConnector.last_error != "":
			_set_model_state("ИИ: ошибка · облако", Palette.DANGER)
		else:
			_set_model_state("ИИ: облако · не настроено", Palette.MUTED)
		return
	if AIConnector.loading:
		var pct := AIConnector.load_percent
		_set_model_state("ИИ: загрузка %d%%" % pct if pct > 0 else "ИИ: загрузка…", Palette.WARN)
		return
	if AIConnector.is_ready():
		var tok := AIConnector.last_tok_s
		_set_model_state("ИИ: локально · %.1f tok/s" % tok if tok > 0.0 else "ИИ: локально · готов", Palette.OK)
		return
	if AIConnector.last_error != "":
		_set_model_state("ИИ: ошибка", Palette.DANGER)
	else:
		_set_model_state("ИИ: не загружена", Palette.MUTED)

func _on_load_started() -> void:
	_refresh_model_label()
	_show_banner("Загружаю модель…", Palette.WARN)
	_set_input_state("loading", "Загрузка модели…")
	choices.set_loading("Загружаю модель…")

func _on_load_progress(percent: int) -> void:
	_refresh_model_label()

func _on_copy_progress(percent: int) -> void:
	_set_model_state("ИИ: загрузка %d%%" % percent, Palette.WARN)
	_show_banner("Распаковываю модель: %d%%. Не закрывайте приложение." % percent, Palette.WARN)
	_set_input_state("loading", "Загрузка модели %d%%" % percent)

func _on_model_loaded(_path: String) -> void:
	_refresh_model_label()
	if _banner != null:
		_banner.visible = false
	_set_input_state("ready")
	if GameState.turn_number() > 0 and not GameState.current_choices.is_empty():
		choices.set_choices(GameState.current_choices)
		choices.set_enabled(not _generating)
	if _pending_intro and not _generating and GameState.turn_number() == 0:
		_start_intro()

func _on_model_failed(message: String) -> void:
	_set_model_state("ИИ: ошибка", Palette.DANGER)
	_show_banner(message, Palette.DANGER)
	_set_input_state("error", "Модель недоступна — откройте настройки")
	choices.set_enabled(false)
	if GameState.turn_number() == 0:
		choices.set_loading("Модель недоступна")
	toast(message, true)

func _on_state_changed() -> void:
	_refresh_header()
	if status_panel != null:
		status_panel.refresh()

func _refresh_header() -> void:
	if GameState.world.is_empty():
		return
	_world_title.text = str(GameState.world.get("title", "История"))
	var sub := str(GameState.world.get("subtitle", ""))
	var loc := GameState.location_name()
	_world_sub.text = (sub + " · " if sub != "" else "") + loc
	_date_label.text = GameState.time_label()

func _start_intro() -> void:
	if AIConnector.busy or not AIConnector.is_ready():
		return
	_pending_intro = true
	_last_scene = story.current_text()
	_last_choices = GameState.current_choices.duplicate(true)
	_generating = true
	_stream_buffer = ""
	_shown_partial = ""
	story.begin_stream()
	story.set_placeholder("Мир открывается…")
	choices.set_loading("Мастер пишет первый ход…")
	_set_input_state("generating", "Мастер пишет первый ход…")
	var prompt := PromptBuilder.build_intro_prompt(GameState.current_scene)
	if not AIConnector.generate(prompt.text, { "messages": prompt.get("messages", []) }):
		_generating = false
		_restore_after_failure()

func _begin_turn(action: String, continuation: bool = false, name_retry: bool = false) -> void:
	if _generating or AIConnector.busy:
		return
	if not name_retry:
		_name_retry_used = false
	_pending_action = action
	_pending_continuation = continuation
	_pending_intro = false
	_last_scene = story.current_text()
	_last_choices = GameState.current_choices.duplicate(true)
	_generating = true
	_stream_buffer = ""
	_shown_partial = ""
	story.begin_stream()
	story.set_placeholder("Мастер пишет…")
	choices.set_loading("Мастер пишет…")
	_set_input_state("generating")
	var prompt := PromptBuilder.build_prompt(action, { "continuation": continuation, "name_retry": name_retry })
	if not AIConnector.generate(prompt.text, { "messages": prompt.get("messages", []) }):
		_generating = false
		_restore_after_failure()

func _on_choice(choice: Dictionary) -> void:
	var title := str(choice.get("title", "")).strip_edges()
	var desc := str(choice.get("text", "")).strip_edges()
	var action := title
	if desc != "" and desc != title:
		action = title + ". " + desc
	_begin_turn(action, false)

func _on_free_text(text: String) -> void:
	_begin_turn(text, false)

func _on_generation_started() -> void:
	_set_model_state("ИИ: облако · пишет…" if AIConnector.is_openrouter() else "ИИ: локально · пишет…", Palette.GOLD)

func _on_token(token: String) -> void:
	if not _generating:
		return
	_stream_buffer += token
	var partial := _partial_scene(_stream_buffer)
	if partial == "":
		return
	if partial.begins_with(_shown_partial):
		var add := partial.substr(_shown_partial.length())
		if add != "":
			story.append_stream(add)
			_shown_partial = partial
	else:
		story.set_placeholder(partial)
		_shown_partial = partial

func _partial_scene(raw: String) -> String:
	var low := raw.to_lower()
	var start := low.find("<scene>")
	if start >= 0:
		start += 7
	else:
		if low.begins_with("<|im_start|>") or low.begins_with("<|im_end|>") or raw.find("<choices>") >= 0:
			return ""
		start = 0
	var tail := raw.substr(start)
	var low_tail := tail.to_lower()
	var cut := tail.length()
	for marker in ["</scene>", "<choices>", "<delta>", "<|im_end|>", "<|im_start|>"]:
		var idx := low_tail.find(marker)
		if idx >= 0 and idx < cut:
			cut = idx
	tail = tail.substr(0, cut)
	return tail.strip_edges()

func _on_generation_finished(text: String) -> void:
	_generating = false
	_shown_partial = ""
	var parsed := SceneParser.parse(text)
	var scene := str(parsed.get("scene", "")).strip_edges()
	var scene_choices: Array = parsed.get("choices", [])
	var delta: Variant = parsed.get("delta", {})
	if not bool(parsed.get("ok", false)) or scene == "":
		scene = text.strip_edges()
		scene_choices = WorldDB.get_default_choices(GameState.world)
		delta = {}
		toast("Формат сцены сломан — показан текст и шаблонные выборы", true)
	elif str(parsed.get("delta_error", "")) != "":
		toast("Delta не разобрана — изменения не применены", true)
	if scene_choices.is_empty():
		scene_choices = WorldDB.get_default_choices(GameState.world)
	if not _pending_intro and not _name_retry_used:
		var unknown := PromptBuilder.unknown_canon_names(scene)
		if not unknown.is_empty():
			_name_retry_used = true
			print("Повторная генерация: неизвестные имена ", unknown)
			_begin_turn(_pending_action, _pending_continuation, true)
			return
	var report := GameState.apply_delta(delta)
	if not report.get("rejected", []).is_empty():
		toast("Часть изменений отклонена: " + ", ".join(report["rejected"]), true)
	if _pending_intro:
		GameState.record_intro(scene, scene_choices)
	else:
		GameState.record_turn(_pending_action, scene, scene_choices, report)
	story.set_scene(scene)
	choices.set_choices(scene_choices)
	choices.set_enabled(true)
	_set_input_state("ready")
	input_bar.clear()
	_refresh_model_label()
	_pending_intro = false
	status_panel.refresh()
	_refresh_header()
	_autosave()

func _on_generation_failed(message: String) -> void:
	_generating = false
	_restore_after_failure()
	toast(message, true)

func _restore_after_failure() -> void:
	_generating = false
	_shown_partial = ""
	if _last_scene != "":
		story.set_scene(_last_scene)
	elif GameState.current_scene != "":
		story.set_scene(GameState.current_scene)
	if not _last_choices.is_empty():
		choices.set_choices(_last_choices)
	elif not GameState.current_choices.is_empty():
		choices.set_choices(GameState.current_choices)
	else:
		choices.set_choices(WorldDB.get_default_choices(GameState.world))
	choices.set_enabled(true)
	_set_input_state("ready" if AIConnector.is_ready() else "error")
	_set_model_state("ИИ: ошибка", Palette.DANGER)

func _autosave() -> void:
	if not GameState.is_loaded():
		return
	if SaveManager.save_game(true):
		var t := Time.get_time_dict_from_system()
		_save_flash.text = "Сохранено %02d:%02d" % [int(t.get("hour", 0)), int(t.get("minute", 0))]
	else:
		_save_flash.text = "Не сохранено"

func _on_wide_drag(relative: Vector2) -> void:
	if _right_col == null or _middle == null:
		return
	var max_width := 560
	if _middle.size.x > 320:
		max_width = maxi(250, int(_middle.size.x * 0.58))
	_right_col.custom_minimum_size.x = clampi(int(_right_col.custom_minimum_size.x) - int(relative.x), 250, max_width)

func _on_tall_drag(relative: Vector2) -> void:
	if _choices_panel == null or _right_col == null:
		return
	_choices_panel.custom_minimum_size.y = clampi(int(_choices_panel.custom_minimum_size.y) - int(relative.y), 150, _max_choices_height())

func _max_choices_height() -> int:
	if _right_col == null or _right_col.size.y < 520:
		return 560
	return maxi(150, int(_right_col.size.y) - 196)

func _clamp_layout() -> void:
	if _layout_guard:
		return
	_layout_guard = true
	if _right_col != null and _middle != null:
		var max_width := 560
		if _middle.size.x > 320:
			max_width = maxi(250, int(_middle.size.x * 0.58))
		_right_col.custom_minimum_size.x = clampi(int(_right_col.custom_minimum_size.x), 250, max_width)
	if _choices_panel != null and _right_col != null and _right_col.size.y >= 520:
		_choices_panel.custom_minimum_size.y = clampi(int(_choices_panel.custom_minimum_size.y), 150, _max_choices_height())
	_layout_guard = false

func _save_layout() -> void:
	if _right_col == null or _choices_panel == null:
		return
	SettingsManager.set_many({
		"game_panel_width": int(_right_col.custom_minimum_size.x),
		"game_choices_height": int(_choices_panel.custom_minimum_size.y),
	})

func _open_menu() -> void:
	if _menu_btn == null:
		return
	var r := _menu_btn.get_global_rect()
	_menu.position = Vector2i(int(r.position.x), int(r.position.y + r.size.y + 4))
	_menu.popup()

func _on_menu_pressed(id: int) -> void:
	match id:
		0:
			if SaveManager.save_game(false):
				toast("История сохранена")
			else:
				toast("Не удалось сохранить", true)
		1:
			_open_settings()
		2:
			AIConnector.unload()
			AIConnector.initialize()
		3:
			_leave_to_menu()

func _open_settings() -> void:
	if GameState.is_loaded():
		SaveManager.save_game(true)
	go("res://scenes/settings.tscn")

func _leave_to_menu() -> void:
	if GameState.is_loaded():
		SaveManager.save_game(true)
	go("res://scenes/main_menu.tscn")

func _process(_delta: float) -> void:
	var h := DisplayServer.virtual_keyboard_get_height()
	if h != _kb_height_px:
		_kb_height_px = h
		if h > 0:
			_kb_fallback = false
		_apply_keyboard_inset(h)

func _apply_keyboard_inset(h_px: int) -> void:
	if page_margin == null:
		return
	var scale_y: float = get_viewport().get_screen_transform().get_scale().y
	if scale_y <= 0.0:
		scale_y = 1.0
	var inset_ui := int(ceil(float(maxi(0, h_px)) / scale_y))
	page_margin.add_theme_constant_override("margin_bottom", 6 + inset_ui)
	if _right_col != null:
		_right_col.visible = inset_ui == 0
	if _wide_divider != null:
		_wide_divider.visible = inset_ui == 0
	if input_bar != null:
		input_bar.visible = true

func _on_input_focus(active: bool) -> void:
	_input_focused = active
	_focus_serial += 1
	var serial := _focus_serial
	if active:
		story.scroll_to_end()
		await get_tree().process_frame
		await get_tree().process_frame
		if serial != _focus_serial or not _input_focused:
			return
		if DisplayServer.virtual_keyboard_get_height() == 0:
			_kb_fallback = true
			var fallback := int(float(get_viewport_rect().size.y) * 0.45)
			_apply_keyboard_inset(fallback)
	else:
		_kb_fallback = false
		_apply_keyboard_inset(DisplayServer.virtual_keyboard_get_height())

func _sync_keyboard() -> void:
	_kb_fallback = false
	_apply_keyboard_inset(DisplayServer.virtual_keyboard_get_height())

func _input(event: InputEvent) -> void:
	if input_bar == null or not input_bar.has_input_focus():
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		pos = mb.position
	if pressed and not input_bar.get_global_rect().has_point(pos):
		input_bar.hide_keyboard()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_to_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GameState.is_loaded():
			SaveManager.save_game(true)
