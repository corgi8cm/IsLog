class_name CloudSave
extends RefCounted
## 雲端備份的存檔包：把玩家存檔與所有島嶼打包成一份，並判斷要上傳、下載還是讓玩家選擇。
## 與實際的雲端服務無關（Play 遊戲服務或測試用的假雲端都用同一份格式）。

const FORMAT := 1

## 同步判斷結果
const NONE := "none"          ## 兩邊一樣，不用動
const UPLOAD := "upload"      ## 只有本機有新進度
const DOWNLOAD := "download"  ## 只有雲端有新進度
const CONFLICT := "conflict"  ## 兩邊都有新進度，讓玩家選


## islands: {島嶼 id: IslandData.to_dict()}
static func make_bundle(game: Dictionary, islands: Dictionary, saved_at: int, device: String) -> Dictionary:
	var isl := {}
	for k in islands:
		isl[str(k)] = islands[k]
	return {
		"format": FORMAT,
		"saved_at": saved_at,
		"device": device,
		"summary": summarize(game, isl),
		"game": game,
		"islands": isl,
	}


## 給玩家比較用的摘要：累計完成件數、島嶼數、事件數、最後完成日期。
static func summarize(game: Dictionary, islands: Dictionary) -> Dictionary:
	var last := ""
	var events: Array = game.get("events", [])
	for e in events:
		var d: String = str(e.get("done_date", ""))
		if d > last:
			last = d
	var blocks := 0
	for k in islands:
		blocks += (islands[k].get("blocks", []) as Array).size()
	return {
		"total_completed": int(game.get("total_completed", 0)),
		"islands": islands.size(),
		"events": events.size(),
		"blocks": blocks,
		"last_done": last,
	}


## 檢查下載回來的存檔包能不能用。
static func is_valid(bundle: Dictionary) -> bool:
	if int(bundle.get("format", 0)) < 1 or int(bundle.get("format", 0)) > FORMAT:
		return false
	if typeof(bundle.get("game")) != TYPE_DICTIONARY or typeof(bundle.get("islands")) != TYPE_DICTIONARY:
		return false
	var game: Dictionary = bundle.game
	var current := str(int(game.get("current_island", 0)))
	return (bundle.islands as Dictionary).has(current)


## remote_saved_at：雲端存檔包的時間，沒有雲端存檔時為 0。
## last_synced：本機上次上傳或下載時，雲端存檔包的時間；從沒同步過為 0。
## local_changed：上次同步後本機有沒有新進度。
## local_fresh：本機是不是剛開始玩的新存檔（換新手機時）。
static func decide(remote_saved_at: int, last_synced: int, local_changed: bool, local_fresh: bool) -> String:
	if remote_saved_at == 0:
		return UPLOAD if local_changed or last_synced == 0 else NONE
	if remote_saved_at == last_synced:
		return UPLOAD if local_changed else NONE
	# 雲端被別的裝置更新過
	if last_synced == 0:
		return DOWNLOAD if local_fresh else CONFLICT
	return CONFLICT if local_changed else DOWNLOAD


## 「累計完成 120 件 · 2 座島 · 最後完成 2026-11-12」
static func summary_text(summary: Dictionary) -> String:
	var parts := ["累計完成 %d 件" % int(summary.get("total_completed", 0)),
		"%d 座島" % int(summary.get("islands", 1))]
	var last: String = str(summary.get("last_done", ""))
	if last != "":
		parts.append("最後完成 " + last)
	return " · ".join(parts)


## 「2026-11-12 21:05」（本地時間）
static func time_text(unix: int) -> String:
	if unix <= 0:
		return "—"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]
