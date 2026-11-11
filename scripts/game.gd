extends Node
## 全域遊戲狀態（Autoload: Game）。負責呼叫核心邏輯、存檔與通知畫面更新。

signal changed
## 只有動物位置改變（漫步），不需要存檔與重建畫面。
signal animals_moved

const WANDER_SECONDS := 2.5
const TICK_SECONDS := 60.0

const SAVE_FILE := "save.json"
const ISLAND_DIR := "islands"

## 存檔根目錄，測試時可改成其他資料夾。
var save_root := "user://"
var data: GameData = GameData.new()
var island: IslandData = IslandData.new()
var rng := RandomNumberGenerator.new()
var _tick_state := ""
## 最近一次來訪的動物是不是第一次來（給畫面顯示「新的動物！」）。
var result_first_visit := false


func _ready() -> void:
	rng.randomize()
	load_game()
	tick()
	_add_timer(WANDER_SECONDS, wander)
	_add_timer(TICK_SECONDS, tick)


func _add_timer(seconds: float, callback: Callable) -> void:
	var t := Timer.new()
	t.wait_time = seconds
	t.autostart = true
	t.timeout.connect(callback)
	add_child(t)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		tick()


func today() -> String:
	return Time.get_date_string_from_system()


func now() -> int:
	return int(Time.get_unix_time_from_system())


# --- 事件 ---------------------------------------------------------------

func add_event(title: String, subtask_titles: Array = []) -> Dictionary:
	var ev := data.add_event(title, now(), subtask_titles)
	if not ev.is_empty():
		_tutorial("event_added")
		_commit()
	return ev


## 完成事件：給素材與植物、照顧島嶼（恢復顏色），並讓一隻動物來訪。
func complete_event(id: int) -> Dictionary:
	var result := data.complete_event(id, today(), now(), rng)
	if not result.ok:
		return result
	_tutorial_rewards(id, result)
	result.visitor = _after_completion(id)
	_tutorial("completed")
	_commit()
	return result


func exchange(from_type: String, to_type: String) -> bool:
	var ok := data.exchange(from_type, to_type)
	if ok:
		_commit()
	return ok


func add_subtask(event_id: int, title: String) -> Dictionary:
	var sub := data.add_subtask(event_id, title)
	if not sub.is_empty():
		_commit()
	return sub


func delete_subtask(event_id: int, sub_id: int) -> bool:
	var ok := data.delete_subtask(event_id, sub_id)
	if ok:
		_commit()
	return ok


## 完成子事件：子事件也算完成一件事，一樣會照顧島嶼、讓動物來訪（一次動作最多來一隻）。
func complete_subtask(event_id: int, sub_id: int) -> Dictionary:
	var result := data.complete_subtask(event_id, sub_id, today(), now(), rng)
	if not result.ok:
		return result
	var parent_done: bool = not result.parent.is_empty()
	if parent_done:
		_tutorial_rewards(event_id, result.parent)
	result.visitor = _after_completion(event_id if parent_done else -1)
	_tutorial("completed")
	_commit()
	return result


## 完成一件事之後：照顧島嶼、更新動物、讓一隻動物來訪。回傳來訪的物種。
func _after_completion(event_id: int) -> String:
	island.care(today())
	var fade := current_fade()
	island.update_animals(fade, now())
	var seen := data.seen_animals
	if data.tutorial_step == Tutorial.Step.VISIT:
		# 引導中：讓綿羊來（把其他動物都當作來過，綿羊就會優先）
		seen = {}
		for species in Catalog.animal_ids():
			if species != "sheep":
				seen[species] = true
	var visitor := ""
	# 引導期間只有「再完成一件小事」那一步會有客人
	if not Tutorial.is_active(data.tutorial_step) or data.tutorial_step == Tutorial.Step.VISIT:
		visitor = island.try_visit(fade, now(), rng, seen)
	if visitor != "":
		result_first_visit = not data.seen_animals.has(visitor)
		if result_first_visit:
			data.seen_animals[visitor] = today()
	if event_id >= 0:
		data.find_event(event_id).visitor = visitor
	return visitor


func delete_event(id: int) -> bool:
	var ok := data.delete_event(id)
	if ok:
		_commit()
	return ok


# --- 島嶼 ---------------------------------------------------------------

func place_block(p: Vector3i, type: String) -> bool:
	var ok := island.place(p, type, data.inventory)
	if ok:
		if data.tutorial_step == Tutorial.Step.PLACE:
			# 引導：放下第一個方塊，灰色的島長出顏色
			island.fade_base = 0.0
			island.last_care_date = today()
		_tutorial("placed")
		_island_changed()
	return ok


func remove_block(p: Vector3i) -> String:
	var type := island.remove(p, data.inventory, data.plants)
	if type != "":
		_island_changed()
	return type


func plant(p: Vector3i, plant_id: String) -> bool:
	var ok := island.plant(p, plant_id, data.plants)
	if ok:
		_tutorial("planted")
		_island_changed()
	return ok


func remove_plant(p: Vector3i) -> String:
	var plant_id := island.remove_plant(p, data.plants)
	if plant_id != "":
		_island_changed()
	return plant_id


func current_fade() -> float:
	return island.fade_on(today())


## 定期檢查：換日後的褪色、動物離開。
func tick() -> void:
	var state := "%s|%.3f" % [today(), current_fade()]
	if island.update_animals(current_fade(), now()):
		_commit()
	elif state != _tick_state:
		changed.emit()
	_tick_state = state


func wander() -> void:
	if island.animals.is_empty():
		return
	island.wander(rng)
	animals_moved.emit()


func _island_changed() -> void:
	island.update_animals(current_fade(), now())
	_commit()


# --- 新手引導 -------------------------------------------------------------

## 全新開始：天空中一塊灰色的土方塊，從引導第一步開始。
func new_game() -> void:
	data = GameData.new()
	data.tutorial_step = Tutorial.Step.INTRO
	island = IslandData.new()
	island.blocks[Vector3i(4, 4, 0)] = Materials.DIRT
	island.fade_base = 1.0


## 卡片上的按鈕（開始、看圖鑑、開始我的空島）。
func tutorial_button() -> void:
	if _tutorial("button"):
		_commit()


func skip_tutorial() -> void:
	data.tutorial_step = Tutorial.Step.DONE
	if island.last_care_date == "":
		island.fade_base = 0.0
	_commit()


func _tutorial(trigger: String) -> bool:
	var next := Tutorial.advance(data.tutorial_step, trigger)
	if next == data.tutorial_step:
		return false
	data.tutorial_step = next
	return true


## 引導中第一次完成事件：保證拿到土（才能放方塊）和一株花（種在土上）。
func _tutorial_rewards(event_id: int, result: Dictionary) -> void:
	if data.tutorial_step != Tutorial.Step.COMPLETE or result.rewards.is_empty():
		return
	var ev := data.find_event(event_id)
	if not result.rewards.has(Materials.DIRT):
		data.inventory[result.rewards[0]] -= 1
		data.inventory[Materials.DIRT] += 1
		result.rewards[0] = Materials.DIRT
	if result.plant != "flower":
		if result.plant != "":
			data.plants[result.plant] -= 1
		data.plants["flower"] += 1
		result.plant = "flower"
	ev.rewards = result.rewards
	ev.plant = result.plant


const TIP_TEXTS := {
	"daily_cap": "今天的 10 件素材都拿到了。之後還是可以完成事件，只是不會給素材，明天再來吧！",
	"first_fade": "島開始褪色了。整天沒完成事件超過一天，島就會慢慢變灰，動物也會離開；每天完成一件小事，顏色就會回來。",
	"near_100": "快要完成 100 件事件了！累積 100 件會解鎖一座新的島（之後的版本開放）。",
}


## 情境提示：第一次發生時顯示一次。回傳提示的代號，沒有則回傳空字串。
func pending_tip() -> String:
	if Tutorial.is_active(data.tutorial_step):
		return ""
	var conditions := {
		"daily_cap": not data.is_pro and data.completions_on(today()) >= GameData.DAILY_LIMIT,
		"first_fade": current_fade() > 0.0,
		"near_100": data.total_completed >= 90,
	}
	for key in conditions:
		if conditions[key] and not data.tips_shown.has(key):
			return key
	return ""


func dismiss_tip(key: String) -> void:
	data.tips_shown[key] = true
	save_game()


# --- 存檔 ---------------------------------------------------------------

func _commit() -> void:
	save_game()
	changed.emit()


func _save_path() -> String:
	return save_root.path_join(SAVE_FILE)


func _island_path(id: int) -> String:
	return save_root.path_join(ISLAND_DIR).path_join("island_%d.json" % id)


func save_game() -> void:
	DirAccess.make_dir_recursive_absolute(save_root.path_join(ISLAND_DIR))
	_write_json(_save_path(), data.to_dict())
	_write_json(_island_path(island.id), island.to_dict())


func load_game() -> void:
	if not FileAccess.file_exists(_save_path()) and not FileAccess.file_exists(_save_path() + ".tmp"):
		new_game()
		changed.emit()
		return
	var d := _read_json(_save_path())
	data = GameData.from_dict(d) if not d.is_empty() else GameData.new()
	var i := _read_json(_island_path(0))
	island = IslandData.from_dict(i) if not i.is_empty() else IslandData.new()
	# 舊存檔沒有圖鑑：島上已經有的動物算來過
	for a in island.animals:
		if not data.seen_animals.has(a.species):
			data.seen_animals[a.species] = today()
	changed.emit()


static func _write_json(path: String, d: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("無法寫入存檔 %s：%s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("無法更新存檔 %s：%s" % [path, error_string(err)])
		return false
	return true


static func _read_json(path: String) -> Dictionary:
	# 若上次寫入在 remove 與 rename 之間中斷，改讀暫存檔。
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".tmp"):
		path += ".tmp"
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		# 保留壞掉的檔案，避免下次存檔直接覆蓋掉。
		DirAccess.copy_absolute(path, path + ".bad")
		push_error("存檔格式錯誤：%s（已備份為 .bad）" % path)
		return {}
	return parsed
