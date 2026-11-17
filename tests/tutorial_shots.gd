extends SceneTree
## 開發用：新手引導各步的截圖（不會動到正式存檔）。
##   godot --path . -s res://tests/tutorial_shots.gd -- <輸出資料夾>

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shots"
	var game = root.get_node("Game")
	game.save_root = "user://tutorial_demo"
	game.data = GameData.new()
	game.island = IslandData.new()
	game.island.place(Vector3i(4, 4, 0), Materials.DIRT, {Materials.DIRT: 1})
	game.clock_override = 12 * 60
	game.data.notify.asked = true
	game.data.tutorial_step = Tutorial.Step.ADD_EVENT
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot(out_dir, "tutorial_add.png")
	game.add_event("喝一杯水")
	game.data.tutorial_step = Tutorial.Step.COMPLETE
	await _shot(out_dir, "tutorial_complete.png")
	game.data.inventory[Materials.DIRT] += 1
	game.data.tutorial_step = Tutorial.Step.PLACE
	main.call("_show_page", 1)
	await _shot(out_dir, "tutorial_place_a.png")
	main.get("_pages")[1].call("_select_tool", Materials.DIRT)
	await _shot(out_dir, "tutorial_place_b.png")
	quit()


func _shot(dir: String, file: String) -> void:
	for i in 8:
		await process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(file))
	print("saved ", dir.path_join(file))
