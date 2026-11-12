class_name FakeCloudBackend
extends CloudBackend
## 測試用的假雲端：把存檔包寫在本機資料夾，模擬登入與上傳下載。
## 電腦版與自動測試使用；手機上要接 Play 遊戲服務才是真的雲端。

var folder := "user://fake_cloud"
var fail_next := false
var _signed_in := false


func is_available() -> bool:
	return true


func service_name() -> String:
	return "測試雲端（只存在這台電腦）"


func sign_in(_silent: bool, done: Callable) -> void:
	if _take_failure():
		done.call_deferred(false, "")
		return
	_signed_in = true
	done.call_deferred(true, "測試玩家")


func is_signed_in() -> bool:
	return _signed_in


func player_name() -> String:
	return "測試玩家" if _signed_in else ""


func load_bundle(done: Callable) -> void:
	if not _signed_in or _take_failure():
		done.call_deferred(false, {})
		return
	var path := folder.path_join("cloud.json")
	if not FileAccess.file_exists(path):
		done.call_deferred(true, {})
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	done.call_deferred(typeof(parsed) == TYPE_DICTIONARY, parsed if typeof(parsed) == TYPE_DICTIONARY else {})


func save_bundle(bundle: Dictionary, done: Callable) -> void:
	if not _signed_in or _take_failure():
		done.call_deferred(false)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var f := FileAccess.open(folder.path_join("cloud.json"), FileAccess.WRITE)
	if f == null:
		done.call_deferred(false)
		return
	f.store_string(JSON.stringify(bundle))
	f.close()
	done.call_deferred(true)


func sign_out() -> void:
	_signed_in = false


func _take_failure() -> bool:
	var f := fail_next
	fail_next = false
	return f
