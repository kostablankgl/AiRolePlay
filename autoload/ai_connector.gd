extends Node

signal status_changed(text: String)
signal load_started
signal model_loaded(path: String)
signal model_failed(message: String)
signal copy_progress(percent: int)
signal generation_started
signal token_received(token: String)
signal generation_finished(text: String)
signal generation_failed(message: String)
signal busy_changed(is_busy: bool)
signal load_progress(percent: int)

var model: Object
var context: Object
var model_path: String = ""
var loading: bool = false
var busy: bool = false
var last_error: String = ""
var prompt_tokens: int = 0
var first_token_ms: int = 0
var generation_ms: int = 0
var last_tok_s: float = 0.0
var load_percent: int = 0

var _load_thread: Thread
var _gen_thread: Thread
var _load_done: bool = false
var _load_error: int = OK
var _load_path: String = ""
var _load_params: Dictionary = {}
var _mutex := Mutex.new()
var _tokens: Array = []
var _done: bool = false
var _result: String = ""
var _error: String = ""
var _streaming: bool = false
var _started_ms: int = 0
var _stop_requested: bool = false
var _finalized: bool = false
var _gen_params: Dictionary = {}
var _connected_models: bool = false

func _ready() -> void:
	OpenRouterClient.chat_finished.connect(_on_openrouter_finished)
	OpenRouterClient.chat_failed.connect(_on_openrouter_failed)
	if not _connected_models:
		ModelManager.model_ready.connect(_on_model_ready)
		ModelManager.model_error.connect(_on_model_error)
		ModelManager.copy_progress.connect(_on_copy_progress)
		_connected_models = true

func _process(_delta: float) -> void:
	if loading and _load_done:
		_finish_load()
	if busy:
		_drain_generation()

func provider() -> String:
	return str(SettingsManager.get_value("ai_provider", "local"))

func is_openrouter() -> bool:
	return provider() == "openrouter"

func is_ready() -> bool:
	if is_openrouter():
		return str(SettingsManager.get_value("openrouter_api_key", "")) != "" and str(SettingsManager.get_value("openrouter_model", "")) != ""
	if model == null or context == null:
		return false
	if not model.is_loaded():
		return false
	return context.is_initialized()

func model_label() -> String:
	if is_openrouter():
		var m := str(SettingsManager.get_value("openrouter_model", ""))
		return "OpenRouter: " + (m if m != "" else "не выбрана")
	if model_path == "":
		return "Модель не загружена"
	return model_path.get_file()

func initialize() -> void:
	if loading or busy:
		return
	if is_openrouter():
		if is_ready():
			last_error = ""
			status_changed.emit("OpenRouter готов")
			model_loaded.emit("openrouter:" + str(SettingsManager.get_value("openrouter_model", "")))
		else:
			_fail_load("Укажите API-ключ и бесплатную модель OpenRouter в настройках")
		return
	if is_ready():
		status_changed.emit("Модель готова")
		model_loaded.emit(model_path)
		return
	last_error = ""
	var custom := str(SettingsManager.get_value("model_path", ""))
	if custom != "":
		if FileAccess.file_exists(custom):
			_start_model_load(custom)
			return
		status_changed.emit("Файл модели не найден, ищу другую…")
	var first := ModelManager.active_model()
	if first != "":
		SettingsManager.set_value("model_path", first)
		_start_model_load(first)
		return
	status_changed.emit("Подготавливаю модель...")
	ModelManager.prepare()

func _on_copy_progress(percent: int) -> void:
	load_percent = percent
	status_changed.emit("Распаковываю модель в память телефона: %d%%" % percent)
	load_progress.emit(percent)
	copy_progress.emit(percent)

func _on_model_ready(path: String) -> void:
	_start_model_load(path)

func _on_model_error(message: String) -> void:
	last_error = message
	loading = false
	status_changed.emit(message)
	model_failed.emit(message)

func _start_model_load(path: String) -> void:
	if loading or busy:
		return
	if not ClassDB.class_exists("LlamaModel") or not ClassDB.class_exists("LlamaContext"):
		_fail_load("GDExtension llama не загрузилось. Проверьте lib/arm64-v8a в APK.")
		return
	var load_path := path
	if load_path.begins_with("user://") or load_path.begins_with("res://"):
		load_path = ProjectSettings.globalize_path(load_path)
	if model != null or context != null:
		_unload_local()
	model = ClassDB.instantiate("LlamaModel")
	if model == null:
		_fail_load("Не удалось создать LlamaModel")
		return
	loading = true
	_load_done = false
	_load_error = OK
	_load_path = load_path
	_load_params = SettingsManager.model_params()
	load_percent = 0
	last_error = ""
	status_changed.emit("Загружаю модель: " + load_path.get_file())
	load_progress.emit(0)
	load_started.emit()
	_load_thread = Thread.new()
	_load_thread.start(_load_worker)

func _load_worker() -> void:
	_load_error = model.load(_load_path, _load_params)
	_load_done = true

func _finish_load() -> void:
	loading = false
	if _load_thread != null:
		_load_thread.wait_to_finish()
		_load_thread = null
	_load_done = false
	if _load_error != OK:
		model = null
		_fail_load("Модель не загрузилась (код %d). Файл повреждён или не хватает памяти." % _load_error)
		return
	context = ClassDB.instantiate("LlamaContext")
	if context == null:
		model = null
		_fail_load("Не удалось создать LlamaContext")
		return
	context.token_generated.connect(_on_token)
	context.generation_finished.connect(_on_generation_finished)
	context.generation_error.connect(_on_generation_error)
	var err: int = context.create(model, SettingsManager.context_params())
	if err != OK:
		context = null
		model.unload()
		model = null
		_fail_load("Не удалось создать контекст (код %d). Уменьшите n_ctx в настройках." % err)
		return
	model_path = _load_path
	busy = false
	load_percent = 100
	load_progress.emit(100)
	status_changed.emit("Модель готова")
	model_loaded.emit(model_path)

func _fail_load(message: String) -> void:
	last_error = message
	loading = false
	status_changed.emit(message)
	model_failed.emit(message)

func _unload_local() -> void:
	if context != null:
		context = null
	if model != null:
		model.unload()
	model = null
	model_path = ""

func unload() -> void:
	if busy:
		cancel()
		return
	_unload_local()
	load_percent = 0
	status_changed.emit("Модель выгружена")

func generate(prompt: String, opts: Dictionary = {}) -> bool:
	if busy:
		return false
	if is_openrouter():
		return _generate_openrouter(prompt, opts)
	if not is_ready():
		generation_failed.emit("Модель ещё не готова")
		return false
	var max_tokens := int(SettingsManager.get_value("max_tokens", 380))
	if opts.has("max_tokens"):
		max_tokens = int(opts["max_tokens"])
	var n_ctx := int(SettingsManager.get_value("n_ctx", 4096))
	var tokens: int = int(model.tokenize(prompt, false).size())
	prompt_tokens = tokens
	if tokens >= n_ctx - 32:
		generation_failed.emit("Промпт не помещается в контекст (%d из %d токенов). Уменьшите n_ctx? Нет: увеличьте контекст или сократите историю." % [tokens, n_ctx])
		return false
	_mutex.lock()
	_tokens.clear()
	_done = false
	_result = ""
	_error = ""
	_finalized = false
	_mutex.unlock()
	_stop_requested = false
	_streaming = bool(SettingsManager.get_value("streaming", true))
	_gen_params = SettingsManager.generation_params()
	_started_ms = Time.get_ticks_msec()
	first_token_ms = 0
	generation_ms = 0
	busy = true
	busy_changed.emit(true)
	generation_started.emit()
	status_changed.emit("Модель думает...")
	_gen_thread = Thread.new()
	_gen_thread.start(_generate_worker.bind(prompt, max_tokens))
	return true

func _generate_worker(prompt: String, max_tokens: int) -> void:
	var params := _gen_params.duplicate(true)
	params["max_tokens"] = max_tokens
	params["reuse_kv"] = false
	context.set_prompt(prompt)
	var text := ""
	if _streaming:
		text = context.generate_stream(max_tokens, params)
	else:
		text = context.generate(max_tokens, params)
	_mutex.lock()
	if not _done:
		_result = text
		_done = true
	_mutex.unlock()

func _on_token(token_text: String, _token_id: int) -> void:
	_mutex.lock()
	_tokens.append(token_text)
	var first := first_token_ms
	_mutex.unlock()
	if first == 0 and token_text != "":
		first_token_ms = Time.get_ticks_msec() - _started_ms

func _on_generation_finished(full_text: String) -> void:
	_mutex.lock()
	_result = full_text
	_done = true
	_mutex.unlock()

func _on_generation_error(message: String) -> void:
	_mutex.lock()
	_error = message
	_done = true
	_mutex.unlock()

func _drain_generation() -> void:
	var to_emit: Array = []
	_mutex.lock()
	to_emit = _tokens.duplicate()
	_tokens.clear()
	var done := _done
	var result := _result
	var err := _error
	_mutex.unlock()
	for t in to_emit:
		token_received.emit(str(t))
	if not done:
		return
	if _finalized:
		return
	_finalized = true
	if _gen_thread != null:
		_gen_thread.wait_to_finish()
		_gen_thread = null
	busy = false
	busy_changed.emit(false)
	generation_ms = Time.get_ticks_msec() - _started_ms
	if err != "" or _stop_requested:
		var msg := err if err != "" else "Генерация остановлена"
		last_error = msg
		status_changed.emit(msg)
		generation_failed.emit(msg)
		return
	if result.strip_edges() == "":
		last_error = "Модель вернула пустой ответ"
		status_changed.emit(last_error)
		generation_failed.emit(last_error)
		return
	last_tok_s = float(maxi(1, token_count(result))) / maxf(0.1, float(generation_ms) / 1000.0)
	status_changed.emit("Готово")
	generation_finished.emit(result)

func cancel() -> void:
	if not busy:
		return
	_stop_requested = true
	if is_openrouter():
		OpenRouterClient.cancel_chat()
		busy = false
		busy_changed.emit(false)
		generation_failed.emit("Генерация остановлена")
		return
	if context != null:
		context.cancel()
	status_changed.emit("Останавливаю...")

func _generate_openrouter(prompt: String, opts: Dictionary) -> bool:
	if not is_ready():
		generation_failed.emit("Укажите API-ключ и модель OpenRouter")
		return false
	var messages: Array = opts.get("messages", [])
	if messages.is_empty():
		messages = [{ "role": "user", "content": prompt }]
	_mutex.lock()
	_tokens.clear()
	_done = false
	_result = ""
	_error = ""
	_finalized = false
	_mutex.unlock()
	_stop_requested = false
	_started_ms = Time.get_ticks_msec()
	first_token_ms = 0
	generation_ms = 0
	last_tok_s = 0.0
	busy = true
	busy_changed.emit(true)
	generation_started.emit()
	status_changed.emit("OpenRouter думает...")
	OpenRouterClient.chat(messages, SettingsManager.generation_params())
	return true

func _on_openrouter_finished(text: String) -> void:
	if not is_openrouter():
		return
	generation_ms = Time.get_ticks_msec() - _started_ms
	busy = false
	busy_changed.emit(false)
	if _stop_requested:
		generation_failed.emit("Генерация остановлена")
		return
	if text.strip_edges() == "":
		generation_failed.emit("Модель вернула пустой ответ")
		return
	last_tok_s = float(maxi(1, int(text.length() / 2.4))) / maxf(0.1, float(generation_ms) / 1000.0)
	token_received.emit(text)
	status_changed.emit("Готово")
	generation_finished.emit(text)

func _on_openrouter_failed(message: String) -> void:
	if not is_openrouter():
		return
	generation_ms = Time.get_ticks_msec() - _started_ms
	busy = false
	last_error = message
	busy_changed.emit(false)
	status_changed.emit(message)
	generation_failed.emit(message)

func token_count(text: String) -> int:
	if is_openrouter() or model == null or not model.is_loaded():
		return int(text.length() / 2.4)
	return model.tokenize(text, false).size()
