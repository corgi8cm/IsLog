class_name Schedule
extends RefCounted
## 事件的日期、時間與重複規則（純邏輯）。
##
## 事件欄位：
##   due_date  ""＝隨時都能做；"YYYY-MM-DD"＝預定那天
##   due_time  -1＝沒指定時間；0..1439＝當天第幾分鐘
##   repeat    {}＝不重複；{"kind": "daily" | "weekly" | "monthly" | "every", "days": [0..6], "every": n}
##             weekly 的 days 是星期幾（0＝星期日）；monthly 用 due_date 的日期；every 是每隔 n 天
##   remind    -1＝不提醒；其他＝提前幾分鐘提醒（v0.6.0）
##   streak    重複事件連續準時完成的次數

const DAILY := "daily"
const WEEKLY := "weekly"
const MONTHLY := "monthly"
const EVERY := "every"
const KINDS := [DAILY, WEEKLY, MONTHLY, EVERY]
const WEEKDAY_NAMES := ["日", "一", "二", "三", "四", "五", "六"]
## 提醒可以選的提前時間（分鐘）。
const REMIND_CHOICES := [0, 10, 60, 1440]

## 事件頁的分組。
const OVERDUE := "overdue"
const TODAY := "today"
const TOMORROW := "tomorrow"
const LATER := "later"


# --- 日期 ---------------------------------------------------------------

static func _unix(date: String) -> int:
	# 用中午換算，避免日光節約時間造成差一天
	return Time.get_unix_time_from_datetime_string(date + "T12:00:00")


static func add_days(date: String, n: int) -> String:
	return Time.get_date_string_from_unix_time(_unix(date) + n * 86400)


static func days_between(a: String, b: String) -> int:
	return roundi((_unix(b) - _unix(a)) / 86400.0)


## 0＝星期日。
static func weekday(date: String) -> int:
	return Time.get_datetime_dict_from_unix_time(_unix(date)).weekday


static func is_valid_date(date: String) -> bool:
	if date.length() != 10 or date[4] != "-" or date[7] != "-":
		return false
	var parts := date.split("-")
	var y := int(parts[0])
	var m := int(parts[1])
	var d := int(parts[2])
	return y > 2000 and m >= 1 and m <= 12 and d >= 1 and d <= days_in_month(y, m)


static func days_in_month(y: int, m: int) -> int:
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31


static func _ymd(date: String) -> Vector3i:
	var p := date.split("-")
	return Vector3i(int(p[0]), int(p[1]), int(p[2]))


static func _make(y: int, m: int, d: int) -> String:
	return "%04d-%02d-%02d" % [y, m, d]


# --- 重複規則 -------------------------------------------------------------

static func make_rule(kind: String, days: Array = [], every: int = 2) -> Dictionary:
	if not kind in KINDS:
		return {}
	var rule := {"kind": kind}
	if kind == WEEKLY:
		var clean: Array = []
		for d in days:
			if int(d) >= 0 and int(d) <= 6 and not clean.has(int(d)):
				clean.append(int(d))
		clean.sort()
		rule.days = clean
	if kind == EVERY:
		rule.every = clampi(every, 2, 365)
	return rule


## 讀存檔用：不合法的規則變成不重複。
static func clean_rule(raw) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or not str(raw.get("kind", "")) in KINDS:
		return {}
	return make_rule(str(raw.kind), raw.get("days", []), int(raw.get("every", 2)))


static func is_repeating(ev: Dictionary) -> bool:
	return not ev.get("repeat", {}).is_empty()


## anchor（第一次的日期）開始，這條規則在 date 這天有沒有。
static func occurs_on(rule: Dictionary, anchor: String, date: String) -> bool:
	if rule.is_empty():
		return date == anchor
	if date < anchor:
		return false
	match str(rule.kind):
		DAILY:
			return true
		EVERY:
			return days_between(anchor, date) % int(rule.every) == 0
		WEEKLY:
			var days: Array = rule.get("days", [])
			if days.is_empty():
				days = [weekday(anchor)]
			return days.has(weekday(date))
		MONTHLY:
			var a := _ymd(anchor)
			var d := _ymd(date)
			return d.z == mini(a.z, days_in_month(d.x, d.y))
	return false


## after 之後（不含 after）第一個符合規則的日期；anchor 是第一次的日期。
static func next_date(rule: Dictionary, anchor: String, after: String) -> String:
	if rule.is_empty():
		return ""
	var start := anchor if anchor > after else add_days(after, 1)
	match str(rule.kind):
		DAILY:
			return start
		EVERY:
			var n := int(rule.every)
			var k := ceili(days_between(anchor, start) / float(n))
			return add_days(anchor, maxi(k, 0) * n)
		MONTHLY:
			var a := _ymd(anchor)
			var s := _ymd(start)
			for i in 14:
				var y := s.x + (s.y - 1 + i) / 12
				var m := (s.y - 1 + i) % 12 + 1
				var candidate := _make(y, m, mini(a.z, days_in_month(y, m)))
				if candidate >= start:
					return candidate
	# WEEKLY（以及其他）：一週內一定找得到
	for i in 8:
		var d := add_days(start, i)
		if occurs_on(rule, anchor, d):
			return d
	return start


static func describe(rule: Dictionary, anchor := "") -> String:
	if rule.is_empty():
		return ""
	match str(rule.kind):
		DAILY:
			return "每天"
		EVERY:
			return "每 %d 天" % int(rule.every)
		WEEKLY:
			var days: Array = rule.get("days", [])
			if days.is_empty() and anchor != "":
				days = [weekday(anchor)]
			if days.size() == 7:
				return "每天"
			if days == [1, 2, 3, 4, 5]:
				return "平日"
			if days == [0, 6]:
				return "週末"
			return "每週" + "、".join(days.map(func(d): return WEEKDAY_NAMES[d]))
		MONTHLY:
			return "每月 %d 號" % _ymd(anchor).z if anchor != "" else "每月"
	return ""


# --- 顯示 ---------------------------------------------------------------

static func time_text(minutes: int) -> String:
	if minutes < 0:
		return ""
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## 「今天」「明天」「昨天」或「11/20（五）」。
static func date_label(date: String, today: String) -> String:
	if date == "":
		return "隨時"
	match days_between(today, date):
		0:
			return "今天"
		1:
			return "明天"
		-1:
			return "昨天"
	var d := _ymd(date)
	var t := _ymd(today)
	var text := "%d/%d" % [d.y, d.z]
	if d.x != t.x:
		text = "%d/%s" % [d.x, text]
	return "%s（%s）" % [text, WEEKDAY_NAMES[weekday(date)]]


## 事件的日期時間與重複，例如「明天 08:00 · 每天」；隨時都能做的事件回傳空字串。
static func summary(ev: Dictionary, today: String) -> String:
	var parts: Array = []
	var date: String = ev.get("due_date", "")
	if date != "":
		var head := date_label(date, today)
		if int(ev.get("due_time", -1)) >= 0:
			head += " " + time_text(int(ev.due_time))
		parts.append(head)
	var rule: Dictionary = ev.get("repeat", {})
	if not rule.is_empty():
		parts.append(describe(rule, date))
	return " · ".join(parts)


static func remind_text(minutes_before: int) -> String:
	match minutes_before:
		-1:
			return "不提醒"
		0:
			return "準時提醒"
		1440:
			return "前一天提醒"
	if minutes_before % 60 == 0:
		return "提前 %d 小時" % (minutes_before / 60)
	return "提前 %d 分鐘" % minutes_before


## 事件頁的分組：之前沒做完、今天（含隨時）、明天、之後。
static func group(ev: Dictionary, today: String) -> String:
	var date: String = ev.get("due_date", "")
	if date == "" or date == today:
		return TODAY
	if date < today:
		return OVERDUE
	if date == add_days(today, 1):
		return TOMORROW
	return LATER


## 排序鍵：日期 → 有時間的在前、依時間 → 建立順序。
static func sort_key(ev: Dictionary) -> String:
	var date: String = ev.get("due_date", "")
	var t := int(ev.get("due_time", -1))
	return "%s|%04d|%08d" % [date if date != "" else "0000-00-00", t if t >= 0 else 9999, int(ev.get("id", 0))]
