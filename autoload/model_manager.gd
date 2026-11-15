extends Node

signal copy_progress(percent: int)
signal model_ready(path: String)
signal model_error(message: String)

const MODEL_FILE := "qwen2.5-3b-instruct-q4_k_m.gguf"
const RES_MODEL := "res://models/" + MODEL_FILE
const USER_DIR := "user://models"
const USER_MODEL := USER_DIR + "/" + MODEL_FILE
const CHUNK := 4 * 1024 * 1024

var ready_path: String = ""
var last_error: String = ""
var copying: bool = false
var _thread: Thread

func _ready() -> void:
	pass

func expected_size() -> int:
	if FileAccess.file_exists(RES_MODEL):
		return _file_size(RES_MODEL)
	if FileAccess.file_exists(USER_MODEL):
		return _file_size(USER_MODEL)
	return 0

func model_name() -> String:
	return MODEL_FILE

func is_ready() -> bool:
	return ready_path != "" and FileAccess.file_exists(ready_path)

func prepare() -> void:
	last_error = ""
	if is_ready():
		model_ready.emit(ready_path)
		return
	if not OS.has_feature("android"):
		if FileAccess.file_exists(RES_MODEL):
			ready_path = ProjectSettings.globalize_path(RES_MODEL)
			model_ready.emit(ready_path)
			return
		last_error = "Модель не найдена: " + RES_MODEL
		model_error.emit(last_error)
		return
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var wanted := _file_size(USER_MODEL)
	var source_size := _file_size(RES_MODEL)
	if wanted > 0 and source_size > 0 and wanted == source_size:
		ready_path = ProjectSettings.globalize_path(USER_MODEL)
		model_ready.emit(ready_path)
		return
	if source_size == 0:
		last_error = "В APK нет модели: " + RES_MODEL
		model_error.emit(last_error)
		return
	if copying:
		return
	copying = true
	_thread = Thread.new()
	_thread.start(_copy_worker)

func _copy_worker() -> void:
	var src := FileAccess.open(RES_MODEL, FileAccess.READ)
	if src == null:
		_finish_error("Не удалось открыть модель в APK")
		return
	var total := src.get_length()
	if total <= 0:
		src.close()
		_finish_error("Пустой файл модели")
		return
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var tmp := USER_MODEL + ".part"
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_MODEL))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(USER_MODEL))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		_finish_error("Не удалось переименовать файл модели")
		return
	call_deferred("_finish_ready", ProjectSettings.globalize_path(USER_MODEL))

func _emit_progress(percent: int) -> void:
	copy_progress.emit(percent)

func _finish_ready(path: String) -> void:
	copying = false
	ready_path = path
	model_ready.emit(path)

func _finish_error(message: String) -> void:
	copying = false
	last_error = message
	call_deferred("_emit_error", message)

func _emit_error(message: String) -> void:
	copying = false
	model_error.emit(message)

func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size := f.get_length()
	f.close()
	return size

func delete_local_copy() -> void:
	if FileAccess.file_exists(USER_MODEL):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(USER_MODEL))
	ready_path = ""
