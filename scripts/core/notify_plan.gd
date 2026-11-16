class_name NotifyPlan
extends RefCounted
## 要排哪些手機通知（純邏輯）：事件提醒、每日小提醒、褪色預告，並避開安靜時段。
## 每次存檔後重新算一次、整批換掉，所以只需要排最近的幾天。

const KIND_EVENT := "event"
const KIND_DAILY := "daily"
const KIND_FADE := "fade"
## 沒指定時間的事件，提醒當天早上 9 點。
const DEFAULT_EVENT_TIME := 9 * 60
## 褪色預告在前一晚幾點。
const FADE_WARNING_TIME := 20 * 60
const MAX_ITEMS := 40
const TITLE := "空島事記"

## 通知設定的預設值（存在 GameData.notify）。
const DEFAULTS := {
	"events": true,
	"daily": false,
	"daily_time": 21 * 60,
	"fade": true,
	"quiet_start": 23 * 60,
	"quiet_end": 8 * 60,
	# 第一次完成事件後問過「要不要每日提醒」了沒
	"asked": false,
}


static func clean_settings(raw) -> Dictionary:
	var s := DEFAULTS.duplicate()
	if typeof(raw) != TYPE_DICTIONARY:
		return s
	for k in ["events", "daily", "fade", "asked"]:
		if raw.has(k):
			s[k] = bool(raw[k])
	for k in ["daily_time", "quiet_start", "quiet_end"]:
		if raw.has(k):
			s[k] = posmod(int(raw[k]), 1440)
	return s


## 本地日期 + 分鐘 → unix 時間。bias：時區和 UTC 差幾分鐘（台灣是 +480）。
static func to_unix(date: String, minutes: int, bias: int) -> int:
	var utc := Time.get_unix_time_from_datetime_string("%sT%02d:%02d:00" % [date, minutes / 60, minutes % 60])
	return utc - bias * 60


static func in_quiet(minutes: int, start: int, end: int) -> bool:
	if start == end:
		return false
	if start < end:
		return minutes >= start and minutes < end
	return minutes >= start or minutes < end


## 落在安靜時段的通知延到安靜時段結束。回傳 [日期, 分鐘]。
static func after_quiet(date: String, minutes: int, settings: Dictionary) -> Array:
	var start: int = settings.quiet_start
	var end: int = settings.quiet_end
	if not in_quiet(minutes, start, end):
		return [date, minutes]
	# 跨午夜的安靜時段：晚上那一段要延到隔天早上
	if start > end and minutes >= start:
		return [Schedule.add_days(date, 1), end]
	return [date, end]


## 排出通知清單：[{id, at, title, body, kind}]，依時間排序。
## island_fade_base / last_care：目前這座島的褪色起點與最後照顧日（封存的島不會褪色，不用管）。
static func build(data: GameData, settings: Dictionary, today: String, now_unix: int, bias: int,
		last_care: String, fade_now: float) -> Array:
	var out: Array = []
	# 事件提醒：玩家自己設的時間，照設定準時發（不受安靜時段影響）
	if settings.events:
		for ev in data.pending_events():
			var remind := int(ev.get("remind", -1))
			if remind < 0 or ev.get("due_date", "") == "":
				continue
			var t := int(ev.due_time) if int(ev.due_time) >= 0 else DEFAULT_EVENT_TIME
			var at := to_unix(ev.due_date, t, bias) - remind * 60
			if at <= now_unix:
				continue
			out.append({"id": 1000 + int(ev.id), "at": at, "title": TITLE,
				"body": event_text(ev.title, remind), "kind": KIND_EVENT})

	# 每日小提醒：今天還沒完成任何事才提醒；明天的先排好（明天打開遊戲時會重算）
	if settings.daily:
		for i in 2:
			var date := Schedule.add_days(today, i)
			if i == 0 and data.completions_on(today) > 0:
				continue
			var when := after_quiet(date, settings.daily_time, settings)
			var at := to_unix(when[0], when[1], bias)
			if at > now_unix:
				out.append({"id": 1 + i, "at": at, "title": TITLE,
					"body": "今天還沒做小事喔，喝一杯水也算！島在等你。", "kind": KIND_DAILY})

	# 褪色預告：島還是完整的顏色、再不照顧就會開始褪色的前一晚
	if settings.fade and last_care != "" and fade_now <= 0.0:
		var fade_day := Schedule.add_days(last_care, 3)
		var when := after_quiet(Schedule.add_days(fade_day, -1), FADE_WARNING_TIME, settings)
		var at := to_unix(when[0], when[1], bias)
		if at > now_unix:
			out.append({"id": 3, "at": at, "title": TITLE,
				"body": "明天島就要開始褪色了，完成一件小事就能保住顏色。", "kind": KIND_FADE})

	out.sort_custom(func(a, b): return a.at < b.at)
	return out.slice(0, MAX_ITEMS)


static func event_text(title: String, remind: int) -> String:
	match remind:
		0:
			return "「%s」的時間到囉！" % title
		10:
			return "再 10 分鐘要「%s」喔。" % title
		60:
			return "再 1 小時要「%s」喔。" % title
		1440:
			return "明天要「%s」，別忘了喔。" % title
	return "記得「%s」喔。" % title
