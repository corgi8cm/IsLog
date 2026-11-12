class_name CloudSync
extends Node
## 帳號綁定與雲端備份流程：登入、自動備份、換機還原、兩邊都有進度時讓玩家選。
## 存檔內容由 Game 打包與套用；這裡只管什麼時候上傳、下載，以及同步紀錄。

signal status_changed
## 兩邊都有新進度，畫面要讓玩家選要留哪一份。
signal choice_needed(local_summary: Dictionary, remote_bundle: Dictionary)

const STATE_FILE := "cloud.json"
## 遊戲進行中最多每 10 分鐘自動備份一次（離開遊戲時也會備份）。
const AUTO_BACKUP_SECONDS := 600.0

var backend: CloudBackend
## 遊戲本體（Autoload Game）；用參數傳入以免與 Game 互相依賴。
var game: Node
var root := "user://"
## 玩家有沒有綁定帳號（綁定後每次開遊戲自動登入）。
var linked := false
## 上次同步時雲端存檔包的時間。
var last_synced := 0
## 上次同步後本機有沒有新進度。
var local_changed := false
## 上次成功備份的時間（給畫面顯示）。
var last_backup_at := 0
## 目前狀態：idle / working / error
var status := "idle"
var message := ""
var _pending_remote := {}
var _suppress_changes := false


func setup(g: Node, b: CloudBackend, save_root: String) -> void:
	game = g
	backend = b
	root = save_root
	if backend.get_parent() == null:
		add_child(backend)
	_load_state()


func _ready() -> void:
	var t := Timer.new()
	t.wait_time = AUTO_BACKUP_SECONDS
	t.autostart = true
	t.timeout.connect(auto_backup)
	add_child(t)


## 開遊戲時：已綁定就安靜地登入並同步。
func start() -> void:
	if linked and backend.is_available():
		_set_status("working", "正在連線…")
		backend.sign_in(true, func(ok: bool, _name: String):
			if ok:
				sync()
			else:
				_set_status("error", "無法登入，稍後再試"))


func is_available() -> bool:
	return backend != null and backend.is_available()


func is_busy() -> bool:
	return status == "working"


## 玩家按「綁定帳號」。
func link() -> void:
	if not is_available() or is_busy():
		return
	_set_status("working", "正在登入…")
	backend.sign_in(false, func(ok: bool, _name: String):
		if not ok:
			_set_status("error", "登入失敗，請再試一次")
			return
		linked = true
		_save_state()
		sync())


## 解除綁定：之後不再自動備份，雲端存檔保留。
func unlink() -> void:
	backend.sign_out()
	linked = false
	last_synced = 0
	_save_state()
	_set_status("idle", "")


## 本機進度有變（Game 每次存檔時呼叫）。
func mark_changed() -> void:
	if _suppress_changes or local_changed:
		return
	local_changed = true
	_save_state()


## 定時或離開遊戲時：有新進度才同步。
func auto_backup() -> void:
	if linked and local_changed and backend.is_signed_in() and not is_busy():
		sync()


## 讀雲端存檔，判斷要上傳、下載還是讓玩家選。
func sync() -> void:
	if not backend.is_signed_in():
		_set_status("error", "還沒登入")
		return
	_set_status("working", "正在同步…")
	backend.load_bundle(func(ok: bool, remote: Dictionary):
		if not ok:
			_set_status("error", "讀取雲端存檔失敗，稍後再試")
			return
		if not remote.is_empty() and not CloudSave.is_valid(remote):
			# 雲端是新版遊戲的存檔或壞掉了，不要覆蓋它
			_set_status("error", "雲端存檔無法讀取，可能需要更新遊戲")
			return
		var remote_at := int(remote.get("saved_at", 0))
		var choice: String = CloudSave.decide(remote_at, last_synced, local_changed, game.is_fresh_save())
		if choice == CloudSave.UPLOAD:
			_upload(remote_at)
		elif choice == CloudSave.DOWNLOAD:
			_download(remote)
		elif choice == CloudSave.CONFLICT:
			_pending_remote = remote
			_set_status("idle", "雲端和這台手機都有新進度")
			choice_needed.emit(game.export_summary(), remote)
		else:
			_set_status("idle", "已是最新"))


## 玩家選要保留哪一份：keep_local 為 true 時用本機覆蓋雲端，否則用雲端覆蓋本機。
func resolve(keep_local: bool) -> void:
	if _pending_remote.is_empty():
		return
	var remote := _pending_remote
	_pending_remote = {}
	if keep_local:
		_set_status("working", "正在備份…")
		_upload(int(remote.get("saved_at", 0)))
	else:
		_download(remote)


func has_pending_choice() -> bool:
	return not _pending_remote.is_empty()


func _upload(remote_at: int) -> void:
	# 時間要比雲端上的新，才能判斷是誰最後寫入
	var saved_at: int = maxi(game.now(), maxi(remote_at, last_synced) + 1)
	var bundle: Dictionary = game.export_bundle(saved_at)
	backend.save_bundle(bundle, func(ok: bool):
		if not ok:
			_set_status("error", "備份失敗，稍後再試")
			return
		last_synced = saved_at
		local_changed = false
		last_backup_at = game.now()
		_save_state()
		_set_status("idle", "已備份"))


func _download(remote: Dictionary) -> void:
	_suppress_changes = true
	var ok: bool = game.apply_bundle(remote)
	_suppress_changes = false
	if not ok:
		_set_status("error", "還原失敗，本機存檔沒有變動")
		return
	last_synced = int(remote.get("saved_at", 0))
	local_changed = false
	last_backup_at = last_synced
	_save_state()
	_set_status("idle", "已從雲端還原")


func _set_status(s: String, msg: String) -> void:
	status = s
	message = msg
	status_changed.emit()


func _state_path() -> String:
	return root.path_join(STATE_FILE)


func _load_state() -> void:
	var path := _state_path()
	var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
	linked = bool(d.get("linked", false))
	last_synced = int(d.get("last_synced", 0))
	local_changed = bool(d.get("local_changed", true))
	last_backup_at = int(d.get("last_backup_at", 0))


func _save_state() -> void:
	var f := FileAccess.open(_state_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"linked": linked, "last_synced": last_synced,
		"local_changed": local_changed, "last_backup_at": last_backup_at}))
	f.close()
