extends SceneTree
## 開發用：截新手引導的畫面。
##   godot --path . -s res://tests/tutorial_shot.gd -- <輸出資料夾>

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://shots"
	var game = root.get_node("Game")
	game.save_root = "user://tutorial_demo"
	game.new_game()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _shot(out_dir, "tutorial_1_intro.png")
	game.tutorial_button()
	await _shot(out_dir, "tutorial_2_add_event.png")
	var ev: Dictionary = game.add_event("喝一杯水")
	game.complete_event(ev.id)
	await _shot(out_dir, "tutorial_3_place.png")
	DirAccess.remove_absolute("user://tutorial_demo/islands/island_0.json")
	DirAccess.remove_absolute("user://tutorial_demo/islands")
	DirAccess.remove_absolute("user://tutorial_demo/save.json")
	DirAccess.remove_absolute("user://tutorial_demo")
	quit()


func _shot(dir: String, file: String) -> void:
	for i in 6:
		await process_frame
	DirAccess.make_dir_recursive_absolute(dir)
	root.get_texture().get_image().save_png(dir.path_join(file))
	print("saved ", dir.path_join(file))
