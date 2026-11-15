extends Node
const Kit = preload("res://ui/kit.gd")

signal worlds_changed

const BUILTIN_DIR := "res://worlds"
const USER_DIR := "user://worlds"
var worlds: Dictionary = {}
var lore_chunks: Dictionary = {}
var selected_world_id: String = ""
var last_error: String = ""

func _ready() -> void:
	ensure_user_worlds()
	reload()

func ensure_user_worlds() -> void:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	for id in _builtin_ids():
		_copy_builtin_world(id)

func _builtin_ids() -> Array:
	var out: Array = []
	var dir := DirAccess.open(BUILTIN_DIR)
	if dir == null:
		return out
	for sub in dir.get_directories():
		if FileAccess.file_exists(BUILTIN_DIR.path_join(sub).path_join("world.json")):
			out.append(sub)
	out.sort()
	return out

func _copy_builtin_world(id: String) -> void:
	var src_dir := BUILTIN_DIR.path_join(id)
	var dst_dir := USER_DIR.path_join(id)
	var src_json := src_dir.path_join("world.json")
	if not FileAccess.file_exists(src_json):
		return
	var text := _read_text(src_json)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	DirAccess.make_dir_recursive_absolute(dst_dir)
	var dst_json := dst_dir.path_join("world.json")
	var copy_json := not FileAccess.file_exists(dst_json)
	if not copy_json:
		var dst_parsed: Variant = JSON.parse_string(_read_text(dst_json))
		if dst_parsed is Dictionary and int(dst_parsed.get("version", 1)) < int(parsed.get("version", 1)):
			copy_json = true
	if copy_json:
		_write_text(dst_json, text)
	var lore: Array = parsed.get("lore_files", [])
	DirAccess.make_dir_recursive_absolute(dst_dir.path_join("lore"))
	for rel in lore:
		var rel_s := str(rel)
		var src_file := src_dir.path_join(rel_s)
		var dst_file := dst_dir.path_join(rel_s)
		if FileAccess.file_exists(src_file):
			var parent := dst_file.get_base_dir()
			DirAccess.make_dir_recursive_absolute(parent)
			if copy_json or not FileAccess.file_exists(dst_file):
				_write_text(dst_file, _read_text(src_file))
	var cover := str(parsed.get("cover", ""))
	if cover != "":
		var src_cover := src_dir.path_join(cover)
		var dst_cover := dst_dir.path_join(cover)
		if FileAccess.file_exists(src_cover) and (copy_json or not FileAccess.file_exists(dst_cover)):
			_copy_binary(src_cover, dst_cover)

func reload() -> void:
	worlds.clear()
	lore_chunks.clear()
	last_error = ""
	for id in _builtin_ids():
		_load_world_dir(BUILTIN_DIR.path_join(id), false)
	var dir := DirAccess.open(USER_DIR)
	if dir != null:
		for sub in dir.get_directories():
			_load_world_dir(USER_DIR.path_join(sub), true)
	for wid in worlds:
		var w: Dictionary = worlds[wid]
		lore_chunks[wid] = _build_lore_index(w)
	worlds_changed.emit()

func _load_world_dir(dir_path: String, override_builtin: bool) -> void:
	var json_path := dir_path.path_join("world.json")
	if not FileAccess.file_exists(json_path):
		return
	var parsed: Variant = JSON.parse_string(_read_text(json_path))
	if not (parsed is Dictionary):
		last_error = "Не удалось прочитать world.json в " + dir_path
		return
	var w: Dictionary = parsed
	if str(w.get("id", "")) == "" or str(w.get("title", "")) == "":
		last_error = "В паке " + dir_path + " нет id или title"
		return
	if not (w.get("currency", null) is Dictionary):
		last_error = "В паке " + str(w.get("id", "?")) + " нет валюты"
		return
	if not (w.get("start_templates", null) is Array):
		w["start_templates"] = []
	if not (w.get("characters", null) is Array):
		w["characters"] = []
	if not (w.get("locations", null) is Array):
		w["locations"] = []
	if not (w.get("lore_files", null) is Array):
		w["lore_files"] = []
	if not (w.get("principles", null) is Array):
		w["principles"] = []
	if not (w.get("rules", null) is Array):
		w["rules"] = []
	if not (w.get("items", null) is Dictionary):
		w["items"] = {}
	w["_dir"] = dir_path
	var wid := str(w["id"])
	if not override_builtin and worlds.has(wid):
		return
	worlds[wid] = w

func _build_lore_index(w: Dictionary) -> Array:
	var chunks: Array = []
	var dir_path := str(w.get("_dir", ""))
	var files: Array = w.get("lore_files", [])
	for rel in files:
		var path := dir_path.path_join(str(rel))
		if not FileAccess.file_exists(path):
			continue
		var text := _read_text(path)
		chunks.append_array(_split_lore(text, str(rel)))
	return chunks

func _split_lore(text: String, file_name: String) -> Array:
	var chunks: Array = []
	var file_tags: Array = []
	var current_title := file_name.get_file().get_basename()
	var current_tags: Array = []
	var current_lines: PackedStringArray = []
	var seen_heading := false
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.to_lower().begins_with("<!-- tags:"):
			var inside := line.replace("<!--", "").replace("-->", "").replace("tags:", "").strip_edges()
			var parts := inside.split(",")
			for p in parts:
				var tag := p.strip_edges().to_lower()
				if tag != "":
					file_tags.append(tag)
					current_tags.append(tag)
			continue
		if line.begins_with("## "):
			if seen_heading and not current_lines.is_empty():
				chunks.append(_make_chunk(current_title, current_tags, current_lines, file_name))
			current_title = line.substr(3).strip_edges()
			current_tags = file_tags.duplicate()
			current_tags.append_array(_title_tags(current_title))
			current_lines = PackedStringArray()
			seen_heading = true
			continue
		if line.begins_with("# "):
			continue
		if seen_heading:
			current_lines.append(raw_line)
	if seen_heading and not current_lines.is_empty():
		chunks.append(_make_chunk(current_title, current_tags, current_lines, file_name))
	if chunks.is_empty() and text.strip_edges() != "":
		var tags := file_tags.duplicate()
		tags.append_array(_title_tags(file_name))
		chunks.append({
			"title": file_name.get_file().get_basename(),
			"file": file_name,
			"tags": tags,
			"text": Kit.shorten(text.strip_edges(), 900),
		})
	return chunks

func _make_chunk(title: String, tags: Array, lines: PackedStringArray, file_name: String) -> Dictionary:
	var body := "\n".join(lines).strip_edges()
	var text := title
	if body != "":
		text += "\n" + body
	return {
		"title": title,
		"file": file_name,
		"tags": _unique_tags(tags),
		"text": Kit.shorten(text, 950),
	}

func _title_tags(title: String) -> Array:
	var out: Array = []
	for word in title.to_lower().replace(",", " ").replace(".", " ").split(" ", false):
		var w := str(word).strip_edges()
		if w.length() >= 4:
			out.append(w)
	return out

func _unique_tags(tags: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for t in tags:
		var s := str(t).strip_edges().to_lower()
		if s != "" and not seen.has(s):
			seen[s] = true
			out.append(s)
	return out

func retrieve_lore(world_id: String, query: String, location: String, flags: Array, max_chunks: int = 2) -> Array:
	if not lore_chunks.has(world_id):
		return []
	var chunks: Array = lore_chunks[world_id]
	if chunks.is_empty():
		return []
	var words := _query_words(query)
	var loc := location.to_lower()
	var flag_words: Array = []
	for f in flags:
		flag_words.append(str(f).to_lower().replace("_", " "))
	var scored: Array = []
	for chunk_v in chunks:
		var chunk: Dictionary = chunk_v
		var score := 0.0
		var tags: Array = chunk.get("tags", [])
		var title := str(chunk.get("title", "")).to_lower()
		var body := str(chunk.get("text", "")).to_lower()
		for w in words:
			if tags.has(w):
				score += 3.0
			if title.contains(w):
				score += 2.0
			if body.contains(w):
				score += 0.6
		if loc != "":
			if tags.has(loc) or title.contains(loc) or body.contains(loc):
				score += 4.0
		for fw in flag_words:
			if fw.length() >= 4 and (tags.has(fw) or body.contains(fw)):
				score += 2.0
		if score > 0.0:
			scored.append({ "score": score, "chunk": chunk })
	if scored.is_empty():
		scored.append({ "score": 0.0, "chunk": chunks[0] })
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	var out: Array = []
	for i in range(mini(max_chunks, scored.size())):
		out.append(scored[i]["chunk"])
	return out

func _query_words(query: String) -> Array:
	var stop := {
		"что": true, "как": true, "это": true, "для": true, "или": true, "она": true,
		"они": true, "его": true, "её": true, "мне": true, "меня": true, "был": true,
		"была": true, "были": true, "есть": true, "уже": true, "ещё": true, "еще": true,
		"чтобы": true, "когда": true, "если": true, "там": true, "тут": true, "вот": true,
		"the": true, "and": true, "with": true, "this": true, "that": true
	}
	var out: Array = []
	for word in query.to_lower().replace(",", " ").replace(".", " ").replace("—", " ").split(" ", false):
		var w := str(word).strip_edges()
		if w.length() >= 4 and not stop.has(w):
			out.append(w)
	return out

func get_world(world_id: String) -> Dictionary:
	return worlds.get(world_id, {})

func get_world_by_selected() -> Dictionary:
	return get_world(selected_world_id)

func list_worlds() -> Array:
	var out: Array = []
	for id in worlds:
		out.append(worlds[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("title", "")) < str(b.get("title", "")))
	return out

func get_start_templates(w: Dictionary) -> Array:
	return w.get("start_templates", [])

func default_date(w: Dictionary) -> String:
	var direct := str(w.get("default_start_date", ""))
	if direct != "":
		return direct
	for t in get_start_templates(w):
		var date := str(t.get("start_date", ""))
		if date != "":
			return date
	return "1000-01-01"

func get_template(w: Dictionary, id: String) -> Dictionary:
	for t in get_start_templates(w):
		if str(t.get("id", "")) == id:
			return t
	return {}

func get_locations(w: Dictionary) -> Array:
	return w.get("locations", [])

func get_location(w: Dictionary, id: String) -> Dictionary:
	for l in w.get("locations", []):
		if str(l.get("id", "")) == id:
			return l
	return {}

func get_character(w: Dictionary, id: String) -> Dictionary:
	for c in w.get("characters", []):
		if str(c.get("id", "")) == id:
			return c
	return {}

func get_item(w: Dictionary, id: String) -> Dictionary:
	var items: Dictionary = w.get("items", {})
	if items.has(id):
		var item: Dictionary = items[id]
		return item
	return {}

func get_default_choices(w: Dictionary) -> Array:
	var raw: Array = w.get("fallback_choices", [])
	var out: Array = []
	for c in raw:
		if c is Dictionary:
			out.append({
				"title": str(c.get("title", "Продолжить")),
				"text": str(c.get("text", "")),
			})
		elif c is String:
			out.append({ "title": str(c), "text": "" })
	if out.is_empty():
		out = [
			{ "title": "Осмотреться", "text": "Понять, кто здесь на самом деле распоряжается." },
			{ "title": "Задать вопрос", "text": "Осторожно выяснить то, о чём все молчат." },
			{ "title": "Выиграть время", "text": "Сохранить лицо и посмотреть, что будет дальше." },
		]
	return out

func format_money(minor: int, w: Dictionary) -> String:
	var cur: Dictionary = w.get("currency", {})
	var symbol := str(cur.get("symbol", ""))
	var per_major := int(cur.get("minor_per_major", 100))
	if per_major <= 0:
		per_major = 100
	var negative := minor < 0
	var amount := absi(minor)
	var major := int(amount / per_major)
	var rest := amount % per_major
	var subunits: Array = cur.get("subunits", [])
	var parts: Array[String] = []
	if subunits.is_empty():
		if per_major == 100:
			parts.append("%s%d.%02d" % [symbol, major, rest])
		else:
			parts.append("%s%d" % [symbol, major])
			if rest > 0:
				parts.append("%d" % rest)
	else:
		var left := rest
		if major > 0:
			parts.append("%s%d" % [symbol, major])
		for sub_v in subunits:
			var sub: Dictionary = sub_v
			var per := int(sub.get("per_major", 1))
			if per <= 0:
				per = 1
			var count := int(left / per)
			left = left % per
			if count > 0:
				parts.append("%d%s" % [count, str(sub.get("short", ""))])
		if left > 0:
			parts.append("%d%s" % [left, str(cur.get("minor_short", ""))])
		if parts.is_empty():
			parts.append("%s0" % symbol)
	var text := " ".join(parts)
	return ("-" if negative else "") + text

func major_to_minor(value: float, w: Dictionary) -> int:
	var cur: Dictionary = w.get("currency", {})
	var per := int(cur.get("minor_per_major", 100))
	return int(round(value * float(per)))

func minor_to_major(value: int, w: Dictionary) -> float:
	var cur: Dictionary = w.get("currency", {})
	var per := int(cur.get("minor_per_major", 100))
	return float(value) / float(per) if per > 0 else float(value)

func validate_world(w: Dictionary) -> String:
	var wid := str(w.get("id", "")).strip_edges()
	if wid == "":
		return "В world.json нет поля id"
	if str(w.get("title", "")).strip_edges() == "":
		return "В world.json нет поля title"
	if not (w.get("currency", null) is Dictionary):
		return "В world.json нет объекта currency"
	var cur: Dictionary = w.get("currency", {})
	if int(cur.get("minor_per_major", 0)) <= 0:
		return "В currency.minor_per_major должно быть положительное число"
	if not (w.get("start_templates", null) is Array):
		return "В world.json нет массива start_templates"
	if not (w.get("characters", null) is Array):
		return "В world.json нет массива characters"
	if not (w.get("locations", null) is Array):
		return "В world.json нет массива locations"
	var templates: Array = w.get("start_templates", [])
	if templates.is_empty():
		return "В world.json нет ни одного стартового персонажа"
	for t in templates:
		if not (t is Dictionary) or str(t.get("id", "")) == "" or str(t.get("name", "")) == "":
			return "У стартового персонажа нет id или name"
	return ""

func _safe_id(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	var out := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
		elif ch == " ":
			out += "_"
	return out.strip_edges()

func _allowed_import_file(rel: String) -> bool:
	var low := rel.to_lower()
	return low == "world.json" or low.begins_with("lore/") or low.begins_with("cover.") or low.ends_with(".md") or low.ends_with(".txt") or low.ends_with(".json") or low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp")

func _write_bytes(path: String, data: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(data)
	f.close()
	return true

func import_world_zip(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return { "ok": false, "error": "Не удалось открыть ZIP" }
	var names := reader.get_files()
	var json_name := ""
	for n in names:
		var nn := str(n)
		if nn.to_lower().ends_with("world.json"):
			if json_name == "" or nn.length() < json_name.length():
				json_name = nn
	if json_name == "" or json_name.begins_with("/") or json_name.contains(".."):
		reader.close()
		return { "ok": false, "error": "В ZIP нет корректного world.json" }
	var parsed: Variant = JSON.parse_string(reader.read_file(json_name).get_string_from_utf8())
	if not (parsed is Dictionary):
		reader.close()
		return { "ok": false, "error": "world.json внутри ZIP повреждён" }
	var w: Dictionary = parsed
	var problem := validate_world(w)
	if problem != "":
		reader.close()
		return { "ok": false, "error": problem }
	var wid := _safe_id(str(w.get("id", "")))
	if wid == "":
		reader.close()
		return { "ok": false, "error": "Некорректный id мира" }
	var target := USER_DIR.path_join(wid)
	if DirAccess.dir_exists_absolute(target):
		reader.close()
		return { "ok": false, "error": "Мир с id «%s» уже существует" % wid }
	var prefix := json_name.get_base_dir()
	if prefix == ".":
		prefix = ""
	DirAccess.make_dir_recursive_absolute(target)
	var written := 0
	for n in names:
		var nn := str(n)
		if nn.ends_with("/"):
			continue
		var rel := nn
		if prefix != "":
			if not nn.begins_with(prefix + "/"):
				continue
			rel = nn.substr(prefix.length() + 1)
		if rel == "" or rel.begins_with("__MACOSX") or rel.contains("..") or rel.begins_with("/"):
			continue
		if not _allowed_import_file(rel):
			continue
		var dst := target.path_join(rel)
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		if not _write_bytes(dst, reader.read_file(nn)):
			reader.close()
			_remove_tree(target)
			return { "ok": false, "error": "Не удалось записать " + rel }
		written += 1
	reader.close()
	if written == 0:
		_remove_tree(target)
		return { "ok": false, "error": "В ZIP не нашлось файлов мира" }
	reload()
	if not worlds.has(wid):
		_remove_tree(target)
		return { "ok": false, "error": last_error if last_error != "" else "Мир не прошёл проверку после распаковки" }
	selected_world_id = wid
	return { "ok": true, "id": wid, "title": str(w.get("title", wid)) }

func import_world_folder(path: String) -> Dictionary:
	var root := path
	var json_path := root.path_join("world.json")
	if not FileAccess.file_exists(json_path):
		var dir := DirAccess.open(root)
		if dir != null:
			for sub in dir.get_directories():
				if FileAccess.file_exists(root.path_join(sub).path_join("world.json")):
					root = root.path_join(sub)
					json_path = root.path_join("world.json")
					break
	if not FileAccess.file_exists(json_path):
		return { "ok": false, "error": "В папке нет world.json" }
	var parsed: Variant = JSON.parse_string(_read_text(json_path))
	if not (parsed is Dictionary):
		return { "ok": false, "error": "world.json повреждён" }
	var w: Dictionary = parsed
	var problem := validate_world(w)
	if problem != "":
		return { "ok": false, "error": problem }
	var wid := _safe_id(str(w.get("id", "")))
	if wid == "":
		return { "ok": false, "error": "Некорректный id мира" }
	var target := USER_DIR.path_join(wid)
	if DirAccess.dir_exists_absolute(target):
		return { "ok": false, "error": "Мир с id «%s» уже существует" % wid }
	DirAccess.make_dir_recursive_absolute(target)
	var copied := 0
	var files: Array = []
	_collect_files(root, "", files)
	for rel in files:
		if not _allowed_import_file(str(rel)):
			continue
		var src := root.path_join(str(rel))
		var dst := target.path_join(str(rel))
		DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
		var data := FileAccess.get_file_as_bytes(src)
		if not _write_bytes(dst, data):
			_remove_tree(target)
			return { "ok": false, "error": "Не удалось записать " + str(rel) }
		copied += 1
	if copied == 0:
		_remove_tree(target)
		return { "ok": false, "error": "В папке не нашлось файлов мира" }
	reload()
	if not worlds.has(wid):
		_remove_tree(target)
		return { "ok": false, "error": last_error if last_error != "" else "Мир не прошёл проверку после копирования" }
	selected_world_id = wid
	return { "ok": true, "id": wid, "title": str(w.get("title", wid)) }

func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir != null:
		for f in dir.get_files():
			DirAccess.remove_absolute(path.path_join(f))
		for sub in dir.get_directories():
			_remove_tree(path.path_join(sub))
	DirAccess.remove_absolute(path)

func _collect_files(root: String, rel: String, out: Array) -> void:
	var dir := DirAccess.open(root.path_join(rel))
	if dir == null:
		return
	for f in dir.get_files():
		out.append(rel.path_join(f) if rel != "" else f)
	for sub in dir.get_directories():
		_collect_files(root, rel.path_join(sub) if rel != "" else sub, out)

func world_overview(w: Dictionary) -> Array:
	var rows: Array = []
	rows.append(["Название", str(w.get("title", ""))])
	rows.append(["ID", str(w.get("id", ""))])
	rows.append(["Подзаголовок", str(w.get("subtitle", ""))])
	rows.append(["Язык", str(w.get("language_instruction", w.get("language", "")))])
	var cur: Dictionary = w.get("currency", {})
	rows.append(["Валюта", "%s %s (%d minor)" % [str(cur.get("symbol", "")), str(cur.get("major", "")), int(cur.get("minor_per_major", 0))]])
	rows.append(["Символ", str(cur.get("symbol", "")) + " · код: " + str(cur.get("code", "нет"))])
	rows.append(["Персонажи", str(w.get("characters", []).size())])
	rows.append(["Локации", str(w.get("locations", []).size())])
	rows.append(["Старты", str(w.get("start_templates", []).size())])
	rows.append(["Лор", ", ".join(PackedStringArray(w.get("lore_files", [])))])
	return rows

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

func _write_text(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true

func _copy_binary(src: String, dst: String) -> void:
	var data := FileAccess.get_file_as_bytes(src)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f != null:
		f.store_buffer(data)
		f.close()
