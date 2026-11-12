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
	# 腳本載入失敗時 await 會卡住，60 秒後強制結束並視為失敗
	create_timer(60.0).timeout.connect(func():
		printerr("FAIL UI 測試逾時")
		quit(1))
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

	# 拍照模式：隱藏介面與格線，返回後恢復（不測儲存，避免寫進電腦的圖片資料夾）
	main.call("_show_page", 1)
	page.call("set_photo_mode", true)
	await _frames()
	var top_bar: Control = main.get_child(1).get_child(0)
	check(not top_bar.visible and view.photo_mode, "拍照模式隱藏上方列並關閉格線")
	check(not (_find(page, func(n): return n is Button and n.text == "移除") as Control).is_visible_in_tree(), "工具列隱藏")
	page.call("set_photo_mode", false)
	await _frames()
	check(top_bar.visible and not view.photo_mode, "返回後恢復")
	main.call("_show_page", 0)

	# 交換素材視窗
	for t in Materials.TYPES:
		game.data.inventory[t] = 0
	game.data.inventory[Materials.DIRT] = 4
	main.call("open_exchange", Materials.DIRT)
	await _frames()
	var go: Button = _find(main, func(n): return n is Button and n.text == "交換")
	check(go != null and not go.disabled, "交換按鈕可按")
	go.pressed.emit()
	go.pressed.emit()
	await _frames()
	check(game.data.inventory[Materials.DIRT] == 0 and game.data.inventory[Materials.WATER] == 2, "4 土換成 2 水")
	check(go.disabled, "素材不夠時按鈕停用")
	(_find(main, func(n): return n is Button and n.text == "關閉") as Button).pressed.emit()
	await _frames()
	check(_find(main, func(n): return n is Button and n.text == "交換") == null, "關閉視窗")

	# 我的島：滿 100 件建立新島，再把第一座拿回來
	main.call("_show_page", 1)
	game.data.total_completed = 100
	var first_blocks: int = game.island.block_count()
	_button(page, "我的島").pressed.emit()
	await _frames()
	check(_find(main, func(n): return n is Label and n.text == "第 1 座島") != null, "列出第一座島")
	_button(main, "建立新島（目前的島會收起來）").pressed.emit()
	await _frames()
	check(game.island.id == 1 and game.island.block_count() == 0, "建立並切到新島")
	_button(page, "我的島").pressed.emit()
	await _frames()
	_button(main, "拿出來").pressed.emit()
	await _frames()
	check(game.island.id == 0 and game.island.block_count() == first_blocks, "拿回第一座島")
	main.call("_show_page", 0)

	# 自訂方塊：設計 → 儲存 → 製作 → 放置
	main.call("_show_page", 1)
	game.data.inventory[Materials.STONE] = 2
	page.call("_select_tool", "custom")
	await _frames()
	_button(page, "＋ 設計").pressed.emit()
	await _frames()
	_button(main, "石").pressed.emit()
	await _frames()
	var canvas: Control = _find(main, func(n): return n.get_script() != null and n.has_signal("painted"))
	var corner: Vector2 = canvas.get_global_rect().position + Vector2(4, 4)
	_mouse_button(corner, true)
	await _frames(1)
	var mm := InputEventMouseMotion.new()
	mm.position = corner + Vector2(canvas.size.x - 8, 0)
	mm.global_position = mm.position
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mm)
	await _frames(1)
	_mouse_button(mm.position, false)
	await _frames()
	var painted_row := 0
	for x in 8:
		if canvas.pixels[x].is_equal_approx(Color("7cc35a")):
			painted_row += 1
	check(painted_row >= 6, "拖曳連續上色（%d/8 格）" % painted_row)
	_button(main, "儲存到「我的方塊」").pressed.emit()
	await _frames()
	check(game.data.custom_designs.size() == 1 and game.data.custom_designs[0].base == Materials.STONE, "存成石頭類的自訂方塊")
	var ctype := CustomBlocks.type_of(game.data.custom_designs[0].id)
	_button(page, "製作").pressed.emit()
	await _frames()
	check(game.data.inventory[ctype] == 1 and game.data.inventory[Materials.STONE] == 1, "製作消耗 1 個石頭")
	# 選畫面上方的格子，避免被下方的工具列擋住
	var spot := Vector3i(6, 1, 0)
	view.layer = 0
	_close_modals(main)
	await _frames()
	await _click(_cell_screen_pos(view, spot))
	check(game.island.get_block(spot) == ctype, "點格子放置自訂方塊")
	page.call("_select_tool", Materials.DIRT)
	main.call("_show_page", 0)

	await _cloud_flow(game, main)
	await _tutorial_walkthrough(game, main)

	_cleanup("user://ui_smoke")
	quit(1 if _failures > 0 else 0)


## 關掉對話框（例如「快滿 100 件」的小提示）。
func _close_modals(main: Control) -> void:
	for c in main.get_children():
		if c is ColorRect and c.get_child_count() > 0 and c.get_child(0) is CenterContainer:
			c.queue_free()


func _button(node: Node, text: String) -> Button:
	return _find(node, func(n): return n is Button and n.text == text and n.is_visible_in_tree()) as Button


## 帳號綁定：第一次備份、兩邊都有進度時選雲端、只有雲端有進度時自動還原。
func _cloud_flow(game, main: Control) -> void:
	_close_modals(main)
	var backend := FakeCloudBackend.new()
	backend.folder = "user://ui_smoke/cloud"
	game.setup_cloud(backend)
	var cloud = game.cloud
	main.call("_show_page", 2)
	await _frames()
	_button(main, "帳號與備份").pressed.emit()
	await _frames()
	check(_button(main, "綁定帳號") != null, "顯示綁定按鈕")
	_button(main, "綁定帳號").pressed.emit()
	await _frames(8)
	check(cloud.linked and not cloud.local_changed, "綁定後第一次備份完成")
	check(FileAccess.file_exists("user://ui_smoke/cloud/cloud.json"), "雲端有存檔")
	check(_button(main, "立即備份") != null, "畫面改成已綁定")

	# 模擬另一台手機更新了雲端，這台也有新進度
	var path := "user://ui_smoke/cloud/cloud.json"
	var remote: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	remote.saved_at = int(remote.saved_at) + 100
	remote.game.total_completed = 999
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(remote))
	f.close()
	var ev: Dictionary = game.add_event("雲端測試")
	game.complete_event(ev.id)
	check(cloud.local_changed, "本機有新進度")
	_button(main, "立即備份").pressed.emit()
	await _frames(8)
	var keep_cloud := _find(main, func(n): return n is Button and n.text.begins_with("保留雲端") and n.is_visible_in_tree()) as Button
	check(keep_cloud != null, "兩邊都有進度時讓玩家選")
	if keep_cloud:
		keep_cloud.pressed.emit()
		await _frames(4)
	check(game.data.total_completed == 999, "選雲端後還原雲端進度")
	check(not cloud.local_changed and cloud.last_synced == int(remote.saved_at), "還原後同步紀錄更新")
	check(FileAccess.file_exists("user://ui_smoke/backup/save.json"), "還原前留了備份")

	# 只有雲端有新進度：直接還原
	remote.saved_at = int(remote.saved_at) + 100
	remote.game.total_completed = 1234
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(remote))
	f.close()
	cloud.sync()
	await _frames(8)
	check(game.data.total_completed == 1234, "只有雲端有新進度時自動還原")
	cloud.unlink()
	check(not cloud.linked, "解除綁定")
	_close_modals(main)
	await _frames()
	main.call("_show_page", 0)


## 新手引導從頭走到尾：照著亮起來的地方點。
func _tutorial_walkthrough(game, main: Control) -> void:
	_close_modals(main)
	game.new_game()
	game.changed.emit()
	await _frames(4)
	var guide: Control = main.get("_guide")
	var events_page = main.get("_pages")[0]
	var island_page = main.get("_pages")[1]
	check(guide.visible and island_page.visible and game.current_fade() == 1.0, "引導開始：柯基出現，島嶼頁，灰色的島")
	check(game.island.block_count() == 1, "天空中一塊方塊")
	_button(guide, "開始").pressed.emit()
	await _frames(4)
	check(events_page.visible, "進到事件頁")
	# 亮起來以外的地方按不到（例如下方的「回顧」分頁）
	await _click(_button(main, "回顧").get_global_rect().get_center())
	check(events_page.visible, "引導中按不到亮起來以外的地方")
	_button(guide, "喝一杯水").pressed.emit()
	await _frames(4)
	check(game.data.tutorial_step == Tutorial.Step.COMPLETE, "加入建議的事件")
	await _click(_guide_target(guide))
	check(game.data.inventory[Materials.DIRT] >= 1 and game.data.plants["flower"] == 1, "點亮起來的「完成」，保證拿到土和花")
	await _frames(4)
	check(island_page.visible, "回到島嶼頁放方塊")
	await _click(_guide_target(guide))
	check(game.island.get_block(Tutorial.PLACE_CELL) == Materials.DIRT, "點亮起來的格子放下方塊")
	check(game.current_fade() == 0.0, "島長出顏色")
	await _frames(4)
	await _click(_guide_target(guide))
	check(island_page.current_tool() == island_page.PLANT_MODE, "點亮起來的「植物」")
	await _frames(4)
	await _click(_guide_target(guide))
	check(game.island.plants.size() == 1, "點亮起來的方塊種下花")
	await _frames(4)
	check(game.data.tutorial_step == Tutorial.Step.VISIT and events_page.visible, "再完成一件")
	_button(guide, "伸展一分鐘").pressed.emit()
	await _frames(4)
	await _click(_guide_target(guide))
	await _frames(4)
	check(game.island.animals.size() == 1 and game.island.animals[0].species == "sheep", "綿羊來訪")
	check(island_page.visible, "回到島嶼頁看綿羊")
	await _click(_guide_target(guide))
	await _frames(4)
	check(_button(main, "關閉") != null, "點亮起來的「圖鑑」打開圖鑑")
	_close_modals(main)
	await _frames(4)
	check(game.data.tutorial_step == Tutorial.Step.OUTRO and island_page.view.zoom < 1.0, "鏡頭拉遠")
	_button(guide, "開始我的空島").pressed.emit()
	await _frames()
	check(game.data.tutorial_step == Tutorial.Step.DONE and not guide.visible, "引導完成，柯基離開")

	game.new_game()
	game.changed.emit()
	await _frames(4)
	_button(guide, "略過教學").pressed.emit()
	await _frames()
	check(game.data.tutorial_step == Tutorial.Step.DONE and game.current_fade() == 0.0, "略過教學，島恢復顏色")


func _guide_target(guide: Control) -> Vector2:
	var r: Rect2 = guide.get("_target")
	return r.get_center()


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
