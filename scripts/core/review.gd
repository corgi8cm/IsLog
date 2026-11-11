class_name Review
extends RefCounted
## 事件回顧：從玩家資料整理出每天完成了什麼、連續天數與常做的事。純邏輯。


## 某一天完成的項目。每項：{kind: "event"|"subtask", event, sub, title, rewards, plant, visitor}
## 子事件只列出「自己打勾、而且母事件不是同一天完成」的那些（同一天完成的會顯示在母事件底下）。
static func entries_on(data: GameData, date: String) -> Array:
	var out := []
	for ev in data.events:
		if ev.done_date == date:
			out.append({"kind": "event", "event": ev, "sub": {}, "title": ev.title,
				"rewards": ev.rewards, "plant": ev.plant, "visitor": ev.visitor, "at": ev.done_at})
		for sub in ev.subtasks:
			if sub.done_date == date and sub.self_done and ev.done_date != date:
				out.append({"kind": "subtask", "event": ev, "sub": sub, "title": sub.title,
					"rewards": sub.rewards, "plant": "", "visitor": "", "at": sub.done_at})
	out.sort_custom(func(a, b): return a.at > b.at)
	return out


## 每天完成的件數（一般事件、母事件、自己打勾的子事件各算 1）。回傳 {date: count}。
static func counts_by_date(data: GameData) -> Dictionary:
	var counts := {}
	for ev in data.events:
		if ev.done_date != "":
			counts[ev.done_date] = counts.get(ev.done_date, 0) + 1
		for sub in ev.subtasks:
			if sub.done_date != "" and sub.self_done:
				counts[sub.done_date] = counts.get(sub.done_date, 0) + 1
	return counts


## 有完成事件的日期，新的在前。
static func active_dates(data: GameData) -> Array:
	var dates := counts_by_date(data).keys()
	dates.sort()
	dates.reverse()
	return dates


## 連續照顧天數：從今天往前數，每天都有完成事件的天數；今天還沒完成時從昨天開始算。
static func streak(data: GameData, today: String) -> int:
	var counts := counts_by_date(data)
	var day := today
	if not counts.has(day):
		day = IslandData.days_ago(today, 1)
	var n := 0
	while counts.has(day):
		n += 1
		day = IslandData.days_ago(day, 1)
	return n


## 最常做的事：依完成次數排序的 [標題, 次數]，最多 limit 筆；次數相同時依標題排序。
static func top_titles(data: GameData, limit: int = 3) -> Array:
	var counts := {}
	for ev in data.events:
		if ev.done_date != "":
			counts[ev.title] = counts.get(ev.title, 0) + 1
	var list := []
	for t in counts:
		list.append([t, counts[t]])
	list.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[0] < b[0]))
	return list.slice(0, limit)


# --- 日期工具 -------------------------------------------------------------

static func parse(date: String) -> Dictionary:
	return Time.get_datetime_dict_from_datetime_string(date + "T00:00:00", true)


static func make_date(year: int, month: int, day: int) -> String:
	return "%04d-%02d-%02d" % [year, month, day]


static func days_in_month(year: int, month: int) -> int:
	var next := make_date(year + (1 if month == 12 else 0), 1 if month == 12 else month + 1, 1)
	return int(parse(IslandData.days_ago(next, 1)).day)


## 0 = 星期日。
static func weekday(date: String) -> int:
	return int(parse(date).weekday)


static func label(date: String) -> String:
	var d := parse(date)
	return "%d 月 %d 日（%s）" % [d.month, d.day, "日一二三四五六"[int(d.weekday)]]
