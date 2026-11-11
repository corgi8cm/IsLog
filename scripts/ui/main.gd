extends Control
## 主畫面：上方素材列、中間頁面、下方分頁切換。

const EventsPage := preload("res://scripts/ui/events_page.gd")
const IslandPage := preload("res://scripts/ui/island_page.gd")

var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _counts := {}
var _daily: Label


func _ready() -> void:
	theme = UiKit.make_theme()

	var bg := ColorRect.new()
	bg.color = Color("f4f8fb")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	col.add_child(_build_top_bar())

	var content := Control.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.clip_contents = true
	col.add_child(content)
	for page in [EventsPage.new(), IslandPage.new()]:
		page.set_anchors_preset(PRESET_FULL_RECT)
		content.add_child(page)
		_pages.append(page)

	col.add_child(_build_tab_bar())

	Game.changed.connect(_refresh)
	_refresh()
	_show_page(0)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	var sb := UiKit.box(Color.WHITE, 0)
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	for t in Materials.TYPES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 26)
		for state in ["normal", "hover", "pressed"]:
			var chip_sb := UiKit.box(Materials.top_color(t), 12)
			chip_sb.content_margin_left = 12
			chip_sb.content_margin_right = 12
			chip_sb.content_margin_top = 6
			chip_sb.content_margin_bottom = 6
			b.add_theme_stylebox_override(state, chip_sb)
		b.pressed.connect(open_exchange.bind(t))
		_counts[t] = b
		row.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(spacer)
	_daily = UiKit.label("", 24)
	_daily.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_daily)
	return panel


## 素材交換視窗：選要給出的素材和要換到的素材。
func open_exchange(from_type: String = Materials.DIRT) -> void:
	var parts := UiKit.open_modal(self, "交換素材")
	var body: VBoxContainer = parts[1]
	var state := {"from": from_type, "to": Materials.WATER if from_type != Materials.WATER else Materials.DIRT}
	var info := UiKit.label("", 26)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rows := {}
	for key in ["from", "to"]:
		body.add_child(UiKit.label("給出 %d 個" % GameData.EXCHANGE_COST if key == "from" else "換到 1 個", 24))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)
		var group := ButtonGroup.new()
		rows[key] = {}
		for t in Materials.TYPES:
			var b := UiKit.tool_button(group, Materials.top_color(t))
			b.custom_minimum_size = Vector2(0, 64)
			b.button_pressed = state[key] == t
			b.pressed.connect(func():
				state[key] = t
				state.update.call())
			row.add_child(b)
			rows[key][t] = b
	body.add_child(info)
	var go := UiKit.button("交換", func():
		if Game.exchange(state.from, state.to):
			state.update.call())
	go.custom_minimum_size = Vector2(0, 72)
	go.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
	body.add_child(go)
	# lambda 擷取的是區域變數當下的值，所以把 update 放在 state 字典裡讓前面的按鈕也能呼叫
	state.update = func():
		for key in rows:
			for t in rows[key]:
				rows[key][t].text = "%s %d" % [Materials.display_name(t), Game.data.inventory[t]]
		var have: int = Game.data.inventory[state.from]
		if state.from == state.to:
			info.text = "請選兩種不同的素材"
		elif have < GameData.EXCHANGE_COST:
			info.text = "%s只有 %d 個，不夠交換" % [Materials.display_name(state.from), have]
		else:
			info.text = "用 %d 個%s換 1 個%s" % [GameData.EXCHANGE_COST,
				Materials.display_name(state.from), Materials.display_name(state.to)]
		go.disabled = state.from == state.to or have < GameData.EXCHANGE_COST
	state.update.call()


func _build_tab_bar() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color.WHITE, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var names := ["事件", "島嶼"]
	for i in names.size():
		var b := UiKit.button(names[i], _show_page.bind(i))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 80)
		row.add_child(b)
		_tabs.append(b)
	return panel


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index
		var selected := i == index
		_tabs[i].add_theme_stylebox_override(
			"normal", UiKit.box(Color("dceefc") if selected else Color.WHITE, 14))


func _refresh() -> void:
	for t in Materials.TYPES:
		_counts[t].text = "%s %d" % [Materials.display_name(t), Game.data.inventory.get(t, 0)]
	var today := Game.today()
	if Game.data.is_pro:
		_daily.text = "今日 %d 件" % Game.data.completions_on(today)
	else:
		_daily.text = "今日素材 %d/%d" % [
			mini(Game.data.completions_on(today), GameData.DAILY_LIMIT), GameData.DAILY_LIMIT]
