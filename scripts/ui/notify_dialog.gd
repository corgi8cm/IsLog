class_name NotifyDialog
extends RefCounted
## 通知設定：事件提醒、每日小提醒、褪色預告、安靜時段。


static func open(host: Control) -> void:
	var parts := UiKit.open_modal(host, "通知")
	var body: VBoxContainer = parts[1]
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	body.add_child(content)
	var rebuild := {}
	rebuild.fn = func():
		for c in content.get_children():
			c.queue_free()
		_build(content, rebuild.fn)
	rebuild.fn.call()


static func _build(content: VBoxContainer, redo: Callable) -> void:
	var s: Dictionary = Game.data.notify
	var notifier: Notifier = Game.notifier
	if not notifier.is_real():
		var note := UiKit.label("電腦版不會發通知，這裡的設定會在手機上生效。", 22, "Muted")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(note)
	elif not notifier.has_permission():
		var warn := UiKit.label("手機還沒允許「空島事記」發通知。", 22, "Accent")
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(warn)
		var ask := UiKit.button("允許通知", func():
			notifier.request_permission()
			redo.call(), "AccentButton")
		ask.custom_minimum_size = Vector2(0, 68)
		content.add_child(ask)

	_toggle(content, "事件提醒", "設定了提醒的事件，時間到時通知你", s.events, func(on: bool):
		Game.set_notify("events", on)
		redo.call())
	_toggle(content, "每日小提醒", "那天還沒完成任何事時，柯基提醒你一次", s.daily, func(on: bool):
		if on:
			notifier.request_permission()
		Game.set_notify("daily", on)
		redo.call())
	if s.daily:
		ScheduleDialog._stepper(content, "每天 %s" % Schedule.time_text(s.daily_time), func(d: int):
			Game.set_notify("daily_time", posmod(int(Game.data.notify.daily_time) + d * 30, 1440))
			redo.call())
	_toggle(content, "褪色預告", "島快要開始褪色的前一晚提醒你", s.fade, func(on: bool):
		Game.set_notify("fade", on)
		redo.call())

	content.add_child(UiKit.label("安靜時段（每日小提醒和褪色預告不會在這段時間發）", 22, "Muted"))
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 12)
	content.add_child(q)
	ScheduleDialog._stepper(q, "從 " + Schedule.time_text(s.quiet_start), func(d: int):
		Game.set_notify("quiet_start", posmod(int(Game.data.notify.quiet_start) + d * 30, 1440))
		redo.call())
	ScheduleDialog._stepper(q, "到 " + Schedule.time_text(s.quiet_end), func(d: int):
		Game.set_notify("quiet_end", posmod(int(Game.data.notify.quiet_end) + d * 30, 1440))
		redo.call())

	var count := Game.notifier.scheduled.size()
	content.add_child(UiKit.label("目前排了 %d 則通知" % count, 21, "Muted"))


## 一列開關：標題、說明、右邊的開／關按鈕。
static func _toggle(parent: Control, title: String, desc: String, on: bool, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	col.add_child(UiKit.label(title, 27))
	var d := UiKit.label(desc, 21, "Muted")
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d)
	var b := UiKit.button("開" if on else "關", func(): cb.call(not on), "AccentButton" if on else "")
	b.tooltip_text = title
	b.custom_minimum_size = Vector2(96, 64)
	row.add_child(b)


## 第一次完成事件後問一次：要不要每天提醒？
static func ask_daily(host: Control) -> void:
	var parts := UiKit.open_modal(host, "每天提醒你一次？")
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var l := UiKit.label("那天還沒完成任何小事的話，柯基會在晚上 9 點提醒你一次。之後可以在「回顧 → 通知」裡改時間或關掉。", 26)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	body.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	var no := UiKit.button("先不用", func():
		Game.set_notify("asked", true)
		overlay.queue_free())
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.custom_minimum_size = Vector2(0, 72)
	row.add_child(no)
	var yes := UiKit.button("好，提醒我", func():
		Game.notifier.request_permission()
		Game.data.notify.daily = true
		Game.set_notify("asked", true)
		overlay.queue_free(), "AccentButton")
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.custom_minimum_size = Vector2(0, 72)
	row.add_child(yes)
	# 按「關閉」也算問過了
	overlay.tree_exiting.connect(func():
		if not Game.data.notify.asked:
			Game.set_notify("asked", true))
