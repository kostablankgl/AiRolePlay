extends Node

signal saves_changed

const SAVE_DIR := "user://saves"
const INDEX_PATH := "user://saves/world_index.json"

var index: Array = []
var last_error: String = ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	refresh()

func refresh() -> void:
	index = []
	var f := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Array:
			index = parsed
		elif parsed is Dictionary and parsed.get("saves", null) is Array:
			index = parsed["saves"]
	_rebuild_missing()
	saves_changed.emit()

func _rebuild_missing() -> void:
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	var known: Dictionary = {}
	for e in index:
		if e is Dictionary:
			known[str(e.get("id", ""))] = true
	for file in dir.get_files():
		if not file.begins_with("save_") or not file.ends_with(".json"):
			continue
		var id := file.get_basename().substr(5)
		if known.has(id):
			continue
		var entry := _entry_from_file(file)
		if not entry.is_empty():
			index.append(entry)
	_write_index()

func _entry_from_file(file: String) -> Dictionary:
	var path := SAVE_DIR.path_join(file)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	var meta: Dictionary = d.get("meta", {})
	var ch: Dictionary = d.get("character", {})
	return {
		"id": str(d.get("id", file.get_basename().substr(5))),
		"world_id": str(d.get("world_id", "")),
		"title": str(meta.get("title", ch.get("name", "История"))),
		"character": str(ch.get("name", "")),
		"location": str(d.get("location", "")),
		"turn": int(meta.get("turn", d.get("turn", 0))),
		"updated": int(meta.get("updated", 0)),
		"date": str(d.get("time", {}).get("date", "")),
		"path": path,
	}

func list_saves() -> Array:
	var out := index.duplicate(true)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("updated", 0)) > int(b.get("updated", 0)))
	return out

func list_saves_for_world(world_id: String) -> Array:
	var out: Array = []
	for e in list_saves():
		if str(e.get("world_id", "")) == world_id:
			out.append(e)
	return out

func latest_for_world(world_id: String) -> Dictionary:
	var list := list_saves_for_world(world_id)
	return list[0] if not list.is_empty() else {}

func has_saves() -> bool:
	return not index.is_empty()

func new_id() -> String:
	return "s_%d_%04d" % [int(Time.get_unix_time_from_system()), randi() % 10000]

func save_game(autosave: bool = false) -> bool:
	last_error = ""
	if not GameState.is_loaded():
		last_error = "Нет активной игры"
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var data := GameState.to_dict()
	var id := str(data.get("meta", {}).get("id", ""))
	if id == "":
		id = new_id()
	data["id"] = id
	data["version"] = 1
	data["saved_at"] = int(Time.get_unix_time_from_system())
	data["autosave"] = autosave
	var meta: Dictionary = data.get("meta", {})
	meta["id"] = id
	meta["updated"] = int(data["saved_at"])
	data["meta"] = meta
	var file := "save_" + _safe_id(id) + ".json"
	var path := SAVE_DIR.path_join(file)
	if not _write_json(path, data):
		last_error = "Не удалось записать сохранение"
		return false
	GameState.meta = meta
	_upsert_index(id, data, path)
	saves_changed.emit()
	return true

func load_game(id: String) -> bool:
	last_error = ""
	var clean := _safe_id(id)
	var path := SAVE_DIR.path_join("save_" + clean + ".json")
	if not FileAccess.file_exists(path):
		last_error = "Сохранение не найдено"
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "Не удалось открыть сохранение"
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		last_error = "Повреждённый файл сохранения"
		return false
	var d: Dictionary = parsed
	var wid := str(d.get("world_id", ""))
	var w := WorldDB.get_world(wid)
	if w.is_empty():
		last_error = "Мир сохранения не найден: " + wid
		return false
	GameState.load_from_dict(d, w)
	return true

func delete_save(id: String) -> bool:
	var clean := _safe_id(id)
	var path := SAVE_DIR.path_join("save_" + clean + ".json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var out: Array = []
	for e in index:
		if str(e.get("id", "")) != clean:
			out.append(e)
	index = out
	_write_index()
	saves_changed.emit()
	return true

func _upsert_index(id: String, data: Dictionary, path: String) -> void:
	var clean := _safe_id(id)
	var meta: Dictionary = data.get("meta", {})
	var ch: Dictionary = data.get("character", {})
	var entry := {
		"id": clean,
		"world_id": str(data.get("world_id", "")),
		"title": str(meta.get("title", ch.get("name", "История"))),
		"character": str(ch.get("name", "")),
		"location": str(data.get("location", "")),
		"turn": int(meta.get("turn", data.get("turn", 0))),
		"updated": int(meta.get("updated", 0)),
		"date": str(data.get("time", {}).get("date", "")),
		"path": path,
	}
	var replaced := false
	for i in range(index.size()):
		if str(index[i].get("id", "")) == clean:
			index[i] = entry
			replaced = true
			break
	if not replaced:
		index.append(entry)
	_write_index()

func _write_index() -> bool:
	return _write_json(INDEX_PATH, index)

func _write_json(path: String, value: Variant) -> bool:
	var text := JSON.stringify(value)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	return err == OK

func _safe_id(id: String) -> String:
	var out := ""
	for ch in id:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	if out == "":
		out = new_id()
	return out

func autosave_current() -> void:
	if GameState.is_loaded():
		save_game(true)
