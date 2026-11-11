extends Control
## 島嶼頁：等角畫面 + 樓層切換、旋轉、縮放、素材選擇與移除模式。

const IslandView := preload("res://scripts/ui/island_view.gd")
const REMOVE_MODE := "remove"

var view: IslandView
var _layer_label: Label
var _hint: Label
var _tool_buttons := {}
var _tool := Materials.DIRT


func _ready() -> void:
	view = IslandView.new()
	view.set_anchors_preset(PRESET_FULL_RECT)
	add_child(view)
	view.cell_tapped.connect(_on_cell_tapped)

	# 左側：樓層切換
	var layer_box := VBoxContainer.new()
	layer_box.add_theme_constant_override("separation", 8)
	add_child(layer_box)
	layer_box.set_anchors_and_offsets_preset(PRESET_TOP_LEFT, PRESET_MODE_MINSIZE, 16)
	var up := UiKit.button("▲ 上一層", _change_layer.bind(1))
	var down := UiKit.button("▼ 下一層", _change_layer.bind(-1))
	_layer_label = UiKit.label("", 26)
	_layer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer_box.add_child(up)
	layer_box.add_child(UiKit.chip(_layer_label, Color(1, 1, 1, 0.75)))
	layer_box.add_child(down)

	# 右側：鏡頭
	var cam_box := VBoxContainer.new()
	cam_box.add_theme_constant_override("separation", 8)
	add_child(cam_box)
	cam_box.grow_horizontal = GROW_DIRECTION_BEGIN
	cam_box.set_anchors_and_offsets_preset(PRESET_TOP_RIGHT, PRESET_MODE_MINSIZE, 16)
	cam_box.add_child(UiKit.button("旋轉", func(): view.rotation_step += 1))
	cam_box.add_child(UiKit.button("放大", func(): view.zoom_at(1.25, view.size * 0.5)))
	cam_box.add_child(UiKit.button("縮小", func(): view.zoom_at(0.8, view.size * 0.5)))
	cam_box.add_child(UiKit.button("置中", view.reset_view))

	# 下方：素材與移除
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = GROW_DIRECTION_BEGIN
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -12
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)

	_hint = UiKit.label("", 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color("36506b"))
	bottom.add_child(_hint)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	bottom.add_child(tools)
	var group := ButtonGroup.new()
	for t in Materials.TYPES:
		var b := UiKit.tool_button(group, Materials.top_color(t))
		b.pressed.connect(_select_tool.bind(t))
		tools.add_child(b)
		_tool_buttons[t] = b
	var rm := UiKit.tool_button(group, Color("f2b8b5"))
	rm.text = "移除"
	rm.pressed.connect(_select_tool.bind(REMOVE_MODE))
	tools.add_child(rm)
	_tool_buttons[REMOVE_MODE] = rm
	_tool_buttons[_tool].button_pressed = true

	Game.changed.connect(_refresh)
	_refresh()


func _change_layer(delta: int) -> void:
	view.layer += delta
	_refresh()


func _select_tool(t: String) -> void:
	_tool = t
	_refresh()


func _on_cell_tapped(pos: Vector2) -> void:
	if _tool == REMOVE_MODE:
		var target := view.block_at(pos)
		if target.x < 0:
			target = view.floor_cell_at(pos)
		var removed := Game.remove_block(target)
		_flash("退回 1 個%s" % Materials.display_name(removed) if removed != "" else "這裡沒有方塊")
		return
	var cell := view.floor_cell_at(pos)
	if not IslandData.in_bounds(cell):
		return
	if Game.island.has_block(cell):
		_flash("這格已經有方塊了")
	elif int(Game.data.inventory.get(_tool, 0)) <= 0:
		_flash("%s不夠了，去完成一件小事吧" % Materials.display_name(_tool))
	else:
		Game.place_block(cell, _tool)


func _flash(text: String) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_hint, "modulate:a", 0.0, 0.6)


func _refresh() -> void:
	_layer_label.text = "第 %d 層" % (view.layer + 1)
	for t in Materials.TYPES:
		_tool_buttons[t].text = "%s %d" % [Materials.display_name(t), Game.data.inventory.get(t, 0)]
