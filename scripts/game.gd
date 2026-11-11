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

func add_event(title: String) -> Dictionary:
	var ev := data.add_event(title, now())
	if not ev.is_empty():
		_commit()
	return ev


## 完成事件：給素材與植物、照顧島嶼（恢復顏色），並讓一隻動物來訪。
func complete_event(id: int) -> Dictionary:
	var result := data.complete_event(id, today(), now(), rng)
	if not result.ok:
		return result
	island.care(today())
	var fade := current_fade()
	island.update_animals(fade, now())
	var visitor := island.try_visit(fade, now(), rng)
	result.visitor = visitor
	data.find_event(id).visitor = visitor
	_commit()
	return result


func delete_event(id: int) -> bool:
	var ok := data.delete_event(id)
	if ok:
		_commit()
	return ok


# --- 島嶼 ---------------------------------------------------------------

func place_block(p: Vector3i, type: String) -> bool:
	var ok := island.place(p, type, data.inventory)
	if ok:
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
	var d := _read_json(_save_path())
	data = GameData.from_dict(d) if not d.is_empty() else GameData.new()
	var i := _read_json(_island_path(0))
	island = IslandData.from_dict(i) if not i.is_empty() else IslandData.new()
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
