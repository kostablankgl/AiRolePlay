extends "res://ui/screen_base.gd"

var _model_status: Label
var _model_name: Label
var _model_option: OptionButton
var _import_label: Label
var _ram_bar: ProgressBar
var _ram_label: Label
var _ram_hint: Label
var _advanced: VBoxContainer
var _advanced_toggle: CheckBox
var _controls: Dictionary = {}
var _dialog: FileDialog
var _import_thread: Thread
var _import_src: String = ""
var _import_dst: String = ""
var _import_progress: int = 0
var _import_done: bool = false
var _import_error: String = ""
var _importing: bool = false

func _ready() -> void:
	_build()
	_load_values()
	AIConnector.status_changed.connect(_on_ai_status)
	AIConnector.model_loaded.connect(_on_model_loaded)
	AIConnector.model_failed.connect(_on_model_failed)
	RamMonitor.updated.connect(_refresh_ram)
	_refresh_models()
	_refresh_ram()
	_on_ai_status("Модель готова" if AIConnector.is_ready() else "Модель не загружена")

func _build() -> void:
	var outer := setup_page()
	outer.add_child(header("Настройки", "res://scenes/main_menu.tscn"))
	var sc := Kit.scroll()
	outer.add_child(sc)
	var page := Kit.vbox(12)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(page)

	var model := Kit.panel("CardPanel")
	var mb := Kit.vbox(8)
	model.add_child(mb)
	mb.add_child(Kit.label("Модель", 22, Palette.GOLD))
	_model_name = Kit.label("", 16, Palette.TEXT, true)
	mb.add_child(_model_name)
	_model_status = Kit.small("", Palette.MUTED)
	mb.add_child(_model_status)
	var mrow := Kit.hbox(8)
	_model_option = OptionButton.new()
	_model_option.custom_minimum_size = Vector2(0, 50)
	_model_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_option.item_selected.connect(_on_model_selected)
	mrow.add_child(_model_option)
	var import := Kit.button("Импортировать .gguf", "GhostButton")
	import.custom_minimum_size = Vector2(190, 50)
	import.pressed.connect(_open_import)
	mrow.add_child(import)
	var load := Kit.button("Загрузить", "AccentButton")
	load.custom_minimum_size = Vector2(130, 50)
	load.pressed.connect(_load_model)
	mrow.add_child(load)
	var unload := Kit.button("Выгрузить", "GhostButton")
	unload.custom_minimum_size = Vector2(130, 50)
	unload.pressed.connect(func() -> void:
		AIConnector.unload()
	)
	mrow.add_child(unload)
	mb.add_child(mrow)
	_import_label = Kit.small("", Palette.MUTED)
	mb.add_child(_import_label)
	mb.add_child(Kit.small("Встроенная модель лежит в APK. При первом запуске она распаковывается в user://models. Другие .gguf можно положить туда же.", Palette.MUTED))
	page.add_child(model)

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

	var gen := Kit.panel("CardPanel")
	var gb := Kit.vbox(8)
	gen.add_child(gb)
	gb.add_child(Kit.label("Генерация", 22, Palette.GOLD))
	gb.add_child(_spin_row("Контекст (n_ctx)", "n_ctx", 1024, 8192, 128, 0))
	gb.add_child(_spin_row("Потоки", "threads", 1, 8, 1, 0))
	gb.add_child(_spin_row("Температура", "temperature", 0.0, 2.0, 0.05, 2))
	gb.add_child(_spin_row("Top-p", "top_p", 0.01, 1.0, 0.01, 2))
	gb.add_child(_spin_row("Top-k", "top_k", 0, 200, 1, 0))
	gb.add_child(_spin_row("Min-p", "min_p", 0.0, 1.0, 0.01, 2))
	gb.add_child(_spin_row("Штраф повторов", "repeat_penalty", 0.8, 2.0, 0.01, 2))
	gb.add_child(_spin_row("Макс. токенов ответа", "max_tokens", 64, 1024, 32, 0))
	var stream := CheckBox.new()
	stream.text = "Показывать текст по мере генерации"
	stream.button_pressed = true
	_controls["streaming"] = stream
	gb.add_child(stream)
	var light := CheckBox.new()
	light.text = "Лёгкий режим: короче контекст и ответы"
	light.toggled.connect(_on_light_toggled)
	_controls["light_mode"] = light
	gb.add_child(light)

	_advanced_toggle = CheckBox.new()
	_advanced_toggle.text = "Дополнительно"
	_advanced_toggle.toggled.connect(func(on: bool) -> void: _advanced.visible = on)
	gb.add_child(_advanced_toggle)
	_advanced = Kit.vbox(8)
	_advanced.visible = false
	gb.add_child(_advanced)
	_advanced.add_child(_spin_row("Batch (n_batch)", "n_batch", 32, 1024, 32, 0))
	_advanced.add_child(_spin_row("Штраф: последние N", "penalty_last_n", -1, 1024, 16, 0))
	_advanced.add_child(_spin_row("Frequency penalty", "frequency_penalty", -1.0, 2.0, 0.05, 2))
	_advanced.add_child(_spin_row("Presence penalty", "presence_penalty", -1.0, 2.0, 0.05, 2))
	_advanced.add_child(_spin_row("Seed (-1 = случайный)", "seed", -1, 2147483647, 1, 0))
	var mmap := CheckBox.new()
	mmap.text = "mmap (экономит RAM, рекомендуется)"
	_controls["use_mmap"] = mmap
	_advanced.add_child(mmap)
	var mlock := CheckBox.new()
	mlock.text = "mlock (держать модель в RAM)"
	_controls["use_mlock"] = mlock
	_advanced.add_child(mlock)
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

func _spin_row(caption: String, key: String, min_v: float, max_v: float, step: float, decimals: int) -> HBoxContainer:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	if decimals > 0:
		spin.suffix = ""
		spin.custom_arrow_step = step
	spin.custom_minimum_size = Vector2(180, 50)
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
	var path := str(SettingsManager.get_value("model_path", ""))
	_model_name.text = "Встроенная модель: " + ModelManager.model_name() if path == "" else "Своя модель: " + path.get_file()

func _refresh_models() -> void:
	_model_option.clear()
	_model_option.add_item("Встроенная модель (APK)", 0)
	_model_option.set_item_metadata(0, "")
	var current := str(SettingsManager.get_value("model_path", ""))
	var dir := DirAccess.open("user://models")
	var index := 0
	if dir != null:
		for f in dir.get_files():
			if not f.to_lower().ends_with(".gguf"):
				continue
			index += 1
			var rel := "user://models/" + f
			_model_option.add_item(f, index)
			_model_option.set_item_metadata(index, rel)
			if rel == current:
				_model_option.select(index)
	if current == "":
		_model_option.select(0)

func _on_model_selected(idx: int) -> void:
	var path := str(_model_option.get_item_metadata(idx))
	SettingsManager.set_value("model_path", path)
	_model_name.text = "Встроенная модель: " + ModelManager.model_name() if path == "" else "Своя модель: " + path.get_file()
	toast("Модель выбрана. Нажмите «Сохранить и перезагрузить».")

func _load_model() -> void:
	_save(false)
	if AIConnector.busy:
		toast("Сначала дождитесь конца генерации", true)
		return
	AIConnector.initialize()

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
	SettingsManager.set_many(values)
	if show_toast:
		toast("Настройки сохранены")

func _on_light_toggled(on: bool) -> void:
	if not on:
		return
	(_controls["n_ctx"] as SpinBox).value = 2048
	(_controls["max_tokens"] as SpinBox).value = 256
	(_controls["threads"] as SpinBox).value = 4

func _on_ai_status(text: String) -> void:
	_model_status.text = text
	var color := Palette.MUTED
	if AIConnector.is_ready():
		color = Palette.OK
	elif text.to_lower().contains("ошиб") or text.to_lower().contains("не "):
		color = Palette.DANGER
	_model_status.add_theme_color_override("font_color", color)

func _on_model_loaded(path: String) -> void:
	_model_status.text = "Загружена: " + path.get_file()
	_model_status.add_theme_color_override("font_color", Palette.OK)

func _on_model_failed(message: String) -> void:
	_model_status.text = message
	_model_status.add_theme_color_override("font_color", Palette.DANGER)

func _open_import() -> void:
	_dialog.popup_centered_ratio(0.8)

func _start_import(src: String) -> void:
	if not src.to_lower().ends_with(".gguf"):
		toast("Нужен файл .gguf", true)
		return
	var base := src.get_file()
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
			_import_label.text = "Импортировано: " + _import_dst.get_file()
			toast("Модель импортирована. Нажмите «Сохранить и перезагрузить».")
			_refresh_models()
			_model_name.text = "Своя модель: " + _import_dst.get_file()

func _refresh_ram() -> void:
	if _ram_bar == null:
		return
	var path := str(SettingsManager.get_value("model_path", ""))
	var probe := path if path != "" else "embedded_qwen2.5-3b"
	var n_ctx := int(SettingsManager.get_value("n_ctx", 4096))
	var footprint := RamMonitor.estimate_footprint_mb(probe, n_ctx)
	_ram_bar.max_value = maxf(1.0, float(RamMonitor.total_mb))
	_ram_bar.value = float(RamMonitor.total_used_mb())
	_ram_label.text = "Занято %s из %s · свободно %s" % [RamMonitor.format_gb(RamMonitor.total_used_mb()), RamMonitor.format_gb(RamMonitor.total_mb), RamMonitor.format_gb(RamMonitor.available_mb)]
	_ram_hint.text = "Модель + контекст: около %s. %s" % [RamMonitor.format_mb(footprint), RamMonitor.suggestion(probe, n_ctx)]
	_ram_hint.add_theme_color_override("font_color", Palette.DANGER if RamMonitor.is_risky(footprint) else Palette.MUTED)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_save(false)
		go("res://scenes/main_menu.tscn")
