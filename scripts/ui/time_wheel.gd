class_name TimeWheel
extends Control
## 一欄可以上下滑動的數字滾輪（像手機鬧鐘）：放開後自動對齊到中間那格，頭尾相接。
## 時間選擇用兩欄（時 1–12、分 0–59），外框與中間的選取帶由 TimeWheel.Picker 畫。

signal changed(value: int)

const ROW_H := 44.0
## 中間上下各顯示幾格。
const SIDE_ROWS := 2

var values: Array = []
var unit := ""
## 目前在中間的是第幾個（可以是小數：滑動中）。
var _pos := 0.0
var _dragging := false
var _moved := 0.0
var _tween: Tween


func setup(list: Array, start_value: int, unit_text: String) -> void:
	values = list
	unit = unit_text
	var i := values.find(start_value)
	_pos = float(maxi(i, 0))
	custom_minimum_size = Vector2(170, ROW_H * (SIDE_ROWS * 2 + 1))
	mouse_filter = MOUSE_FILTER_STOP
	queue_redraw()


func value() -> int:
	return values[posmod(roundi(_pos), values.size())]


## 往下（正）或往上（負）撥幾格，會對齊並通知。
func step(rows: int) -> void:
	_pos = roundf(_pos) + rows
	_snap(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			step(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			step(1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_moved = 0.0
				if _tween:
					_tween.kill()
			elif _dragging:
				_dragging = false
				if _moved < 6.0:
					# 輕點上面或下面那格：撥過去
					var rows := roundi((mb.position.y - size.y * 0.5) / ROW_H)
					_pos = roundf(_pos) + rows
				_snap(true)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var dy: float = (event as InputEventMouseMotion).relative.y
		_moved += absf(dy)
		_pos -= dy / ROW_H
		queue_redraw()
		accept_event()


func _snap(animate: bool) -> void:
	var target := roundf(_pos)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(func(v: float):
			_pos = v
			queue_redraw(), _pos, target, 0.12)
		_tween.tween_callback(func(): changed.emit(value()))
	else:
		_pos = target
		queue_redraw()
		changed.emit(value())


func _draw() -> void:
	if values.is_empty():
		return
	var font := get_theme_default_font()
	var ink := UiKit.color("ink")
	var cy := size.y * 0.5
	var base := floori(_pos)
	var frac := _pos - base
	for k in range(-SIDE_ROWS - 1, SIDE_ROWS + 2):
		var i := posmod(base + k, values.size())
		var y := cy + (k - frac) * ROW_H
		var dist := absf((k - frac))
		if dist > SIDE_ROWS + 0.5:
			continue
		var a := clampf(1.0 - dist * 0.32, 0.0, 1.0)
		var fs := int(lerpf(40.0, 26.0, clampf(dist, 0.0, 1.0)))
		var text := "%02d" % values[i] if unit == "分" else str(values[i])
		draw_string(font, Vector2(0, y + fs * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, size.x - 40, fs, Color(ink, a))
	draw_string(font, Vector2(size.x - 38, cy + 8), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.color("muted"))


## 時、分兩欄滾輪加外框、中間選取帶與「:」。changed(minutes_of_12h_clock) 只回報時與分。
class Picker extends Control:
	var hour: TimeWheel
	var minute: TimeWheel
	signal picked(hour12: int, minute: int)

	func _init(h12: int, m: int) -> void:
		custom_minimum_size = Vector2(0, TimeWheel.ROW_H * (TimeWheel.SIDE_ROWS * 2 + 1) + 16)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 60)
		add_child(row)
		row.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var hours := []
		for i in range(1, 13):
			hours.append(i)
		var mins := []
		for i in 60:
			mins.append(i)
		hour = TimeWheel.new()
		hour.setup(hours, h12, "時")
		minute = TimeWheel.new()
		minute.setup(mins, m, "分")
		for w in [hour, minute]:
			w.size_flags_vertical = SIZE_SHRINK_CENTER
			w.changed.connect(func(_v): picked.emit(hour.value(), minute.value()))
			row.add_child(w)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO, size)
		draw_style_box(UiKit.box(Color(UiKit.color("ink"), 0.04), 22), box)
		var band := Rect2(12, size.y * 0.5 - 28, size.x - 24, 56)
		draw_style_box(UiKit.box(UiKit.color("sel"), 16, UiKit.color("accent"), 2), band)
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, size.y * 0.5 + 13), ":", HORIZONTAL_ALIGNMENT_CENTER, size.x, 38, UiKit.color("ink"))
