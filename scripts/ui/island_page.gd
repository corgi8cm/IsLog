extends Control
## 島嶼頁：等角畫面 + 樓層切換、旋轉、縮放、素材選擇與移除模式。

const IslandView := preload("res://scripts/ui/island_view.gd")
const REMOVE_MODE := "remove"
const PLANT_MODE := "plant"
const CUSTOM_MODE := "custom"

var view: IslandView
var _layer_label: Label
var _hint: Label
var _tool_buttons := {}
var _tool := Materials.DIRT
var _status: Label
var _plant_row: HBoxContainer
var _plant_scroll: ScrollContainer
var _custom_row: HBoxContainer
var _custom_scroll: ScrollContainer
var _custom_choice := ""
var _plant_choice := ""
var _codex_button: Button
## 平常的操作介面（拍照模式時隱藏）。
var _normal_ui: Array[Control] = []
var _photo_ui: Control
var _photo_buttons: Control
var _photo_hint: Label

signal photo_mode_changed(on: bool)


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
	_codex_button = UiKit.button("圖鑑", func():
		Encyclopedia.open(_modal_host())
		if Game.data.tutorial_step == Tutorial.Step.MEET:
			Game.tutorial_button())
	cam_box.add_child(_codex_button)
	cam_box.add_child(UiKit.button("拍照", set_photo_mode.bind(true)))
	cam_box.add_child(UiKit.button("我的島", func(): IslandsDialog.open(_modal_host())))

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
	_custom_scroll = ScrollContainer.new()
	_custom_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_custom_scroll.custom_minimum_size = Vector2(0, 150)
	bottom.add_child(_custom_scroll)
	_custom_row = HBoxContainer.new()
	_custom_row.add_theme_constant_override("separation", 8)
	_custom_scroll.add_child(_custom_row)

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
	var cu := UiKit.tool_button(group, Color("e1d5f5"))
	cu.text = "自訂"
	cu.pressed.connect(_select_tool.bind(CUSTOM_MODE))
	tools.add_child(cu)
	_tool_buttons[CUSTOM_MODE] = cu
	var rm := UiKit.tool_button(group, Color("f2b8b5"))
	rm.text = "移除"
	rm.pressed.connect(_select_tool.bind(REMOVE_MODE))
	tools.add_child(rm)
	_tool_buttons[REMOVE_MODE] = rm
	_tool_buttons[_tool].button_pressed = true

	_normal_ui = [layer_box, cam_box, bottom]
	_build_photo_ui()
	Game.changed.connect(_refresh)
	_refresh()


# --- 拍照模式 -------------------------------------------------------------

func _build_photo_ui() -> void:
	_photo_ui = Control.new()
	_photo_ui.set_anchors_preset(PRESET_FULL_RECT)
	_photo_ui.mouse_filter = MOUSE_FILTER_IGNORE
	_photo_ui.visible = false
	add_child(_photo_ui)
	var stamp := UiKit.label("", 26)
	stamp.name = "Stamp"
	stamp.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	stamp.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.3, 0.45))
	stamp.add_theme_constant_override("shadow_offset_x", 2)
	stamp.add_theme_constant_override("shadow_offset_y", 2)
	_photo_ui.add_child(stamp)
	stamp.set_anchors_and_offsets_preset(PRESET_TOP_LEFT, PRESET_MODE_MINSIZE, 24)

	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	_photo_ui.add_child(bottom)
	bottom.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = GROW_DIRECTION_BEGIN
	bottom.offset_left = 16
	bottom.offset_right = -16
	bottom.offset_bottom = -16
	_photo_hint = UiKit.label("拖曳、縮放、旋轉調整角度後按「儲存照片」", 22)
	_photo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_photo_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_photo_hint.add_theme_color_override("font_color", Color("36506b"))
	bottom.add_child(_photo_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)
	for item in [["旋轉", func(): view.rotation_step += 1], ["儲存照片", _save_photo],
			["返回", set_photo_mode.bind(false)]]:
		var b := UiKit.button(item[0], item[1])
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		row.add_child(b)
	_photo_buttons = bottom


func set_photo_mode(on: bool) -> void:
	for c in _normal_ui:
		c.visible = not on
	_photo_ui.visible = on
	view.photo_mode = on
	(_photo_ui.get_node("Stamp") as Label).text = "空島事記　%s" % Game.today().replace("-", ".")
	photo_mode_changed.emit(on)


## 存成 PNG：先放手機的「圖片/Islog」資料夾，失敗時改存在遊戲資料夾。
func _save_photo() -> void:
	_photo_buttons.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	_photo_buttons.visible = true
	var file := "islog_%s.png" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var result := save_photo_image(image, file)
	_photo_hint.text = ("已儲存到 " + result) if result != "" else "儲存失敗，請改用手機截圖"


static func save_photo_image(image: Image, file: String) -> String:
	for dir in [OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("Islog"), "user://photos"]:
		if dir.begins_with("/Islog") or dir == "Islog":
			continue
		DirAccess.make_dir_recursive_absolute(dir)
		var path: String = dir.path_join(file)
		if image.save_png(path) == OK:
			return ProjectSettings.globalize_path(path)
	return ""


## 對話框要蓋住整個畫面，所以開在主畫面上。
func _modal_host() -> Control:
	var n: Node = self
	while n.get_parent() is Control:
		n = n.get_parent()
	return n as Control


func _change_layer(delta: int) -> void:
	view.layer += delta
	_refresh()


## 新手引導用：目前的工具與按鈕位置。
func current_tool() -> String:
	return _tool


func tool_rect(t: String) -> Rect2:
	return _tool_buttons[t].get_global_rect()


func codex_rect() -> Rect2:
	return _codex_button.get_global_rect()


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
		CUSTOM_MODE:
			if _custom_choice == "":
				_flash("先設計一個方塊")
			else:
				_place_at(view.floor_cell_at(pos), _custom_choice)
		_:
			_place_at(view.floor_cell_at(pos), _tool)


func _place_at(cell: Vector3i, type: String) -> void:
	match Game.island.place_problem(cell, type, Game.data.inventory):
		"":
			Game.place_block(cell, type)
		"occupied":
			_flash("這格已經有方塊了")
		"plant_below":
			_flash("下面種了植物，不能蓋住它")
		"no_material":
			if CustomBlocks.is_custom(type):
				_flash("這個方塊用完了，按「製作」用 1 個%s再做一個" % Materials.display_name(Materials.base_of(type)))
			else:
				_flash("%s不夠了，去完成一件小事吧" % Materials.display_name(type))


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
	_refresh_custom()
	_refresh_status()


func _refresh_status() -> void:
	var fade := Game.current_fade()
	var lines := []
	if Tutorial.is_active(Game.data.tutorial_step):
		pass
	elif fade >= 1.0:
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


## 「我的方塊」：每個設計可以選來放置，按「製作」消耗 1 個基礎素材做一個。
func _refresh_custom() -> void:
	_custom_scroll.visible = _tool == CUSTOM_MODE
	for c in _custom_row.get_children():
		c.queue_free()
	var designs: Array = Game.data.custom_designs
	if not designs.is_empty() and not CustomBlocks.has(_custom_choice):
		_custom_choice = CustomBlocks.type_of(designs[0].id)
	var group := ButtonGroup.new()
	for d in designs:
		var type := CustomBlocks.type_of(d.id)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		_custom_row.add_child(col)
		var b := UiKit.tool_button(group, Color("f4f8fb"))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size = Vector2(100, 84)
		b.button_pressed = type == _custom_choice
		b.pressed.connect(func(): _custom_choice = type)
		var preview := BlockDesigner.CubePreview.new()
		preview.top_tex = CustomBlocks.texture(type, CustomBlocks.FACE_TOP)
		preview.side_tex = CustomBlocks.texture(type, CustomBlocks.FACE_SIDE)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.set_anchors_preset(PRESET_FULL_RECT)
		preview.offset_right = -44
		b.add_child(preview)
		b.text = "×%d" % int(Game.data.inventory.get(type, 0))
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size = Vector2(130, 84)
		col.add_child(b)
		var make := UiKit.button("製作", func():
			if not Game.make_custom(d.id):
				_flash("%s不夠，沒辦法製作" % Materials.display_name(d.base)))
		make.add_theme_font_size_override("font_size", 22)
		col.add_child(make)
	var add := UiKit.button("＋ 設計", func(): BlockDesigner.open(_modal_host()))
	add.custom_minimum_size = Vector2(110, 84)
	_custom_row.add_child(add)


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