class_name ScheduleDialog
extends RefCounted
## 設定事件的日期、時間與重複（像日曆 App 那樣，但都用按鈕，不用打字）。


const TIME_PRESETS := [["早上 8:00", 480], ["中午 12:00", 720], ["晚上 8:00", 1200]]
## 按「自訂時間」時，沒有選過時間就從這裡開始撥。
const CUSTOM_START := 9 * 60


## initial：{due_date, due_time, repeat, remind}；on_done(when) 在按「確定」時呼叫。
static func open(host: Control, title: String, initial: Dictionary, today: String, on_done: Callable) -> void:
	var parts := UiKit.open_modal(host, title)
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	body.add_child(content)
	var state := {
		"date": str(initial.get("due_date", "")),
		"time": int(initial.get("due_time", -1)),
		"repeat": Schedule.clean_rule(initial.get("repeat", {})),
		"remind": int(initial.get("remind", -1)),
		"every": 2,
		"days": [],
	}
	# 不是快速選項的時間：一打開就顯示滾輪
	state.custom = state.time >= 0 and not TIME_PRESETS.any(func(p): return p[1] == state.time)
	var rule: Dictionary = state.repeat
	if rule.get("kind", "") == Schedule.EVERY:
		state.every = int(rule.every)
	if rule.get("kind", "") == Schedule.WEEKLY:
		state.days = rule.get("days", []).duplicate()
	state.rebuild = func():
		for c in content.get_children():
			c.queue_free()
		_build(content, state, today)
	state.rebuild.call()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var clear := UiKit.button("清除", func():
		overlay.queue_free()
		on_done.call({"due_date": "", "due_time": -1, "repeat": {}, "remind": -1}))
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.custom_minimum_size = Vector2(0, 72)
	row.add_child(clear)
	var ok := UiKit.button("確定", func():
		overlay.queue_free()
		var when := result(state)
		if int(when.remind) >= 0:
			# 第一次設提醒時問手機要不要允許通知
			Game.notifier.request_permission()
		on_done.call(when), "AccentButton")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.custom_minimum_size = Vector2(0, 72)
	row.add_child(ok)


## 畫面上的選擇 → 事件的欄位。
static func result(state: Dictionary) -> Dictionary:
	var rule := {}
	var kind: String = state.repeat.get("kind", "")
	if kind == Schedule.WEEKLY:
		rule = Schedule.make_rule(kind, state.days)
	elif kind == Schedule.EVERY:
		rule = Schedule.make_rule(kind, [], state.every)
	elif kind != "":
		rule = Schedule.make_rule(kind)
	return {"due_date": state.date, "due_time": state.time if state.date != "" else -1,
		"repeat": rule, "remind": state.remind if state.date != "" else -1}


static func _build(content: VBoxContainer, state: Dictionary, today: String) -> void:
	var redo: Callable = state.rebuild
	# 日期
	content.add_child(UiKit.label("日期", 24, "Muted"))
	var quick := _chips(content)
	var tomorrow := Schedule.add_days(today, 1)
	for item in [["隨時", ""], ["今天", today], ["明天", tomorrow]]:
		_chip(quick, item[0], state.date == item[1], func():
			state.date = item[1]
			if item[1] == "":
				state.repeat = {}
			redo.call())
	if state.date != "":
		var stepper := _stepper(content, Schedule.date_label(state.date, today),
			func(d: int):
				var nd := Schedule.add_days(state.date, d)
				state.date = nd if nd >= today else today
				redo.call())
		stepper.get_child(0).disabled = state.date <= today

		# 時間
		content.add_child(UiKit.label("時間", 24, "Muted"))
		var trow := _chips(content)
		_chip(trow, "不指定", state.time < 0, func():
			state.time = -1
			state.custom = false
			redo.call())
		for preset in TIME_PRESETS:
			_chip(trow, preset[0], state.time == preset[1] and not state.custom, func():
				state.time = preset[1]
				state.custom = false
				redo.call())
		_chip(trow, "自訂時間", state.custom, func():
			if state.time < 0:
				state.time = CUSTOM_START
			state.custom = true
			redo.call())
		if state.custom:
			_time_wheel(content, state)

		# 重複
		content.add_child(UiKit.label("重複", 24, "Muted"))
		var rrow := _chips(content)
		var kind: String = state.repeat.get("kind", "")
		for item in [["不重複", ""], ["每天", Schedule.DAILY], ["每週", Schedule.WEEKLY],
				["每月", Schedule.MONTHLY], ["每隔幾天", Schedule.EVERY]]:
			_chip(rrow, item[0], kind == item[1], func():
				state.repeat = {} if item[1] == "" else {"kind": item[1]}
				if item[1] == Schedule.WEEKLY and state.days.is_empty():
					state.days = [Schedule.weekday(state.date)]
				redo.call())
		if kind == Schedule.WEEKLY:
			var wrow := HBoxContainer.new()
			wrow.add_theme_constant_override("separation", 6)
			content.add_child(wrow)
			for d in 7:
				var on: bool = state.days.has(d)
				var b := _chip(wrow, Schedule.WEEKDAY_NAMES[d], on, func():
					if state.days.has(d):
						if state.days.size() > 1:
							state.days.erase(d)
					else:
						state.days.append(d)
					redo.call())
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elif kind == Schedule.EVERY:
			_stepper(content, "每 %d 天" % state.every, func(d: int):
				state.every = clampi(state.every + d, 2, 365)
				redo.call())
		elif kind == Schedule.MONTHLY:
			content.add_child(UiKit.label(Schedule.describe({"kind": Schedule.MONTHLY}, state.date), 22, "Muted"))

		# 提醒（手機通知）
		content.add_child(UiKit.label("提醒", 24, "Muted"))
		var mrow := _chips(content)
		for m in [-1] + Schedule.REMIND_CHOICES:
			var text := "不提醒" if m == -1 else Schedule.remind_text(m).trim_suffix("提醒")
			if m == 0:
				text = "準時"
			_chip(mrow, text, state.remind == m, func():
				state.remind = m
				redo.call())
		if state.remind >= 0 and state.time < 0:
			content.add_child(UiKit.label("沒指定時間的事件，在當天早上 9 點提醒。", 21, "Muted"))


## 上午／下午 + 時、分滾輪。撥動時只改 state.time，不重建畫面（滾輪才不會被換掉）。
static func _time_wheel(content: VBoxContainer, state: Dictionary) -> void:
	var pm: bool = state.time >= 720
	var seg := HBoxContainer.new()
	seg.alignment = BoxContainer.ALIGNMENT_CENTER
	seg.add_theme_constant_override("separation", 0)
	content.add_child(seg)
	var picker := TimeWheel.Picker.new(posmod(state.time / 60 - 1, 12) + 1, state.time % 60)
	var apply := func(is_pm: bool, h12: int, m: int):
		state.time = ((h12 % 12) + (12 if is_pm else 0)) * 60 + m
	var group := ButtonGroup.new()
	var halves := []
	for i in 2:
		var b := Button.new()
		b.text = "上午" if i == 0 else "下午"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 60)
		b.add_theme_font_size_override("font_size", 26)
		b.button_pressed = (i == 1) == pm
		b.theme_type_variation = "AccentButton" if b.button_pressed else "FlatButton"
		var is_pm := i == 1
		b.toggled.connect(func(on: bool):
			b.theme_type_variation = "AccentButton" if on else "FlatButton"
			if on:
				apply.call(is_pm, picker.hour.value(), picker.minute.value()))
		seg.add_child(b)
		halves.append(b)
	picker.picked.connect(func(h12: int, m: int):
		apply.call(halves[1].button_pressed, h12, m))
	content.add_child(picker)


static func _chips(parent: Control) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	parent.add_child(row)
	return row


static func _chip(parent: Control, text: String, on: bool, cb: Callable) -> Button:
	var b := UiKit.button(text, cb)
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 24)
	if on:
		b.add_theme_stylebox_override("pressed", UiKit.box(UiKit.color("sel"), 20, UiKit.color("accent"), 3))
		b.add_theme_stylebox_override("hover_pressed", UiKit.box(UiKit.color("sel"), 20, UiKit.color("accent"), 3))
	parent.add_child(b)
	return b


## ‹ 文字 ›：on_step(-1 或 +1)。回傳整列（第一個子節點是「‹」）。
static func _stepper(parent: Control, text: String, on_step: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var minus := UiKit.button("‹", on_step.bind(-1))
	minus.custom_minimum_size = Vector2(64, 60)
	row.add_child(minus)
	var l := UiKit.label(text, 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var plus := UiKit.button("›", on_step.bind(1))
	plus.custom_minimum_size = Vector2(64, 60)
	row.add_child(plus)
	return row
