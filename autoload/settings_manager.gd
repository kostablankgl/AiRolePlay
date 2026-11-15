extends Node

signal changed(key: String, value: Variant)

const PATH := "user://settings.json"

const DEFAULTS := {
	"model_path": "",
	"n_ctx": 4096,
	"threads": 5,
	"n_batch": 256,
	"temperature": 0.72,
	"top_p": 0.9,
	"top_k": 40,
	"min_p": 0.05,
	"repeat_penalty": 1.08,
	"frequency_penalty": 0.1,
	"presence_penalty": 0.1,
	"penalty_last_n": 128,
	"max_tokens": 380,
	"seed": -1,
	"streaming": true,
	"use_mmap": true,
	"use_mlock": false,
	"light_mode": false,
	"auto_unload_pause": false,
	"show_ram": true,
}

var data: Dictionary = {}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	data = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					data[k] = parsed[k]
	_sanitize()
	if not FileAccess.file_exists(PATH):
		save_settings()

func _sanitize() -> void:
	data["n_ctx"] = clampi(int(data.get("n_ctx", 4096)), 1024, 8192)
	data["threads"] = clampi(int(data.get("threads", 5)), 1, 12)
	data["n_batch"] = clampi(int(data.get("n_batch", 256)), 32, 1024)
	data["temperature"] = clampf(float(data.get("temperature", 0.72)), 0.0, 2.0)
	data["top_p"] = clampf(float(data.get("top_p", 0.9)), 0.01, 1.0)
	data["top_k"] = clampi(int(data.get("top_k", 40)), 0, 200)
	data["min_p"] = clampf(float(data.get("min_p", 0.05)), 0.0, 1.0)
	data["repeat_penalty"] = clampf(float(data.get("repeat_penalty", 1.08)), 0.8, 2.0)
	data["frequency_penalty"] = clampf(float(data.get("frequency_penalty", 0.1)), -1.0, 2.0)
	data["presence_penalty"] = clampf(float(data.get("presence_penalty", 0.1)), -1.0, 2.0)
	data["penalty_last_n"] = clampi(int(data.get("penalty_last_n", 128)), -1, 1024)
	data["max_tokens"] = clampi(int(data.get("max_tokens", 380)), 64, 1024)
	data["seed"] = int(data.get("seed", -1))

func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func get_value(key: String, fallback: Variant = null) -> Variant:
	if data.has(key):
		return data[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return fallback

func set_value(key: String, value: Variant, persist: bool = true) -> void:
	data[key] = value
	changed.emit(key, value)
	if persist:
		save_settings()

func set_many(values: Dictionary) -> void:
	for k in values:
		data[k] = values[k]
	_sanitize()
	save_settings()

func reset() -> void:
	data = DEFAULTS.duplicate(true)
	save_settings()

func generation_params() -> Dictionary:
	return {
		"temperature": float(data["temperature"]),
		"top_p": float(data["top_p"]),
		"top_k": int(data["top_k"]),
		"min_p": float(data["min_p"]),
		"repeat_penalty": float(data["repeat_penalty"]),
		"frequency_penalty": float(data["frequency_penalty"]),
		"presence_penalty": float(data["presence_penalty"]),
		"penalty_last_n": int(data["penalty_last_n"]),
		"seed": int(data["seed"]),
		"max_tokens": int(data["max_tokens"]),
		"stop_sequences": PackedStringArray(["<|im_end|>", "<|im_start|>", "<|endoftext|>", "</delta>"]),
	}

func context_params() -> Dictionary:
	return {
		"n_ctx": int(data["n_ctx"]),
		"n_batch": int(data["n_batch"]),
		"threads": int(data["threads"]),
		"threads_batch": int(data["threads"]),
	}

func model_params() -> Dictionary:
	return {
		"n_gpu_layers": 0,
		"use_mmap": bool(data["use_mmap"]),
		"use_mlock": bool(data["use_mlock"]),
	}
