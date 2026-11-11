extends SceneTree
## UI 冒煙測試：模擬點擊與拖曳，確認放置、移除、平移都接得上。
##   godot --headless --path . -s res://tests/ui_smoke.gd

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ", msg)
	else:
		print("ok   ", msg)


func _run() -> void:
	# headless 預設視窗只有 64×64，改成實際的直式解析度。
	root.size = Vector2i(720, 1280)
	var game = root.get_node("Game")
	game.save_root = "user://ui_smoke"
	game.data = GameData.new()
	game.island = IslandData.new()
	game.data.inventory[Materials.DIRT] = 2

	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.call("_show_page", 1)
	await _frames()
	var page = main.get("_pages")[1]
	var view: Control = page.view

	# 點選第 1 層 (2, 3) 格子中心 → 放置土
	var cell := Vector3i(2, 3, 0)
	var pos := _cell_screen_pos(view, cell)
	await _click(pos)
	check(game.island.get_block(cell) == Materials.DIRT, "點擊放置方塊")
	check(game.data.inventory[Materials.DIRT] == 1, "放置扣素材")

	# 拖曳不應放置，而是平移鏡頭
	var pan_before: Vector2 = view.pan
	await _drag(_cell_screen_pos(view, Vector3i(5, 5, 0)), Vector2(80, 40))
	check(view.pan != pan_before, "拖曳會平移鏡頭")
	check(game.island.block_count() == 1, "拖曳不會放置方塊")

	# 移除模式：點方塊的上半部（頂面）也要能選到
	page.call("_select_tool", "remove")
	var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), view.rotation_step)
	var top_face: Vector2 = view.get_global_transform() * (view.call("_origin") + Iso.to_screen(rc.x + 0.5, rc.y + 0.5, 1.0) * view.zoom)
	await _click(top_face)
	check(not game.island.has_block(cell), "點頂面移除方塊")
	check(game.data.inventory[Materials.DIRT] == 2, "移除退回素材")

	# 植物模式：點方塊頂面種花；移除模式先收回植物
	page.call("_select_tool", Materials.DIRT)
	await _click(_cell_screen_pos(view, cell))
	check(game.island.has_block(cell), "再放一次方塊")
	game.data.plants["flower"] = 1
	page.call("_select_tool", "plant")
	await _frames()
	await _click(top_face)
	check(game.island.plants.get(cell, "") == "flower", "點方塊種花")
	check(game.data.plants["flower"] == 0, "種花扣植物")
	page.call("_select_tool", "remove")
	await _click(top_face)
	check(not game.island.plants.has(cell) and game.island.has_block(cell), "移除先收回植物，方塊還在")
	check(game.data.plants["flower"] == 1, "植物退回背包")

	# 事件頁：展開子事件、新增、完成
	main.call("_show_page", 0)
	var events_page = main.get("_pages")[0]
	var ev: Dictionary = game.add_event("整理房間")
	events_page.call("_toggle_subtasks", ev.id)
	await _frames()
	for title in ["收衣服", "擦桌子"]:
		var input := _find(events_page, func(n): return n is LineEdit and n.placeholder_text == "新增子事件") as LineEdit
		input.text = title
		input.text_submitted.emit(title)
		await _frames()
	check(ev.subtasks.size() == 2, "從畫面新增兩個子事件")
	var focused := root.gui_get_focus_owner()
	check(focused is LineEdit and focused.placeholder_text == "新增子事件", "新增後輸入框保持焦點")
	check(_find(events_page, func(n): return n is Label and n.text == "整理房間（0/2）") != null, "顯示進度 0/2")
	for i in 2:
		var row: Node = _find(events_page, func(n): return n is Label and n.text == ev.subtasks[i].title).get_parent()
		var btn: Button = _find(row, func(n): return n is Button and n.text == "完成")
		btn.pressed.emit()
		await _frames()
	check(ev.done_date != "", "兩個子事件完成後母事件自動完成")
	check(_find(events_page, func(n): return n is Label and n.text.begins_with("✓ 整理房間")) != null, "出現在今天完成")

	_cleanup("user://ui_smoke")
	quit(1 if _failures > 0 else 0)


func _find(node: Node, pred: Callable) -> Node:
	for c in node.get_children():
		if c.is_queued_for_deletion():
			continue
		if pred.call(c):
			return c
		var found := _find(c, pred)
		if found != null:
			return found
	return null


func _cell_screen_pos(view: Control, cell: Vector3i) -> Vector2:
	var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), view.rotation_step)
	var local: Vector2 = view.call("_origin") + Iso.to_screen(rc.x + 0.5, rc.y + 0.5, cell.z) * view.zoom
	return view.get_global_transform() * local


func _click(pos: Vector2) -> void:
	_mouse_button(pos, true)
	await _frames(2)
	_mouse_button(pos, false)
	await _frames(2)


func _drag(from: Vector2, delta: Vector2) -> void:
	_mouse_button(from, true)
	await _frames(1)
	for i in 5:
		var mm := InputEventMouseMotion.new()
		mm.position = from + delta * (i + 1) / 5.0
		mm.global_position = mm.position
		mm.relative = delta / 5.0
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mm)
		await _frames(1)
	_mouse_button(from + delta, false)
	await _frames(2)


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	mb.global_position = pos
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(mb)


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _cleanup(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_cleanup(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)
