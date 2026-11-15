extends "res://ui/screen_base.gd"

var _saves_box: VBoxContainer
var _continue_btn: Button
var _model_label: Label
var _saves_count: Label
var _confirm: ConfirmationDialog
var _pending_delete_id: String = ""
var _pending_delete_title: String = ""

func _ready() -> void:
	_build()
	SaveManager.saves_changed.connect(_refresh_saves)
	_refresh_saves()
	_refresh_model_line()

func _build() -> void:
	var outer := setup_page()
	var top := Kit.hbox(12)
	outer.add_child(top)
	var brand := Kit.vbox(0)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(Kit.label("Мастер историй", 30, Palette.GOLD))
	brand.add_child(Kit.small("Локальные ролевые истории. Своя GGUF-модель или OpenRouter.", Palette.MUTED))
	top.add_child(brand)
	var settings_btn := Kit.button("⚙  Настройки", "GhostButton")
	settings_btn.custom_minimum_size = Vector2(170, 48)
	settings_btn.pressed.connect(func() -> void: go("res://scenes/settings.tscn"))
	top.add_child(settings_btn)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Удалить историю?"
	_confirm.ok_button_text = "Удалить"
	_confirm.cancel_button_text = "Отмена"
	_confirm.confirmed.connect(_confirm_delete)
	add_child(_confirm)

	var hero := Kit.hbox(18)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(hero)
	var intro := Kit.vbox(14)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.add_child(intro)
	var kicker := Kit.chip("ДВИЖОК МИРОВ · v0.1", Palette.GOLD)
	var kicker_row := Kit.hbox(0)
	kicker_row.add_child(kicker)
	kicker_row.add_child(Kit.spacer())
	intro.add_child(kicker_row)
	intro.add_child(Kit.label("История, которая помнит\nваши решения.", 46, Palette.TEXT, true))
	intro.add_child(Kit.label("Выберите мир, персонажа и точку старта. Дальше мастер ведёт сцену, а движок сам считает время, деньги, отношения и последствия. Всё хранится на планшете.", 18, Palette.MUTED, true))
	var actions := Kit.hbox(12)
	actions.add_child(_action_button("Новая история", "AccentButton", _new_story))
	_continue_btn = _action_button("Продолжить", "Button", _continue_latest)
	actions.add_child(_continue_btn)
	actions.add_child(_action_button("Как это работает", "GhostButton", _show_help))
	intro.add_child(actions)
	var features := Kit.grid(3, 10, 10)
	features.add_child(_mini_card("🏛", "Миры как паки", "Новый мир — папка с лором и валютой, без правки кода."))
	features.add_child(_mini_card("🧠", "Своя модель", "GGUF в user://models или OpenRouter. Локальный режим работает на CPU."))
	features.add_child(_mini_card("💾", "Память и автосейв", "Состояние, хроника и отношения хранятся в JSON."))
	intro.add_child(features)
	_model_label = Kit.small("", Palette.MUTED)
	intro.add_child(_model_label)

	var side := Kit.panel("CardPanel")
	side.custom_minimum_size = Vector2(430, 0)
	var side_box := Kit.vbox(10)
	side.add_child(side_box)
	var side_head := Kit.hbox(8)
	side_head.add_child(Kit.label("Ваши истории", 21, Palette.GOLD))
	side_head.add_child(Kit.spacer())
	_saves_count = Kit.small("", Palette.MUTED)
	side_head.add_child(_saves_count)
	side_box.add_child(side_head)
	var sc := Kit.scroll()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_box.add_child(sc)
	_saves_box = Kit.vbox(8)
	_saves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_saves_box)
	hero.add_child(side)

func _action_button(text: String, variation: String, cb: Callable) -> Button:
	var b := Kit.button(text, variation)
	b.custom_minimum_size = Vector2(190, 56)
	b.pressed.connect(cb)
	return b

func _mini_card(icon: String, title: String, body: String) -> PanelContainer:
	var p := Kit.panel("InsetPanel")
	var box := Kit.vbox(5)
	var row := Kit.hbox(8)
	row.add_child(Kit.label(icon, 24, Palette.TEXT))
	row.add_child(Kit.label(title, 16, Palette.TEXT))
	box.add_child(row)
	box.add_child(Kit.small(body, Palette.MUTED))
	p.add_child(box)
	return p

func _refresh_saves() -> void:
	if _saves_box == null:
		return
	Kit.clear(_saves_box)
	var saves := SaveManager.list_saves()
	_saves_count.text = "%d" % saves.size()
	_continue_btn.disabled = saves.is_empty()
	if saves.is_empty():
		var empty := Kit.panel("InsetPanel")
		var box := Kit.vbox(6)
		box.add_child(Kit.label("Пока пусто", 18, Palette.TEXT))
		box.add_child(Kit.small("Создайте первую историю — она сохранится автоматически после каждого хода.", Palette.MUTED))
		empty.add_child(box)
		_saves_box.add_child(empty)
		return
	for entry in saves:
		_saves_box.add_child(_save_card(entry))

func _save_card(entry: Dictionary) -> PanelContainer:
	var p := Kit.panel("InsetPanel")
	var row := Kit.hbox(10)
	p.add_child(row)
	var text := Kit.vbox(3)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := str(entry.get("title", "История"))
	text.add_child(Kit.label(Kit.shorten(title, 40), 16, Palette.TEXT, true))
	var wid := str(entry.get("world_id", ""))
	var w := WorldDB.get_world(wid)
	var meta := str(w.get("title", wid))
	var loc := str(entry.get("location", ""))
	var loc_name := loc
	var loc_data := WorldDB.get_location(w, loc)
	if not loc_data.is_empty():
		loc_name = str(loc_data.get("name", loc))
	var sub := "%s · %s · ход %d" % [meta, loc_name, int(entry.get("turn", 0))]
	text.add_child(Kit.small(sub, Palette.MUTED))
	var date := str(entry.get("date", ""))
	if date != "":
		text.add_child(Kit.small(GameState.format_date_ru(date), Palette.MUTED))
	row.add_child(text)
	var open := Kit.button("Открыть", "GhostButton")
	open.custom_minimum_size = Vector2(104, 46)
	open.pressed.connect(_load_save.bind(str(entry.get("id", ""))))
	row.add_child(open)
	var del := Kit.button("×", "GhostButton")
	del.custom_minimum_size = Vector2(46, 46)
	del.tooltip_text = "Удалить историю"
	del.pressed.connect(_delete_save.bind(str(entry.get("id", "")), title))
	row.add_child(del)
	return p

func _new_story() -> void:
	go("res://scenes/world_select.tscn")

func _continue_latest() -> void:
	var saves := SaveManager.list_saves()
	if saves.is_empty():
		toast("Сохранений пока нет")
		return
	_load_save(str(saves[0].get("id", "")))

func _load_save(id: String) -> void:
	if SaveManager.load_game(id):
		go("res://scenes/game_screen.tscn")
	else:
		toast(SaveManager.last_error, true)

func _delete_save(id: String, title: String) -> void:
	_pending_delete_id = id
	_pending_delete_title = title
	_confirm.dialog_text = "«%s» будет удалена без возможности восстановления." % Kit.shorten(title, 60)
	_confirm.popup_centered(Vector2i(520, 220))

func _confirm_delete() -> void:
	if _pending_delete_id == "":
		return
	if SaveManager.delete_save(_pending_delete_id):
		toast("Удалено: " + Kit.shorten(_pending_delete_title, 30))
	else:
		toast("Не удалось удалить", true)
	_pending_delete_id = ""
	_pending_delete_title = ""

func _refresh_model_line() -> void:
	if _model_label == null:
		return
	if str(SettingsManager.get_value("ai_provider", "local")) == "openrouter":
		_model_label.text = "Провайдер: OpenRouter · " + str(SettingsManager.get_value("openrouter_model", "модель не выбрана"))
		return
	var bytes := ModelManager.expected_size()
	var size := "не выбрана" if bytes <= 0 else "%.1f ГБ" % (float(bytes) / 1073741824.0)
	_model_label.text = "Модель: %s · %s · локально на CPU" % [ModelManager.model_name(), size]

func _show_help() -> void:
	var d := AcceptDialog.new()
	d.title = "Как это работает"
	d.dialog_text = "1. Выберите мир и готового персонажа или создайте своего.\n2. Задайте дату и место старта.\n3. Мастер пишет сцену и три варианта действий.\n4. Можно нажать вариант, написать свой ход или продолжить сцену.\n5. Движок сам меняет время, деньги, предметы, отношения и флаги; после каждого хода — автосохранение.\n\nМодель GGUF импортируется в user://models и работает локально на CPU. В настройках можно подключить OpenRouter."
	d.ok_button_text = "Понятно"
	add_child(d)
	d.popup_centered(Vector2i(640, 420))
