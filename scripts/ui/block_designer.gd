class_name BlockDesigner
extends RefCounted
## 自訂方塊設計：選基礎類型 → 切換頂面／側面用 8×8 像素作畫 → 儲存（不需要取名）。

const PALETTE := [
	"ffffff", "d9d9d9", "8c8c8c", "3d3d3d",
	"7cc35a", "4c9a3f", "2e6b2e", "c5e1a5",
	"5cbcf0", "3a8fd0", "1f5f99", "b3e5fc",
	"efdca2", "d8c07f", "9a6b45", "5d3a1e",
	"e53935", "ff8a3d", "ffd54f", "f48fb1",
	"ba68c8", "7e57c2", "26a69a", "8d6e63",
]


## 等角小方塊預覽（頂面與側面貼圖）。
class CubePreview:
	extends Control
	var top_tex: Texture2D
	var side_tex: Texture2D

	func _draw() -> void:
		if top_tex == null or side_tex == null:
			return
		var s := minf(size.x / 2.0, size.y / 2.0) * 0.95
		var c := Vector2(size.x * 0.5, size.y * 0.5 - s * 0.5)
		var t0 := c + Vector2(0, -s * 0.5)
		var t1 := c + Vector2(s, 0)
		var t2 := c + Vector2(0, s * 0.5)
		var t3 := c + Vector2(-s, 0)
		var down := Vector2(0, s)
		var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		for f in [[PackedVector2Array([t3, t2, t2 + down, t3 + down]), side_tex, 0.92],
				[PackedVector2Array([t2, t1, t1 + down, t2 + down]), side_tex, 0.75],
				[PackedVector2Array([t0, t1, t2, t3]), top_tex, 1.0]]:
			var k: float = f[2]
			var col := Color(k, k, k)
			draw_polygon(f[0], PackedColorArray([col, col, col, col]), uv, f[1])


## 8×8 畫布：按住拖曳連續上色。
class PixelCanvas:
	extends Control
	signal painted
	var pixels := PackedColorArray()
	var color := Color.WHITE
	var _painting := false
	var _last_pos := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_painting = event.pressed
			if event.pressed:
				_paint_at(event.position)
				_last_pos = event.position
			accept_event()
		elif event is InputEventMouseMotion and _painting:
			# 手指移動很快時中間的格子也要補上
			var cell := size.x / CustomBlocks.SIZE
			var steps := maxi(1, ceili(_last_pos.distance_to(event.position) / (cell * 0.4)))
			for i in steps + 1:
				_paint_at(_last_pos.lerp(event.position, float(i) / steps))
			_last_pos = event.position
			accept_event()

	func _paint_at(pos: Vector2) -> void:
		var cell := size.x / CustomBlocks.SIZE
		var x := int(pos.x / cell)
		var y := int(pos.y / cell)
		if x < 0 or y < 0 or x >= CustomBlocks.SIZE or y >= CustomBlocks.SIZE:
			return
		var i := y * CustomBlocks.SIZE + x
		if pixels[i] != color:
			pixels[i] = color
			queue_redraw()
			painted.emit()

	func _draw() -> void:
		var cell := size.x / CustomBlocks.SIZE
		for y in CustomBlocks.SIZE:
			for x in CustomBlocks.SIZE:
				draw_rect(Rect2(x * cell, y * cell, cell, cell), pixels[y * CustomBlocks.SIZE + x])
		for i in CustomBlocks.SIZE + 1:
			var line_color := Color(0, 0, 0, 0.18)
			draw_line(Vector2(i * cell, 0), Vector2(i * cell, size.y), line_color)
			draw_line(Vector2(0, i * cell), Vector2(size.x, i * cell), line_color)


static func open(host: Control, start_base: String = Materials.DIRT) -> void:
	var parts := UiKit.open_modal(host, "設計方塊")
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var state := {
		"base": start_base,
		"face": CustomBlocks.FACE_TOP,
		"top": CustomBlocks.default_pixels(start_base, CustomBlocks.FACE_TOP),
		"side": CustomBlocks.default_pixels(start_base, CustomBlocks.FACE_SIDE),
	}

	var slots := UiKit.label("設計格 %d / %d" % [Game.data.custom_designs.size(), Game.data.design_slots()], 22)
	slots.add_theme_color_override("font_color", Color("6b7480"))
	body.add_child(slots)

	# 基礎類型
	body.add_child(UiKit.label("基礎類型（功能跟著它，只改外觀）", 22))
	var base_row := HBoxContainer.new()
	base_row.add_theme_constant_override("separation", 8)
	body.add_child(base_row)
	var base_group := ButtonGroup.new()

	# 頂面／側面
	var face_row := HBoxContainer.new()
	face_row.add_theme_constant_override("separation", 8)
	var face_group := ButtonGroup.new()

	var canvas_row := HBoxContainer.new()
	canvas_row.add_theme_constant_override("separation", 16)
	var canvas := PixelCanvas.new()
	canvas.custom_minimum_size = Vector2(384, 384)
	var side_col := VBoxContainer.new()
	side_col.add_theme_constant_override("separation", 10)
	side_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview := CubePreview.new()
	preview.custom_minimum_size = Vector2(0, 170)

	var refresh := func():
		canvas.pixels = state[state.face]
		canvas.queue_redraw()
		preview.top_tex = CustomBlocks.make_texture(state.top)
		preview.side_tex = CustomBlocks.make_texture(state.side)
		preview.queue_redraw()
	state.refresh = refresh

	for t in Materials.TYPES:
		var b := UiKit.tool_button(base_group, Materials.top_color(t))
		b.text = Materials.display_name(t)
		b.custom_minimum_size = Vector2(0, 60)
		b.button_pressed = t == start_base
		b.pressed.connect(func():
			state.base = t
			state.top = CustomBlocks.default_pixels(t, CustomBlocks.FACE_TOP)
			state.side = CustomBlocks.default_pixels(t, CustomBlocks.FACE_SIDE)
			state.refresh.call())
		base_row.add_child(b)

	body.add_child(face_row)
	for face in [[CustomBlocks.FACE_TOP, "頂面"], [CustomBlocks.FACE_SIDE, "側面（四面共用）"]]:
		var b := UiKit.tool_button(face_group, Color("eef2f5"))
		b.text = face[1]
		b.custom_minimum_size = Vector2(0, 56)
		b.button_pressed = face[0] == CustomBlocks.FACE_TOP
		var face_id: String = face[0]
		b.pressed.connect(func():
			state.face = face_id
			state.refresh.call())
		face_row.add_child(b)

	body.add_child(canvas_row)
	canvas_row.add_child(canvas)
	canvas_row.add_child(side_col)
	side_col.add_child(preview)
	canvas.painted.connect(func():
		state[state.face] = canvas.pixels
		preview.top_tex = CustomBlocks.make_texture(state.top)
		preview.side_tex = CustomBlocks.make_texture(state.side)
		preview.queue_redraw())
	var fill := UiKit.button("整面填色", func():
		var px := PackedColorArray()
		px.resize(CustomBlocks.SIZE * CustomBlocks.SIZE)
		px.fill(canvas.color)
		state[state.face] = px
		state.refresh.call())
	side_col.add_child(fill)
	side_col.add_child(UiKit.button("回到起點", func():
		state[state.face] = CustomBlocks.default_pixels(state.base, state.face)
		state.refresh.call()))

	# 調色盤
	var palette := GridContainer.new()
	palette.columns = 12
	palette.add_theme_constant_override("h_separation", 6)
	palette.add_theme_constant_override("v_separation", 6)
	body.add_child(palette)
	var swatch_group := ButtonGroup.new()
	for hex in PALETTE:
		var c := Color(hex)
		var sw := Button.new()
		sw.toggle_mode = true
		sw.button_group = swatch_group
		sw.focus_mode = Control.FOCUS_NONE
		sw.custom_minimum_size = Vector2(42, 42)
		sw.add_theme_stylebox_override("normal", UiKit.box(c, 8, Color(0, 0, 0, 0.15)))
		sw.add_theme_stylebox_override("hover", UiKit.box(c, 8, Color(0, 0, 0, 0.3)))
		sw.add_theme_stylebox_override("pressed", UiKit.box(c, 8, Color("2b3a4a")))
		sw.pressed.connect(func(): canvas.color = c)
		palette.add_child(sw)
		if hex == "7cc35a":
			sw.button_pressed = true
			canvas.color = c

	var save := UiKit.button("儲存到「我的方塊」", func():
		if Game.save_design(state.base, state.top, state.side) >= 0:
			overlay.queue_free())
	save.custom_minimum_size = Vector2(0, 72)
	save.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
	body.add_child(save)
	if not Game.data.can_add_design():
		save.disabled = true
		save.text = "設計格滿了（再完成 %d 件事件解鎖）" % Game.data.events_to_next_slot()
	refresh.call()
