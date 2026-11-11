extends Control
## 事件頁：新增、完成、刪除事件；顯示今天完成的事件與獲得的素材。

const PAGE_BG := Color("f4f8fb")
const DONE_COLOR := Color("8a97a5")
const DONE_BG := Color("d8f0c8")

var _input: LineEdit
var _list: VBoxContainer
var _toast: Label
## 哪些事件展開了子事件（只存在畫面上，不存檔）。
var _expanded := {}
## 新增子事件後重建畫面時，讓那個事件的輸入框保持焦點。
var _refocus_event := -1


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
	if result.ok:
		_toast_result([_event_reward_line(result)], result)


func _complete_sub(event_id: int, sub_id: int) -> void:
	var result := Game.complete_subtask(event_id, sub_id)
	if not result.ok:
		return
	var lines := []
	if result.capped:
		lines.append("今天的素材已經拿滿 %d 件了" % GameData.DAILY_LIMIT)
	else:
		lines.append("子事件完成：" + Materials.summary(result.rewards))
	if not result.parent.is_empty():
		lines.append("全部完成！" + _event_reward_line(result.parent))
	_toast_result(lines, result)


func _event_reward_line(result: Dictionary) -> String:
	if result.capped:
		return "今天的素材已經拿滿 %d 件了，明天再來！" % GameData.DAILY_LIMIT
	var text := "獲得素材：" + Materials.summary(result.rewards)
	if result.get("bonus", 0) > 0:
		text += "（子事件加成 +%d）" % result.bonus
	if result.plant != "":
		text += "，還有一株%s！" % Catalog.plant_name(result.plant)
	return text


func _toast_result(lines: Array, result: Dictionary) -> void:
	if result.get("visitor", "") != "":
		var new_text := "（新發現！已記錄到圖鑑）" if Game.result_first_visit else ""
		lines.append("%s來到你的島上了！%s" % [Catalog.animal_name(result.visitor), new_text])
	var capped: bool = result.capped and result.get("parent", {}).get("capped", true)
	_show_toast("
".join(lines), Color("b07a2a") if capped else Color("4f8a34"))


func _redo(ev: Dictionary) -> void:
	var titles := []
	for sub in ev.subtasks:
		titles.append(sub.title)
	Game.add_event(ev.title, titles)


func _toggle_subtasks(id: int) -> void:
	_expanded[id] = not _expanded.get(id, false)
	_rebuild()


func _add_sub(event_id: int, input: LineEdit) -> void:
	# 新增成功會觸發重建畫面，所以要在呼叫前先記下要保持焦點的事件
	_refocus_event = event_id
	if Game.add_subtask(event_id, input.text).is_empty():
		_refocus_event = -1


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
		_list.add_child(_pending_card(ev))

	var done := Game.data.events_done_on(Game.today())
	if not done.is_empty():
		_list.add_child(_section("今天完成（%d）" % done.size()))
		done.reverse()
		for ev in done:
			_list.add_child(_done_row(ev))
	_refocus_event = -1


func _section(text: String) -> Label:
	var l := UiKit.label(text, 24)
	l.add_theme_color_override("font_color", DONE_COLOR)
	return l


func _card(bg: Color) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(bg, 16))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	return [panel, row, col]


func _title_label(text: String, color: Color, font_size: int = 0) -> Label:
	var l := UiKit.label(text, font_size)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	return l


func _small_button(text: String, bg: Color, callback: Callable) -> Button:
	var b := UiKit.button(text, callback)
	b.add_theme_stylebox_override("normal", UiKit.box(bg, 12))
	b.add_theme_stylebox_override("pressed", UiKit.box(bg.darkened(0.1), 12))
	return b


func _pending_card(ev: Dictionary) -> Control:
	var parts := _card(Color.WHITE)
	var row: HBoxContainer = parts[1]
	var col: VBoxContainer = parts[2]
	row.add_child(_small_button("完成", DONE_BG, _complete.bind(ev.id)))
	var progress := GameData.subtask_progress(ev)
	var title: String = ev.title
	if progress.y > 0:
		title += "（%d/%d）" % [progress.x, progress.y]
	row.add_child(_title_label(title, UiKit.TEXT_COLOR))
	var expanded: bool = _expanded.get(ev.id, false)
	var sub_label := "收起" if expanded else ("子事件" if progress.y == 0 else "展開")
	row.add_child(_small_button(sub_label, Color("e8f1fb"), _toggle_subtasks.bind(ev.id)))
	row.add_child(_small_button("刪除", Color("f6f0f0"), Game.delete_event.bind(ev.id)))
	if expanded:
		for sub in ev.subtasks:
			col.add_child(_subtask_row(ev, sub))
		col.add_child(_add_sub_row(ev))
	return parts[0]


func _subtask_row(ev: Dictionary, sub: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(24, 0)
	row.add_child(indent)
	if sub.done_date == "":
		row.add_child(_small_button("完成", DONE_BG, _complete_sub.bind(ev.id, sub.id)))
		row.add_child(_title_label(sub.title, UiKit.TEXT_COLOR, 26))
	else:
		row.add_child(_title_label("✓ " + sub.title, DONE_COLOR, 26))
		var r := UiKit.label(Materials.summary(sub.rewards), 22)
		r.add_theme_color_override("font_color", DONE_COLOR)
		row.add_child(r)
	row.add_child(_small_button("刪除", Color("f6f0f0"), Game.delete_subtask.bind(ev.id, sub.id)))
	return row


func _add_sub_row(ev: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(24, 0)
	row.add_child(indent)
	var input := LineEdit.new()
	input.placeholder_text = "新增子事件"
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	input.max_length = 60
	input.add_theme_font_size_override("font_size", 26)
	input.add_theme_stylebox_override("normal", UiKit.box(PAGE_BG, 12))
	input.add_theme_stylebox_override("focus", UiKit.box(PAGE_BG, 12, Color("7cc35a")))
	input.text_submitted.connect(func(_t): _add_sub(ev.id, input))
	row.add_child(input)
	row.add_child(UiKit.button("新增", _add_sub.bind(ev.id, input)))
	if _refocus_event == ev.id:
		input.ready.connect(input.grab_focus, CONNECT_DEFERRED)
	return row


func _done_row(ev: Dictionary) -> Control:
	var parts := _card(Color("eef2f5"))
	var row: HBoxContainer = parts[1]
	var title: String = "✓ " + ev.title
	var progress := GameData.subtask_progress(ev)
	if progress.y > 0:
		title += "（子事件 %d）" % progress.y
	row.add_child(_title_label(title, DONE_COLOR))
	var reward_text := Materials.summary(ev.rewards)
	if ev.plant != "":
		reward_text += "＋" + Catalog.plant_name(ev.plant)
	var r := UiKit.label(reward_text, 22)
	r.add_theme_color_override("font_color", DONE_COLOR)
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(r)
	row.add_child(UiKit.button("再一次", _redo.bind(ev)))
	return parts[0]
