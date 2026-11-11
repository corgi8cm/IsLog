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
		var l := UiKit.label("", 26)
		_counts[t] = l
		row.add_child(UiKit.chip(l, Materials.top_color(t)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(spacer)
	_daily = UiKit.label("", 24)
	_daily.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_daily)
	return panel


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
