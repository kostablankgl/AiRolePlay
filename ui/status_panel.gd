class_name StatusPanel
extends PanelContainer
const Palette = preload("res://ui/app_theme.gd")
const Kit = preload("res://ui/kit.gd")

var _tabs: TabContainer
var _character_box: VBoxContainer
var _inventory_box: VBoxContainer
var _wallet_box: VBoxContainer
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
	custom_minimum_size = Vector2(340, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_tabs)
	_character_box = _make_tab("Герой")
	_inventory_box = _make_tab("Сумка")
	_wallet_box = _make_tab("Кошелёк")

func _make_tab(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.name = title
	_tabs.add_child(sc)
	var box := Kit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	return box

func refresh() -> void:
	if not _built:
		return
	_refresh_character()
	_refresh_inventory()
	_refresh_wallet()

func _refresh_character() -> void:
	Kit.clear(_character_box)
	var c := GameState.character
	var name := str(c.get("name", "Безымянный"))
	var role := str(c.get("title", ""))
	_character_box.add_child(Kit.label(name, 23, Palette.TEXT, true))
	if role != "":
		_character_box.add_child(Kit.muted(role, true))
	var facts := Kit.vbox(4)
	var age := int(c.get("age", 0))
	var rows := [
		["Возраст", "%d" % age if age > 0 else "—"],
		["Одежда", str(c.get("clothes", "—"))],
		["Дом", GameState.location_name()],
	]
	for row in rows:
		var line := Kit.hbox(8)
		var key := Kit.label(str(row[0]), 14, Palette.MUTED)
		key.custom_minimum_size.x = 76
		line.add_child(key)
		var val := Kit.label(str(row[1]), 15, Palette.TEXT, true)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(val)
		facts.add_child(line)
	_character_box.add_child(facts)
	var rels := GameState.relationship_rows()
	if not rels.is_empty():
		_character_box.add_child(Kit.separator())
		_character_box.add_child(Kit.label("Отношения", 16, Palette.GOLD))
		for r in rels:
			var row := Kit.hbox(8)
			var n := Kit.label(str(r.get("name", "")), 15, Palette.TEXT, true)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(n)
			var level := int(r.get("level", 0))
			var color := Palette.OK if level > 0 else (Palette.DANGER if level < 0 else Palette.MUTED)
			row.add_child(Kit.label(GameState.rel_label(level), 13, color))
			_character_box.add_child(row)
	var skills: Array = c.get("skills", [])
	if not skills.is_empty():
		_character_box.add_child(Kit.separator())
		_character_box.add_child(Kit.label("Умения", 16, Palette.GOLD))
		var wrap := Kit.hbox(6)
		wrap.add_theme_constant_override("separation", 6)
		var count := 0
		for s in skills:
			wrap.add_child(Kit.chip(str(s)))
			count += 1
			if count >= 4:
				_character_box.add_child(wrap)
				wrap = Kit.hbox(6)
				count = 0
		if count > 0:
			_character_box.add_child(wrap)
	var abilities: Array = c.get("abilities", [])
	if not abilities.is_empty():
		_character_box.add_child(Kit.label("Особенности", 16, Palette.GOLD))
		for a in abilities:
			_character_box.add_child(Kit.small("• " + str(a), Palette.TEXT))
	var ts := Kit.label("Хроника: %d ходов" % GameState.turn_number(), 13, Palette.MUTED)
	_character_box.add_child(Kit.separator())
	_character_box.add_child(ts)

func _refresh_inventory() -> void:
	Kit.clear(_inventory_box)
	var slots := int(GameState.inventory_slots)
	var head := Kit.hbox(8)
	head.add_child(Kit.label("Сумка", 20, Palette.GOLD))
	head.add_child(Kit.spacer())
	head.add_child(Kit.label("%d / %d" % [GameState.inventory.size(), slots], 14, Palette.MUTED))
	_inventory_box.add_child(head)
	var grid := Kit.grid(4, 8, 8)
	for item_v in GameState.inventory:
		var item: Dictionary = item_v
		var cell := Kit.panel("InsetPanel")
		cell.custom_minimum_size = Vector2(0, 92)
		var box := Kit.vbox(4)
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var emoji := Kit.label(GameState.item_emoji(item), 26, Palette.TEXT)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(emoji)
		var nm := Kit.label(Kit.shorten(GameState.item_name(item), 16), 12, Palette.TEXT, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nm)
		var qty := int(item.get("qty", 1))
		if qty > 1:
			var q := Kit.label("×%d" % qty, 12, Palette.GOLD)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(q)
		cell.add_child(box)
		grid.add_child(cell)
	var empty := maxi(0, slots - GameState.inventory.size())
	for i in range(empty):
		var cell := Kit.panel("InsetPanel")
		cell.custom_minimum_size = Vector2(0, 92)
		var q := Kit.label("·", 24, Color(Palette.MUTED, 0.35))
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(q)
		grid.add_child(cell)
	_inventory_box.add_child(grid)
	if GameState.inventory.is_empty():
		_inventory_box.add_child(Kit.small("Пусто. Предметы появятся, когда вы их получите.", Palette.MUTED))

func _refresh_wallet() -> void:
	Kit.clear(_wallet_box)
	var cur: Dictionary = GameState.world.get("currency", {})
	var labels: Dictionary = GameState.world.get("finance_labels", {})
	_wallet_box.add_child(Kit.label("Кошелёк", 20, Palette.GOLD))
	_wallet_box.add_child(Kit.label(GameState.format_money(GameState.cash()), 30, Palette.TEXT, true))
	_wallet_box.add_child(Kit.small(str(labels.get("cash", "Наличные")) + " · " + str(cur.get("major", "")), Palette.MUTED))
	var bank := Kit.panel("InsetPanel")
	var bank_box := Kit.vbox(5)
	bank_box.add_child(Kit.small(str(labels.get("bank", "В банке"))))
	bank_box.add_child(Kit.label(GameState.format_money(GameState.bank()), 20, Palette.TEXT))
	bank.add_child(bank_box)
	_wallet_box.add_child(bank)
	var trust := Kit.panel("InsetPanel")
	var trust_box := Kit.vbox(5)
	trust_box.add_child(Kit.small(str(labels.get("trust", "Резерв"))))
	trust_box.add_child(Kit.label(GameState.format_money(GameState.trust()), 20, Palette.TEXT))
	trust.add_child(trust_box)
	_wallet_box.add_child(trust)
	var income: Array = GameState.finances.get("income", [])
	if not income.is_empty():
		_wallet_box.add_child(Kit.separator())
		_wallet_box.add_child(Kit.label("Доходы", 16, Palette.GOLD))
		for inc_v in income:
			if not (inc_v is Dictionary):
				continue
			var inc: Dictionary = inc_v
			var row := Kit.hbox(6)
			var src := Kit.label(str(inc.get("src", "")), 14, Palette.TEXT, true)
			src.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(src)
			row.add_child(Kit.label(GameState.format_money(int(inc.get("per_year_minor", 0))) + "/год", 13, Palette.MUTED))
			_wallet_box.add_child(row)
	var prop: Array = GameState.finances.get("property", [])
	if not prop.is_empty():
		_wallet_box.add_child(Kit.separator())
		_wallet_box.add_child(Kit.label("Собственность", 16, Palette.GOLD))
		for p_v in prop:
			if not (p_v is Dictionary):
				continue
			var p: Dictionary = p_v
			_wallet_box.add_child(Kit.small("• " + str(p.get("note", p.get("id", ""))), Palette.TEXT))
	var total := GameState.total_money()
	_wallet_box.add_child(Kit.separator())
	var total_row := Kit.hbox(6)
	total_row.add_child(Kit.label(str(labels.get("total", "Всего")), 15, Palette.MUTED))
	total_row.add_child(Kit.spacer())
	total_row.add_child(Kit.label(GameState.format_money(total), 17, Palette.GOLD))
	_wallet_box.add_child(total_row)
