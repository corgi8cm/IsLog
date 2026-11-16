extends Control
## 事件頁：新增、完成、刪除事件；顯示今天完成的事件與獲得的素材。

var _input: LineEdit
var _list: VBoxContainer
var _toast: Label
var _greeting: Label
## 哪些事件展開了子事件（只存在畫面上，不存檔）。
var _expanded := {}
## 新增子事件後重建畫面時，讓那個事件的輸入框保持焦點。
var _refocus_event := -1
var _add_row: Control
## 第一件待完成事件的「完成」按鈕（新手引導要亮它）。
var _first_complete: Button


## 打招呼的柯基。
class CorgiBadge extends Control:
	var painter := IsoPainter.new(self)

	func _ready() -> void:
		custom_minimum_size = Vector2(120, 96)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2(size.x * 0.5 - 6, size.y - 16), 0.0, Vector2(3.6, 3.6))
		painter.animal("corgi", Vector2.ZERO, false, false, 0.0)
		draw_set_transform(Vector2.ZERO)


## 打勾的圓圈：空心是待完成，實心打勾是完成。
class CheckMark extends Control:
	var checked := false
	var radius := 21.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var acc := UiKit.color("accent")
		if checked:
			draw_circle(c, radius, acc)
			var k := radius / 21.0
			draw_polyline(PackedVector2Array([c + Vector2(-10, 0) * k, c + Vector2(-3, 7) * k, c + Vector2(11, -8) * k]),
				UiKit.color("on_accent"), 4.0 * k, true)
		else:
			draw_arc(c, radius - 2, 0, TAU, 36, acc, 4.0, true)


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	# 柯基打招呼（依時段換句話）
	var hello := HBoxContainer.new()
	hello.add_theme_constant_override("separation", 6)
	col.add_child(hello)
	hello.add_child(CorgiBadge.new())
	var bubble := PanelContainer.new()
	bubble.theme_type_variation = "Card"
	bubble.size_flags_horizontal = SIZE_EXPAND_FILL
	hello.add_child(bubble)
	var bubble_col := VBoxContainer.new()
	bubble_col.add_theme_constant_override("separation", 0)
	bubble.add_child(bubble_col)
	_greeting = UiKit.label("", 26)
	_greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_col.add_child(_greeting)
	bubble_col.add_child(UiKit.label("做完一件，島就會多一點顏色。", 21, "Muted"))

	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 12)
	col.add_child(add_row)
	_add_row = add_row
	_input = LineEdit.new()
	_input.placeholder_text = "輸入一件小事，例如：喝一杯水"
	_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 76)
	_input.max_length = 60
	_input.text_submitted.connect(func(_t): _add())
	add_row.add_child(_input)
	var add_btn := UiKit.icon_button("plus", "新增", _add, 76)
	add_btn.theme_type_variation = "AccentButton"
	(add_btn.get_child(0) as Icon).role = "on_accent"
	add_btn.add_theme_stylebox_override("normal", UiKit.box(UiKit.color("accent"), 38))
	add_btn.add_theme_stylebox_override("pressed", UiKit.box(UiKit.color("accent").darkened(0.1), 38))
	add_btn.add_theme_stylebox_override("hover", UiKit.box(UiKit.color("accent").lightened(0.08), 38))
	add_row.add_child(add_btn)

	_toast = UiKit.label("", 25, "Accent")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.custom_minimum_size = Vector2(0, 36)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_toast)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	Game.changed.connect(_rebuild)
	Game.daytime_changed.connect(_update_greeting)
	_update_greeting()
	_rebuild()


func _notification(what: int) -> void:
	# 換日夜主題時，強調色按鈕的底色要跟著換
	if what == NOTIFICATION_THEME_CHANGED and _add_row != null:
		var add_btn: Button = _add_row.get_child(1)
		add_btn.add_theme_stylebox_override("normal", UiKit.box(UiKit.color("accent"), 38))
		add_btn.add_theme_stylebox_override("pressed", UiKit.box(UiKit.color("accent").darkened(0.1), 38))
		add_btn.add_theme_stylebox_override("hover", UiKit.box(UiKit.color("accent").lightened(0.08), 38))


func _update_greeting() -> void:
	match DayCycle.phase(Game.now_minutes()):
		DayCycle.MORNING:
			_greeting.text = "早安！今天想完成什麼小事？"
		DayCycle.EVENING:
			_greeting.text = "辛苦了，今天還想完成什麼嗎？"
		DayCycle.NIGHT:
			_greeting.text = "晚上好，睡前再做一件小事？"
		_:
			_greeting.text = "今天想完成什麼小事？"


## 新手引導用：輸入列與第一個「完成」按鈕在畫面上的位置。
func add_row_rect() -> Rect2:
	return _add_row.get_global_rect()


func first_complete_rect() -> Rect2:
	if _first_complete == null or not _first_complete.is_inside_tree():
		return Rect2()
	return _first_complete.get_global_rect()


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
	_show_toast("\n".join(lines))


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


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


## 「⋯」：子事件與刪除收在這裡。
func _open_menu(ev: Dictionary) -> void:
	var parts := UiKit.open_modal(_modal_host(), ev.title)
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var expanded: bool = _expanded.get(ev.id, false)
	var progress := GameData.subtask_progress(ev)
	var sub_text := "收起子事件" if expanded else ("拆成子事件" if progress.y == 0 else "展開子事件")
	var sub := UiKit.button(sub_text, func():
		overlay.queue_free()
		_toggle_subtasks(ev.id))
	sub.custom_minimum_size = Vector2(0, 76)
	body.add_child(sub)
	var del := UiKit.button("刪除這件事", func():
		overlay.queue_free()
		Game.delete_event(ev.id), "DangerButton")
	del.custom_minimum_size = Vector2(0, 76)
	body.add_child(del)


func _modal_host() -> Control:
	var n: Node = self
	while n.get_parent() is Control:
		n = n.get_parent()
	return n as Control


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()

	var pending := Game.data.pending_events()
	_list.add_child(_section("待完成 · %d" % pending.size()))
	if pending.is_empty():
		_list.add_child(UiKit.label("還沒有事件，先加一件小事吧。", 26, "Muted"))
	_first_complete = null
	for ev in pending:
		_list.add_child(_pending_card(ev))

	var done := Game.data.events_done_on(Game.today())
	if not done.is_empty():
		_list.add_child(_section("今天完成 · %d" % done.size()))
		done.reverse()
		for ev in done:
			_list.add_child(_done_row(ev))
	_refocus_event = -1


func _section(text: String) -> Label:
	return UiKit.label(text, 23, "Muted")


func _card(variation: String) -> Array:
	var panel := PanelContainer.new()
	panel.theme_type_variation = variation
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	return [panel, row, col]


func _title_label(text: String, font_size: int = 0, variation := "") -> Label:
	var l := UiKit.label(text, font_size, variation)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## 打勾圓圈按鈕（tooltip「完成」）。
func _check_button(callback: Callable, radius := 21.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = "FlatButton"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = "完成"
	b.custom_minimum_size = Vector2(radius * 2 + 14, radius * 2 + 14)
	b.pressed.connect(callback)
	var mark := CheckMark.new()
	mark.radius = radius
	b.add_child(mark)
	mark.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return b


func _done_mark(radius := 21.0) -> Control:
	var mark := CheckMark.new()
	mark.checked = true
	mark.radius = radius
	mark.custom_minimum_size = Vector2(radius * 2 + 14, radius * 2 + 14)
	return mark


## 獲得的素材用小方塊表示。
func _reward_cubes(rewards: Array, plant := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_END
	for t in rewards.slice(0, 6):
		var c := UiKit.mini_cube(t)
		c.half = 9
		row.add_child(c)
	if rewards.size() > 6:
		row.add_child(UiKit.label("+%d" % (rewards.size() - 6), 20, "Muted"))
	if plant != "":
		row.add_child(UiKit.label("＋" + Catalog.plant_name(plant), 20, "Muted"))
	return row


func _pending_card(ev: Dictionary) -> Control:
	var parts := _card("Card")
	var row: HBoxContainer = parts[1]
	var col: VBoxContainer = parts[2]
	var done_btn := _check_button(_complete.bind(ev.id))
	row.add_child(done_btn)
	if _first_complete == null:
		_first_complete = done_btn
	var progress := GameData.subtask_progress(ev)
	var title: String = ev.title
	if progress.y > 0:
		title += "（%d/%d）" % [progress.x, progress.y]
	var title_label := _title_label(title)
	# 點標題展開或收起子事件
	title_label.mouse_filter = MOUSE_FILTER_STOP
	title_label.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_toggle_subtasks(ev.id))
	row.add_child(title_label)
	var more := UiKit.icon_button("more", "更多", _open_menu.bind(ev), 56)
	more.theme_type_variation = "FlatButton"
	(more.get_child(0) as Icon).role = "muted"
	row.add_child(more)
	var expanded: bool = _expanded.get(ev.id, false)
	if expanded:
		for sub in ev.subtasks:
			col.add_child(_subtask_row(ev, sub))
		col.add_child(_add_sub_row(ev))
	return parts[0]


func _subtask_row(ev: Dictionary, sub: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(30, 0)
	row.add_child(indent)
	if sub.done_date == "":
		row.add_child(_check_button(_complete_sub.bind(ev.id, sub.id), 15))
		row.add_child(_title_label(sub.title, 26))
	else:
		row.add_child(_done_mark(15))
		row.add_child(_title_label(sub.title, 26, "Muted"))
		row.add_child(_reward_cubes(sub.rewards))
	var del := UiKit.icon_button("close", "刪除", Game.delete_subtask.bind(ev.id, sub.id), 44)
	del.theme_type_variation = "FlatButton"
	(del.get_child(0) as Icon).role = "muted"
	(del.get_child(0) as Icon).icon_size = 26
	row.add_child(del)
	return row


func _add_sub_row(ev: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(30, 0)
	row.add_child(indent)
	var input := LineEdit.new()
	input.placeholder_text = "新增子事件"
	input.size_flags_horizontal = SIZE_EXPAND_FILL
	input.max_length = 60
	input.add_theme_font_size_override("font_size", 26)
	input.text_submitted.connect(func(_t): _add_sub(ev.id, input))
	row.add_child(input)
	row.add_child(UiKit.button("新增", _add_sub.bind(ev.id, input)))
	if _refocus_event == ev.id:
		input.ready.connect(input.grab_focus, CONNECT_DEFERRED)
	return row


func _done_row(ev: Dictionary) -> Control:
	var parts := _card("Soft")
	var row: HBoxContainer = parts[1]
	row.add_child(_done_mark())
	var title: String = ev.title
	var progress := GameData.subtask_progress(ev)
	if progress.y > 0:
		title += "（子事件 %d）" % progress.y
	row.add_child(_title_label(title, 0, "Muted"))
	row.add_child(_reward_cubes(ev.rewards, ev.plant))
	row.add_child(UiKit.button("再一次", _redo.bind(ev), "FlatButton"))
	return parts[0]
