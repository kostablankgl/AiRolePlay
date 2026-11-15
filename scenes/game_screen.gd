extends "res://ui/screen_base.gd"

const StoryPanelType = preload("res://ui/story_panel.gd")
const StatusPanelType = preload("res://ui/status_panel.gd")
const ChoiceButtonsType = preload("res://ui/choice_buttons.gd")
const InputBarType = preload("res://ui/input_bar.gd")

var story
var status_panel
var choices
var input_bar
var _world_title: Label
var _world_sub: Label
var _date_label: Label
var _money_button: Button
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
	var outer := setup_page(8, 8, 8)
	var top := Kit.panel("TopBarPanel")
	top.custom_minimum_size.y = 56
	var top_row := Kit.hbox(8)
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
	_money_button = Kit.button("", "GhostButton")
	_money_button.custom_minimum_size = Vector2(150, 44)
	_money_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_button.tooltip_text = "Открыть сумку и кошелёк"
	_money_button.add_theme_color_override("font_color", Palette.GOLD)
	_money_button.pressed.connect(_open_wallet)
	top_row.add_child(_money_button)
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

	var middle := Kit.hbox(8)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(middle)
	var left := Kit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(left)
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
	left.add_child(story)
	input_bar = InputBarType.new()
	left.add_child(input_bar)
	input_bar.submitted.connect(_on_free_text)
	input_bar.continuation_requested.connect(_on_continue)

	var right := Kit.vbox(8)
	right.custom_minimum_size = Vector2(380, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(right)
	status_panel = StatusPanelType.new()
	status_panel.custom_minimum_size = Vector2(380, 260)
	status_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_panel.size_flags_stretch_ratio = 1.0
	right.add_child(status_panel)

	var choices_panel := Kit.panel("CardPanel")
	choices_panel.custom_minimum_size = Vector2(380, 260)
	choices_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_panel.size_flags_stretch_ratio = 1.15
	var cbox := Kit.vbox(6)
	choices_panel.add_child(cbox)
	cbox.add_child(Kit.label("Что вы сделаете?", 17, Palette.GOLD))
	var cscroll := Kit.scroll()
	cbox.add_child(cscroll)
	choices = ChoiceButtonsType.new()
	cscroll.add_child(choices)
	choices.choice_selected.connect(_on_choice)
	right.add_child(choices_panel)

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
	if AIConnector.is_ready():
		_set_model_state("ИИ: готов", Palette.OK)
	elif text.to_lower().contains("ошиб") or text.to_lower().contains("не удалось"):
		_set_model_state("ИИ: ошибка", Palette.DANGER)
	else:
		_set_model_state("ИИ: " + Kit.shorten(text, 28), Palette.WARN)

func _on_load_started() -> void:
	_set_model_state("ИИ: загрузка…", Palette.WARN)
	_show_banner("Загружаю модель…", Palette.WARN)
	_set_input_state("loading", "Загрузка модели…")
	choices.set_loading("Загружаю модель…")

func _on_copy_progress(percent: int) -> void:
	_set_model_state("ИИ: загрузка %d%%" % percent, Palette.WARN)
	_show_banner("Распаковываю модель: %d%%. Не закрывайте приложение." % percent, Palette.WARN)
	_set_input_state("loading", "Загрузка модели %d%%" % percent)

func _on_model_loaded(_path: String) -> void:
	_set_model_state("ИИ: готов", Palette.OK)
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
	_money_button.text = GameState.format_money(GameState.cash())
	_money_button.tooltip_text = "Наличные: %s\nБанк: %s\nРезерв: %s" % [
		GameState.format_money(GameState.cash()),
		GameState.format_money(GameState.bank()),
		GameState.format_money(GameState.trust()),
	]

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

func _begin_turn(action: String, continuation: bool = false) -> void:
	if _generating or AIConnector.busy:
		return
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
	var prompt := PromptBuilder.build_prompt(action, { "continuation": continuation })
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

func _on_continue() -> void:
	_begin_turn("Продолжи сцену с того же момента, не повторяя написанное.", true)

func _on_generation_started() -> void:
	_set_model_state("ИИ: пишет…", Palette.GOLD)

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
	var tok := AIConnector.last_tok_s
	_set_model_state("ИИ: готов" + (" · %.1f tok/s" % tok if tok > 0.0 else ""), Palette.OK)
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

func _open_wallet() -> void:
	if status_panel != null:
		status_panel.open_wallet()

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_to_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GameState.is_loaded():
			SaveManager.save_game(true)
