extends SceneTree
## 核心邏輯測試。執行：
##   godot --headless --path . -s res://tests/run_tests.gd

var _failures := 0
var _checks := 0
var _current := ""


func _init() -> void:
	for m in get_method_list():
		var name: String = m.name
		if name.begins_with("test_"):
			_current = name
			call(name)
	print("\n%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL [%s] %s" % [_current, msg])


func _rng(seed_value: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


# --- 事件與素材 -----------------------------------------------------------

func test_add_event_trims_and_rejects_empty() -> void:
	var g := GameData.new()
	check(g.add_event("   ", 0).is_empty(), "空白標題不應建立事件")
	var ev := g.add_event("  喝一杯水 ", 100)
	check(ev.title == "喝一杯水", "標題應去除前後空白")
	check(g.pending_events().size() == 1, "應有一件待完成")


func test_complete_gives_three_materials() -> void:
	var g := GameData.new()
	var ev := g.add_event("伸展", 0)
	var r := g.complete_event(ev.id, "2026-11-11", 10, _rng())
	check(r.ok, "應完成成功")
	check(r.rewards.size() == 3, "應得到 3 個素材")
	var total := 0
	for t in Materials.TYPES:
		total += g.inventory[t]
	check(total == 3, "背包總數應為 3")
	check(g.total_completed == 1, "累計完成數應為 1")
	check(not g.complete_event(ev.id, "2026-11-11", 11, _rng()).ok, "不可重複完成")


func test_daily_limit_and_reset() -> void:
	var g := GameData.new()
	var rng := _rng()
	for i in 12:
		var ev := g.add_event("事件 %d" % i, 0)
		var r := g.complete_event(ev.id, "2026-11-11", 0, rng)
		if i < GameData.DAILY_LIMIT:
			check(not r.capped and r.rewards.size() == 3, "第 %d 件應給素材" % (i + 1))
		else:
			check(r.capped and r.rewards.is_empty(), "第 %d 件不應給素材" % (i + 1))
	check(g.rewards_left_on("2026-11-11") == 0, "今日剩餘應為 0")
	check(g.rewards_left_on("2026-11-12") == GameData.DAILY_LIMIT, "隔天應重置")
	var ev2 := g.add_event("隔天", 0)
	check(not g.complete_event(ev2.id, "2026-11-12", 0, rng).capped, "隔天應再給素材")
	check(g.total_completed == 13, "累計完成數應為 13")


func test_pro_has_no_limit() -> void:
	var g := GameData.new()
	g.is_pro = true
	for i in 15:
		var ev := g.add_event("x", 0)
		check(not g.complete_event(ev.id, "2026-11-11", 0, _rng(i)).capped, "Pro 不應有上限")
	check(g.rewards_left_on("2026-11-11") == -1, "Pro 剩餘應為 -1")


func test_delete_event() -> void:
	var g := GameData.new()
	var a := g.add_event("a", 0)
	g.add_event("b", 0)
	check(g.delete_event(a.id), "應刪除成功")
	check(not g.delete_event(a.id), "重複刪除應失敗")
	check(g.events.size() == 1, "應剩一件")


func test_game_data_roundtrip_through_json() -> void:
	var g := GameData.new()
	var ev := g.add_event("整理桌面", 5)
	g.add_event("散步", 6)
	g.complete_event(ev.id, "2026-11-11", 7, _rng())
	var text := JSON.stringify(g.to_dict())
	var g2 := GameData.from_dict(JSON.parse_string(text))
	check(g2.inventory == g.inventory, "背包應相同")
	check(g2.events.size() == 2, "事件數應相同")
	check(g2.events[0].done_date == "2026-11-11", "完成日期應保留")
	check(typeof(g2.events[0].id) == TYPE_INT, "id 應轉回整數")
	check(g2.next_id == g.next_id, "next_id 應相同")
	check(g2.completions_on("2026-11-11") == 1, "今日計數應保留")


# --- 島嶼 ---------------------------------------------------------------

func test_place_and_remove_refunds() -> void:
	var island := IslandData.new()
	var inv := Materials.empty_inventory()
	inv[Materials.DIRT] = 1
	var p := Vector3i(1, 2, 0)
	check(island.place(p, Materials.DIRT, inv), "應放置成功")
	check(inv[Materials.DIRT] == 0, "應扣素材")
	check(not island.place(Vector3i(2, 2, 0), Materials.DIRT, inv), "素材不足不應放置")
	inv[Materials.DIRT] = 1
	check(not island.place(p, Materials.DIRT, inv), "同一格不可重複放置")
	check(island.remove(p, inv) == Materials.DIRT, "應移除土")
	check(inv[Materials.DIRT] == 2, "移除應退回素材")
	check(island.remove(p, inv) == "", "空格移除應回傳空字串")


func test_bounds() -> void:
	var island := IslandData.new()
	var inv := Materials.empty_inventory()
	inv[Materials.STONE] = 5
	for p in [Vector3i(-1, 0, 0), Vector3i(10, 0, 0), Vector3i(0, 0, 10), Vector3i(0, -1, 0)]:
		check(not island.place(p, Materials.STONE, inv), "超出範圍不應放置 %s" % p)
	check(island.place(Vector3i(9, 9, 9), Materials.STONE, inv), "角落應可放置")


func test_island_roundtrip() -> void:
	var island := IslandData.new()
	var inv := {Materials.DIRT: 2, Materials.WATER: 1, Materials.STONE: 0, Materials.SAND: 0}
	island.place(Vector3i(0, 0, 0), Materials.DIRT, inv)
	island.place(Vector3i(3, 4, 5), Materials.WATER, inv)
	var i2 := IslandData.from_dict(JSON.parse_string(JSON.stringify(island.to_dict())))
	check(i2.blocks == island.blocks, "方塊應相同")


# --- 等角座標 -------------------------------------------------------------

func test_rotation_inverse() -> void:
	for step in 4:
		for x in IslandData.SIZE:
			for y in IslandData.SIZE:
				var c := Vector2i(x, y)
				var r := Iso.rotate_cell(c, step)
				check(r.x >= 0 and r.y >= 0 and r.x < 10 and r.y < 10, "旋轉後應在範圍內")
				check(Iso.unrotate_cell(r, step) == c, "旋轉 %d 應可還原 %s" % [step, c])
	check(Iso.rotate_cell(Vector2i(0, 0), 1) == Vector2i(9, 0), "旋轉一次的方向")
	check(Iso.rotate_cell(Vector2i(2, 3), 4) == Vector2i(2, 3), "旋轉四次應回原位")


func test_pick_floor_roundtrip() -> void:
	for step in 4:
		for z in [0, 4, 9]:
			for x in IslandData.SIZE:
				for y in IslandData.SIZE:
					var rc := Iso.rotate_cell(Vector2i(x, y), step)
					var center := Iso.to_screen(rc.x + 0.5, rc.y + 0.5, z)
					check(Iso.pick_floor(center, z, step) == Vector2i(x, y),
						"點選格子中心應得到 (%d,%d,%d) step %d" % [x, y, z, step])


func test_cube_outline_contains_floor_center() -> void:
	var rc := Vector2i(3, 4)
	var outline := Iso.cube_outline(rc, 2)
	check(Geometry2D.is_point_in_polygon(Iso.to_screen(3.5, 4.5, 2.5), outline), "方塊中心應在外框內")
	check(not Geometry2D.is_point_in_polygon(Iso.to_screen(6, 6, 2), outline), "遠處不應在外框內")


func test_draw_order_back_to_front() -> void:
	check(Iso.draw_key(Vector2i(0, 0), 9) < Iso.draw_key(Vector2i(1, 0), 0), "後方高處應先畫")
	check(Iso.draw_key(Vector2i(2, 2), 0) < Iso.draw_key(Vector2i(2, 2), 1), "同位置低的先畫")


# --- 存檔 ---------------------------------------------------------------

func test_save_and_load_files() -> void:
	var dir := "user://test_save_%d" % Time.get_ticks_usec()
	var game = load("res://scripts/game.gd").new()
	game.save_root = dir
	game.rng.seed = 7
	var ev: Dictionary = game.add_event("喝水")
	game.complete_event(ev.id)
	var t: String = game.data.events[0].rewards[0]
	check(game.place_block(Vector3i(5, 5, 0), t), "應可放置剛拿到的素材")

	var game2 = load("res://scripts/game.gd").new()
	game2.save_root = dir
	game2.load_game()
	check(game2.data.total_completed == 1, "讀檔後完成數應為 1")
	check(game2.island.get_block(Vector3i(5, 5, 0)) == t, "讀檔後方塊應存在")
	check(game2.data.inventory == game.data.inventory, "讀檔後背包應相同")

	var f := FileAccess.open(dir.path_join("save.json"), FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var game3 = load("res://scripts/game.gd").new()
	game3.save_root = dir
	game3.load_game()
	check(game3.data.events.is_empty(), "壞檔應讀成空資料")
	check(FileAccess.file_exists(dir.path_join("save.json.bad")), "壞檔應備份為 .bad")

	game.free()
	game2.free()
	game3.free()
	_remove_dir(dir)


func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_dir(path.path_join(sub))
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)
