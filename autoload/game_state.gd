extends Node
const Kit = preload("res://ui/kit.gd")

signal state_changed
signal turn_recorded

const TOD_MORNING := "morning"
const TOD_AFTERNOON := "afternoon"
const TOD_EVENING := "evening"
const TOD_NIGHT := "night"

const FALLBACK_DATE := "1000-01-01"
const MONTHS_RU := ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]

var world_id: String = ""
var world: Dictionary = {}
var character: Dictionary = {}
var time: Dictionary = {"date": FALLBACK_DATE, "minutes": 540}
var location: String = ""
var finances: Dictionary = {}
var inventory: Array = []
var inventory_slots: int = 8
var relationships: Dictionary = {}
var flags: Array = []
var history: Array = []
var summary: String = ""
var timeline: Array = []
var current_scene: String = ""
var current_choices: Array = []
var meta: Dictionary = {}
var last_action: String = ""
var last_report: Dictionary = {}

func _ready() -> void:
	clear()

func clear() -> void:
	world_id = ""
	world = {}
	character = {}
	time = {"date": FALLBACK_DATE, "minutes": 540}
	location = ""
	finances = {"cash_minor": 0, "bank_minor": 0, "trust_minor": 0, "income": [], "property": []}
	inventory = []
	inventory_slots = 8
	relationships = {}
	flags = []
	history = []
	summary = ""
	timeline = []
	current_scene = ""
	current_choices = []
	meta = {"id": "", "title": "", "created": 0, "updated": 0, "turn": 0}
	last_action = ""
	last_report = {}
	state_changed.emit()

func is_loaded() -> bool:
	return world_id != "" and not world.is_empty()

func start_new(w: Dictionary, template: Dictionary, char: Dictionary, opts: Dictionary) -> void:
	clear()
	world = w
	world_id = str(w.get("id", ""))
	character = char.duplicate(true)
	if str(character.get("home", "")).strip_edges() == "":
		character["home"] = str(opts.get("home", template.get("home", w.get("default_home", ""))))
	finances = _default_finances()
	var tfin: Dictionary = template.get("finances", {})
	for k in ["cash_minor", "bank_minor", "trust_minor"]:
		if tfin.has(k):
			finances[k] = int(tfin[k])
	finances["income"] = tfin.get("income", []).duplicate(true)
	finances["property"] = tfin.get("property", []).duplicate(true)
	if opts.has("finances"):
		var of: Dictionary = opts["finances"]
		for k in ["cash_minor", "bank_minor", "trust_minor"]:
			if of.has(k):
				finances[k] = int(of[k])
	inventory = template.get("inventory", []).duplicate(true)
	relationships = _normalize_relationships(template.get("relationships", {}))
	flags = template.get("flags", []).duplicate(true)
	var loc := str(opts.get("location", template.get("start_location", "")))
	if loc == "" and not WorldDB.get_locations(w).is_empty():
		loc = str(WorldDB.get_locations(w)[0].get("id", ""))
	location = loc
	var fallback := WorldDB.default_date(w)
	var date := str(opts.get("date", template.get("start_date", fallback)))
	if not is_valid_date(date):
		date = fallback
	time = {"date": date, "minutes": 9 * 60}
	meta = {
		"id": str(opts.get("id", "")),
		"title": str(character.get("name", "История")) + " · " + str(w.get("title", "")),
		"created": int(Time.get_unix_time_from_system()),
		"updated": int(Time.get_unix_time_from_system()),
		"turn": 0,
	}
	current_scene = str(opts.get("intro", template.get("intro", w.get("intro", ""))))
	current_choices = template.get("start_choices", []).duplicate(true)
	if current_choices.is_empty():
		current_choices = WorldDB.get_default_choices(w)
	summary = ""
	timeline = [{ "date": date, "event": "Начало истории" }]
	history = []
	state_changed.emit()

func load_from_dict(data: Dictionary, w: Dictionary) -> void:
	clear()
	world = w
	world_id = str(data.get("world_id", w.get("id", "")))
	character = data.get("character", {}).duplicate(true)
	if str(character.get("home", "")).strip_edges() == "":
		character["home"] = str(w.get("default_home", ""))
	var t: Variant = data.get("time", {})
	if t is Dictionary:
		var td: Dictionary = t
		var fallback := WorldDB.default_date(w)
		var date := str(td.get("date", fallback))
		var minutes := int(td.get("minutes", -1))
		if minutes < 0:
			minutes = _minutes_from_tod(str(td.get("tod", TOD_MORNING)))
		if not is_valid_date(date):
			date = fallback
		time = {"date": date, "minutes": clampi(minutes, 0, 1439)}
	else:
		time = {"date": FALLBACK_DATE, "minutes": 540}
	location = str(data.get("location", ""))
	if location == "" and not WorldDB.get_locations(w).is_empty():
		location = str(WorldDB.get_locations(w)[0].get("id", ""))
	finances = _default_finances()
	var fin: Variant = data.get("finances", {})
	if fin is Dictionary:
		for k in ["cash_minor", "bank_minor", "trust_minor"]:
			finances[k] = int(fin.get(k, 0))
		finances["income"] = fin.get("income", [])
		finances["property"] = fin.get("property", [])
	inventory = data.get("inventory", []).duplicate(true)
	inventory_slots = clampi(int(data.get("inventory_slots", 8)), 1, 24)
	relationships = _normalize_relationships(data.get("relationships", {}))
	flags = data.get("flags", []).duplicate(true)
	history = data.get("history", []).duplicate(true)
	summary = str(data.get("summary", ""))
	timeline = data.get("timeline", []).duplicate(true)
	current_scene = str(data.get("current_scene", ""))
	current_choices = data.get("current_choices", []).duplicate(true)
	if current_choices.is_empty():
		current_choices = WorldDB.get_default_choices(w)
	meta = data.get("meta", {}).duplicate(true)
	if not meta.has("id"):
		meta["id"] = str(data.get("id", ""))
	meta["turn"] = int(meta.get("turn", data.get("turn", 0)))
	meta["updated"] = int(meta.get("updated", 0))
	meta["created"] = int(meta.get("created", 0))
	last_action = str(data.get("last_action", ""))
	state_changed.emit()

func to_dict() -> Dictionary:
	return {
		"world_id": world_id,
		"character": character.duplicate(true),
		"time": { "date": time.get("date", ""), "minutes": int(time.get("minutes", 540)), "tod": get_tod() },
		"location": location,
		"finances": finances.duplicate(true),
		"inventory": inventory.duplicate(true),
		"inventory_slots": inventory_slots,
		"relationships": relationships.duplicate(true),
		"flags": flags.duplicate(true),
		"history": history.duplicate(true),
		"summary": summary,
		"timeline": timeline.duplicate(true),
		"current_scene": current_scene,
		"current_choices": current_choices.duplicate(true),
		"meta": meta.duplicate(true),
		"last_action": last_action,
		"turn": int(meta.get("turn", 0)),
	}

func _default_finances() -> Dictionary:
	return {"cash_minor": 0, "bank_minor": 0, "trust_minor": 0, "income": [], "property": []}

func is_valid_date(date: String) -> bool:
	var parts := date.split("-")
	if parts.size() != 3:
		return false
	if not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	var y := int(parts[0])
	var m := int(parts[1])
	var d := int(parts[2])
	if y < 1 or y > 9999 or m < 1 or m > 12:
		return false
	return d >= 1 and d <= days_in_month(y, m)

func days_in_month(y: int, m: int) -> int:
	match m:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			var leap := (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)
			return 29 if leap else 28
	return 30

func add_days(date: String, days: int) -> String:
	var parts := date.split("-")
	if parts.size() != 3:
		return date
	var y := int(parts[0])
	var m := int(parts[1])
	var d := int(parts[2])
	var delta := days
	while delta > 0:
		d += 1
		if d > days_in_month(y, m):
			d = 1
			m += 1
			if m > 12:
				m = 1
				y += 1
		delta -= 1
	while delta < 0:
		d -= 1
		if d < 1:
			m -= 1
			if m < 1:
				m = 12
				y -= 1
			d = days_in_month(y, m)
		delta += 1
	return "%04d-%02d-%02d" % [y, m, d]

func advance_minutes(minutes: int) -> void:
	var total := int(time.get("minutes", 540)) + minutes
	var date := str(time.get("date", FALLBACK_DATE))
	while total >= 1440:
		total -= 1440
		date = add_days(date, 1)
	while total < 0:
		total += 1440
		date = add_days(date, -1)
	time = {"date": date, "minutes": total}
	state_changed.emit()

func get_tod() -> String:
	var m := int(time.get("minutes", 540))
	if m >= 300 and m < 720:
		return TOD_MORNING
	if m >= 720 and m < 1020:
		return TOD_AFTERNOON
	if m >= 1020 and m < 1320:
		return TOD_EVENING
	return TOD_NIGHT

func _minutes_from_tod(tod: String) -> int:
	match tod:
		TOD_MORNING:
			return 540
		TOD_AFTERNOON:
			return 840
		TOD_EVENING:
			return 1140
		TOD_NIGHT:
			return 1380
	return 540

func tod_label(tod: String = "") -> String:
	var t := tod if tod != "" else get_tod()
	match t:
		TOD_MORNING:
			return "утро"
		TOD_AFTERNOON:
			return "день"
		TOD_EVENING:
			return "вечер"
		TOD_NIGHT:
			return "ночь"
	return "день"

func format_date_ru(date: String) -> String:
	var parts := date.split("-")
	if parts.size() != 3:
		return date
	var d := int(parts[2])
	var m := int(parts[1])
	var y := int(parts[0])
	if m < 1 or m > 12:
		return date
	return "%d %s %d" % [d, MONTHS_RU[m - 1], y]

func time_label() -> String:
	return "%s, %s" % [format_date_ru(str(time.get("date", ""))), tod_label()]

func location_name(id: String = "") -> String:
	var lid := id if id != "" else location
	var loc := WorldDB.get_location(world, lid)
	return str(loc.get("name", lid))

func format_money(minor: int) -> String:
	return WorldDB.format_money(minor, world)

func cash() -> int:
	return int(finances.get("cash_minor", 0))

func bank() -> int:
	return int(finances.get("bank_minor", 0))

func trust() -> int:
	return int(finances.get("trust_minor", 0))

func total_money() -> int:
	return cash() + bank() + trust()

func yearly_income() -> int:
	var total := 0
	for inc in finances.get("income", []):
		if inc is Dictionary:
			total += int(inc.get("per_year_minor", 0))
	return total

func money_brief() -> String:
	return format_money(cash())

func add_item(id: String, qty: int = 1, emoji: String = "", item_name: String = "") -> bool:
	if qty <= 0 or id == "wallet":
		return false
	for item_v in inventory:
		var item: Dictionary = item_v
		if str(item.get("id", "")) == id:
			item["qty"] = int(item.get("qty", 0)) + qty
			state_changed.emit()
			return true
	if used_slots() >= inventory_slots:
		return false
	var cat := WorldDB.get_item(world, id)
	if emoji == "":
		emoji = str(cat.get("emoji", "•"))
	if item_name == "":
		item_name = str(cat.get("name", id))
	inventory.append({ "id": id, "emoji": emoji, "name": item_name, "qty": qty })
	state_changed.emit()
	return true

func remove_item(id: String, qty: int = 1) -> bool:
	if id == "wallet":
		return false
	for i in range(inventory.size()):
		var item: Dictionary = inventory[i]
		if str(item.get("id", "")) == id:
			var left := int(item.get("qty", 1)) - qty
			if left <= 0:
				inventory.remove_at(i)
			else:
				item["qty"] = left
			state_changed.emit()
			return true
	return false

func item_name(item: Dictionary) -> String:
	var n := str(item.get("name", ""))
	if n != "":
		return n
	var cat := WorldDB.get_item(world, str(item.get("id", "")))
	return str(cat.get("name", item.get("id", "?")))

func item_emoji(item: Dictionary) -> String:
	var e := str(item.get("emoji", ""))
	if e != "":
		return e
	var cat := WorldDB.get_item(world, str(item.get("id", "")))
	return str(cat.get("emoji", "•"))

func used_slots() -> int:
	return mini(inventory.size() + 1, inventory_slots)

func wallet_item() -> Dictionary:
	var labels: Dictionary = world.get("finance_labels", {})
	return {
		"id": "wallet",
		"emoji": "💰",
		"name": str(labels.get("cash", "Наличные")),
		"qty": 1,
		"is_cash": true,
	}

func inventory_display() -> Array:
	var out: Array = [wallet_item()]
	out.append_array(inventory)
	return out

func item_description(item: Dictionary) -> String:
	if bool(item.get("is_cash", false)) or str(item.get("id", "")) == "wallet":
		return "Наличные на руках. Банк, резерв и доходы — во вкладке «Герой»."
	var cat := WorldDB.get_item(world, str(item.get("id", "")))
	var desc := str(cat.get("desc", ""))
	return desc if desc != "" else "Предмет из этого мира."

func home() -> String:
	return str(character.get("home", "")).strip_edges()

func set_flag(flag: String) -> bool:
	var f := sanitize_flag(flag)
	if f == "" or flags.has(f):
		return false
	flags.append(f)
	if flags.size() > 120:
		flags = flags.slice(flags.size() - 120)
	state_changed.emit()
	return true

func unset_flag(flag: String) -> bool:
	var f := sanitize_flag(flag)
	if flags.has(f):
		flags.erase(f)
		state_changed.emit()
		return true
	return false

func sanitize_flag(flag: String) -> String:
	var f := flag.strip_edges().to_lower().replace(" ", "_")
	if f.length() > 48:
		f = f.substr(0, 48)
	return f

func _normalize_relationships(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Array:
		for entry_v in raw:
			if entry_v is Dictionary:
				var e: Dictionary = entry_v
				var eid := str(e.get("id", "")).strip_edges()
				if eid != "":
					out[eid] = e.duplicate(true)
	elif raw is Dictionary:
		out = raw.duplicate(true)
	for id in out.keys():
		var c := WorldDB.get_character(world, str(id))
		var e: Dictionary = out[id] if out[id] is Dictionary else { "level": int(out[id]) }
		e["level"] = clampi(int(e.get("level", 0)), 0, 5)
		if str(e.get("type", "")).strip_edges() == "":
			e["type"] = str(c.get("type", c.get("role", "знакомый")))
		if str(e.get("group", "")).strip_edges() == "":
			e["group"] = str(c.get("group", "other"))
		if str(e.get("emoji", "")).strip_edges() == "":
			e["emoji"] = str(c.get("emoji", "•"))
		if str(e.get("note", "")).strip_edges() == "":
			e["note"] = str(e.get("secret", c.get("note", "")))
		out[id] = e
	return out

func rel_level(id: String) -> int:
	if not relationships.has(id):
		return 0
	var value: Variant = relationships[id]
	if value is Dictionary:
		return clampi(int(value.get("level", 0)), 0, 5)
	if value is int or value is float:
		return clampi(int(value), 0, 5)
	return 0

func change_rel(id: String, delta: int) -> bool:
	if WorldDB.get_character(world, id).is_empty():
		return false
	var entry: Dictionary = { "level": 0 }
	var old: Variant = relationships.get(id, null)
	if old is Dictionary:
		entry = old
	elif old is int or old is float:
		entry["level"] = int(old)
	entry["level"] = clampi(int(entry.get("level", 0)) + delta, 0, 5)
	relationships[id] = entry
	relationships = _normalize_relationships(relationships)
	state_changed.emit()
	return true

func relationship_rows() -> Array:
	var rows: Array = []
	for id in relationships:
		var c := WorldDB.get_character(world, str(id))
		var value: Variant = relationships[id]
		var level := 0
		var secret := ""
		var note := ""
		var type := ""
		var group := "other"
		var emoji := "•"
		if value is Dictionary:
			level = int(value.get("level", 0))
			secret = str(value.get("secret", ""))
			note = str(value.get("note", secret))
			type = str(value.get("type", ""))
			group = str(value.get("group", "other"))
			emoji = str(value.get("emoji", "•"))
		elif value is int or value is float:
			level = int(value)
		rows.append({
			"id": str(id),
			"name": str(c.get("name", id)),
			"role": str(c.get("role", "")),
			"type": type if type != "" else str(c.get("type", c.get("role", "знакомый"))),
			"group": group if group != "" else str(c.get("group", "other")),
			"group_name": relationship_group_name(group if group != "" else str(c.get("group", "other"))),
			"emoji": emoji if emoji != "" else str(c.get("emoji", "•")),
			"level": clampi(level, 0, 5),
			"note": note,
			"secret": secret,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ga := relationship_group_order(str(a.get("group", "")))
		var gb := relationship_group_order(str(b.get("group", "")))
		if ga != gb:
			return ga < gb
		if int(a["level"]) != int(b["level"]):
			return int(a["level"]) > int(b["level"])
		return str(a["name"]) < str(b["name"])
	)
	return rows

func relationship_groups() -> Array:
	var raw: Array = world.get("relationship_groups", [])
	if raw is Array and not raw.is_empty():
		return raw
	return [
		{ "id": "family", "name": "Семья" },
		{ "id": "staff", "name": "Дом и служба" },
		{ "id": "street", "name": "Улица" },
		{ "id": "corporate", "name": "Корпорации" },
		{ "id": "other", "name": "Знакомые" },
	]

func relationship_group_order(group_id: String) -> int:
	var groups := relationship_groups()
	for i in range(groups.size()):
		if str(groups[i].get("id", "")) == group_id:
			return i
	return groups.size()

func relationship_group_name(group_id: String) -> String:
	for g in relationship_groups():
		if str(g.get("id", "")) == group_id:
			return str(g.get("name", group_id))
	return "Знакомые"

func rel_label(level: int) -> String:
	match clampi(level, 0, 5):
		0:
			return "нейтрально"
		1:
			return "знакомство"
		2:
			return "симпатия"
		3:
			return "дружба"
		4:
			return "близость"
		5:
			return "доверие"
	return "нейтрально"

func prompt_state() -> Dictionary:
	var loc := WorldDB.get_location(world, location)
	return {
		"world": str(world.get("title", "")),
		"character": {
			"name": str(character.get("name", "")),
			"age": int(character.get("age", 0)),
			"title": str(character.get("title", "")),
			"is_heir": bool(character.get("is_heir", false)),
			"home": home(),
			"clothes": str(character.get("clothes", "")),
			"skills": character.get("skills", []),
			"abilities": character.get("abilities", []),
		},
		"time": { "date": str(time.get("date", "")), "tod": tod_label() },
		"location": { "id": location, "name": str(loc.get("name", location)) },
		"finances": {
			"cash_minor": cash(),
			"bank_minor": bank(),
			"trust_minor": trust(),
			"income": finances.get("income", []),
			"property": finances.get("property", []),
		},
		"inventory": inventory.duplicate(true),
		"relationships": relationships.duplicate(true),
		"flags": flags.slice(maxi(0, flags.size() - 40)),
	}

func apply_delta(delta: Variant) -> Dictionary:
	var report := { "ok": true, "applied": {}, "rejected": [], "time_advanced": false }
	if not (delta is Dictionary):
		report["ok"] = true
		return report
	var d: Dictionary = delta
	if d.is_empty():
		return report
	for key in ["cash_minor", "bank_minor", "trust_minor"]:
		if not d.has(key):
			continue
		var dv: Variant = _as_int(d[key])
		if dv == null:
			report["rejected"].append("неверная сумма " + key)
			continue
		var current := int(finances.get(key, 0))
		var next := current + int(dv)
		if next < 0:
			report["rejected"].append("недостаточно средств: " + key)
			continue
		finances[key] = next
		report["applied"][key] = int(dv)
	if d.has("inventory_add"):
		var adds: Array = d["inventory_add"] if d["inventory_add"] is Array else [d["inventory_add"]]
		for add_v in adds:
			if not (add_v is Dictionary):
				continue
			var add: Dictionary = add_v
			var iid := str(add.get("id", "")).strip_edges()
			if iid == "":
				report["rejected"].append("предмет без id")
				continue
			if iid == "wallet":
				report["rejected"].append("wallet управляется через cash_minor")
				continue
			var qty := int(_as_int(add.get("qty", 1)))
			if qty <= 0:
				qty = 1
			if add_item(iid, qty, str(add.get("emoji", "")), str(add.get("name", ""))):
				report["applied"]["inventory_add"] = true
			else:
				report["rejected"].append("нет места для предмета " + iid)
	if d.has("inventory_remove"):
		var rems: Array = d["inventory_remove"] if d["inventory_remove"] is Array else [d["inventory_remove"]]
		for rem_v in rems:
			var rid := ""
			var rqty := 1
			if rem_v is Dictionary:
				rid = str(rem_v.get("id", ""))
				rqty = int(_as_int(rem_v.get("qty", 1)))
			else:
				rid = str(rem_v)
			if rid != "" and remove_item(rid, maxi(1, rqty)):
				report["applied"]["inventory_remove"] = true
			elif rid != "":
				report["rejected"].append("нет предмета " + rid)
	if d.has("rel"):
		var rel: Variant = d["rel"]
		if rel is Dictionary:
			for cid in rel:
				var rv: Variant = rel[cid]
				var dv2: Variant = null
				if rv is Dictionary:
					dv2 = _as_int(rv.get("delta", rv.get("level", 0)))
				else:
					dv2 = _as_int(rv)
				if dv2 == null:
					report["rejected"].append("неверное отношение " + str(cid))
					continue
				if change_rel(str(cid), int(dv2)):
					report["applied"]["rel"] = true
				else:
					report["rejected"].append("неизвестный персонаж " + str(cid))
	if d.has("add_flag"):
		var af: Variant = d["add_flag"]
		var af_list: Array = af if af is Array else [af]
		for f in af_list:
			if set_flag(str(f)):
				report["applied"]["flag"] = true
	if d.has("add_flags"):
		var afs: Variant = d["add_flags"]
		var afs_list: Array = afs if afs is Array else [afs]
		for f in afs_list:
			if set_flag(str(f)):
				report["applied"]["flag"] = true
	if d.has("remove_flags"):
		var rfs: Variant = d["remove_flags"]
		var rfs_list: Array = rfs if rfs is Array else [rfs]
		for f in rfs_list:
			if unset_flag(str(f)):
				report["applied"]["flag_removed"] = true
	if d.has("time_advance"):
		var ta: Variant = d["time_advance"]
		if ta is Dictionary:
			var minutes := int(_as_int(ta.get("minutes", 0)))
			minutes += int(_as_int(ta.get("hours", 0))) * 60
			minutes += int(_as_int(ta.get("days", 0))) * 1440
			if minutes != 0:
				advance_minutes(minutes)
				report["time_advanced"] = true
				report["applied"]["time"] = minutes
	if d.has("location"):
		var lid := str(d["location"]).strip_edges()
		if not WorldDB.get_location(world, lid).is_empty():
			location = lid
			report["applied"]["location"] = lid
			report["location_changed"] = true
			state_changed.emit()
		else:
			report["rejected"].append("неизвестная локация " + lid)
	if d.has("add_skills"):
		var sk: Variant = d["add_skills"]
		var sk_list: Array = sk if sk is Array else [sk]
		var skills: Array = character.get("skills", [])
		for s in sk_list:
			var skill := str(s).strip_edges().substr(0, 48)
			if skill != "" and not skills.has(skill) and skills.size() < 20:
				skills.append(skill)
				report["applied"]["skills"] = true
		character["skills"] = skills
	if d.has("add_abilities"):
		var ab: Variant = d["add_abilities"]
		var ab_list: Array = ab if ab is Array else [ab]
		var abilities: Array = character.get("abilities", [])
		for a in ab_list:
			var ability := str(a).strip_edges().substr(0, 64)
			if ability != "" and not abilities.has(ability) and abilities.size() < 20:
				abilities.append(ability)
				report["applied"]["abilities"] = true
		character["abilities"] = abilities
	if d.has("clothes"):
		var cl := str(d["clothes"]).strip_edges()
		if cl != "" and cl.length() <= 140:
			character["clothes"] = cl
			report["applied"]["clothes"] = true
	if d.has("timeline_event"):
		var ev := str(d["timeline_event"]).strip_edges().substr(0, 140)
		if ev != "":
			timeline.append({ "date": str(time.get("date", "")), "event": ev })
			_trim_timeline()
			report["applied"]["timeline"] = ev
	if not report["rejected"].is_empty():
		report["ok"] = false
		_log_rejected(report)
	last_report = report
	state_changed.emit()
	return report

func _log_rejected(report: Dictionary) -> void:
	var rejected: Array = report.get("rejected", [])
	if rejected.is_empty():
		return
	DirAccess.make_dir_recursive_absolute("user://logs")
	var path := "user://logs/delta.log"
	var old := ""
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			old = f.get_as_text()
			f.close()
		if old.length() > 48000:
			old = old.substr(old.length() - 32000)
	var line := "%s | turn %d | %s\n" % [Time.get_datetime_string_from_system(), turn_number(), ", ".join(rejected)]
	var out := FileAccess.open(path, FileAccess.WRITE)
	if out != null:
		out.store_string(old + line)
		out.close()

func _as_int(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return int(v)
		TYPE_FLOAT:
			return int(round(float(v)))
		TYPE_STRING:
			var s := str(v).strip_edges()
			if s.is_valid_int():
				return int(s)
			if s.is_valid_float():
				return int(round(float(s)))
	return null

func record_intro(scene: String, choices: Array) -> void:
	current_scene = scene
	current_choices = choices.duplicate(true)
	meta["turn"] = 1
	meta["updated"] = int(Time.get_unix_time_from_system())
	summary = Kit.shorten(scene.replace("\n", " "), 650)
	timeline.append({ "date": str(time.get("date", "")), "event": "История началась" })
	_trim_timeline()
	advance_minutes(15)
	state_changed.emit()
	turn_recorded.emit()

func record_turn(action: String, scene: String, choices: Array, report: Dictionary) -> void:
	last_action = action
	history.append({
		"date": str(time.get("date", "")),
		"location": location,
		"action": action,
		"scene": scene,
	})
	while history.size() > 3:
		history.pop_front()
	current_scene = scene
	current_choices = choices.duplicate(true)
	meta["turn"] = int(meta.get("turn", 0)) + 1
	meta["updated"] = int(Time.get_unix_time_from_system())
	if not bool(report.get("time_advanced", false)):
		advance_minutes(20)
	var ev: String = "Сцена: " + Kit.shorten(scene.replace("\n", " "), 90)
	if not report.get("applied", {}).has("timeline"):
		timeline.append({ "date": str(time.get("date", "")), "event": ev })
		_trim_timeline()
	_update_summary(action, scene)
	state_changed.emit()
	turn_recorded.emit()

func _update_summary(action: String, scene: String) -> void:
	var addition: String = "«%s» → %s" % [Kit.shorten(action, 160), Kit.shorten(scene.replace("\n", " "), 320)]
	if summary == "":
		summary = addition
	else:
		summary += "\n" + addition
	if summary.length() > 1300:
		summary = summary.substr(summary.length() - 1300)
		var cut := summary.find("\n")
		if cut > 0:
			summary = summary.substr(cut + 1)

func _trim_timeline() -> void:
	while timeline.size() > 80:
		timeline.pop_front()

func recent_scenes(count: int = 2) -> Array:
	var out: Array = []
	var start := maxi(0, history.size() - count)
	for i in range(start, history.size()):
		out.append(history[i])
	return out

func title() -> String:
	return str(meta.get("title", "История"))

func turn_number() -> int:
	return int(meta.get("turn", 0))
