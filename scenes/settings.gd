extends "res://ui/screen_base.gd"

var _model_status: Label
var _model_name: Label
var _models_box: VBoxContainer
var _import_label: Label
var _ram_bar: ProgressBar
var _ram_label: Label
var _ram_hint: Label
var _advanced: VBoxContainer
var _controls: Dictionary = {}
var _dialog: FileDialog
var _provider_option: OptionButton
var _or_key: LineEdit
var _or_model: OptionButton
var _or_manual: LineEdit
var _or_status: Label
var _delete_confirm: ConfirmationDialog
var _pending_delete_path: String = ""
var _import_thread: Thread
var _import_src: String = ""
var _import_dst: String = ""
var _import_progress: int = 0
var _import_done: bool = false
var _import_error: String = ""
var _importing: bool = false
var _scene_font_slider: HSlider
var _ui_font_slider: HSlider
var _line_slider: HSlider
var _font_preview: RichTextLabel

func _ready() -> void:
	_build()
	_load_values()
	AIConnector.status_changed.connect(_on_ai_status)
	AIConnector.model_loaded.connect(_on_model_loaded)
	AIConnector.model_failed.connect(_on_model_failed)
	AIConnector.load_progress.connect(_on_load_progress)
	OpenRouterClient.models_loaded.connect(_on_or_models_loaded)
	OpenRouterClient.models_failed.connect(_on_or_models_failed)
	RamMonitor.updated.connect(_refresh_ram)
	_refresh_models()
	_refresh_ram()
	_refresh_model_status()

func _build() -> void:
	var outer := setup_page()
	outer.add_child(header("Настройки", "res://scenes/main_menu.tscn"))
	var sc := Kit.scroll()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	sc.follow_focus = true
	sc.scroll_deadzone = 8
	var scroll_bar := sc.get_v_scroll_bar()
	scroll_bar.custom_minimum_size.x = 28
	scroll_bar.add_theme_constant_override("minimum_grabber_size", 48)
	outer.add_child(sc)
	var page := Kit.vbox(12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(page)

	var model := Kit.panel("CardPanel")
	var mb := Kit.vbox(8)
	model.add_child(mb)
	mb.add_child(Kit.label("Модели", 22, Palette.GOLD))
	_model_name = Kit.label("", 16, Palette.TEXT, true)
	mb.add_child(_model_name)
	_model_status = Kit.small("", Palette.MUTED)
	mb.add_child(_model_status)
	var mrow := Kit.hbox(8)
	var import := Kit.button("Импортировать .gguf", "GhostButton")
	import.custom_minimum_size = Vector2(210, 48)
	import.pressed.connect(_open_import)
	mrow.add_child(import)
	var refresh := Kit.button("Обновить список", "GhostButton")
	refresh.custom_minimum_size = Vector2(170, 48)
	refresh.pressed.connect(_refresh_models)
	mrow.add_child(refresh)
	var unload_all := Kit.button("Выгрузить всё", "GhostButton")
	unload_all.custom_minimum_size = Vector2(160, 48)
	unload_all.pressed.connect(func() -> void: AIConnector.unload())
	mrow.add_child(unload_all)
	mb.add_child(mrow)
	_import_label = Kit.small("", Palette.MUTED)
	mb.add_child(_import_label)
	_models_box = Kit.vbox(6)
	mb.add_child(_models_box)
	mb.add_child(Kit.small("Все .gguf лежат только в user://models и не входят в APK.", Palette.MUTED))
	page.add_child(model)

	var provider := Kit.panel("CardPanel")
	var pb := Kit.vbox(8)
	provider.add_child(pb)
	pb.add_child(Kit.label("Провайдер ИИ", 22, Palette.GOLD))
	var prow := Kit.hbox(8)
	_provider_option = OptionButton.new()
	_provider_option.custom_minimum_size = Vector2(240, 48)
	_provider_option.add_item("Локальная модель", 0)
	_provider_option.add_item("OpenRouter", 1)
	_provider_option.item_selected.connect(_on_provider_selected)
	prow.add_child(_provider_option)
	pb.add_child(prow)
	pb.add_child(Kit.small("OpenRouter — внешний сервис. Текст истории уходит на его сервер; локальный режим остаётся офлайн.", Palette.MUTED))
	var key_row := Kit.hbox(8)
	_or_key = LineEdit.new()
	_or_key.secret = true
	_or_key.placeholder_text = "API-ключ OpenRouter"
	_or_key.custom_minimum_size = Vector2(0, 48)
	_or_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(_or_key)
	var test := Kit.button("Проверить и обновить", "GhostButton")
	test.custom_minimum_size = Vector2(220, 48)
	test.pressed.connect(_test_openrouter)
	key_row.add_child(test)
	pb.add_child(key_row)
	_or_model = OptionButton.new()
	_or_model.custom_minimum_size = Vector2(0, 48)
	_or_model.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_or_model.item_selected.connect(_on_model_selected)
	pb.add_child(_or_model)
	_or_manual = LineEdit.new()
	_or_manual.placeholder_text = "Или id модели вручную, например google/gemini-2.0-flash-exp:free"
	_or_manual.custom_minimum_size.y = 48
	pb.add_child(_or_manual)
	_or_status = Kit.small("", Palette.MUTED)
	pb.add_child(_or_status)
	page.add_child(provider)

	var ram := Kit.panel("CardPanel")
	var rb := Kit.vbox(6)
	ram.add_child(rb)
	rb.add_child(Kit.label("Память", 22, Palette.GOLD))
	_ram_bar = Kit.progress()
	_ram_bar.custom_minimum_size.y = 14
	rb.add_child(_ram_bar)
	_ram_label = Kit.small("", Palette.MUTED)
	rb.add_child(_ram_label)
	_ram_hint = Kit.small("", Palette.MUTED)
	rb.add_child(_ram_hint)
	page.add_child(ram)

	var design := Kit.panel("CardPanel")
	var db := Kit.vbox(8)
	design.add_child(db)
	db.add_child(Kit.label("Оформление", 22, Palette.GOLD))
	db.add_child(Kit.label("Размер текста сцены", 15, Palette.MUTED))
	_scene_font_slider = HSlider.new()
	_scene_font_slider.min_value = 14
	_scene_font_slider.max_value = 30
	_scene_font_slider.step = 1
	_scene_font_slider.custom_minimum_size = Vector2(0, 40)
	_scene_font_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_font_slider.value_changed.connect(func(_v: float) -> void: _apply_typography())
	db.add_child(_scene_font_slider)
	db.add_child(Kit.label("Размер интерфейса", 15, Palette.MUTED))
	_ui_font_slider = HSlider.new()
	_ui_font_slider.min_value = 12
	_ui_font_slider.max_value = 20
	_ui_font_slider.step = 1
	_ui_font_slider.custom_minimum_size = Vector2(0, 40)
	_ui_font_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_font_slider.value_changed.connect(func(_v: float) -> void: _apply_typography())
	db.add_child(_ui_font_slider)
	db.add_child(Kit.label("Межстрочный интервал", 15, Palette.MUTED))
	_line_slider = HSlider.new()
	_line_slider.min_value = 0
	_line_slider.max_value = 10
	_line_slider.step = 1
	_line_slider.custom_minimum_size = Vector2(0, 40)
	_line_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_slider.value_changed.connect(func(_v: float) -> void: _apply_typography())
	db.add_child(_line_slider)
	var preview_panel := Kit.panel("InsetPanel")
	_font_preview = RichTextLabel.new()
	_font_preview.bbcode_enabled = false
	_font_preview.fit_content = true
	_font_preview.custom_minimum_size = Vector2(0, 92)
	_font_preview.text = "Так будет выглядеть текст сцены.\nВторая строка для проверки интервала."
	preview_panel.add_child(_font_preview)
	db.add_child(preview_panel)
	page.add_child(design)

	var gen := Kit.panel("CardPanel")
	var gb := Kit.vbox(8)
	gen.add_child(gb)
	gb.add_child(Kit.label("Генерация", 22, Palette.GOLD))
	gb.add_child(_spin_row("Контекст (n_ctx)", "n_ctx", 1024, 8192, 128, 0))
	gb.add_child(_spin_row("Потоки", "threads", 1, 8, 1, 0))
	gb.add_child(_spin_row("Температура", "temperature", 0.0, 2.0, 0.01, 2))
	gb.add_child(_spin_row("Top-p", "top_p", 0.01, 1.0, 0.01, 2))
	gb.add_child(_spin_row("Top-k", "top_k", 0, 200, 1, 0))
	gb.add_child(_spin_row("Min-p", "min_p", 0.0, 1.0, 0.01, 2))
	gb.add_child(_spin_row("Штраф повторов", "repeat_penalty", 0.8, 2.0, 0.01, 2))
	gb.add_child(_spin_row("Макс. токенов ответа", "max_tokens", 64, 1024, 1, 0))
	var stream := CheckBox.new()
	stream.text = "Показывать текст по мере генерации"
	_controls["streaming"] = stream
	gb.add_child(stream)
	var light := CheckBox.new()
	light.text = "Лёгкий режим: короче контекст и ответы"
	light.toggled.connect(_on_light_toggled)
	_controls["light_mode"] = light
	gb.add_child(light)

	var adv_toggle := CheckBox.new()
	adv_toggle.text = "Дополнительно"
	adv_toggle.toggled.connect(func(on: bool) -> void: _advanced.visible = on)
	gb.add_child(adv_toggle)
	_advanced = Kit.vbox(8)
	_advanced.visible = false
	gb.add_child(_advanced)
	_advanced.add_child(_spin_row("Batch (n_batch)", "n_batch", 32, 1024, 32, 0))
	_advanced.add_child(_spin_row("Штраф: последние N", "penalty_last_n", -1, 1024, 1, 0))
	_advanced.add_child(_spin_row("Frequency penalty", "frequency_penalty", -1.0, 2.0, 0.01, 2))
	_advanced.add_child(_spin_row("Presence penalty", "presence_penalty", -1.0, 2.0, 0.01, 2))
	_advanced.add_child(_spin_row("Seed (-1 = случайный)", "seed", -1, 2147483647, 1, 0))
	var mmap := CheckBox.new()
	mmap.text = "mmap (экономит RAM, рекомендуется)"
	_controls["use_mmap"] = mmap
	_advanced.add_child(mmap)
	var mlock := CheckBox.new()
	mlock.text = "mlock (держать модель в RAM)"
	_controls["use_mlock"] = mlock
	_advanced.add_child(mlock)
	var flash := CheckBox.new()
	flash.text = "Flash Attention"
	_controls["flash_attn"] = flash
	_advanced.add_child(flash)
	var kv := OptionButton.new()
	kv.add_item("f16", 0)
	kv.add_item("q8_0", 1)
	kv.add_item("q4_0", 2)
	kv.custom_minimum_size = Vector2(180, 48)
	_controls["kv_type"] = kv
	_advanced.add_child(Kit.field_row("Тип KV-кэша", kv))
	var repack := CheckBox.new()
	repack.text = "Repack (если поддерживает сборка)"
	_controls["use_repack"] = repack
	_advanced.add_child(repack)
	_advanced.add_child(Kit.small("Flash Attention, KV и repack применяются только если они включены в текущей сборке llama.cpp. Иначе параметр сохраняется, но движок его игнорирует.", Palette.MUTED))
	page.add_child(gen)

	var actions := Kit.hbox(8)
	actions.add_child(Kit.spacer())
	var reload := Kit.button("Сохранить и перезагрузить", "Button")
	reload.custom_minimum_size = Vector2(260, 54)
	reload.pressed.connect(_save_and_reload)
	actions.add_child(reload)
	var save := Kit.button("Сохранить", "AccentButton")
	save.custom_minimum_size = Vector2(180, 54)
	save.pressed.connect(_save)
	actions.add_child(save)
	page.add_child(actions)

	_dialog = FileDialog.new()
	_dialog.use_native_dialog = true
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = PackedStringArray(["*.gguf ; GGUF модель"])
	_dialog.title = "Выберите .gguf"
	_dialog.file_selected.connect(_start_import)
	add_child(_dialog)
	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.title = "Удалить модель?"
	_delete_confirm.ok_button_text = "Удалить"
	_delete_confirm.cancel_button_text = "Отмена"
	_delete_confirm.confirmed.connect(_confirm_delete_model)
	add_child(_delete_confirm)

func _spin_row(caption: String, key: String, min_v: float, max_v: float, step: float, decimals: int) -> HBoxContainer:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.custom_minimum_size = Vector2(180, 48)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls[key] = spin
	return Kit.field_row(caption, spin)

func _load_values() -> void:
	for key in _controls:
		var c: Control = _controls[key]
		var value: Variant = SettingsManager.get_value(key, 0)
		if c is SpinBox:
			c.value = float(value)
		elif c is CheckBox:
			c.button_pressed = bool(value)
		elif c is OptionButton:
			if key == "kv_type":
				var idx := 1
				if str(value) == "f16":
					idx = 0
				elif str(value) == "q4_0":
					idx = 2
				c.select(idx)
	_provider_option.select(1 if str(SettingsManager.get_value("ai_provider", "local")) == "openrouter" else 0)
	_or_key.text = str(SettingsManager.get_value("openrouter_api_key", ""))
	_or_manual.text = str(SettingsManager.get_value("openrouter_model", ""))
	_scene_font_slider.value = int(SettingsManager.get_value("scene_font_size", 18))
	_ui_font_slider.value = int(SettingsManager.get_value("ui_font_size", 15))
	_line_slider.value = int(SettingsManager.get_value("line_spacing", 4))
	_apply_typography(false)
	_refresh_model_name()

func _apply_typography(persist: bool = true) -> void:
	if _scene_font_slider == null:
		return
	var scene_size := int(_scene_font_slider.value)
	var ui_size := int(_ui_font_slider.value)
	var line := int(_line_slider.value)
	SettingsManager.set_value("scene_font_size", scene_size, false)
	SettingsManager.set_value("ui_font_size", ui_size, false)
	SettingsManager.set_value("line_spacing", line, false)
	if persist:
		SettingsManager.save_settings()
	Palette.apply_typography(theme, ui_size, line)
	if _font_preview != null:
		_font_preview.add_theme_font_size_override("normal_font_size", scene_size)
		_font_preview.add_theme_constant_override("line_separation", line)

func _refresh_model_name() -> void:
	if _model_name == null:
		return
	if str(SettingsManager.get_value("ai_provider", "local")) == "openrouter":
		_model_name.text = "Провайдер: OpenRouter · " + (str(SettingsManager.get_value("openrouter_model", "")) if str(SettingsManager.get_value("openrouter_model", "")) != "" else "модель не выбрана")
		return
	var selected := str(SettingsManager.get_value("model_path", ""))
	var ready := AIConnector.model_path != ""
	if selected == "":
		_model_name.text = "Локальная модель: не выбрана"
	elif ready and AIConnector.model_path == ProjectSettings.globalize_path(selected):
		_model_name.text = "Локальная модель: " + ModelManager.display_name(selected) + " · загружена"
	else:
		_model_name.text = "Локальная модель: " + ModelManager.display_name(selected) + " · выбрана, не загружена"

func _refresh_models() -> void:
	if _models_box == null:
		return
	Kit.clear(_models_box)
	var models := ModelManager.list_models()
	var current := str(SettingsManager.get_value("model_path", ""))
	if models.is_empty():
		var empty := Kit.panel("InsetPanel")
		var box := Kit.vbox(4)
		box.add_child(Kit.label("Моделей нет", 16, Palette.TEXT))
		box.add_child(Kit.small("Импортируйте .gguf или выберите OpenRouter.", Palette.MUTED))
		empty.add_child(box)
		_models_box.add_child(empty)
		_refresh_model_name()
		return
	for m in models:
		_models_box.add_child(_model_row(m, current))
	_refresh_model_status()

func _model_row(m: Dictionary, current: String) -> PanelContainer:
	var p := Kit.panel("InsetPanel")
	var row := Kit.hbox(8)
	p.add_child(row)
	var text := Kit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Kit.label(ModelManager.display_name(str(m.get("name", ""))), 15, Palette.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.clip_text = true
	text.add_child(name)
	var size := float(int(m.get("size", 0))) / 1073741824.0
	var flags: PackedStringArray = ["%.1f ГБ" % size]
	if str(m.get("path", "")) == current:
		flags.append("активна")
	if AIConnector.model_path != "" and AIConnector.model_path == ProjectSettings.globalize_path(str(m.get("path", ""))):
		flags.append("загружена")
	text.add_child(Kit.small(" · ".join(flags), Palette.MUTED))
	row.add_child(text)
	var load := Kit.button("Загрузить", "GhostButton")
	load.custom_minimum_size = Vector2(120, 44)
	load.pressed.connect(_load_model_path.bind(str(m.get("path", ""))))
	row.add_child(load)
	var del := Kit.button("×", "GhostButton")
	del.custom_minimum_size = Vector2(44, 44)
	del.tooltip_text = "Удалить модель"
	del.pressed.connect(_ask_delete_model.bind(str(m.get("path", "")), str(m.get("name", ""))))
	row.add_child(del)
	return p

func _load_model_path(path: String) -> void:
	if AIConnector.busy:
		toast("Сначала дождитесь конца генерации", true)
		return
	_save(false)
	SettingsManager.set_value("ai_provider", "local")
	SettingsManager.set_value("model_path", path)
	_provider_option.select(0)
	AIConnector.unload()
	AIConnector.initialize()
	_refresh_models()
	toast("Загружаю: " + ModelManager.display_name(path))

func _ask_delete_model(path: String, name: String) -> void:
	_pending_delete_path = path
	_delete_confirm.dialog_text = "«%s» будет удалена из user://models. Это действие необратимо." % name
	_delete_confirm.popup_centered(Vector2i(520, 220))

func _confirm_delete_model() -> void:
	if _pending_delete_path == "":
		return
	if AIConnector.busy:
		toast("Сначала дождитесь конца генерации", true)
		return
	var was_loaded := AIConnector.model_path != "" and AIConnector.model_path == ProjectSettings.globalize_path(_pending_delete_path)
	if ModelManager.delete_model(_pending_delete_path):
		if was_loaded:
			AIConnector.unload()
		toast("Модель удалена")
		_refresh_models()
	else:
		toast(ModelManager.last_error, true)
	_pending_delete_path = ""

func _on_model_selected(idx: int) -> void:
	var path := str(_or_model.get_item_metadata(idx)) if idx >= 0 else ""
	if path != "":
		_or_manual.text = path
		SettingsManager.set_value("openrouter_model", path)

func _on_provider_selected(idx: int) -> void:
	SettingsManager.set_value("ai_provider", "openrouter" if idx == 1 else "local")
	_or_status.text = "Провайдер: OpenRouter" if idx == 1 else "Провайдер: локальная модель"
	_refresh_model_status()
	if idx == 1 and OpenRouterClient.api_key() != "":
		OpenRouterClient.fetch_models()

func _test_openrouter() -> void:
	SettingsManager.set_value("openrouter_api_key", _or_key.text.strip_edges())
	if _or_key.text.strip_edges() == "":
		_or_status.text = "Сначала введите API-ключ"
		_or_status.add_theme_color_override("font_color", Palette.DANGER)
		return
	_or_status.text = "Запрашиваю список бесплатных моделей…"
	_or_status.add_theme_color_override("font_color", Palette.WARN)
	OpenRouterClient.fetch_models()

func _on_or_models_loaded(models: Array) -> void:
	_or_model.clear()
	var current := str(SettingsManager.get_value("openrouter_model", ""))
	for i in range(models.size()):
		var m: Dictionary = models[i]
		_or_model.add_item("%s (%dK)" % [str(m.get("name", m.get("id", ""))), int(m.get("context", 0)) / 1000], i)
		_or_model.set_item_metadata(i, str(m.get("id", "")))
		if str(m.get("id", "")) == current:
			_or_model.select(i)
	_or_status.text = "Бесплатных текстовых моделей: %d. Список может меняться." % models.size()
	_or_status.add_theme_color_override("font_color", Palette.OK)

func _on_or_models_failed(message: String) -> void:
	_or_status.text = message + " Можно ввести id модели вручную."
	_or_status.add_theme_color_override("font_color", Palette.DANGER)

func _save_and_reload() -> void:
	_save(false)
	if AIConnector.busy:
		toast("Сначала дождитесь конца генерации", true)
		return
	AIConnector.unload()
	AIConnector.initialize()
	toast("Настройки сохранены, модель перезагружается")

func _save(show_toast: bool = true) -> void:
	var values: Dictionary = {}
	for key in _controls:
		var c: Control = _controls[key]
		if c is SpinBox:
			var v: float = (c as SpinBox).value
			var is_float: bool = key in ["temperature", "top_p", "min_p", "repeat_penalty", "frequency_penalty", "presence_penalty"]
			values[key] = v if is_float else int(roundf(v))
		elif c is CheckBox:
			values[key] = c.button_pressed
		elif c is OptionButton:
			var idx := (c as OptionButton).selected
			if key == "kv_type":
				values[key] = ["f16", "q8_0", "q4_0"][idx]
	values["ai_provider"] = "openrouter" if _provider_option.selected == 1 else "local"
	values["openrouter_api_key"] = _or_key.text.strip_edges()
	var manual := _or_manual.text.strip_edges()
	if manual != "":
		values["openrouter_model"] = manual
	elif _or_model.item_count > 0 and _or_model.selected >= 0:
		values["openrouter_model"] = str(_or_model.get_item_metadata(_or_model.selected))
	SettingsManager.set_many(values)
	if show_toast:
		toast("Настройки сохранены")
	_refresh_models()

func _on_light_toggled(on: bool) -> void:
	if not on:
		return
	(_controls["n_ctx"] as SpinBox).value = 2048
	(_controls["max_tokens"] as SpinBox).value = 256
	(_controls["threads"] as SpinBox).value = 4

func _refresh_model_status() -> void:
	if _model_status == null:
		return
	var text := ""
	var color := Palette.MUTED
	if AIConnector.is_openrouter():
		if AIConnector.is_ready():
			text = "Облако: OpenRouter готов"
			color = Palette.BLUE
		elif AIConnector.last_error != "":
			text = "Облако: ошибка · " + AIConnector.last_error
			color = Palette.DANGER
		else:
			text = "Облако: не настроено"
	else:
		var selected := str(SettingsManager.get_value("model_path", ""))
		var loaded := AIConnector.model_path != "" and selected != "" and AIConnector.model_path == ProjectSettings.globalize_path(selected)
		if AIConnector.loading:
			var pct := AIConnector.load_percent
			text = "Загружается: %d%%" % pct if pct > 0 else "Загружается…"
			color = Palette.WARN
		elif AIConnector.is_ready() and loaded:
			text = "Загружена: " + selected.get_file()
			color = Palette.OK
		elif AIConnector.last_error != "":
			text = "Ошибка: " + AIConnector.last_error
			color = Palette.DANGER
		elif selected != "":
			text = "Выбрана, но не загружена: " + selected.get_file()
			color = Palette.WARN
		else:
			text = "Модель не выбрана"
	_model_status.text = text
	_model_status.add_theme_color_override("font_color", color)
	_refresh_model_name()

func _on_ai_status(_text: String) -> void:
	_refresh_model_status()

func _on_load_progress(_percent: int) -> void:
	_refresh_model_status()

func _on_model_loaded(_path: String) -> void:
	_refresh_model_status()
	_refresh_models()

func _on_model_failed(message: String) -> void:
	_model_status.text = message
	_model_status.add_theme_color_override("font_color", Palette.DANGER)

func _open_import() -> void:
	_dialog.popup_centered_ratio(0.8)

func _start_import(src: String) -> void:
	if not src.to_lower().ends_with(".gguf"):
		toast("Нужен файл .gguf", true)
		return
	var base := _clean_model_name(src)
	var dst := "user://models/" + base
	DirAccess.make_dir_recursive_absolute("user://models")
	if FileAccess.file_exists(dst) and _file_size(dst) == _file_size(src):
		toast("Этот файл уже импортирован")
		_refresh_models()
		return
	_import_src = src
	_import_dst = dst
	_import_progress = 0
	_import_done = false
	_import_error = ""
	_importing = true
	_import_label.text = "Импорт: 0%"
	_import_thread = Thread.new()
	_import_thread.start(_import_worker)

func _import_worker() -> void:
	var f := FileAccess.open(_import_src, FileAccess.READ)
	if f == null:
		_import_error = "Не удалось открыть файл"
		_import_done = true
		return
	var total := f.get_length()
	var tmp := _import_dst + ".part"
	var out := FileAccess.open(tmp, FileAccess.WRITE)
	if out == null:
		f.close()
		_import_error = "Не удалось создать файл в user://models"
		_import_done = true
		return
	var written := 0
	var last := -1
	while written < total:
		var buf := f.get_buffer(4 * 1024 * 1024)
		if buf.is_empty():
			break
		out.store_buffer(buf)
		written += buf.size()
		var pct := int(float(written) * 100.0 / float(total))
		if pct != last:
			last = pct
			call_deferred("_set_import_progress", pct)
	f.close()
	out.close()
	if written != total:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		_import_error = "Копирование прервалось"
		_import_done = true
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_import_dst))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(_import_dst))
	if err != OK:
		_import_error = "Не удалось переименовать файл"
		_import_done = true
		return
	_import_done = true

func _clean_model_name(path: String) -> String:
	var decoded := path.uri_decode().get_file()
	decoded = decoded.strip_edges()
	if decoded.to_lower().ends_with(".gguf"):
		decoded = decoded.substr(0, decoded.length() - 5)
	var out := ""
	for ch in decoded:
		var code := ch.unicode_at(0)
		if code < 32 or ch in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|", "%"]:
			out += "_"
		else:
			out += ch
	out = out.strip_edges()
	while out.contains("__"):
		out = out.replace("__", "_")
	if out == "":
		out = "model"
	return out + ".gguf"

func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size

func _set_import_progress(pct: int) -> void:
	_import_progress = pct
	_import_label.text = "Импорт: %d%%" % pct

func _process(_delta: float) -> void:
	if not _importing:
		return
	if _import_done:
		_importing = false
		if _import_thread != null:
			_import_thread.wait_to_finish()
			_import_thread = null
		if _import_error != "":
			_import_label.text = _import_error
			toast(_import_error, true)
		else:
			SettingsManager.set_value("model_path", _import_dst)
			SettingsManager.set_value("ai_provider", "local")
			_provider_option.select(0)
			_import_label.text = "Импортировано: " + _import_dst.get_file()
			toast("Модель импортирована. Нажмите «Загрузить» у неё в списке.")
			_refresh_models()
			_refresh_model_status()

func _refresh_ram() -> void:
	if _ram_bar == null:
		return
	var ram := RamMonitor.get_ram()
	if not bool(ram.get("valid", false)):
		_ram_bar.value = 0
		_ram_label.text = "RAM: —"
		_ram_hint.text = "Нет данных /proc/meminfo."
		return
	var path := str(SettingsManager.get_value("model_path", ""))
	var n_ctx := int(SettingsManager.get_value("n_ctx", 4096))
	var footprint := RamMonitor.estimate_footprint_mb(path, n_ctx)
	_ram_bar.max_value = maxf(1.0, float(ram.get("total_mb", 1)))
	_ram_bar.value = float(ram.get("used_mb", 0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = RamMonitor.color_for_free()
	fill.set_corner_radius_all(6)
	_ram_bar.add_theme_stylebox_override("fill", fill)
	_ram_label.text = "Занято %s из %s · свободно %s" % [
		RamMonitor.format_gb(int(ram.get("used_mb", 0))),
		RamMonitor.format_gb(int(ram.get("total_mb", 0))),
		RamMonitor.format_gb(int(ram.get("available_mb", 0))),
	]
	_ram_hint.text = "Модель + контекст: около %s. %s" % [RamMonitor.format_mb(footprint), RamMonitor.suggestion(path, n_ctx)]
	_ram_hint.add_theme_color_override("font_color", Palette.DANGER if RamMonitor.is_risky(footprint) else Palette.MUTED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_save(false)
		go("res://scenes/main_menu.tscn")
