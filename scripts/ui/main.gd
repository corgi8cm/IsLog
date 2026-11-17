extends Control
## 主畫面：上方素材列、中間頁面、下方分頁切換。

const EventsPage := preload("res://scripts/ui/events_page.gd")
const IslandPage := preload("res://scripts/ui/island_page.gd")
const ReviewPage := preload("res://scripts/ui/review_page.gd")
const TutorialGuide := preload("res://scripts/ui/tutorial_guide.gd")

var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _counts := {}
var _daily: DailyBadge
var _guide: Control
var _top_sb: StyleBoxFlat
var _tab_sb: StyleBoxFlat

## 手機螢幕的圓角與瀏海會切到畫面邊緣：上、下、左右至少留這麼多（畫面座標）。
const MIN_TOP_INSET := 34.0
const MIN_BOTTOM_INSET := 18.0
const MIN_SIDE_INSET := 10.0
var _tutorial_step := -1
var _tip_open := false


## 背景的點點紙（顏色跟著時段）。
class Paper extends Control:
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		Game.daytime_changed.connect(queue_redraw)

	func _draw() -> void:
		Doodles.paper(self, Rect2(Vector2.ZERO, size), Game.now_minutes())


## 右上角：時段圖示 + 「今日素材」與今天拿到幾件（十顆點）。
class DailyBadge extends Control:
	var done := 0
	var limit := 10
	var pro := false

	func _ready() -> void:
		custom_minimum_size = Vector2(172, 56)
		tooltip_text = "今天完成事件拿到的素材"
		Game.daytime_changed.connect(queue_redraw)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()

	func _draw() -> void:
		var minutes := Game.now_minutes()
		var glyph := "sun"
		match DayCycle.phase(minutes):
			DayCycle.MORNING: glyph = "sunrise"
			DayCycle.EVENING: glyph = "sunset"
			DayCycle.NIGHT: glyph = "moon"
		draw_set_transform(Vector2(26, size.y * 0.5))
		Icon.draw_glyph(self, glyph, UiKit.color("ink"))
		draw_set_transform(Vector2.ZERO)
		var font := get_theme_default_font()
		var ink := UiKit.color("ink")
		if pro:
			draw_string(font, Vector2(56, size.y * 0.5 - 4), "今日素材", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(ink, 0.7))
			draw_string(font, Vector2(56, size.y * 0.5 + 20), "%d 件" % done, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
			return
		draw_string(font, Vector2(56, size.y * 0.5 - 6), "今日素材 %d/%d" % [done, limit], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(ink, 0.7))
		for i in limit:
			var c := Vector2(61 + i * 11.4, size.y * 0.5 + 12)
			draw_circle(c, 4.6, UiKit.color("accent") if i < done else Color(ink, 0.18))


func _ready() -> void:
	UiKit.night = Game.is_night()
	theme = UiKit.make_theme()

	var bg := Paper.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var col := VBoxContainer.new()
	col.set_anchors_preset(PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	col.add_child(_build_top_bar())

	var content := Control.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.clip_contents = true
	col.add_child(content)
	for page in [EventsPage.new(), IslandPage.new(), ReviewPage.new()]:
		page.set_anchors_preset(PRESET_FULL_RECT)
		content.add_child(page)
		_pages.append(page)

	var tab_bar := _build_tab_bar()
	col.add_child(tab_bar)
	var top_bar: Control = col.get_child(0)
	_pages[1].photo_mode_changed.connect(func(on: bool):
		top_bar.visible = not on
		tab_bar.visible = not on)

	_guide = TutorialGuide.new()
	_guide.main = self
	_guide.visible = false
	add_child(_guide)

	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

	Game.changed.connect(_refresh)
	Game.daytime_changed.connect(_check_night)
	Game.cloud_choice_needed.connect(func(local_summary: Dictionary, remote: Dictionary):
		AccountDialog.open_choice(self, local_summary, remote))
	_show_page(0)
	_refresh()


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	_top_sb = UiKit.box(Color.TRANSPARENT, 0)
	_top_sb.content_margin_top = 18
	_top_sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", _top_sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	# 素材：小方塊 + 數字，點一下開交換視窗
	var bar := PanelContainer.new()
	bar.theme_type_variation = "Bar"
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(bar)
	var mats := HBoxContainer.new()
	mats.add_theme_constant_override("separation", 0)
	bar.add_child(mats)
	for t in Materials.TYPES:
		var b := Button.new()
		b.theme_type_variation = "FlatButton"
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.tooltip_text = Materials.display_name(t)
		b.custom_minimum_size = Vector2(0, 44)
		var inner := HBoxContainer.new()
		inner.mouse_filter = MOUSE_FILTER_IGNORE
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 6)
		b.add_child(inner)
		inner.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		var cube := UiKit.mini_cube(t)
		cube.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(cube)
		var n := UiKit.label("0", 26)
		n.mouse_filter = MOUSE_FILTER_IGNORE
		inner.add_child(n)
		b.pressed.connect(open_exchange.bind(t))
		_counts[t] = n
		mats.add_child(b)
	var daily := PanelContainer.new()
	daily.theme_type_variation = "Bar"
	row.add_child(daily)
	_daily = DailyBadge.new()
	daily.add_child(_daily)
	return panel


func _check_night() -> void:
	if UiKit.night == Game.is_night():
		return
	UiKit.night = Game.is_night()
	theme = UiKit.make_theme()
	_show_page(_current_page)


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
	_tab_sb = UiKit.box(Color.TRANSPARENT, 0)
	_tab_sb.content_margin_top = 6
	panel.add_theme_stylebox_override("panel", _tab_sb)
	var bar := PanelContainer.new()
	bar.theme_type_variation = "Bar"
	panel.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var names := ["事件", "島嶼", "回顧"]
	var icons := ["events", "island", "review"]
	var group := ButtonGroup.new()
	for i in names.size():
		var b := UiKit.tile_button(group, UiKit.icon(icons[i]), names[i], "TabButton")
		b.custom_minimum_size = Vector2(0, 84)
		b.text = names[i]
		b.add_theme_color_override("font_color", Color.TRANSPARENT)
		b.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
		b.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
		b.add_theme_color_override("font_hover_pressed_color", Color.TRANSPARENT)
		b.pressed.connect(_show_page.bind(i))
		row.add_child(b)
		_tabs.append(b)
	return panel


var _current_page := 0


func _show_page(index: int) -> void:
	_current_page = index
	for i in _pages.size():
		_pages[i].visible = i == index
		var selected := i == index
		_tabs[i].set_pressed_no_signal(selected)
		var role := "accent" if selected else "ink"
		(_tabs[i].get_child(0).get_child(0) as Icon).role = role
		(_tabs[i].get_meta("caption") as Label).theme_type_variation = "Accent" if selected else ""


# --- 安全區域 -------------------------------------------------------------

## 依手機回報的安全區域（瀏海、圓角）加大上方素材列與下方分頁列的留白。
func _apply_safe_area() -> void:
	var insets := safe_insets()
	_top_sb.content_margin_top = 18 + insets.top
	_top_sb.content_margin_left = 16 + insets.side
	_top_sb.content_margin_right = 16 + insets.side
	_tab_sb.content_margin_bottom = 10 + insets.bottom
	_tab_sb.content_margin_left = 16 + insets.side
	_tab_sb.content_margin_right = 16 + insets.side


## 畫面座標的上、下、左右留白：{top, bottom, side}
func safe_insets() -> Dictionary:
	var top := MIN_TOP_INSET
	var bottom := MIN_BOTTOM_INSET
	var side := MIN_SIDE_INSET
	var win := DisplayServer.window_get_size()
	# 電腦版的安全區域是工作列以外的範圍，不適用；只在手機上用（手機上遊戲是全螢幕）
	if win.x > 0 and OS.has_feature("mobile"):
		var k := get_viewport_rect().size.x / win.x
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if safe.size.x > 0 and screen.x > 0:
			top = maxf(top, safe.position.y * k)
			bottom = maxf(bottom, (screen.y - safe.end.y) * k)
			side = maxf(side, maxf(safe.position.x, screen.x - safe.end.x) * k)
	return {"top": top, "bottom": bottom, "side": side}


# --- 新手引導與提示 -------------------------------------------------------

func _refresh_tutorial() -> void:
	var step := Game.data.tutorial_step
	_guide.visible = Tutorial.is_active(step)
	if step == _tutorial_step:
		return
	_tutorial_step = step
	var island_page = _pages[1]
	if not Tutorial.is_active(step):
		island_page.view.reset_view()
		return
	_show_page(Tutorial.info(step).page)
	if step == Tutorial.Step.PLACE:
		island_page.view.layer = 0
		island_page.view.reset_view()
	elif step == Tutorial.Step.OUTRO:
		island_page.view.zoom = 0.62


func _check_tip() -> void:
	if _tip_open:
		return
	var key := Game.pending_tip()
	if key == "":
		if Game.should_ask_daily_reminder():
			_tip_open = true
			NotifyDialog.ask_daily(self)
			get_child(-1).tree_exited.connect(func(): _tip_open = false)
		return
	_tip_open = true
	Game.dismiss_tip(key)
	var parts := UiKit.open_modal(self, "小提示")
	var body: VBoxContainer = parts[1]
	var l := UiKit.label(Game.TIP_TEXTS[key], 27)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	body.add_child(l)
	var ok := UiKit.button("知道了", parts[0].queue_free)
	body.add_child(ok)
	parts[0].tree_exited.connect(func(): _tip_open = false)


func _refresh() -> void:
	_refresh_tutorial()
	_check_tip.call_deferred()
	for t in Materials.TYPES:
		_counts[t].text = str(Game.data.inventory.get(t, 0))
	var today := Game.today()
	_daily.pro = Game.data.is_pro
	_daily.limit = GameData.DAILY_LIMIT
	_daily.done = mini(Game.data.completions_on(today), GameData.DAILY_LIMIT) if not Game.data.is_pro else Game.data.completions_on(today)
	_daily.tooltip_text = "今日素材 %d/%d" % [mini(Game.data.completions_on(today), GameData.DAILY_LIMIT), GameData.DAILY_LIMIT]
	_daily.queue_redraw()
