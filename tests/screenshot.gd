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

	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot(out_dir, "events.png")
	main.call("_show_page", 1)
	await _shot(out_dir, "island.png")
	var page = main.get("_pages")[1]
	page.view.layer = 1
	page.view.rotation_step = 1
	await _shot(out_dir, "island_rotated_layer2.png")
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
