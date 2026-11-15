extends Node
const Kit = preload("res://ui/kit.gd")

func parse(text: String) -> Dictionary:
	var raw := text.replace("\r\n", "\n").replace("\r", "\n")
	raw = raw.replace("<|im_end|>", "").replace("<|im_start|>assistant", "").replace("<|im_start|>", "")
	raw = _strip_code_fences(raw)
	var scene := _tag_contents(raw, "scene").strip_edges()
	if scene == "":
		var without := _remove_tags(raw).strip_edges()
		if without != "":
			scene = without
	var choices := parse_choices(_tag_contents(raw, "choices"))
	var delta_text := _tag_contents(raw, "delta").strip_edges()
	var delta: Dictionary = {}
	var delta_error := ""
	if delta_text != "":
		var obj: Variant = _parse_json_object(delta_text)
		if obj == null:
			delta_error = "Не удалось разобрать delta"
			var rescued: Variant = _find_json_object(delta_text)
			if rescued != null:
				delta = rescued
				delta_error = ""
		else:
			delta = obj
	var result := {
		"ok": scene != "",
		"scene": scene,
		"choices": choices,
		"delta": delta,
		"delta_error": delta_error,
		"raw": raw,
	}
	if not result["ok"]:
		result["error"] = "В ответе нет текста сцены"
	return result

func parse_choices(block: String) -> Array:
	var out: Array = []
	if block.strip_edges() == "":
		return out
	for raw_line in block.split("\n"):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		line = _strip_choice_prefix(line)
		line = line.replace("**", "").replace("__", "").strip_edges()
		if line.length() < 2:
			continue
		if line.length() > 110:
			line = Kit.shorten(line, 110)
		out.append({ "title": line, "text": line })
		if out.size() >= 4:
			break
	if out.size() == 1:
		var single := str(out[0].get("title", ""))
		if single.contains(" | "):
			var split: Array = []
			for piece in single.split(" | "):
				var p := str(piece).strip_edges()
				if p.length() >= 2:
					split.append({ "title": Kit.shorten(p, 110), "text": p })
			if split.size() >= 2:
				out = split
	return out

func _strip_choice_prefix(line: String) -> String:
	var result := line
	for marker in ["- ", "* ", "• ", "— "]:
		if result.begins_with(marker):
			result = result.substr(marker.length()).strip_edges()
			break
	var dot := -1
	for i in range(mini(3, result.length())):
		var ch := result[i]
		if ch == "." or ch == ")" or ch == ":":
			dot = i
			break
		if ch < "0" or ch > "9":
			dot = -2
			break
	if dot >= 1:
		var prefix := result.substr(0, dot)
		if prefix.is_valid_int():
			result = result.substr(dot + 1).strip_edges()
	if result.begins_with("«") and result.ends_with("»") and result.length() > 2:
		result = result.substr(1, result.length() - 2).strip_edges()
	if result.begins_with("\"") and result.ends_with("\"") and result.length() > 2:
		result = result.substr(1, result.length() - 2).strip_edges()
	return result

func _tag_contents(text: String, tag: String) -> String:
	var low := text.to_lower()
	var open_tag := "<" + tag + ">"
	var close_tag := "</" + tag + ">"
	var start := low.find(open_tag)
	if start < 0:
		return ""
	start += open_tag.length()
	var end := low.find(close_tag, start)
	if end < 0:
		var next := low.find("<", start)
		if next >= 0:
			return text.substr(start, next - start)
		return text.substr(start)
	return text.substr(start, end - start)

func _remove_tags(text: String) -> String:
	var low := text.to_lower()
	var out := text
	var tags := ["scene", "choices", "delta"]
	for tag_v in tags:
		var tag: String = str(tag_v)
		var open_tag: String = "<" + tag + ">"
		var close_tag: String = "</" + tag + ">"
		var start := low.find(open_tag)
		if start >= 0:
			var end := low.find(close_tag, start)
			if end >= 0:
				out = out.substr(0, start) + out.substr(end + close_tag.length())
			else:
				out = out.substr(0, start)
			low = out.to_lower()
	return out

func _parse_json_object(text: String) -> Variant:
	var t := text.strip_edges()
	if t.begins_with("```"):
		t = _strip_code_fences(t)
	return _json_dict(t)

func _find_json_object(text: String) -> Variant:
	var start := text.find("{")
	var end := text.rfind("}")
	if start < 0 or end <= start:
		return null
	return _json_dict(text.substr(start, end - start + 1))

func _json_dict(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return null
	return parser.data if parser.data is Dictionary else null

func _strip_code_fences(text: String) -> String:
	var out := text
	var fence := "```"
	while true:
		var start := out.find(fence)
		if start < 0:
			break
		var end := out.find(fence, start + fence.length())
		if end < 0:
			out = out.substr(0, start)
			break
		var inner := out.substr(start + fence.length(), end - start - fence.length())
		inner = inner.strip_edges()
		if inner.begins_with("json") or inner.begins_with("JSON"):
			inner = inner.substr(4).strip_edges()
		out = out.substr(0, start) + inner + out.substr(end + fence.length())
	return out
