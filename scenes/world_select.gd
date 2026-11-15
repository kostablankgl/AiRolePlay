extends "res://ui/screen_base.gd"

var _grid: GridContainer
var _empty: Label
var _zip_dialog: FileDialog
var _folder_dialog: FileDialog

func _ready() -> void:
	WorldDB.reload()
	_build()

func _build() -> void:
	var outer := setup_page()
	outer.add_child(header("Выберите мир", "res://scenes/main_menu.tscn"))
	var intro := Kit.label("Каждый мир — отдельный пак: свои персонажи, законы, валюта и лор. Можно импортировать ZIP или папку с world.json.", 17, Palette.MUTED, true)
	outer.add_child(intro)
	var sc := Kit.scroll()
	outer.add_child(sc)
	_grid = Kit.grid(2, 14, 14)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)
	_empty = Kit.small("", Palette.WARN)
	outer.add_child(_empty)
	_zip_dialog = FileDialog.new()
	_zip_dialog.use_native_dialog = true
	_zip_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_zip_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_zip_dialog.filters = PackedStringArray(["*.zip ; Пак мира ZIP"])
	_zip_dialog.title = "Импортировать мир из ZIP"
	_zip_dialog.file_selected.connect(_import_zip)
	add_child(_zip_dialog)
	_folder_dialog = FileDialog.new()
	_folder_dialog.use_native_dialog = true
	_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.title = "Импортировать мир из папки"
	_folder_dialog.dir_selected.connect(_import_folder)
	add_child(_folder_dialog)
	_refresh()

func _refresh() -> void:
	Kit.clear(_grid)
	var list := WorldDB.list_worlds()
	if list.is_empty():
		_empty.text = "Миры не найдены. Импортируйте пак или проверьте user://worlds."
	else:
		_empty.text = ""
	for w in list:
		_grid.add_child(_world_card(w))
	_grid.add_child(_import_card())

func _world_card(w: Dictionary) -> PanelContainer:
	var p := Kit.panel("CardPanel")
	p.custom_minimum_size = Vector2(340, 0)
	var box := Kit.vbox(8)
	p.add_child(box)
	var top := Kit.hbox(8)
	var title := Kit.label(str(w.get("title", "Мир")), 26, Palette.TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 200
	top.add_child(title)
	var cur: Dictionary = w.get("currency", {})
	top.add_child(Kit.chip(str(cur.get("symbol", "")) + " " + str(cur.get("major", "")), Palette.GOLD))
	box.add_child(top)
	var sub := str(w.get("subtitle", ""))
	if sub != "":
		box.add_child(Kit.label(sub, 16, Palette.GOLD))
	box.add_child(Kit.label(str(w.get("description", "")), 15, Palette.MUTED, true))
	var stats := Kit.hbox(6)
	stats.add_child(Kit.chip("%d персонажей" % w.get("characters", []).size(), Palette.BLUE))
	stats.add_child(Kit.chip("%d локаций" % w.get("locations", []).size(), Palette.BLUE))
	stats.add_child(Kit.chip("%d стартов" % w.get("start_templates", []).size(), Palette.BLUE))
	box.add_child(stats)
	var principles: Array = w.get("principles", [])
	if not principles.is_empty():
		var names: Array[String] = []
		for pr in principles:
			if pr is Dictionary:
				names.append(str(pr.get("name", "")))
		if not names.is_empty():
			box.add_child(Kit.small("Тон: " + ", ".join(names), Palette.MUTED))
	box.add_child(Kit.spacer())
	var row := Kit.hbox(8)
	var data := Kit.button("Данные мира", "GhostButton")
	data.custom_minimum_size = Vector2(150, 48)
	data.pressed.connect(_show_world_data.bind(w))
	row.add_child(data)
	row.add_child(Kit.spacer())
	var start := Kit.button("Начать историю", "AccentButton")
	start.custom_minimum_size = Vector2(190, 52)
	start.pressed.connect(_select.bind(str(w.get("id", ""))))
	row.add_child(start)
	box.add_child(row)
	return p

func _import_card() -> PanelContainer:
	var p := Kit.panel("InsetPanel")
	p.custom_minimum_size = Vector2(340, 0)
	var box := Kit.vbox(8)
	p.add_child(box)
	box.add_child(Kit.label("Добавить свой мир", 18, Palette.GOLD))
	box.add_child(Kit.small("ZIP или папка с world.json, персонажами, локациями и лором. После импорта мир появится сразу.", Palette.MUTED))
	var row := Kit.hbox(8)
	var z := Kit.button("Импорт ZIP", "GhostButton")
	z.custom_minimum_size = Vector2(150, 48)
	z.pressed.connect(func() -> void: _zip_dialog.popup_centered_ratio(0.8))
	row.add_child(z)
	var f := Kit.button("Импорт папки", "GhostButton")
	f.custom_minimum_size = Vector2(150, 48)
	f.pressed.connect(func() -> void: _folder_dialog.popup_centered_ratio(0.8))
	row.add_child(f)
	box.add_child(row)
	return p

func _import_zip(path: String) -> void:
	var result := WorldDB.import_world_zip(path)
	_after_import(result)
	if result.get("ok", false):
		WorldDB.reload()
		_refresh()

func _import_folder(path: String) -> void:
	var result := WorldDB.import_world_folder(path)
	_after_import(result)
	if result.get("ok", false):
		WorldDB.reload()
		_refresh()

func _after_import(result: Dictionary) -> void:
	if result.get("ok", false):
		toast("Импортирован мир: " + str(result.get("title", result.get("id", ""))))
	else:
		toast(str(result.get("error", "Не удалось импортировать мир")), true)

func _show_world_data(w: Dictionary) -> void:
	var d := AcceptDialog.new()
	d.title = "Данные мира · " + str(w.get("title", ""))
	d.dialog_autowrap = true
	d.ok_button_text = "Закрыть"
	d.custom_minimum_size = Vector2(760, 620)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(720, 520)
	var box := Kit.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	for row in WorldDB.world_overview(w):
		var line := Kit.hbox(8)
		var k := Kit.label(str(row[0]), 13, Palette.MUTED)
		k.custom_minimum_size.x = 130
		line.add_child(k)
		line.add_child(Kit.label(str(row[1]), 14, Palette.TEXT, true))
		box.add_child(line)
	box.add_child(Kit.separator())
	box.add_child(Kit.label("Персонажи", 15, Palette.GOLD))
	var chars: Array = w.get("characters", [])
	for c_v in chars:
		if c_v is Dictionary:
			box.add_child(Kit.small("%s %s · %s · %s" % [str(c_v.get("emoji", "•")), str(c_v.get("name", "")), str(c_v.get("type", c_v.get("role", ""))), str(c_v.get("group", ""))], Palette.TEXT))
	box.add_child(Kit.label("Локации", 15, Palette.GOLD))
	for l_v in w.get("locations", []):
		if l_v is Dictionary:
			box.add_child(Kit.small("• " + str(l_v.get("name", l_v.get("id", ""))), Palette.TEXT))
	box.add_child(Kit.separator())
	box.add_child(Kit.label("world.json", 15, Palette.GOLD))
	var clean: Dictionary = w.duplicate(true)
	clean.erase("_dir")
	var raw := RichTextLabel.new()
	raw.bbcode_enabled = false
	raw.fit_content = true
	raw.custom_minimum_size = Vector2(680, 0)
	raw.text = JSON.stringify(clean, "  ")
	raw.add_theme_font_size_override("normal_font_size", 12)
	box.add_child(raw)
	d.add_child(sc)
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(780, 660))

func _select(id: String) -> void:
	WorldDB.selected_world_id = id
	go("res://scenes/character_create.tscn")
