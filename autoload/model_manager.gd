extends Node

signal copy_progress(percent: int)
signal model_ready(path: String)
signal model_error(message: String)
signal models_changed

const MODEL_FILE := "qwen2.5-3b-instruct-q4_k_m.gguf"
const EMBEDDED_SOURCE := "res://models/" + MODEL_FILE
const USER_DIR := "user://models"
const CHUNK := 4 * 1024 * 1024

var ready_path: String = ""
var last_error: String = ""
var copying: bool = false
var _thread: Thread

func _ready() -> void:
	ensure_dir()

func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(USER_DIR)

func list_models() -> Array:
	ensure_dir()
	var out: Array = []
	var dir := DirAccess.open(USER_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.to_lower().ends_with(".gguf") or f.ends_with(".part"):
			continue
		var rel := USER_DIR + "/" + f
		out.append({
			"path": rel,
			"name": f,
			"size": file_size(rel),
			"builtin": f == MODEL_FILE and FileAccess.file_exists(EMBEDDED_SOURCE),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]).to_lower() < str(b["name"]).to_lower())
	return out

func first_model() -> String:
	var models := list_models()
	return str(models[0]["path"]) if not models.is_empty() else ""

func active_model() -> String:
	var current := str(SettingsManager.get_value("model_path", ""))
	if current != "" and FileAccess.file_exists(current):
		return current
	return first_model()

func model_name() -> String:
	var current := active_model()
	if current != "":
		return current.get_file()
	if FileAccess.file_exists(EMBEDDED_SOURCE):
		return MODEL_FILE
	return "модель не выбрана"

func expected_size() -> int:
	var current := active_model()
	if current != "":
		return file_size(current)
	if FileAccess.file_exists(EMBEDDED_SOURCE):
		return file_size(EMBEDDED_SOURCE)
	return 0

func is_ready() -> bool:
	return ready_path != "" and FileAccess.file_exists(ready_path)

func prepare() -> void:
	last_error = ""
	var current := active_model()
	if current != "":
		ready_path = ProjectSettings.globalize_path(current)
		model_ready.emit(ready_path)
		return
	if not FileAccess.file_exists(EMBEDDED_SOURCE):
		_finish_error("Модель не найдена. Импортируйте .gguf в настройках.")
		return
	if copying:
		return
	copying = true
	_thread = Thread.new()
	_thread.start(_copy_worker)

func _copy_worker() -> void:
	var src := FileAccess.open(EMBEDDED_SOURCE, FileAccess.READ)
	if src == null:
		_finish_error("Не удалось открыть встроенную модель")
		return
	var total := src.get_length()
	if total <= 0:
		src.close()
		_finish_error("Пустой файл модели")
		return
	ensure_dir()
	var dst_path := USER_DIR + "/" + MODEL_FILE
	var tmp := dst_path + ".part"
	var dst := FileAccess.open(tmp, FileAccess.WRITE)
	if dst == null:
		src.close()
		_finish_error("Не удалось создать файл модели в user://")
		return
	var written := 0
	var last_percent := -1
	while written < total:
		var buf := src.get_buffer(CHUNK)
		if buf.is_empty():
			break
		dst.store_buffer(buf)
		written += buf.size()
		var percent := int(float(written) * 100.0 / float(total))
		if percent != last_percent:
			last_percent = percent
			call_deferred("_emit_progress", percent)
	src.close()
	dst.close()
	if written != total:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		_finish_error("Копирование прервалось: %d из %d байт" % [written, total])
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dst_path))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(dst_path))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		_finish_error("Не удалось переименовать файл модели")
		return
	call_deferred("_finish_ready", ProjectSettings.globalize_path(dst_path), dst_path)

func _emit_progress(percent: int) -> void:
	copy_progress.emit(percent)

func _finish_ready(path: String, settings_path: String = "") -> void:
	copying = false
	ready_path = path
	if settings_path != "":
		SettingsManager.set_value("model_path", settings_path)
	model_ready.emit(path)
	models_changed.emit()

func _finish_error(message: String) -> void:
	copying = false
	last_error = message
	call_deferred("_emit_error", message)

func _emit_error(message: String) -> void:
	copying = false
	model_error.emit(message)

func delete_model(path: String) -> bool:
	if path == "":
		last_error = "Модель не выбрана"
		return false
	var global := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path):
		last_error = "Файл не найден"
		return false
	var err := DirAccess.remove_absolute(global)
	if err != OK:
		last_error = "Не удалось удалить файл"
		return false
	if str(SettingsManager.get_value("model_path", "")) == path:
		SettingsManager.set_value("model_path", "")
	models_changed.emit()
	return true

func delete_local_copy() -> void:
	var p := USER_DIR + "/" + MODEL_FILE
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	ready_path = ""

func file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size
