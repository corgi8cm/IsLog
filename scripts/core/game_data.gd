class_name GameData
extends RefCounted
## 玩家資料：事件與子事件、素材背包、每日上限計數。純邏輯，不碰檔案與畫面。

const DAILY_LIMIT := 10
const REWARD_COUNT := 3
const SUBTASK_REWARD_COUNT := 2
const PLANT_DROP_CHANCE := 0.3
const SAVE_VERSION := 2

var inventory: Dictionary = Materials.empty_inventory()
var plants: Dictionary = Catalog.empty_plant_inventory()
## 每個事件：{id, title, created, done_date, done_at, rewards, plant, visitor, subtasks}
## 每個子事件：{id, title, done_date, done_at, rewards, self_done}
## done_date 為空字串代表尚未完成；self_done 代表玩家自己打勾（直接完成母事件時一起打勾的為 false）。
var events: Array = []
var next_id := 1
var daily_date := ""
## 今天完成的件數（一般事件、母事件、子事件各算 1 件），用來判斷每日上限。
var daily_count := 0
## 今天完成的一般事件與母事件件數，用來判斷每天必掉的植物。
var daily_main_count := 0
var total_completed := 0
var is_pro := false


func add_event(title: String, now_unix: int, subtask_titles: Array = []) -> Dictionary:
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
		"plant": "",
		"visitor": "",
		"subtasks": [],
	}
	next_id += 1
	events.append(ev)
	for t in subtask_titles:
		add_subtask(ev.id, str(t))
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


# --- 子事件 -------------------------------------------------------------

func add_subtask(event_id: int, title: String) -> Dictionary:
	title = title.strip_edges()
	var ev := find_event(event_id)
	if title.is_empty() or ev.is_empty() or ev.done_date != "":
		return {}
	var sub := {
		"id": next_id,
		"title": title,
		"done_date": "",
		"done_at": 0,
		"rewards": [],
		"self_done": false,
	}
	next_id += 1
	ev.subtasks.append(sub)
	return sub


func find_subtask(event_id: int, sub_id: int) -> Dictionary:
	var ev := find_event(event_id)
	if ev.is_empty():
		return {}
	for sub in ev.subtasks:
		if sub.id == sub_id:
			return sub
	return {}


func delete_subtask(event_id: int, sub_id: int) -> bool:
	var ev := find_event(event_id)
	if ev.is_empty() or ev.done_date != "":
		return false
	for i in ev.subtasks.size():
		if ev.subtasks[i].id == sub_id:
			ev.subtasks.remove_at(i)
			return true
	return false


## 母事件的加成：玩家自己打勾的子事件數。
static func subtask_bonus(ev: Dictionary) -> int:
	var n := 0
	for sub in ev.get("subtasks", []):
		if sub.done_date != "" and sub.self_done:
			n += 1
	return n


static func subtask_progress(ev: Dictionary) -> Vector2i:
	var done := 0
	for sub in ev.get("subtasks", []):
		if sub.done_date != "":
			done += 1
	return Vector2i(done, ev.get("subtasks", []).size())


## 完成子事件：給 2 個素材、計 1 件；全部子事件完成時母事件自動完成。
## 回傳 {ok, rewards, capped, parent}，parent 為母事件自動完成時的結果（否則為空字典）。
func complete_subtask(event_id: int, sub_id: int, today: String, now_unix: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var ev := find_event(event_id)
	var sub := find_subtask(event_id, sub_id)
	if ev.is_empty() or sub.is_empty() or ev.done_date != "" or sub.done_date != "":
		return {"ok": false, "rewards": [], "capped": false, "parent": {}}
	_roll_day(today)
	var rewards: Array = []
	if _has_reward_left():
		rewards = _give_materials(SUBTASK_REWARD_COUNT, rng)
	daily_count += 1
	total_completed += 1
	sub.done_date = today
	sub.done_at = now_unix
	sub.rewards = rewards
	sub.self_done = true
	var parent := {}
	if subtask_progress(ev).x == ev.subtasks.size():
		parent = complete_event(event_id, today, now_unix, rng)
	return {"ok": true, "rewards": rewards, "capped": rewards.is_empty(), "parent": parent}


# --- 完成事件 -------------------------------------------------------------

## 完成一般事件或母事件。回傳 {ok, rewards: Array[String], plant: String, capped: bool, bonus: int}。
## 素材 = 3 + 玩家自己打勾的子事件數；有素材時 30% 掉落植物，每天第一個完成的一般事件或母事件必掉一株。
## 還沒完成的子事件會一起打勾，但不計件、不給素材、不算加成。
func complete_event(id: int, today: String, now_unix: int, rng: RandomNumberGenerator) -> Dictionary:
	var ev := find_event(id)
	if ev.is_empty() or ev.done_date != "":
		return {"ok": false, "rewards": [], "plant": "", "capped": false, "bonus": 0}
	_roll_day(today)
	for sub in ev.subtasks:
		if sub.done_date == "":
			sub.done_date = today
			sub.done_at = now_unix
			sub.self_done = false
	var bonus := subtask_bonus(ev)
	var rewards: Array = []
	var plant := ""
	if _has_reward_left():
		rewards = _give_materials(REWARD_COUNT + bonus, rng)
		var first_today := daily_main_count == 0
		if rng.randf() < PLANT_DROP_CHANCE or first_today:
			var ids := Catalog.plant_ids()
			plant = ids[rng.randi_range(0, ids.size() - 1)]
			plants[plant] += 1
	daily_count += 1
	daily_main_count += 1
	total_completed += 1
	ev.done_date = today
	ev.done_at = now_unix
	ev.rewards = rewards
	ev.plant = plant
	return {"ok": true, "rewards": rewards, "plant": plant, "capped": rewards.is_empty(), "bonus": bonus}


func _roll_day(today: String) -> void:
	if daily_date != today:
		daily_date = today
		daily_count = 0
		daily_main_count = 0


func _has_reward_left() -> bool:
	return is_pro or daily_count < DAILY_LIMIT


func _give_materials(count: int, rng: RandomNumberGenerator) -> Array:
	var rewards: Array = []
	for i in count:
		var t: String = Materials.TYPES[rng.randi_range(0, Materials.TYPES.size() - 1)]
		rewards.append(t)
		inventory[t] += 1
	return rewards


# --- 存檔 ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"inventory": inventory.duplicate(),
		"plants": plants.duplicate(),
		"events": events.duplicate(true),
		"next_id": next_id,
		"daily_date": daily_date,
		"daily_count": daily_count,
		"daily_main_count": daily_main_count,
		"total_completed": total_completed,
		"is_pro": is_pro,
	}


static func _str_array(raw) -> Array:
	var out: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for r in raw:
			out.append(str(r))
	return out


static func from_dict(d: Dictionary) -> GameData:
	var g := GameData.new()
	var inv: Dictionary = d.get("inventory", {})
	for t in Materials.TYPES:
		g.inventory[t] = int(inv.get(t, 0))
	var plant_inv: Dictionary = d.get("plants", {})
	for id in Catalog.plant_ids():
		g.plants[id] = int(plant_inv.get(id, 0))
	var max_id := 0
	for raw in d.get("events", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var subtasks: Array = []
		for rs in raw.get("subtasks", []):
			if typeof(rs) != TYPE_DICTIONARY:
				continue
			subtasks.append({
				"id": int(rs.get("id", 0)),
				"title": str(rs.get("title", "")),
				"done_date": str(rs.get("done_date", "")),
				"done_at": int(rs.get("done_at", 0)),
				"rewards": _str_array(rs.get("rewards", [])),
				"self_done": bool(rs.get("self_done", false)),
			})
			max_id = maxi(max_id, subtasks.back().id)
		g.events.append({
			"id": int(raw.get("id", 0)),
			"title": str(raw.get("title", "")),
			"created": int(raw.get("created", 0)),
			"done_date": str(raw.get("done_date", "")),
			"done_at": int(raw.get("done_at", 0)),
			"rewards": _str_array(raw.get("rewards", [])),
			"plant": str(raw.get("plant", "")),
			"visitor": str(raw.get("visitor", "")),
			"subtasks": subtasks,
		})
		max_id = maxi(max_id, g.events.back().id)
	g.next_id = maxi(int(d.get("next_id", 1)), max_id + 1)
	g.daily_date = str(d.get("daily_date", ""))
	g.daily_count = int(d.get("daily_count", 0))
	# v1 存檔沒有子事件，今天的件數都是一般事件
	g.daily_main_count = int(d.get("daily_main_count", g.daily_count))
	g.total_completed = int(d.get("total_completed", 0))
	g.is_pro = bool(d.get("is_pro", false))
	return g
