extends Control
## 島嶼頁：等角畫面 + 樓層切換、旋轉、縮放、素材選擇與移除模式。

const IslandView := preload("res://scripts/ui/island_view.gd")
const REMOVE_MODE := "remove"
const PLANT_MODE := "plant"

var view: IslandView
var _layer_label: Label
var _hint: Label
var _tool_buttons := {}
var _tool := Materials.DIRT
var _status: Label
var _plant_row: HBoxContainer
var _plant_scroll: ScrollContainer
var _plant_choice := ""


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
	cam_box.add_child(UiKit.button("圖鑑", func(): Encyclopedia.open(_modal_host())))

	# 下方：素材與移除
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = GROW_DIRECTION_BEGIN
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_bottom = -12
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)

	_status = UiKit.label("", 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("6b7480"))
	bottom.add_child(_status)

	_hint = UiKit.label("", 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color("36506b"))
	bottom.add_child(_hint)

	_plant_scroll = ScrollContainer.new()
	_plant_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_plant_scroll.custom_minimum_size = Vector2(0, 64)
	bottom.add_child(_plant_scroll)
	_plant_row = HBoxContainer.new()
	_plant_row.add_theme_constant_override("separation", 8)
	_plant_scroll.add_child(_plant_row)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	bottom.add_child(tools)
	var group := ButtonGroup.new()
	for t in Materials.TYPES:
		var b := UiKit.tool_button(group, Materials.top_color(t))
		b.pressed.connect(_select_tool.bind(t))
		tools.add_child(b)
		_tool_buttons[t] = b
	var pl := UiKit.tool_button(group, Color("c5e1a5"))
	pl.text = "植物"
	pl.pressed.connect(_select_tool.bind(PLANT_MODE))
	tools.add_child(pl)
	_tool_buttons[PLANT_MODE] = pl
	var rm := UiKit.tool_button(group, Color("f2b8b5"))
	rm.text = "移除"
	rm.pressed.connect(_select_tool.bind(REMOVE_MODE))
	tools.add_child(rm)
	_tool_buttons[REMOVE_MODE] = rm
	_tool_buttons[_tool].button_pressed = true

	Game.changed.connect(_refresh)
	_refresh()


## 對話框要蓋住整個畫面，所以開在主畫面上。
func _modal_host() -> Control:
	var n: Node = self
	while n.get_parent() is Control:
		n = n.get_parent()
	return n as Control


func _change_layer(delta: int) -> void:
	view.layer += delta
	_refresh()


func _select_tool(t: String) -> void:
	_tool = t
	_refresh()


func _tapped_block(pos: Vector2) -> Vector3i:
	var target := view.block_at(pos)
	return target if target.x >= 0 else view.floor_cell_at(pos)


func _on_cell_tapped(pos: Vector2) -> void:
	match _tool:
		REMOVE_MODE:
			_remove_at(_tapped_block(pos))
		PLANT_MODE:
			_plant_at(_tapped_block(pos))
		_:
			_place_at(view.floor_cell_at(pos))


func _place_at(cell: Vector3i) -> void:
	match Game.island.place_problem(cell, _tool, Game.data.inventory):
		"":
			Game.place_block(cell, _tool)
		"occupied":
			_flash("這格已經有方塊了")
		"plant_below":
			_flash("下面種了植物，不能蓋住它")
		"no_material":
			_flash("%s不夠了，去完成一件小事吧" % Materials.display_name(_tool))


func _plant_at(cell: Vector3i) -> void:
	if _plant_choice == "":
		_flash("還沒有植物，完成事件有機會拿到")
		return
	var pname := Catalog.plant_name(_plant_choice)
	match Game.island.plant_problem(cell, _plant_choice, Game.data.plants):
		"":
			Game.plant(cell, _plant_choice)
		"no_block":
			_flash("點一個方塊來種%s" % pname)
		"wrong_base":
			_flash("%s要種在%s方塊上" % [pname, Materials.display_name(Catalog.plant_base(_plant_choice))])
		"occupied":
			_flash("這裡已經種了東西")
		"covered":
			_flash("上面被方塊蓋住了")
		"no_plant":
			_flash("%s用完了" % pname)


func _remove_at(cell: Vector3i) -> void:
	if Game.island.plants.has(cell):
		_flash("收回 1 株%s" % Catalog.plant_name(Game.remove_plant(cell)))
		return
	var removed := Game.remove_block(cell)
	_flash("退回 1 個%s" % Materials.display_name(removed) if removed != "" else "這裡沒有方塊")


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
	_refresh_plants()
	_refresh_status()


func _refresh_status() -> void:
	var fade := Game.current_fade()
	var lines := []
	if fade >= 1.0:
		lines.append("島褪成灰色了。連續幾天完成事件，顏色會慢慢回來")
	elif fade > 0.0:
		lines.append("島正在褪色（%d%%），完成事件讓它恢復顏色" % roundi(fade * 100))
	var names := []
	for a in Game.island.animals:
		names.append(Catalog.animal_name(a.species) + ("？" if a.confused_since != 0 else ""))
	if not names.is_empty():
		lines.append("島上的動物：" + "、".join(names))
	_status.text = "
".join(lines)
	_status.visible = not lines.is_empty()


func _refresh_plants() -> void:
	_plant_scroll.visible = _tool == PLANT_MODE
	var owned := []
	for id in Catalog.plant_ids():
		if int(Game.data.plants.get(id, 0)) > 0:
			owned.append(id)
	if not owned.has(_plant_choice):
		_plant_choice = owned[0] if not owned.is_empty() else ""
	for c in _plant_row.get_children():
		c.queue_free()
	if owned.is_empty():
		_plant_row.add_child(UiKit.label("還沒有植物，完成事件有機會掉落", 24))
		return
	var group := ButtonGroup.new()
	for id in owned:
		var base := Catalog.plant_base(id)
		var b := UiKit.tool_button(group, Materials.top_color(base).lightened(0.35))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size = Vector2(0, 60)
		b.text = "%s %d" % [Catalog.plant_name(id), Game.data.plants[id]]
		b.button_pressed = id == _plant_choice
		b.pressed.connect(func(): _plant_choice = id)
		_plant_row.add_child(b)