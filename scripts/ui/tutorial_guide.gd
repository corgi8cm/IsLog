extends Control
## 新手引導：畫面變暗，只亮出這一步要按的地方，旁邊有跳動的箭頭；柯基在對話框裡說明。
## 引導進行中只能按亮起來的地方（對話框裡的按鈕、略過也可以按）。

const DIM := Color(0.06, 0.1, 0.16, 0.62)
const HOLE_PAD := 10.0
const BUBBLE_BG := Color("fffdf6")

var main: Control
var _target := Rect2()
## 亮起來的地方能不能按（開場與結尾只是讓玩家看，不能按）。
var _passthrough := false
var _text := ""
var _time := 0.0
var _bubble: PanelContainer
var _label: Label
var _buttons: HBoxContainer
var _corgi: Control
var _key := ""


## 對話框左邊的柯基（用遊戲裡的畫法放大）。
class CorgiPortrait:
	extends Control
	var painter := IsoPainter.new(self)
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var hop := absf(sin(t * 3.0)) * 4.0
		draw_set_transform(Vector2(size.x * 0.5, size.y * 0.9 - hop), 0.0, Vector2(5, 5))
		painter.animal("corgi", Vector2.ZERO, false, false, 0.0)
		draw_set_transform(Vector2.ZERO)


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	_bubble = PanelContainer.new()
	var sb := UiKit.box(BUBBLE_BG, 22, Color("2b3a4a"))
	sb.set_border_width_all(3)
	sb.set_content_margin_all(18)
	_bubble.add_theme_stylebox_override("panel", sb)
	add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bubble.add_child(row)
	_corgi = CorgiPortrait.new()
	_corgi.custom_minimum_size = Vector2(140, 110)
	_corgi.size_flags_vertical = SIZE_SHRINK_END
	_corgi.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(_corgi)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	row.add_child(col)
	_label = UiKit.label("", 27)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_label)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	col.add_child(_buttons)


func _process(delta: float) -> void:
	_time += delta
	if not visible:
		return
	_update()
	queue_redraw()


## 引導進行中，亮起來的地方以外都擋住。
func _has_point(point: Vector2) -> bool:
	if _passthrough and _target.has_area() and _target.grow(HOLE_PAD).has_point(point):
		return false
	return true


func _gui_input(event: InputEvent) -> void:
	accept_event()


# --- 每一步要亮哪裡、說什麼 --------------------------------------------------

func _update() -> void:
	var step := Game.data.tutorial_step
	var pages: Array = main.get("_pages")
	var events = pages[0]
	var island = pages[1]
	var info := Tutorial.info(step)
	var key := str(step)
	var text: String = info.get("text", "")
	var target := Rect2()
	var passthrough := true
	var buttons := []  # [文字, callback]
	match step:
		Tutorial.Step.INTRO:
			target = _cell_rect(island, Vector3i(4, 4, 0), true)
			passthrough = false
			buttons = [[info.button, Game.tutorial_button]]
		Tutorial.Step.ADD_EVENT:
			target = events.add_row_rect()
			buttons = _suggestions()
		Tutorial.Step.COMPLETE:
			target = events.first_complete_rect()
		Tutorial.Step.PLACE:
			if island.current_tool() != Materials.DIRT:
				key += "a"
				text = "拿到土和一株花了！先選下面的「土」。"
				target = island.tool_rect(Materials.DIRT)
			else:
				key += "b"
				text = "點亮起來的格子，把土方塊放到島上。"
				target = _cell_rect(island, Tutorial.PLACE_CELL, false)
		Tutorial.Step.PLANT:
			if island.current_tool() != island.PLANT_MODE:
				key += "a"
				target = island.tool_rect(island.PLANT_MODE)
			else:
				key += "b"
				text = "點一塊土，把花種下去。"
				target = _cell_rect(island, _plant_cell(), true)
		Tutorial.Step.VISIT:
			if Game.data.pending_events().is_empty():
				key += "a"
				target = events.add_row_rect()
				buttons = _suggestions()
			else:
				key += "b"
				text = "做完就按「完成」，看看誰會來拜訪。"
				target = events.first_complete_rect()
		Tutorial.Step.MEET:
			target = island.codex_rect()
		Tutorial.Step.OUTRO:
			passthrough = false
			buttons = [[info.button, Game.tutorial_button]]
	_target = target
	_passthrough = passthrough
	if key != _key:
		_key = key
		_label.text = text
		for c in _buttons.get_children():
			c.queue_free()
		for b in buttons:
			var btn := UiKit.button(b[0], b[1])
			btn.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
			_buttons.add_child(btn)
		var skip := UiKit.button("略過教學", Game.skip_tutorial)
		skip.add_theme_font_size_override("font_size", 20)
		skip.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0, 0, 0), 10))
		skip.add_theme_color_override("font_color", Color("8a97a5"))
		var spacer := Control.new()
		spacer.size_flags_horizontal = SIZE_EXPAND_FILL
		_buttons.add_child(spacer)
		_buttons.add_child(skip)
	_place_bubble()


func _suggestions() -> Array:
	var out := []
	for title in Tutorial.SUGGESTIONS:
		out.append([title, func(): Game.add_event(title)])
	return out


## 種花的格子：剛放下的土優先，沒有植物、上面沒蓋住的土方塊。
func _plant_cell() -> Vector3i:
	for c in [Tutorial.PLACE_CELL, Vector3i(4, 4, 0)]:
		if Game.island.get_block(c) == Materials.DIRT and not Game.island.plants.has(c) \
				and not Game.island.has_block(c + Vector3i(0, 0, 1)):
			return c
	for c in Game.island.blocks:
		if Game.island.blocks[c] == Materials.DIRT and not Game.island.plants.has(c):
			return c
	return Vector3i(4, 4, 0)


## 島上某格的範圍（top 為 true 時是方塊頂面，否則是那格的地板）。
func _cell_rect(island, cell: Vector3i, top: bool) -> Rect2:
	var view: Control = island.view
	var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), view.rotation_step)
	var h := cell.z + (1.0 if top else 0.0)
	var local: Vector2 = view.call("_origin") + Iso.to_screen(rc.x + 0.5, rc.y + 0.5, h) * view.zoom
	var center: Vector2 = view.get_global_transform() * local
	var s: Vector2 = Vector2(Iso.TILE_W, Iso.TILE_H) * view.zoom
	return Rect2(center - s * 0.5, s)


func _place_bubble() -> void:
	var margin := 18.0
	var w := size.x - margin * 2
	# 先固定寬度，自動換行的文字才算得出正確高度
	_bubble.custom_minimum_size = Vector2(w, 0)
	_label.custom_minimum_size = Vector2(w - 36 - 6 - _corgi.custom_minimum_size.x - 14, 0)
	var h := _bubble.get_combined_minimum_size().y
	_bubble.size = Vector2(w, h)
	# 亮起來的地方在上半部時對話框放下面，在下半部時放上面，不要蓋住它
	var y := size.y - h - 110.0
	if _target.has_area() and _target.get_center().y > size.y * 0.5:
		y = 110.0
	_bubble.position = Vector2(margin, y)


# --- 畫面 ---------------------------------------------------------------

func _draw() -> void:
	var r := _target.grow(HOLE_PAD) if _target.has_area() else Rect2()
	if r.has_area():
		draw_rect(Rect2(0, 0, size.x, r.position.y), DIM)
		draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), DIM)
		draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), DIM)
		draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), DIM)
		var pulse := 0.6 + 0.4 * sin(_time * 5.0)
		draw_rect(r, Color(1, 0.86, 0.35, pulse), false, 5.0)
		if _passthrough:
			_draw_arrow(r)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), DIM)


## 跳動的箭頭：亮起來的地方在上半部時從下面指上去，否則從上面指下來。
func _draw_arrow(r: Rect2) -> void:
	var bounce := absf(sin(_time * 4.0)) * 14.0
	var from_below := r.get_center().y < size.y * 0.3
	var tip := Vector2(r.get_center().x, r.end.y + 8 + bounce) if from_below else Vector2(r.get_center().x, r.position.y - 8 - bounce)
	var d := 1.0 if from_below else -1.0
	var pts := PackedVector2Array([tip, tip + Vector2(-26, 30 * d), tip + Vector2(-10, 30 * d),
		tip + Vector2(-10, 62 * d), tip + Vector2(10, 62 * d), tip + Vector2(10, 30 * d), tip + Vector2(26, 30 * d)])
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, Color("ffd54f"))
	draw_polyline(outline, Color("2b3a4a"), 4.0, true)
