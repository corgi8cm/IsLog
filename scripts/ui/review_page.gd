extends Control
## 回顧頁：統計、月曆（點日期看當天）與時間軸（依日期列出全部）。

const MODE_CALENDAR := 0
const MODE_TIMELINE := 1

var _mode := MODE_CALENDAR
var _year := 0
var _month := 0
var _selected := ""
var _content: VBoxContainer
var _mode_buttons: Array[Button] = []
var _toast: Label


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	margin.add_child(_content)

	var today := Review.parse(Game.today())
	_year = today.year
	_month = today.month
	_selected = Game.today()
	Game.changed.connect(_rebuild)
	visibility_changed.connect(func(): if visible: _rebuild())
	_rebuild()


func _notification(what: int) -> void:
	# 日夜主題換了：月曆的顏色要重算
	if what == NOTIFICATION_THEME_CHANGED and _content != null:
		_rebuild.call_deferred()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in _content.get_children():
		c.queue_free()
	_mode_buttons.clear()
	_content.add_child(_stats_card())
	_content.add_child(_mode_bar())
	_toast = UiKit.label("", 24)
	_toast.theme_type_variation = "Accent"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_content.add_child(_toast)
	if _mode == MODE_CALENDAR:
		_content.add_child(_calendar())
		_content.add_child(_day_section(_selected))
	else:
		var dates := Review.active_dates(Game.data)
		if dates.is_empty():
			_content.add_child(_muted("還沒有完成的事件。完成一件小事，這裡就會開始記錄。"))
		for d in dates:
			_content.add_child(_day_section(d))


# --- 統計 ---------------------------------------------------------------

func _stats_card() -> Control:
	var panel := _card()
	var col: VBoxContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var streak := Review.streak(Game.data, Game.today())
	for item in [["累計完成", "%d 件" % Game.data.total_completed],
			["連續照顧", "%d 天" % streak],
			["記錄天數", "%d 天" % Review.active_dates(Game.data).size()]]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = SIZE_EXPAND_FILL
		var n := UiKit.label(item[1], 34)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var t := _muted(item[0], 22)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(n)
		box.add_child(t)
		row.add_child(box)
	var top := Review.top_titles(Game.data, 3)
	if not top.is_empty():
		var names := []
		for t in top:
			names.append("%s ×%d" % [t[0], t[1]])
		var l := _muted("最常做的事：" + "、".join(names), 24)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	return panel


func _mode_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for i in 2:
		var b := UiKit.button(["日曆", "時間軸"][i], _set_mode.bind(i))
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		if _mode == i:
			b.add_theme_stylebox_override("normal", UiKit.box(UiKit.color("sel"), 20, UiKit.color("accent"), 2))
		row.add_child(b)
		_mode_buttons.append(b)
	var account := UiKit.button("帳號與備份", func(): AccountDialog.open(_modal_host()))
	account.add_theme_font_size_override("font_size", 22)
	row.add_child(account)
	return row


## 對話框要蓋住整個畫面，所以加在最上層的 Control。
func _modal_host() -> Control:
	var n: Node = self
	while n.get_parent() is Control:
		n = n.get_parent()
	return n as Control


func _set_mode(mode: int) -> void:
	_mode = mode
	_rebuild()


# --- 月曆 ---------------------------------------------------------------

func _calendar() -> Control:
	var panel := _card()
	var col: VBoxContainer = panel.get_child(0)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(UiKit.button("‹", _shift_month.bind(-1)))
	var title := UiKit.label("%d 年 %d 月" % [_year, _month], 30)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title)
	head.add_child(UiKit.button("›", _shift_month.bind(1)))

	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for w in "日一二三四五六":
		var l := _muted(w, 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		grid.add_child(l)
	var first := Review.make_date(_year, _month, 1)
	for i in Review.weekday(first):
		grid.add_child(Control.new())
	var counts := Review.counts_by_date(Game.data)
	var today := Game.today()
	for day in Review.days_in_month(_year, _month):
		var date := Review.make_date(_year, _month, day + 1)
		var n: int = counts.get(date, 0)
		# 完成越多件，顏色越深
		var bg := UiKit.color("soft")
		if n > 0:
			var acc := UiKit.color("accent")
			bg = UiKit.color("panel").lerp(acc, lerpf(0.3, 0.85, clampf((n - 1) / 5.0, 0.0, 1.0)))
		var b := Button.new()
		b.text = str(day + 1)
		# 今天以後有預定的事：數字旁邊加一個點
		if date >= today and not Game.data.planned_on(date, today).is_empty():
			b.text += "·"
		b.focus_mode = FOCUS_NONE
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 24)
		var border := UiKit.color("ink") if date == _selected else (UiKit.color("accent") if date == today else Color.TRANSPARENT)
		var sb := UiKit.box(bg, 10, border)
		sb.set_content_margin_all(4)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, sb)
		b.pressed.connect(_select_date.bind(date))
		grid.add_child(b)
	return panel


func _shift_month(delta: int) -> void:
	_month += delta
	if _month < 1:
		_month = 12
		_year -= 1
	elif _month > 12:
		_month = 1
		_year += 1
	_rebuild()


func _select_date(date: String) -> void:
	_selected = date
	_rebuild()


# --- 某一天 -------------------------------------------------------------

func _day_section(date: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var entries := Review.entries_on(Game.data, date)
	var today := Game.today()
	var planned: Array = Game.data.planned_on(date, today) if date >= today else []
	var head := _muted("%s · %d 件" % [Review.label(date), entries.size()], 24)
	col.add_child(head)
	if entries.is_empty() and planned.is_empty():
		col.add_child(_muted("這天沒有完成的事件。" if date <= today else "這天還沒有預定的事。", 24))
	for e in entries:
		col.add_child(_entry_card(e))
	if not planned.is_empty():
		col.add_child(_muted("預定 · %d 件" % planned.size(), 22))
		for item in planned:
			col.add_child(_planned_card(item))
	return col


## 預定要做的事（含重複事件推算出來的日子）。
func _planned_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Soft"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var t := UiKit.label(item.title, 26)
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(t)
	var info := Schedule.time_text(item.time)
	if item.repeat:
		info += ("　" if info != "" else "") + "重複"
	if info != "":
		row.add_child(_muted(info, 22))
	return panel


func _entry_card(e: Dictionary) -> Control:
	var panel := _card()
	var col: VBoxContainer = panel.get_child(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var title: String = e.title
	if e.kind == "subtask":
		title = "%s（%s 的子事件）" % [e.title, e.event.title]
	var t := UiKit.label(title, 28)
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(t)
	if e.kind == "event":
		row.add_child(UiKit.button("再做一次", _redo.bind(e.event)))
	if e.kind == "event" and not e.event.subtasks.is_empty():
		var subs := []
		for sub in e.event.subtasks:
			subs.append(sub.title)
		var s := _muted("子事件：" + "、".join(subs), 22)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(s)
	var parts := ["素材：" + Materials.summary(e.rewards, "沒有")]
	if e.plant != "":
		parts.append("植物：" + Catalog.plant_name(e.plant))
	if e.visitor != "":
		parts.append("來訪：" + Catalog.animal_name(e.visitor))
	col.add_child(_muted("　".join(parts), 22))
	return panel


func _redo(ev: Dictionary) -> void:
	var titles := []
	for sub in ev.subtasks:
		titles.append(sub.title)
	Game.add_event(ev.title, titles)
	_toast.text = "已加回待完成：" + ev.title
	_toast.visible = true


# --- 小工具 -------------------------------------------------------------

func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	return panel


func _muted(text: String, font_size: int = 24) -> Label:
	return UiKit.label(text, font_size, "Muted")
