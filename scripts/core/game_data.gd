class_name GameData
extends RefCounted
## 玩家資料：事件、素材背包、每日上限計數。純邏輯，不碰檔案與畫面。

const DAILY_LIMIT := 10
const REWARD_COUNT := 3
const SAVE_VERSION := 1

var inventory: Dictionary = Materials.empty_inventory()
## 每個事件：{id, title, created, done_date, done_at, rewards}
## done_date 為空字串代表尚未完成。
var events: Array = []
var next_id := 1
var daily_date := ""
var daily_count := 0
var total_completed := 0
var is_pro := false


func add_event(title: String, now_unix: int) -> Dictionary:
	title = title.strip_edges()
	if title.is_empty():
		return {}
	var ev := {
		"id": next_id,
		"title": title,
		"created": now_unix,
		"done_date": "",
		"done_at": 0,
		"rewards": [],
	}
	next_id += 1
	events.append(ev)
	return ev


func find_event(id: int) -> Dictionary:
	for ev in events:
		if ev.id == id:
			return ev
	return {}


func delete_event(id: int) -> bool:
	for i in events.size():
		if events[i].id == id:
			events.remove_at(i)
			return true
	return false


func pending_events() -> Array:
	return events.filter(func(ev): return ev.done_date == "")


func events_done_on(date: String) -> Array:
	return events.filter(func(ev): return ev.done_date == date)


func completions_on(date: String) -> int:
	return daily_count if daily_date == date else 0


## 今天還能拿素材的件數；Pro 回傳 -1 代表無上限。
func rewards_left_on(date: String) -> int:
	if is_pro:
		return -1
	return maxi(0, DAILY_LIMIT - completions_on(date))


## 完成事件。回傳 {ok, rewards: Array[String], capped: bool}。
func complete_event(id: int, today: String, now_unix: int, rng: RandomNumberGenerator) -> Dictionary:
	var ev := find_event(id)
	if ev.is_empty() or ev.done_date != "":
		return {"ok": false, "rewards": [], "capped": false}
	if daily_date != today:
		daily_date = today
		daily_count = 0
	var rewards: Array = []
	if is_pro or daily_count < DAILY_LIMIT:
		for i in REWARD_COUNT:
			var t: String = Materials.TYPES[rng.randi_range(0, Materials.TYPES.size() - 1)]
			rewards.append(t)
			inventory[t] += 1
	daily_count += 1
	total_completed += 1
	ev.done_date = today
	ev.done_at = now_unix
	ev.rewards = rewards
	return {"ok": true, "rewards": rewards, "capped": rewards.is_empty()}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"inventory": inventory.duplicate(),
		"events": events.duplicate(true),
		"next_id": next_id,
		"daily_date": daily_date,
		"daily_count": daily_count,
		"total_completed": total_completed,
		"is_pro": is_pro,
	}


static func from_dict(d: Dictionary) -> GameData:
	var g := GameData.new()
	var inv: Dictionary = d.get("inventory", {})
	for t in Materials.TYPES:
		g.inventory[t] = int(inv.get(t, 0))
	for raw in d.get("events", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var rewards: Array = []
		for r in raw.get("rewards", []):
			rewards.append(str(r))
		g.events.append({
			"id": int(raw.get("id", 0)),
			"title": str(raw.get("title", "")),
			"created": int(raw.get("created", 0)),
			"done_date": str(raw.get("done_date", "")),
			"done_at": int(raw.get("done_at", 0)),
			"rewards": rewards,
		})
	g.next_id = int(d.get("next_id", 1))
	for ev in g.events:
		g.next_id = maxi(g.next_id, ev.id + 1)
	g.daily_date = str(d.get("daily_date", ""))
	g.daily_count = int(d.get("daily_count", 0))
	g.total_completed = int(d.get("total_completed", 0))
	g.is_pro = bool(d.get("is_pro", false))
	return g
