class_name StatusPanel
extends PanelContainer
const Palette = preload("res://ui/app_theme.gd")
const Kit = preload("res://ui/kit.gd")
const DashedSlotType = preload("res://ui/dashed_slot.gd")

var _tab_bar: TabBar
var _body: Control
var _character_box: VBoxContainer
var _inventory_box: VBoxContainer
var _relations_box: VBoxContainer
var _tabs: Array[ScrollContainer] = []
var _built := false

func _ready() -> void:
	_ensure()
	GameState.state_changed.connect(refresh)
	refresh()

func _ensure() -> void:
	if _built:
		return
	_built = true
	theme_type_variation = "CardPanel"
	custom_minimum_size = Vector2(340, 260)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var box := Kit.vbox(6)
	margin.add_child(box)
	_tab_bar = TabBar.new()
	_tab_bar.add_tab("Герой")
	_tab_bar.add_tab("Сумка")
	_tab_bar.add_tab("Отношения")
	_tab_bar.tab_changed.connect(_switch_tab)
	box.add_child(_tab_bar)
	_body = Control.new()
	_body.custom_minimum_size = Vector2.ZERO
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_contents = true
	box.add_child(_body)
	_character_box = _make_tab()
	_inventory_box = _make_tab()
	_relations_box = _make_tab()
	_switch_tab(0)

func _make_tab() -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.follow_focus = true
	sc.custom_minimum_size = Vector2.ZERO
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(sc)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := Kit.vbox(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	_tabs.append(sc)
	return content

func _switch_tab(index: int) -> void:
	for i in range(_tabs.size()):
		_tabs[i].visible = i == index

func open_bag() -> void:
	_tab_bar.current_tab = 1
	_switch_tab(1)

func open_wallet() -> void:
	open_bag()
	_show_item(GameState.wallet_item())

func refresh() -> void:
	if not _built:
		return
	_refresh_character()
	_refresh_inventory()
	_refresh_relations()

func _row(key: String, value: String, color: Color = Palette.TEXT) -> HBoxContainer:
	var line := Kit.hbox(8)
	var k := Kit.label(key, 13, Palette.MUTED)
	k.custom_minimum_size.x = 74
	line.add_child(k)
	var v := Kit.label(value, 14, color, true)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(v)
	return line

func _refresh_character() -> void:
	Kit.clear(_character_box)
	var c := GameState.character
	var name := str(c.get("name", "Безымянный"))
	var role := str(c.get("title", ""))
	_character_box.add_child(Kit.label(name, 22, Palette.TEXT, true))
	if role != "":
		_character_box.add_child(Kit.muted(role, true))
	var facts := Kit.vbox(3)
	facts.add_child(_row("Возраст", "%d" % int(c.get("age", 0)) if int(c.get("age", 0)) > 0 else "—"))
	facts.add_child(_row("Дом", GameState.home() if GameState.home() != "" else "—"))
	facts.add_child(_row("Сейчас", GameState.location_name()))
	facts.add_child(_row("Одежда", str(c.get("clothes", "—"))))
	_character_box.add_child(facts)
	_character_box.add_child(Kit.separator())
	_character_box.add_child(Kit.label("Счета и доходы", 15, Palette.GOLD))
	var labels: Dictionary = GameState.world.get("finance_labels", {})
	var finances := Kit.vbox(3)
	finances.add_child(_row(str(labels.get("cash", "Наличные")), GameState.format_money(GameState.cash()), Palette.GOLD))
	finances.add_child(_row(str(labels.get("bank", "В банке")), GameState.format_money(GameState.bank())))
	finances.add_child(_row(str(labels.get("trust", "Резерв")), GameState.format_money(GameState.trust())))
	if GameState.yearly_income() != 0:
		finances.add_child(_row("Доход", GameState.format_money(GameState.yearly_income()) + "/год"))
	_character_box.add_child(finances)
	var income: Array = GameState.finances.get("income", [])
	if not income.is_empty():
		var lines: PackedStringArray = []
		for inc_v in income:
			if inc_v is Dictionary:
				lines.append("%s — %s/год" % [str(inc_v.get("src", "")), GameState.format_money(int(inc_v.get("per_year_minor", 0)))])
		if not lines.is_empty():
			_character_box.add_child(Kit.small("\n".join(lines), Palette.MUTED))
	var prop: Array = GameState.finances.get("property", [])
	if not prop.is_empty():
		var plines: PackedStringArray = []
		for p_v in prop:
			if p_v is Dictionary:
				plines.append("• " + str(p_v.get("note", p_v.get("id", ""))))
		if not plines.is_empty():
			_character_box.add_child(Kit.small("Собственность:\n" + "\n".join(plines), Palette.MUTED))
	_character_box.add_child(Kit.separator())
	_character_box.add_child(Kit.label("Умения", 15, Palette.GOLD))
	var skills: Array = c.get("skills", [])
	if skills.is_empty():
		_character_box.add_child(Kit.small("—", Palette.MUTED))
	else:
		var wrap := Kit.hbox(6)
		var count := 0
		for s in skills:
			wrap.add_child(Kit.chip(str(s)))
			count += 1
			if count >= 3:
				_character_box.add_child(wrap)
				wrap = Kit.hbox(6)
				count = 0
		if count > 0:
			_character_box.add_child(wrap)
	var abilities: Array = c.get("abilities", [])
	if not abilities.is_empty():
		_character_box.add_child(Kit.label("Особенности", 15, Palette.GOLD))
		for a in abilities:
			_character_box.add_child(Kit.small("• " + str(a), Palette.TEXT))
	_character_box.add_child(Kit.separator())
	var chronicle := Kit.button("Хроника: %d ходов" % GameState.turn_number(), "GhostButton")
	chronicle.custom_minimum_size = Vector2(0, 44)
	chronicle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chronicle.pressed.connect(_show_chronicle)
	_character_box.add_child(chronicle)

func _refresh_inventory() -> void:
	Kit.clear(_inventory_box)
	var slots := int(GameState.inventory_slots)
	var display := GameState.inventory_display()
	_inventory_box.add_child(Kit.label("Сумка · %d/%d" % [mini(display.size(), slots), slots], 19, Palette.GOLD))
	var grid := Kit.grid(4, 10, 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item_v in display:
		grid.add_child(_item_slot(item_v))
	var empty := maxi(0, slots - display.size())
	for i in range(empty):
		var cell := DashedSlotType.new()
		cell.custom_minimum_size = Vector2(0, 96)
		var plus := Kit.label("+", 24, Color(Palette.MUTED, 0.55))
		plus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(plus)
		grid.add_child(cell)
	_inventory_box.add_child(grid)
	_inventory_box.add_child(Kit.small("Наличные — предмет «кошелёк». Банк, резерв и доходы — во вкладке «Герой».", Palette.MUTED))

func _item_slot(item: Dictionary) -> Button:
	var b := Kit.button("")
	b.theme_type_variation = "ItemSlot"
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s\n%s" % [GameState.item_name(item), GameState.item_description(item)]
	b.pressed.connect(_show_item.bind(item))
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 3)
	margin.add_theme_constant_override("margin_right", 3)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	root.add_child(margin)
	var box := Kit.vbox(1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	var emoji := Kit.label(GameState.item_emoji(item), 29, Palette.TEXT)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(emoji)
	var nm := Kit.label(GameState.item_name(item), 11, Palette.TEXT, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.max_lines_visible = 2
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(nm)
	var qty := Kit.label("", 11, Palette.GOLD)
	qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(item.get("is_cash", false)) or str(item.get("id", "")) == "wallet":
		qty.text = GameState.format_money(GameState.cash())
	else:
		var n := int(item.get("qty", 1))
		qty.text = "×%d" % n if n > 1 else ""
	box.add_child(qty)
	return b

func _refresh_relations() -> void:
	Kit.clear(_relations_box)
	var rows := GameState.relationship_rows()
	if rows.is_empty():
		_relations_box.add_child(Kit.label("Отношения", 19, Palette.GOLD))
		_relations_box.add_child(Kit.small("—", Palette.MUTED))
		return
	for group in GameState.relationship_groups():
		var gid := str(group.get("id", ""))
		var group_rows: Array = []
		for r in rows:
			if str(r.get("group", "other")) == gid:
				group_rows.append(r)
		if group_rows.is_empty():
			continue
		_relations_box.add_child(Kit.label(str(group.get("name", gid)), 15, Palette.GOLD))
		for r in group_rows:
			_relations_box.add_child(_relation_row(r))

func _relation_row(r: Dictionary) -> Button:
	var b := Kit.button("")
	b.theme_type_variation = "RowButton"
	b.custom_minimum_size = Vector2(0, 58)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = str(r.get("note", ""))
	b.pressed.connect(_show_relation.bind(r))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	b.add_child(margin)
	var row := Kit.hbox(7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	var em := Kit.label(str(r.get("emoji", "•")), 20, Palette.TEXT)
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(em)
	var text := Kit.vbox(0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var n := Kit.label(str(r.get("name", "")), 14, Palette.TEXT)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(n)
	var note := str(r.get("note", "")).strip_edges()
	var sub := str(r.get("type", "")).strip_edges()
	if note != "":
		sub = (sub + " · " + note) if sub != "" else note
	var relation_type := str(r.get("relation_type", r.get("type", ""))).strip_edges()
	var st := Kit.small(relation_type, Palette.MUTED)
	st.autowrap_mode = TextServer.AUTOWRAP_OFF
	st.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	st.clip_text = true
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(st)
	var level := clampi(int(r.get("level", 0)), 0, 5)
	var dots := Kit.label("●".repeat(level) + "○".repeat(5 - level), 13, Palette.GOLD)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dots)
	return b

func _show_chronicle() -> void:
	var d := AcceptDialog.new()
	d.title = "Хроника · %d ходов" % GameState.turn_number()
	d.dialog_autowrap = true
	d.ok_button_text = "Закрыть"
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 420)
	var box := Kit.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	if GameState.timeline.is_empty() and GameState.history.is_empty():
		box.add_child(Kit.small("Событий пока нет.", Palette.MUTED))
	for ev_v in GameState.timeline:
		if ev_v is Dictionary:
			var date := str(ev_v.get("date", ""))
			var line := str(ev_v.get("event", ""))
			if line != "":
				box.add_child(Kit.small(("%s · " % GameState.format_date_ru(date) if date != "" else "") + line, Palette.TEXT))
	for i in range(GameState.history.size()):
		var h: Dictionary = GameState.history[i]
		var act := str(h.get("action", "")).strip_edges()
		if act != "":
			box.add_child(Kit.small("%d. %s" % [i + 1, act], Palette.MUTED))
	d.add_child(sc)
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(680, 500))

func _show_item(item: Dictionary) -> void:
	var d := AcceptDialog.new()
	d.title = "%s %s" % [GameState.item_emoji(item), GameState.item_name(item)]
	d.dialog_autowrap = true
	d.ok_button_text = "Закрыть"
	var qty := "Наличные: " + GameState.format_money(GameState.cash()) if bool(item.get("is_cash", false)) else "Количество: %d" % int(item.get("qty", 1))
	d.dialog_text = "%s\n\n%s" % [qty, GameState.item_description(item)]
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(520, 280))

func _show_relation(r: Dictionary) -> void:
	var d := AcceptDialog.new()
	d.title = "%s %s" % [str(r.get("emoji", "•")), str(r.get("name", ""))]
	d.dialog_autowrap = true
	d.ok_button_text = "Закрыть"
	var level := clampi(int(r.get("level", 0)), 0, 5)
	d.dialog_text = "%s · %s\n\n%s\n\nОтношение: %s (%d/5)" % [
		str(r.get("relation_type", r.get("type", ""))),
		str(r.get("group_name", "")),
		str(r.get("note", "")) if str(r.get("note", "")) != "" else "—",
		GameState.rel_label(level),
		level,
	]
	d.transient = true
	d.exclusive = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 200
	get_tree().root.add_child(dim)
	d.tree_exited.connect(dim.queue_free)
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.close_requested.connect(d.queue_free)
	d.popup_centered(Vector2i(500, 280))
