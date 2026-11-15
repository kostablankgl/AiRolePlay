extends Node
const Kit = preload("res://ui/kit.gd")

const MAX_PROMPT_CHARS := 7600
const LORE_CHUNK_CHARS := 720
const SUMMARY_CHARS := 900
const RECENT_CHARS := 340
const STOP_SEQUENCES := ["<|im_end|>", "<|im_start|>"]

func build_intro_prompt(setup: String) -> Dictionary:
	var action := "Начни первую сцену. Завязка: " + strip_special(setup)
	return _assemble(action, true, "")

func build_prompt(action: String, opts: Dictionary = {}) -> Dictionary:
	var continuation := bool(opts.get("continuation", false))
	var hint := str(opts.get("hint", ""))
	return _assemble(action, false, hint, continuation)

func _assemble(action: String, is_intro: bool, hint: String, continuation: bool = false) -> Dictionary:
	var w := GameState.world
	var n_ctx := int(SettingsManager.get_value("n_ctx", 4096))
	var compact := n_ctx < 4096
	var fixed: PackedStringArray = []
	fixed.append("<|im_start|>system")
	fixed.append(_system_rules(w, compact))
	fixed.append("")
	fixed.append(_output_format(w, compact))
	fixed.append("")
	fixed.append(_catalog(w, compact))
	var fixed_text := "\n".join(fixed)
	var user_text := _user_block(action, is_intro, hint, continuation, compact)
	var budget := mini(MAX_PROMPT_CHARS, maxi(3600, int(float(n_ctx) * 1.85)))
	var remaining := budget - fixed_text.length() - user_text.length()
	var parts: PackedStringArray = [fixed_text]
	var state_json := strip_special(JSON.stringify(GameState.prompt_state()))
	var state_block := "\nСОСТОЯНИЕ (JSON):\n" + state_json + "\n"
	if state_block.length() <= remaining:
		parts.append(state_block)
		remaining -= state_block.length()
	var chunks := _lore_for(action)
	if not chunks.is_empty() and remaining > 500:
		var lore_lines: PackedStringArray = ["", "СПРАВКА ПО МИРУ:"]
		for c in chunks:
			if remaining < 320:
				break
			var txt := strip_special(str(c.get("text", "")))
			var chunk_text := "### " + str(c.get("title", "")) + "\n" + txt
			chunk_text = Kit.shorten(chunk_text, mini(LORE_CHUNK_CHARS, remaining - 40))
			lore_lines.append(chunk_text)
			remaining -= chunk_text.length()
		parts.append("\n".join(lore_lines))
	var recent := _recent_lines()
	if recent != "" and remaining > 380:
		var rb: String = "\nПОСЛЕДНИЕ ХОДЫ:\n" + Kit.shorten(recent, mini(RECENT_CHARS * 2, remaining - 50)) + "\n"
		parts.append(rb)
		remaining -= rb.length()
	if GameState.summary != "" and remaining > 300:
		var sb: String = "\nХРОНИКА:\n" + Kit.shorten(strip_special(GameState.summary), mini(SUMMARY_CHARS, remaining - 40)) + "\n"
		parts.append(sb)
	parts.append(user_text)
	var text := "\n".join(parts)
	return {
		"text": text,
		"chars": text.length(),
		"estimated_tokens": int(float(text.length()) / 2.2),
		"lore_chunks": chunks.size(),
		"stop_sequences": STOP_SEQUENCES.duplicate(),
	}

func _user_block(action: String, is_intro: bool, hint: String, continuation: bool, compact: bool = false) -> String:
	var user := PackedStringArray()
	user.append("<|im_end|>")
	user.append("<|im_start|>user")
	if is_intro:
		user.append("Начни историю. Это первая сцена, игрок ещё не действовал.")
		user.append("Завязка: " + strip_special(action))
		user.append("Покажи место, время и ближайшее напряжение. Дай игроку понятную точку выбора.")
	elif continuation:
		user.append("Продолжи сцену с того же момента. Не повторяй уже написанное, добавь развитие и новые детали, снова дай 3 выбора.")
	else:
		user.append("Ход игрока: " + strip_special(action))
		if hint != "":
			user.append("Пожелание игрока к стилю: " + strip_special(hint))
		user.append("Ответь сценой, которая непосредственно следует из этого хода. Не пересказывай состояние игрока и не повторяй предыдущую сцену.")
	if compact:
		user.append("Верни <scene>, <choices> и <delta>: сцена 2–4 абзаца, 3 варианта, в delta только изменения.")
	else:
		user.append("Верни ровно три блока: <scene>, <choices>, <delta>. Внутри <scene> — только художественный текст, 2–4 абзаца, 120–220 слов. В <choices> — 2–4 варианта, каждый до 90 символов, с глаголом в начале. В <delta> — только изменения, иначе {}.")
	user.append("<|im_end|>")
	user.append("<|im_start|>assistant")
	return "\n".join(user)

func _system_rules(w: Dictionary, compact: bool = false) -> String:
	var lines: PackedStringArray = []
	lines.append("Ты — мастер текстовой ролевой игры. Ты ведёшь одну непрерывную историю. " + strip_special(str(w.get("language_instruction", "Пиши на русском языке."))))
	lines.append("Пиши во втором лице, в настоящем времени, живо и конкретно. Без Markdown, списков и заголовков внутри сцены.")
	lines.append("Ты управляешь только миром и второстепенными персонажами. Не решай за игрока, не описывай его мысли как приказ и не заканчивай историю без его хода.")
	lines.append("Не убивай персонажа игрока, не отбирай всё имущество и не меняй его характер без явного хода.")
	if not compact:
		lines.append("Все факты о мире, персонажах и ценах бери из справки и состояния. Новые детали допустимы, если не противоречат им. Важные новые факты отмечай в timeline_event.")
		lines.append("Меняй деньги, отношения, предметы, время и локацию только через <delta>, только по смыслу сцены и малыми величинами. Деньги указывай в minor units. Не придумывай крупные суммы и наследства.")
		lines.append("Если игрок пытается сделать невозможное, покажи препятствие в сцене, но не отказывай вне сцены.")
	else:
		lines.append("Факты и цены бери из справки и состояния. Меняй деньги, отношения, предметы, время и локацию только через <delta>, малыми величинами.")
	var sys := str(w.get("system_prompt", "")).strip_edges()
	if sys != "":
		lines.append("")
		lines.append(strip_special(Kit.shorten(sys, 300) if compact else sys))
	var rules: Array = w.get("rules", [])
	if not rules.is_empty():
		lines.append("")
		lines.append("ПРАВИЛА МИРА:")
		var rcount := 0
		for r in rules:
			if compact and rcount >= 4:
				break
			var rt := str(r.get("text", "")) if r is Dictionary else str(r)
			if rt != "":
				lines.append("- " + strip_special(Kit.shorten(rt, 85) if compact else rt))
				rcount += 1
	if compact:
		return "\n".join(lines)
	var principles: Array = w.get("principles", [])
	if not principles.is_empty():
		lines.append("")
		lines.append("ПРИНЦИПЫ ТОНА:")
		for p in principles:
			var pt := str(p.get("text", "")) if p is Dictionary else str(p)
			if pt != "":
				lines.append("- " + strip_special(pt))
	return "\n".join(lines)

func _output_format(w: Dictionary, compact: bool = false) -> String:
	var cur: Dictionary = w.get("currency", {})
	var minor_name := str(cur.get("minor", cur.get("minor_name", "minor units")))
	var lines: PackedStringArray = []
	lines.append("ФОРМАТ ОТВЕТА — строго три блока, без текста до и после:")
	lines.append("<scene>")
	lines.append("Художественная сцена, 2–4 абзаца.")
	lines.append("</scene>")
	lines.append("<choices>")
	lines.append("1. Короткий вариант действия")
	lines.append("2. Второй вариант")
	lines.append("3. Третий вариант")
	lines.append("</choices>")
	lines.append("<delta>{...}</delta>")
	lines.append("")
	lines.append("В <delta> разрешены только ключи: cash_minor, bank_minor, trust_minor, inventory_add, inventory_remove, rel, add_flags, remove_flags, time_advance, location, add_skills, add_abilities, clothes, timeline_event.")
	if compact:
		lines.append("Пример: {\"time_advance\":{\"minutes\":15},\"rel\":{\"id\":1},\"cash_minor\":-20}.")
	else:
		lines.append("Формат: {\"time_advance\":{\"minutes\":15},\"rel\":{\"id_персонажа\":1},\"add_flags\":[\"flag\"],\"inventory_add\":[{\"id\":\"id_предмета\",\"qty\":1}],\"inventory_remove\":[{\"id\":\"id_предмета\",\"qty\":1}],\"cash_minor\":-20,\"timeline_event\":\"краткий факт\"}")
		lines.append("Валютный минимум: " + minor_name + ". Меняй cash_minor в этих единицах, например -20 значит минус 20 " + minor_name + ".")
	lines.append("Если изменений нет, верни <delta>{}</delta>. Не добавляй других ключей.")
	return "\n".join(lines)

func _catalog(w: Dictionary, compact: bool = false) -> String:
	var lines: PackedStringArray = []
	lines.append("КАТАЛОГ ID (используй только эти id):")
	var chars: Array = w.get("characters", [])
	var char_limit := 3 if compact else chars.size()
	if not chars.is_empty():
		lines.append("Персонажи:")
		var ccount := 0
		for c in chars:
			if ccount >= char_limit:
				break
			var level := GameState.rel_level(str(c.get("id", "")))
			lines.append("- %s — %s (%s), отношение: %s" % [str(c.get("id", "")), str(c.get("name", "")), str(c.get("role", "")), str(level)])
			ccount += 1
	var locs: Array = w.get("locations", [])
	var loc_limit := 4 if compact else locs.size()
	if not locs.is_empty():
		lines.append("Локации:")
		var lcount := 0
		for l in locs:
			if lcount >= loc_limit:
				break
			lines.append("- %s — %s" % [str(l.get("id", "")), str(l.get("name", ""))])
			lcount += 1
	var items: Dictionary = w.get("items", {})
	if not items.is_empty():
		lines.append("Предметы:")
		var count := 0
		var item_limit := 0 if compact else 24
		for id in items:
			if count >= item_limit:
				break
			var item: Dictionary = items[id]
			lines.append("- %s — %s" % [str(id), str(item.get("name", ""))])
			count += 1
	return "\n".join(lines)

func _lore_for(action: String) -> Array:
	var w := GameState.world
	var query := action
	var scene := GameState.current_scene
	if scene != "":
		query += " " + scene.substr(0, 300)
	for ch in GameState.current_choices:
		if ch is Dictionary:
			query += " " + str(ch.get("title", ""))
	var max_chunks := 2
	if GameState.turn_number() <= 1:
		max_chunks = 1
	return WorldDB.retrieve_lore(GameState.world_id, query, GameState.location, GameState.flags, max_chunks)

func _recent_lines() -> String:
	var out: PackedStringArray = []
	for h in GameState.recent_scenes(2):
		var action := str(h.get("action", "")).strip_edges()
		var scene := str(h.get("scene", "")).replace("\n", " ").strip_edges()
		if action == "":
			continue
		out.append("Игрок: " + Kit.shorten(action, 110))
		out.append("Сцена: " + Kit.shorten(scene, RECENT_CHARS))
	return "\n".join(out)

func strip_special(text: String) -> String:
	return text.replace("<|im_start|>", "").replace("<|im_end|>", "").replace("<scene>", "").replace("</scene>", "").replace("<choices>", "").replace("</choices>", "").replace("<delta>", "").replace("</delta>", "")

func stop_sequences() -> PackedStringArray:
	return PackedStringArray(STOP_SEQUENCES)
