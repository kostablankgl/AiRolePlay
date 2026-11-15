extends "res://ui/screen_base.gd"

var _world: Dictionary = {}
var _templates: Array = []
var _selected_index: int = -1
var _template_box: VBoxContainer
var _name_edit: LineEdit
var _age_spin: SpinBox
var _clothes_edit: LineEdit
var _home_edit: LineEdit
var _date_edit: LineEdit
var _location_option: OptionButton
var _preview: VBoxContainer
var _start_btn: Button
var _title_label: Label
var _sub_label: Label
var _form_title: Label

func _ready() -> void:
	var wid := WorldDB.selected_world_id
	_world = WorldDB.get_world(wid)
	if _world.is_empty():
		toast("Мир не найден", true)
		go.call_deferred("res://scenes/world_select.tscn")
		return
	_templates = WorldDB.get_start_templates(_world)
	_build()
	if not _templates.is_empty():
		_select_template(0)

func _build() -> void:
	var outer := setup_page()
	outer.add_child(header("Новая история", "res://scenes/world_select.tscn"))
	var head := Kit.hbox(10)
	_title_label = Kit.label(str(_world.get("title", "")), 26, Palette.TEXT, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title_label)
	var cur: Dictionary = _world.get("currency", {})
	head.add_child(Kit.chip(str(cur.get("symbol", "")) + " " + str(cur.get("major", "")), Palette.GOLD))
	_sub_label = Kit.small(str(_world.get("subtitle", "")), Palette.MUTED)
	head.add_child(_sub_label)
	outer.add_child(head)

	var body := Kit.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	var left := Kit.panel("CardPanel")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.9
	var left_box := Kit.vbox(8)
	left.add_child(left_box)
	left_box.add_child(Kit.label("Кто вы в этом мире?", 19, Palette.GOLD))
	left_box.add_child(Kit.small("Готовые роли задают семью, деньги, вещи и связи. Имя, возраст и одежду можно изменить.", Palette.MUTED))
	var lsc := Kit.scroll()
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_box.add_child(lsc)
	_template_box = Kit.vbox(8)
	_template_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(_template_box)
	body.add_child(left)

	var right := Kit.panel("CardPanel")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.1
	var right_box := Kit.vbox(8)
	right.add_child(right_box)
	_form_title = Kit.label("Детали персонажа", 19, Palette.GOLD)
	right_box.add_child(_form_title)
	var fsc := Kit.scroll()
	fsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(fsc)
	var form := Kit.vbox(10)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fsc.add_child(form)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Имя"
	_name_edit.custom_minimum_size.y = 50
	form.add_child(Kit.field_row("Имя", _name_edit))
	_age_spin = SpinBox.new()
	_age_spin.min_value = 16
	_age_spin.max_value = 90
	_age_spin.value = 25
	_age_spin.custom_minimum_size.y = 50
	form.add_child(Kit.field_row("Возраст", _age_spin))
	_clothes_edit = LineEdit.new()
	_clothes_edit.placeholder_text = "Во что вы одеты"
	_clothes_edit.custom_minimum_size.y = 50
	form.add_child(Kit.field_row("Одежда", _clothes_edit))
	_home_edit = LineEdit.new()
	_home_edit.placeholder_text = "Где вы живёте"
	_home_edit.custom_minimum_size.y = 50
	form.add_child(Kit.field_row("Дом", _home_edit))
	_date_edit = LineEdit.new()
	_date_edit.placeholder_text = "ГГГГ-ММ-ДД"
	_date_edit.custom_minimum_size.y = 50
	form.add_child(Kit.field_row("Дата старта", _date_edit))
	_location_option = OptionButton.new()
	_location_option.custom_minimum_size.y = 50
	var locs := WorldDB.get_locations(_world)
	for i in range(locs.size()):
		var loc: Dictionary = locs[i]
		_location_option.add_item(str(loc.get("name", loc.get("id", ""))), i)
		_location_option.set_item_metadata(i, str(loc.get("id", "")))
	form.add_child(Kit.field_row("Место старта", _location_option))
	form.add_child(Kit.separator())
	_preview = Kit.vbox(6)
	form.add_child(_preview)
	right_box.add_child(Kit.separator())
	var action_row := Kit.hbox(8)
	action_row.add_child(Kit.spacer())
	_start_btn = Kit.button("Начать историю", "AccentButton")
	_start_btn.custom_minimum_size = Vector2(240, 56)
	_start_btn.pressed.connect(_start_story)
	action_row.add_child(_start_btn)
	right_box.add_child(action_row)
	body.add_child(right)

func _refresh_templates() -> void:
	Kit.clear(_template_box)
	for i in range(_templates.size()):
		_template_box.add_child(_template_card(_templates[i], i))
	var custom := _template_card({
		"id": "_custom",
		"name": "Свой персонаж",
		"role": "свободная роль",
		"description": "Имя, возраст и одежда — ваши. Стартовые деньги и связи возьмём из первой готовой роли этого мира.",
	}, -2)
	_template_box.add_child(custom)

func _template_card(t: Dictionary, index: int) -> Button:
	var b := Kit.button("")
	b.theme_type_variation = "ChoiceButton"
	b.custom_minimum_size = Vector2(0, 96)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var heading := str(t.get("name", ""))
	var role := str(t.get("role", ""))
	var desc := str(t.get("description", ""))
	b.text = "%s\n%s\n%s" % [heading, role, Kit.shorten(desc, 120)]
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(_select_template.bind(index))
	if index == _selected_index:
		b.modulate = Color(1.0, 0.95, 0.82, 1.0)
	else:
		b.modulate = Color(1, 1, 1, 0.86)
	return b

func _select_template(index: int) -> void:
	_selected_index = index
	_refresh_templates()
	if index == -2:
		_form_title.text = "Свой персонаж"
		_name_edit.text = ""
		_age_spin.value = 25
		_clothes_edit.text = ""
		_home_edit.text = str(_world.get("default_home", ""))
		_date_edit.text = _default_date()
		_pick_location(_default_location())
		_refresh_preview({})
		return
	if index < 0 or index >= _templates.size():
		return
	var t: Dictionary = _templates[index]
	var c: Dictionary = t.get("character", {})
	_form_title.text = "Роль: " + str(t.get("role", ""))
	_name_edit.text = str(c.get("name", t.get("name", "")))
	_age_spin.value = int(c.get("age", 25))
	_clothes_edit.text = str(c.get("clothes", ""))
	_home_edit.text = str(c.get("home", t.get("home", _world.get("default_home", ""))))
	_date_edit.text = str(t.get("start_date", _default_date()))
	_pick_location(str(t.get("start_location", _default_location())))
	_refresh_preview(t)

func _default_date() -> String:
	var t: Dictionary = _templates[0] if not _templates.is_empty() else {}
	return str(t.get("start_date", WorldDB.default_date(_world)))

func _default_location() -> String:
	var locs := WorldDB.get_locations(_world)
	if locs.is_empty():
		return ""
	return str(locs[0].get("id", ""))

func _pick_location(id: String) -> void:
	for i in range(_location_option.item_count):
		if str(_location_option.get_item_metadata(i)) == id:
			_location_option.select(i)
			return
	if _location_option.item_count > 0:
		_location_option.select(0)

func _refresh_preview(t: Dictionary) -> void:
	Kit.clear(_preview)
	if t.is_empty():
		_preview.add_child(Kit.small("Это свободная роль. Деньги, вещи и связи будут как у первой готовой роли мира.", Palette.MUTED))
		return
	var home := str(t.get("home", _world.get("default_home", "")))
	if home != "":
		var hrow := Kit.hbox(8)
		hrow.add_child(Kit.small("Дом"))
		hrow.add_child(Kit.spacer())
		hrow.add_child(Kit.label(home, 15, Palette.TEXT, true))
		_preview.add_child(hrow)
	var fin: Dictionary = t.get("finances", {})
	if not fin.is_empty():
		var flabels: Dictionary = _world.get("finance_labels", {})
		_preview.add_child(Kit.label("Стартовый капитал", 15, Palette.GOLD))
		var row := Kit.hbox(8)
		row.add_child(Kit.small(str(flabels.get("cash", "Наличные"))))
		row.add_child(Kit.spacer())
		row.add_child(Kit.label(WorldDB.format_money(int(fin.get("cash_minor", 0)), _world), 16, Palette.TEXT))
		_preview.add_child(row)
		var row2 := Kit.hbox(8)
		row2.add_child(Kit.small(str(flabels.get("bank", "В банке"))))
		row2.add_child(Kit.spacer())
		row2.add_child(Kit.label(WorldDB.format_money(int(fin.get("bank_minor", 0)), _world), 16, Palette.TEXT))
		_preview.add_child(row2)
	var inv: Array = t.get("inventory", [])
	if not inv.is_empty():
		_preview.add_child(Kit.label("С собой", 15, Palette.GOLD))
		var names: Array[String] = []
		for item_v in inv:
			if item_v is Dictionary:
				var cat := WorldDB.get_item(_world, str(item_v.get("id", "")))
				names.append(str(cat.get("name", item_v.get("id", ""))))
		_preview.add_child(Kit.small(", ".join(names), Palette.TEXT))
	var rel: Dictionary = t.get("relationships", {})
	if not rel.is_empty():
		_preview.add_child(Kit.label("Связи", 15, Palette.GOLD))
		for cid in rel:
			var c := WorldDB.get_character(_world, str(cid))
			var entry: Variant = rel[cid]
			var level: int = int(entry.get("level", 0)) if entry is Dictionary else int(entry)
			_preview.add_child(Kit.small("%s — %s" % [str(c.get("name", cid)), GameState.rel_label(level)], Palette.TEXT))

func _start_story() -> void:
	var name := _name_edit.text.strip_edges()
	if name == "":
		toast("Введите имя персонажа", true)
		_name_edit.grab_focus()
		return
	if not GameState.is_valid_date(_date_edit.text.strip_edges()):
		toast("Дата должна быть в формате ГГГГ-ММ-ДД", true)
		_date_edit.grab_focus()
		return
	var template: Dictionary = {}
	if _selected_index >= 0 and _selected_index < _templates.size():
		template = _templates[_selected_index]
	elif not _templates.is_empty():
		template = _templates[0]
	var char: Dictionary
	if _selected_index == -2:
		char = {
			"name": name,
			"age": int(_age_spin.value),
			"title": "новое лицо в этом мире",
			"is_heir": false,
			"clothes": _clothes_edit.text.strip_edges(),
			"home": _home_edit.text.strip_edges(),
			"skills": [],
			"abilities": [],
		}
	else:
		char = template.get("character", {}).duplicate(true)
		char["name"] = name
		char["age"] = int(_age_spin.value)
		char["clothes"] = _clothes_edit.text.strip_edges()
		char["home"] = _home_edit.text.strip_edges()
		if str(char.get("title", "")) == "":
			char["title"] = str(template.get("role", ""))
	var loc_id := _default_location()
	if _location_option.item_count > 0:
		loc_id = str(_location_option.get_item_metadata(_location_option.selected))
	var loc := WorldDB.get_location(_world, loc_id)
	var date := _date_edit.text.strip_edges()
	var intro := str(template.get("intro", ""))
	if _selected_index == -2 or intro == "":
		intro = "Начало истории. %s, %s. %s Вы — %s, %s." % [
			GameState.format_date_ru(date),
			str(loc.get("name", loc_id)),
			str(_world.get("description", "")),
			name,
			str(char.get("title", "новое лицо в этом мире")),
		]
	var opts := {
		"location": loc_id,
		"date": date,
		"intro": intro,
		"home": _home_edit.text.strip_edges(),
	}
	GameState.start_new(_world, template, char, opts)
	if not SaveManager.save_game(false):
		toast("Не удалось сохранить новую историю", true)
		return
	go("res://scenes/game_screen.tscn")
