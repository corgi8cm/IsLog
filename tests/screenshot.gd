extends SceneTree
## 開發用：用示範資料啟動主畫面並截圖（不會動到正式存檔）。
##   godot --path . -s res://tests/screenshot.gd -- <輸出資料夾>

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shots"
	var game = root.get_node("Game")
	game.save_root = "user://screenshot_demo"
	game.data = GameData.new()
	game.island = IslandData.new()
	game.rng.seed = 3
	for title in ["喝一杯水", "伸展一分鐘", "整理桌面", "讀 10 頁書", "散步十分鐘"]:
		game.add_event(title)
	for i in 2:
		game.complete_event(game.data.events[i].id)
	for back in [1, 2, 3, 5, 6, 9]:
		var date := IslandData.days_ago(game.today(), back)
		for k in (back % 3) + 1:
			var ev: Dictionary = game.data.add_event(["散步十分鐘", "喝一杯水", "伸展一分鐘"][k], 0)
			game.data.complete_event(ev.id, date, 0, game.rng)
	var room: Dictionary = game.add_event("整理房間", ["收衣服", "擦桌子", "倒垃圾"])
	game.complete_subtask(room.id, room.subtasks[0].id)
	var book: Dictionary = game.add_event("讀完一本書", ["第一章", "第二章"])
	game.complete_subtask(book.id, book.subtasks[0].id)
	game.complete_subtask(book.id, book.subtasks[1].id)
	for t in Materials.TYPES:
		game.data.inventory[t] += 40
	for x in 10:
		for y in 10:
			if Vector2(x - 4.5, y - 4.5).length() < 4.6:
				game.place_block(Vector3i(x, y, 0), Materials.DIRT if (x + y) % 5 else Materials.STONE)
	for p in [Vector3i(3, 3, 1), Vector3i(4, 3, 1), Vector3i(3, 4, 1), Vector3i(3, 3, 2)]:
		game.place_block(p, Materials.STONE)
	for p in [Vector3i(6, 6, 1), Vector3i(6, 5, 1), Vector3i(5, 6, 1)]:
		game.place_block(p, Materials.WATER)
	game.place_block(Vector3i(7, 4, 1), Materials.SAND)
	game.place_block(Vector3i(8, 4, 0), Materials.SAND)
	var planting := {
		Vector3i(2, 5, 0): "fruit_tree", Vector3i(4, 6, 0): "flower", Vector3i(5, 3, 0): "shrub",
		Vector3i(2, 4, 0): "mushroom", Vector3i(6, 6, 1): "water_lily", Vector3i(5, 6, 1): "reed",
		Vector3i(3, 3, 2): "succulent", Vector3i(4, 3, 1): "moss", Vector3i(7, 4, 1): "cactus",
		Vector3i(8, 4, 0): "palm", Vector3i(3, 4, 1): "alpine_flower", Vector3i(6, 5, 1): "waterweed",
	}
	for p in planting:
		game.data.plants[planting[p]] += 1
		game.plant(p, planting[p])
	for i in 4:
		game.island.try_visit(0.0, game.now(), game.rng)

	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.get("_pages")[0].call("_toggle_subtasks", room.id)
	await _shot(out_dir, "events.png")
	main.call("_show_page", 1)
	await _shot(out_dir, "island.png")
	var page = main.get("_pages")[1]
	page.view.layer = 1
	page.view.rotation_step = 1
	await _shot(out_dir, "island_rotated_layer2.png")
	page.view.layer = 0
	page.view.rotation_step = 0
	page.view.zoom = 1.6
	await _shot(out_dir, "island_zoom.png")
	# 模擬 4 天沒照顧：褪色一半
	game.island.last_care_date = IslandData.days_ago(game.today(), 4)
	game.tick()
	page.view.zoom = 1.0
	await _shot(out_dir, "island_faded.png")
	main.call("_show_page", 2)
	await _shot(out_dir, "review.png")
	var review = main.get("_pages")[2]
	review.call("_set_mode", 1)
	await _shot(out_dir, "review_timeline.png")
	_remove_dir("user://screenshot_demo")
	quit()


func _shot(dir: String, file: String) -> void:
	for i in 6:
		await process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(file))
	print("saved ", dir.path_join(file))


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_dir(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)
