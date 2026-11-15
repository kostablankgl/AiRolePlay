extends Node

signal models_loaded(models: Array)
signal models_failed(message: String)
signal chat_finished(text: String)
signal chat_failed(message: String)

const MODELS_URL := "https://openrouter.ai/api/v1/models"
const CHAT_URL := "https://openrouter.ai/api/v1/chat/completions"

var _models_http: HTTPRequest
var _chat_http: HTTPRequest
var _fetching_models := false
var _chatting := false

func _ready() -> void:
	_models_http = HTTPRequest.new()
	_models_http.timeout = 30.0
	add_child(_models_http)
	_models_http.request_completed.connect(_on_models_completed)
	_chat_http = HTTPRequest.new()
	_chat_http.timeout = 120.0
	add_child(_chat_http)
	_chat_http.request_completed.connect(_on_chat_completed)

func api_key() -> String:
	return str(SettingsManager.get_value("openrouter_api_key", "")).strip_edges()

func fetch_models() -> bool:
	if _fetching_models:
		return false
	_fetching_models = true
	var headers := PackedStringArray([
		"Accept: application/json",
		"HTTP-Referer: https://hefesto.local/airoleplay",
		"X-Title: AiRolePlay",
	])
	if api_key() != "":
		headers.append("Authorization: Bearer " + api_key())
	var err := _models_http.request(MODELS_URL, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_fetching_models = false
		models_failed.emit("Не удалось начать запрос к OpenRouter (код %d)" % err)
		return false
	return true

func _on_models_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_fetching_models = false
	if result != HTTPRequest.RESULT_SUCCESS:
		models_failed.emit("Нет связи с OpenRouter (код %d)" % result)
		return
	if response_code != 200:
		models_failed.emit(_http_error("OpenRouter", response_code, body))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		models_failed.emit("OpenRouter вернул непонятный список моделей")
		return
	var out: Array = []
	for m_v in parsed.get("data", []):
		if not (m_v is Dictionary):
			continue
		var m: Dictionary = m_v
		var pricing: Dictionary = m.get("pricing", {})
		var prompt_price := float(str(pricing.get("prompt", "1")))
		var completion_price := float(str(pricing.get("completion", "1")))
		if prompt_price > 0.0 or completion_price > 0.0:
			continue
		var arch: Dictionary = m.get("architecture", {})
		var inputs: Array = arch.get("input_modalities", [])
		var outputs: Array = arch.get("output_modalities", [])
		if not inputs.is_empty() and not inputs.has("text"):
			continue
		if not outputs.is_empty() and not outputs.has("text"):
			continue
		out.append({
			"id": str(m.get("id", "")),
			"name": str(m.get("name", m.get("id", ""))),
			"context": int(m.get("context_length", 0)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]).to_lower() < str(b["name"]).to_lower())
	models_loaded.emit(out)

func chat(messages: Array, params: Dictionary) -> bool:
	if _chatting:
		return false
	var key := api_key()
	if key == "":
		chat_failed.emit("Не задан API-ключ OpenRouter")
		return false
	var model := str(SettingsManager.get_value("openrouter_model", "")).strip_edges()
	if model == "":
		chat_failed.emit("Не выбрана модель OpenRouter")
		return false
	var body := {
		"model": model,
		"messages": messages,
		"temperature": float(params.get("temperature", 0.72)),
		"top_p": float(params.get("top_p", 0.9)),
		"max_tokens": int(params.get("max_tokens", 380)),
		"frequency_penalty": float(params.get("frequency_penalty", 0.0)),
		"presence_penalty": float(params.get("presence_penalty", 0.0)),
		"stream": false,
	}
	if int(params.get("seed", -1)) >= 0:
		body["seed"] = int(params.get("seed", -1))
	_chatting = true
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"HTTP-Referer: https://hefesto.local/airoleplay",
		"X-Title: AiRolePlay",
		"Authorization: Bearer " + key,
	])
	var err := _chat_http.request(CHAT_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_chatting = false
		chat_failed.emit("Не удалось начать запрос к OpenRouter (код %d)" % err)
		return false
	return true

func _on_chat_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_chatting = false
	if result != HTTPRequest.RESULT_SUCCESS:
		chat_failed.emit("Нет связи с OpenRouter (код %d)" % result)
		return
	if response_code != 200:
		chat_failed.emit(_http_error("OpenRouter", response_code, body))
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		chat_failed.emit("OpenRouter вернул непонятный ответ")
		return
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty() or not (choices[0] is Dictionary):
		chat_failed.emit("OpenRouter не вернул вариантов ответа")
		return
	var message: Variant = choices[0].get("message", {})
	var content: Variant = message.get("content", "") if message is Dictionary else ""
	if content is Array:
		var parts: PackedStringArray = []
		for part in content:
			if part is Dictionary:
				parts.append(str(part.get("text", "")))
		content = "\n".join(parts)
	var text := str(content)
	if text.strip_edges() == "":
		chat_failed.emit("OpenRouter вернул пустой ответ")
		return
	chat_finished.emit(text)

func cancel_chat() -> void:
	if _chat_http != null and _chatting:
		_chat_http.cancel_request()
		_chatting = false

func _http_error(service: String, code: int, body: PackedByteArray) -> String:
	var detail := ""
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		var err: Variant = parsed.get("error", {})
		if err is Dictionary:
			detail = str(err.get("message", ""))
		elif err is String:
			detail = str(err)
	match code:
		401:
			return "OpenRouter: неверный API-ключ"
		402:
			return "OpenRouter: закончились кредиты или модель платная"
		403:
			return "OpenRouter: доступ запрещён" + (" (" + detail + ")" if detail != "" else "")
		429:
			return "OpenRouter: слишком много запросов, попробуйте позже"
	return "%s: HTTP %d%s" % [service, code, (" — " + detail if detail != "" else "")]
