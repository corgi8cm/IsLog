extends Control
## 事件頁：新增、完成、刪除事件；顯示今天完成的事件與獲得的素材。

const PAGE_BG := Color("f4f8fb")
const DONE_COLOR := Color("8a97a5")

var _input: LineEdit
var _list: VBoxContainer
var _toast: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = PAGE_BG
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 10)
	col.add_child(add_row)
	_input = LineEdit.new()
	_input.placeholder_text = "輸入一件小事，例如：喝一杯水"
	_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 72)
	_input.max_length = 60
	_input.text_submitted.connect(func(_t): _add())
	add_row.add_child(_input)
	var add_btn := UiKit.button("新增", _add)
	add_btn.custom_minimum_size = Vector2(110, 72)
	add_row.add_child(add_btn)

	_toast = UiKit.label("", 26)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Color("4f8a34"))
	_toast.custom_minimum_size = Vector2(0, 40)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_toast)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)

	Game.changed.connect(_rebuild)
	_rebuild()


func _add() -> void:
	var ev := Game.add_event(_input.text)
	if not ev.is_empty():
		_input.clear()
	_input.release_focus()
	DisplayServer.virtual_keyboard_hide()


func _complete(id: int) -> void:
	var result := Game.complete_event(id)
	if not result.ok:
		return
	var lines := []
	var color := Color("4f8a34")
	if result.capped:
		lines.append("今天的素材已經拿滿 %d 件了，明天再來！" % GameData.DAILY_LIMIT)
		color = Color("b07a2a")
	else:
		var names := []
		for t in result.rewards:
			names.append(Materials.display_name(t))
		var text := "獲得素材：" + "、".join(names)
		if result.plant != "":
			text += "，還有一株%s！" % Catalog.plant_name(result.plant)
		lines.append(text)
	if result.get("visitor", "") != "":
		lines.append("%s來到你的島上了！" % Catalog.animal_name(result.visitor))
	_show_toast("
".join(lines), color)


func _redo(title: String) -> void:
	Game.add_event(title)


func _show_toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()

	var pending := Game.data.pending_events()
	_list.add_child(_section("待完成（%d）" % pending.size()))
	if pending.is_empty():
		var empty := UiKit.label("還沒有事件，先加一件小事吧。", 26)
		empty.add_theme_color_override("font_color", DONE_COLOR)
		_list.add_child(empty)
	for ev in pending:
		_list.add_child(_pending_row(ev))

	var done := Game.data.events_done_on(Game.today())
	if not done.is_empty():
		_list.add_child(_section("今天完成（%d）" % done.size()))
		done.reverse()
		for ev in done:
			_list.add_child(_done_row(ev))


func _section(text: String) -> Label:
	var l := UiKit.label(text, 24)
	l.add_theme_color_override("font_color", DONE_COLOR)
	return l


func _row(bg: Color) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(bg, 16))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	return [panel, row]


func _title_label(text: String, color: Color) -> Label:
	var l := UiKit.label(text)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	return l


func _pending_row(ev: Dictionary) -> Control:
	var parts := _row(Color.WHITE)
	var row: HBoxContainer = parts[1]
	var done_btn := UiKit.button("完成", _complete.bind(ev.id))
	done_btn.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 12))
	done_btn.add_theme_stylebox_override("pressed", UiKit.box(Color("b9e3a0"), 12))
	row.add_child(done_btn)
	row.add_child(_title_label(ev.title, UiKit.TEXT_COLOR))
	var del := UiKit.button("刪除", Game.delete_event.bind(ev.id))
	del.add_theme_stylebox_override("normal", UiKit.box(Color("f6f0f0"), 12))
	row.add_child(del)
	return parts[0]


func _done_row(ev: Dictionary) -> Control:
	var parts := _row(Color("eef2f5"))
	var row: HBoxContainer = parts[1]
	row.add_child(_title_label("✓ " + ev.title, DONE_COLOR))
	var reward_text := "沒有素材"
	if not ev.rewards.is_empty():
		var names := []
		for t in ev.rewards:
			names.append(Materials.display_name(t))
		reward_text = "".join(names)
	if ev.plant != "":
		reward_text += "＋" + Catalog.plant_name(ev.plant)
	var r := UiKit.label(reward_text, 24)
	r.add_theme_color_override("font_color", DONE_COLOR)
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(r)
	row.add_child(UiKit.button("再一次", _redo.bind(ev.title)))
	return parts[0]
