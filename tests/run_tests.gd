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


# --- 植物 ---------------------------------------------------------------

func test_first_completion_of_day_always_drops_plant() -> void:
	for seed_value in 30:
		var g := GameData.new()
		var ev := g.add_event("a", 0)
		var r := g.complete_event(ev.id, "2026-11-12", 0, _rng(seed_value))
		check(r.plant != "" and Catalog.is_plant(r.plant), "每天第一件必定掉植物（seed %d）" % seed_value)
		check(g.plants[r.plant] == 1, "植物應進背包")


func test_plant_drop_rate_about_30_percent() -> void:
	var g := GameData.new()
	var rng := _rng(99)
	var drops := 0
	var total := 0
	for day in 400:
		var date := "day-%d" % day
		for i in 3:
			var ev := g.add_event("x", 0)
			var r := g.complete_event(ev.id, date, 0, rng)
			if i > 0:
				total += 1
				if r.plant != "":
					drops += 1
	var rate := float(drops) / total
	check(rate > 0.25 and rate < 0.35, "第二件之後掉落率約 30%%（實際 %.3f）" % rate)


func test_capped_completion_drops_no_plant() -> void:
	var g := GameData.new()
	var rng := _rng(5)
	for i in GameData.DAILY_LIMIT:
		g.complete_event(g.add_event("x", 0).id, "2026-11-12", 0, rng)
	var before := g.plants.duplicate()
	for i in 20:
		var r := g.complete_event(g.add_event("y", 0).id, "2026-11-12", 0, rng)
		check(r.plant == "", "超過上限不掉植物")
	check(g.plants == before, "植物背包不變")


func test_planting_rules() -> void:
	var island := IslandData.new()
	var inv := Materials.empty_inventory()
	inv[Materials.DIRT] = 5
	inv[Materials.SAND] = 1
	var pinv := Catalog.empty_plant_inventory()
	pinv["flower"] = 2
	var a := Vector3i(1, 1, 0)
	island.place(a, Materials.DIRT, inv)
	island.place(Vector3i(2, 1, 0), Materials.SAND, inv)
	check(island.plant_problem(Vector3i(5, 5, 0), "flower", pinv) == "no_block", "沒有方塊不能種")
	check(island.plant_problem(Vector3i(2, 1, 0), "flower", pinv) == "wrong_base", "花不能種在沙上")
	check(island.plant(a, "flower", pinv), "花可以種在土上")
	check(pinv["flower"] == 1, "種植扣植物")
	check(island.plant_problem(a, "flower", pinv) == "occupied", "同一格不能種兩株")
	check(island.place_problem(a + Vector3i(0, 0, 1), Materials.DIRT, inv) == "plant_below", "不能把方塊蓋在植物上")
	var b := Vector3i(3, 3, 0)
	island.place(b, Materials.DIRT, inv)
	island.place(b + Vector3i(0, 0, 1), Materials.DIRT, inv)
	check(island.plant_problem(b, "flower", pinv) == "covered", "被蓋住的方塊不能種")
	check(island.remove_plant(a, pinv) == "flower" and pinv["flower"] == 2, "移除植物退回背包")
	island.plant(a, "flower", pinv)
	var dirt_before: int = inv[Materials.DIRT]
	check(island.remove(a, inv, pinv) == Materials.DIRT, "移除有植物的方塊")
	check(inv[Materials.DIRT] == dirt_before + 1 and pinv["flower"] == 2, "方塊與植物都退回")
	check(not island.plants.has(a), "植物跟著移除")


# --- 褪色與恢復 -----------------------------------------------------------

func test_fade_schedule() -> void:
	var island := IslandData.new()
	check(island.fade_on("2026-11-20") == 0.0, "從沒照顧過的新島不褪色")
	island.care("2026-11-10")
	# 11/10 照顧；11/11 起整天沒完成。漏 2 天（11/13）開始褪色，漏 5 天（11/16）全灰。
	var expected := {"2026-11-10": 0.0, "2026-11-11": 0.0, "2026-11-12": 0.0,
		"2026-11-13": 0.25, "2026-11-14": 0.5, "2026-11-15": 0.75, "2026-11-16": 1.0,
		"2026-11-30": 1.0}
	for d in expected:
		check(is_equal_approx(island.fade_on(d), expected[d]),
			"%s 褪色應為 %.2f（實際 %.2f）" % [d, expected[d], island.fade_on(d)])
	check(IslandData.days_between("2026-12-31", "2027-01-01") == 1, "跨年天數")
	check(IslandData.days_between("2026-03-07", "2026-03-09") == 2, "一般天數")


func test_recovery_takes_three_days_and_pauses() -> void:
	var island := IslandData.new()
	island.care("2026-11-01")
	check(island.fade_on("2026-11-10") == 1.0, "全灰")
	island.care("2026-11-10")
	check(is_equal_approx(island.fade_on("2026-11-10"), 2.0 / 3.0), "第 1 天恢復 1/3")
	island.care("2026-11-10")
	check(is_equal_approx(island.fade_on("2026-11-10"), 2.0 / 3.0), "同一天只算一次")
	# 中斷一天：進度暫停，不增加褪色也不歸零
	island.care("2026-11-12")
	check(is_equal_approx(island.fade_on("2026-11-12"), 1.0 / 3.0), "隔一天再照顧，繼續恢復")
	island.care("2026-11-13")
	check(island.fade_on("2026-11-13") == 0.0, "第 3 天完全恢復")


func test_fade_reduces_animal_capacity() -> void:
	check(IslandData.animal_capacity(0.0) == 8, "全彩可住 8 隻（4 種各 2 隻）")
	check(IslandData.animal_capacity(0.5) == 4, "褪一半剩 4 隻")
	check(IslandData.animal_capacity(1.0) == 0, "全灰全部離開")


# --- 動物 ---------------------------------------------------------------

func _island_with(types: Dictionary) -> IslandData:
	var island := IslandData.new()
	var inv := {Materials.DIRT: 99, Materials.WATER: 99, Materials.STONE: 99, Materials.SAND: 99}
	for p in types:
		island.place(p, types[p], inv)
	return island


func test_animals_need_habitat_and_come_one_at_a_time() -> void:
	var island := IslandData.new()
	check(island.try_visit(0.0, 0, _rng()) == "", "空島沒有動物會來")
	island = _island_with({Vector3i(0, 0, 0): Materials.DIRT, Vector3i(1, 0, 0): Materials.DIRT,
		Vector3i(5, 5, 0): Materials.WATER})
	var first := island.try_visit(0.0, 0, _rng())
	check(first == "sheep" or first == "fish", "有土或水才有綿羊或小魚")
	check(island.animals.size() == 1, "一次只來一隻")
	for i in 3:
		check(island.try_visit(0.0, 0, _rng(i)) != "", "第 %d 次也有動物來" % (i + 2))
	check(island.species_count("sheep") == 2 and island.species_count("fish") == 2, "同一種最多 2 隻")
	check(island.try_visit(0.0, 0, _rng()) == "", "沒有石頭和沙，蜥蜴和寄居蟹不會來")
	var sheep := island.animals.filter(func(a): return a.species == "sheep")
	check(sheep[0].pos != sheep[1].pos, "有空位時兩隻綿羊不站同一格")
	for a in island.animals:
		check(island.is_habitat(a.species, a.pos), "動物站在自己的棲地上")


func test_animal_capacity_limits_visits_and_removes_extra() -> void:
	var island := _island_with({Vector3i(0, 0, 0): Materials.DIRT, Vector3i(1, 0, 0): Materials.WATER,
		Vector3i(2, 0, 0): Materials.STONE, Vector3i(3, 0, 0): Materials.SAND})
	for i in 10:
		island.try_visit(0.0, 0, _rng(i))
	check(island.animals.size() == 8, "四種各來兩隻")
	check(island.update_animals(0.5, 0), "褪色時有動物離開")
	check(island.animals.size() == 4, "褪一半剩 4 隻")
	check(island.try_visit(0.5, 0, _rng()) == "", "容量滿了不會再來")
	island.update_animals(1.0, 0)
	check(island.animals.is_empty(), "全灰時動物全部離開")


func test_animal_relocates_or_leaves_when_habitat_removed() -> void:
	var island := _island_with({Vector3i(0, 0, 0): Materials.DIRT, Vector3i(5, 5, 0): Materials.DIRT})
	var inv := Materials.empty_inventory()
	island.try_visit(0.0, 0, _rng())
	var sheep: Dictionary = island.animals[0]
	var start: Vector3i = sheep.pos
	island.remove(start, inv)
	island.update_animals(0.0, 100)
	check(sheep.pos != start and island.is_habitat("sheep", sheep.pos), "腳下方塊被移除，換到其他土上")
	island.remove(sheep.pos, inv)
	island.update_animals(0.0, 1000)
	check(sheep.confused_since == 1000, "沒有棲地時冒問號")
	island.update_animals(0.0, 1000 + IslandData.CONFUSED_LEAVE_SECONDS - 1)
	check(island.animals.size() == 1, "不到一天還不會離開")
	island.place(Vector3i(3, 3, 0), Materials.DIRT, {Materials.DIRT: 1})
	island.update_animals(0.0, 1000 + IslandData.CONFUSED_LEAVE_SECONDS)
	check(sheep.confused_since == 0 and sheep.pos == Vector3i(3, 3, 0), "棲地恢復後問號消失")
	island.remove(Vector3i(3, 3, 0), inv)
	island.update_animals(0.0, 5000)
	island.update_animals(0.0, 5000 + IslandData.CONFUSED_LEAVE_SECONDS)
	check(island.animals.is_empty(), "問號超過一天就離開")


func test_covering_habitat_moves_animal() -> void:
	var island := _island_with({Vector3i(0, 0, 0): Materials.SAND, Vector3i(4, 4, 0): Materials.SAND})
	island.try_visit(0.0, 0, _rng())
	var crab: Dictionary = island.animals[0]
	var under: Vector3i = crab.pos
	island.place(under + Vector3i(0, 0, 1), Materials.STONE, {Materials.STONE: 1})
	island.update_animals(0.0, 0)
	check(crab.pos != under, "方塊蓋在動物頭上時換位置")


func test_wander_stays_on_habitat_nearby() -> void:
	var types := {}
	for x in 6:
		for y in 6:
			types[Vector3i(x, y, 0)] = Materials.DIRT if x < 3 else Materials.STONE
	var island := _island_with(types)
	island.try_visit(0.0, 0, _rng(1))
	island.try_visit(0.0, 0, _rng(2))
	var rng := _rng(3)
	for step in 200:
		var before := []
		for a in island.animals:
			before.append(a.pos)
		island.wander(rng)
		for i in island.animals.size():
			var a: Dictionary = island.animals[i]
			var d: Vector3i = a.pos - before[i]
			check(island.is_habitat(a.species, a.pos), "漫步後仍在棲地上")
			check(absi(d.x) <= 1 and absi(d.y) <= 1 and absi(d.z) <= 1, "每次只走到周圍一格")


func test_island_v2_roundtrip() -> void:
	var island := _island_with({Vector3i(0, 0, 0): Materials.DIRT, Vector3i(1, 0, 0): Materials.WATER})
	var pinv := Catalog.empty_plant_inventory()
	pinv["shrub"] = 1
	island.plant(Vector3i(0, 0, 0), "shrub", pinv)
	island.try_visit(0.0, 77, _rng())
	island.care("2026-11-01")
	island.fade_base = 0.25
	var i2 := IslandData.from_dict(JSON.parse_string(JSON.stringify(island.to_dict())))
	check(i2.plants == island.plants, "植物應相同")
	check(i2.animals.size() == 1 and i2.animals[0].pos == island.animals[0].pos, "動物應相同")
	check(i2.animals[0].species == island.animals[0].species, "物種應相同")
	check(i2.last_care_date == "2026-11-01" and is_equal_approx(i2.fade_base, 0.25), "褪色狀態應保留")
	check(i2.next_animal_id == island.next_animal_id, "動物編號應保留")


func test_old_v1_island_save_still_loads() -> void:
	var i := IslandData.from_dict({"version": 1, "id": 0, "blocks": [[1, 2, 0, "dirt"]]})
	check(i.get_block(Vector3i(1, 2, 0)) == "dirt", "v0.1 存檔可讀")
	check(i.animals.is_empty() and i.plants.is_empty() and i.fade_base == 0.0, "新欄位用預設值")


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
