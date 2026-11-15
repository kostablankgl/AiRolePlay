extends "res://ui/screen_base.gd"

var _grid: GridContainer
var _empty: Label

func _ready() -> void:
	WorldDB.reload()
	_build()

func _build() -> void:
	var outer := setup_page()
	outer.add_child(header("Выберите мир", "res://scenes/main_menu.tscn"))
	var intro := Kit.label("Каждый мир — отдельный пак: свои персонажи, законы, валюта и лор. Выберите вселенную для новой истории.", 17, Palette.MUTED, true)
	outer.add_child(intro)
	var sc := Kit.scroll()
	outer.add_child(sc)
	_grid = Kit.grid(2, 14, 14)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)
	_empty = Kit.small("", Palette.WARN)
	outer.add_child(_empty)
	_refresh()

func _refresh() -> void:
	Kit.clear(_grid)
	var list := WorldDB.list_worlds()
	if list.is_empty():
		_empty.text = "Миры не найдены. Проверьте user://worlds или встроенные паки."
		return
	_empty.text = ""
	for w in list:
		_grid.add_child(_world_card(w))
	var hint := Kit.panel("InsetPanel")
	var box := Kit.vbox(5)
	box.add_child(Kit.label("Добавить свой мир", 16, Palette.GOLD))
	box.add_child(Kit.small("Создайте папку user://worlds/<id>/ с world.json и lore/*.md — движок подхватит её при следующем запуске. Код менять не нужно.", Palette.MUTED))
	hint.add_child(box)
	_grid.add_child(hint)

func _world_card(w: Dictionary) -> PanelContainer:
	var p := Kit.panel("CardPanel")
	p.custom_minimum_size = Vector2(0, 330)
	var box := Kit.vbox(8)
	p.add_child(box)
	var top := Kit.hbox(8)
	top.add_child(Kit.label(str(w.get("title", "Мир")), 24, Palette.TEXT, true))
	top.add_child(Kit.spacer())
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
	row.add_child(Kit.spacer())
	var start := Kit.button("Начать историю", "AccentButton")
	start.custom_minimum_size = Vector2(190, 52)
	start.pressed.connect(_select.bind(str(w.get("id", ""))))
	row.add_child(start)
	box.add_child(row)
	return p

func _select(id: String) -> void:
	WorldDB.selected_world_id = id
	go("res://scenes/character_create.tscn")
