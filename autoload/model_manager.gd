extends Node

signal model_ready(path: String)
signal model_error(message: String)
signal models_changed

const USER_DIR := "user://models"

var ready_path: String = ""
var last_error: String = ""

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
		return display_name(current)
	return "модель не выбрана"

func display_name(path: String) -> String:
	var f := path.get_file()
	if f.to_lower().ends_with(".gguf"):
		f = f.substr(0, f.length() - 5)
	return f

func expected_size() -> int:
	var current := active_model()
	if current != "":
		return file_size(current)
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
	_finish_error("Модель не найдена. Импортируйте .gguf в настройках.")

func _finish_error(message: String) -> void:
	last_error = message
	call_deferred("_emit_error", message)

func _emit_error(message: String) -> void:
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

func file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size
