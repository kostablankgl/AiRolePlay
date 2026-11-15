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
var _money_label: Label
var _ram_label: Label
var _model_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _menu: PopupMenu
var _busy := false
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
		go("res://scenes/main_menu.tscn")
		return
	_build()
	_connect_ai()
	GameState.state_changed.connect(_on_state_changed)
	RamMonitor.updated.connect(_refresh_ram)
	_refresh_header()
	_refresh_ram()
	var turn := GameState.turn_number()
	if turn == 0:
		_pending_intro = true
		story.set_placeholder(GameState.current_scene)
		choices.set_loading("Загружаю модель…")
		input_bar.set_busy(true)
		_banner.visible = true
		_banner_label.text = "Загружаю локальную модель. Первый запуск: 2 ГБ распаковываются в память телефона."
	else:
		story.set_scene(GameState.current_scene)
		choices.set_choices(GameState.current_choices)
		input_bar.set_busy(true)
		_banner.visible = true
		_banner_label.text = "Загружаю локальную модель…"
	AIConnector.initialize()

func _build() -> void:
	var outer := setup_page()
	var top := Kit.panel("TopBarPanel")
	var top_row := Kit.hbox(12)
	top.add_child(top_row)
	var menu_btn := Kit.button("☰", "GhostButton")
	menu_btn.custom_minimum_size = Vector2(52, 48)
	menu_btn.pressed.connect(_open_menu)
	top_row.add_child(menu_btn)
	var titles := Kit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_title = Kit.label("", 21, Palette.TEXT)
	_world_sub = Kit.small("", Palette.MUTED)
	titles.add_child(_world_title)
	titles.add_child(_world_sub)
	top_row.add_child(titles)
	_date_label = Kit.label("", 15, Palette.MUTED)
	_date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_date_label)
	_money_label = Kit.label("", 17, Palette.GOLD)
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_money_label)
	_ram_label = Kit.label("", 13, Palette.MUTED)
	_ram_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_ram_label)
	_model_label = Kit.label("ИИ: —", 13, Palette.MUTED)
	_model_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_row.add_child(_model_label)
	var settings_btn := Kit.button("⚙", "GhostButton")
	settings_btn.custom_minimum_size = Vector2(52, 48)
	settings_btn.pressed.connect(_open_settings)
	top_row.add_child(settings_btn)
	outer.add_child(top)

	var middle := Kit.hbox(12)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(middle)
	var left := Kit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(left)
	_banner = Kit.panel("InsetPanel")
	_banner.visible = false
	var brow := Kit.hbox(10)
	_banner_label = Kit.small("", Palette.WARN)
	_banner_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(_banner_label)
	var retry := Kit.button("Повторить", "GhostButton")
	retry.custom_minimum_size = Vector2(120, 40)
	retry.pressed.connect(func() -> void:
		_banner_label.text = "Пробую снова…"
		AIConnector.initialize()
	)
	brow.add_child(retry)
	_banner.add_child(brow)
	left.add_child(_banner)
	story = StoryPanelType.new()
	left.add_child(story)
	status_panel = StatusPanelType.new()
	middle.add_child(status_panel)

	var bottom := Kit.panel("CardPanel")
	var bbox := Kit.vbox(8)
	bottom.add_child(bbox)
	var bhead := Kit.hbox(8)
	bhead.add_child(Kit.label("Что вы сделаете?", 18, Palette.GOLD))
	bhead.add_child(Kit.spacer())
	_save_flash = Kit.small("", Palette.MUTED)
	bhead.add_child(_save_flash)
	bbox.add_child(bhead)
	choices = ChoiceButtonsType.new()
	bbox.add_child(choices)
	choices.choice_selected.connect(_on_choice)
	input_bar = InputBarType.new()
	bbox.add_child(input_bar)
	input_bar.submitted.connect(_on_free_text)
	input_bar.continuation_requested.connect(_on_continue)
	outer.add_child(bottom)

	_menu = PopupMenu.new()
	_menu.add_item("Сохранить", 0)
	_menu.add_item("Настройки", 1)
	_menu.add_item("Перезагрузить модель", 2)
	_menu.add_item("В главное меню", 3)
	_menu.id_pressed.connect(_on_menu_pressed)
	add_child(_menu)

func _connect_ai() -> void:
	AIConnector.status_changed.connect(_on_ai_status)
	AIConnector.model_loaded.connect(_on_model_loaded)
	AIConnector.model_failed.connect(_on_model_failed)
	AIConnector.generation_started.connect(_on_generation_started)
	AIConnector.token_received.connect(_on_token)
	AIConnector.generation_finished.connect(_on_generation_finished)
	AIConnector.generation_failed.connect(_on_generation_failed)
	AIConnector.busy_changed.connect(_on_ai_busy)
	AIConnector.copy_progress.connect(_on_copy_progress)

func _on_ai_status(text: String) -> void:
	_model_label.text = "ИИ: " + Kit.shorten(text, 42)
	if not _generating and text != "Модель готова":
		_banner.visible = true
		_banner_label.text = text
		_banner_label.add_theme_color_override("font_color", Palette.WARN)
	elif text == "Модель готова":
		_banner.visible = false
		_model_label.add_theme_color_override("font_color", Palette.OK)

func _on_copy_progress(percent: int) -> void:
	_banner.visible = true
	_banner_label.text = "Распаковываю модель: %d%%. Не закрывайте приложение." % percent

func _on_model_loaded(_path: String) -> void:
	_model_label.text = "ИИ: готов"
	_model_label.add_theme_color_override("font_color", Palette.OK)
	_banner.visible = false
	input_bar.set_busy(_generating)
	choices.set_enabled(not _generating)
	if not _generating and GameState.turn_number() > 0 and not GameState.current_choices.is_empty():
		choices.set_choices(GameState.current_choices)
	if _pending_intro and not _generating and GameState.turn_number() == 0:
		_start_intro()

func _on_model_failed(message: String) -> void:
	_model_label.text = "ИИ: ошибка"
	_model_label.add_theme_color_override("font_color", Palette.DANGER)
	_banner.visible = true
	_banner_label.text = message
	_banner_label.add_theme_color_override("font_color", Palette.DANGER)
	input_bar.set_busy(true)
	choices.set_enabled(false)
	if GameState.turn_number() == 0:
		choices.set_loading("Модель недоступна")
	toast(message, true)

func _on_ai_busy(is_busy: bool) -> void:
	_busy = is_busy

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
	_money_label.text = GameState.money_brief()
	if _model_label.text == "":
		_model_label.text = "ИИ: —"

func _refresh_ram() -> void:
	if _ram_label == null:
		return
	var color := Palette.MUTED
	if RamMonitor.pressure >= 0.86:
		color = Palette.DANGER
	elif RamMonitor.pressure >= 0.72:
		color = Palette.WARN
	_ram_label.text = "RAM %s" % RamMonitor.format_gb(RamMonitor.available_mb)
	_ram_label.add_theme_color_override("font_color", color)

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
	input_bar.set_busy(true)
	var prompt := PromptBuilder.build_intro_prompt(GameState.current_scene)
	if not AIConnector.generate(prompt.text):
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
	input_bar.set_busy(true)
	var prompt := PromptBuilder.build_prompt(action, { "continuation": continuation })
	if not AIConnector.generate(prompt.text):
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
	_model_label.text = "ИИ: пишет…"
	_model_label.add_theme_color_override("font_color", Palette.GOLD)

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
	input_bar.set_busy(false)
	input_bar.clear()
	_model_label.text = "ИИ: готов"
	_model_label.add_theme_color_override("font_color", Palette.OK)
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
	input_bar.set_busy(false)
	_model_label.text = "ИИ: ошибка"
	_model_label.add_theme_color_override("font_color", Palette.DANGER)
	_banner.visible = true

func _autosave() -> void:
	if not GameState.is_loaded():
		return
	if SaveManager.save_game(true):
		var t := Time.get_time_dict_from_system()
		_save_flash.text = "Сохранено %02d:%02d" % [int(t.get("hour", 0)), int(t.get("minute", 0))]
	else:
		_save_flash.text = "Не удалось сохранить"

func _open_menu() -> void:
	_menu.popup_centered(Vector2i(320, 240))

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
