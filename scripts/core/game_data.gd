class_name GameData
extends RefCounted
## 玩家資料：事件與子事件、素材背包、每日上限計數。純邏輯，不碰檔案與畫面。

const DAILY_LIMIT := 10
const REWARD_COUNT := 3
const SUBTASK_REWARD_COUNT := 2
const PLANT_DROP_CHANCE := 0.3
## 素材交換：幾個換 1 個。
const EXCHANGE_COST := 2
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
## 圖鑑：來過的動物 → 第一次來訪的日期。
var seen_animals: Dictionary = {}
## 新手引導進度；預設為已完成，只有全新開始的遊戲會從頭開始。
var tutorial_step: int = Tutorial.Step.DONE
## 已經顯示過的情境提示（第一次達到每日上限、第一次褪色……）。
var tips_shown: Dictionary = {}
## 多島：擁有的島嶼 id 與目前在蓋的那一座。
var island_ids: Array = [0]
var current_island := 0

## 每完成幾件事件解鎖一座新島。
const EVENTS_PER_ISLAND := 100
## 自訂方塊設計格：一開始幾格、每完成幾件多一格（暫定，見企劃待決事項）。
const BASE_DESIGN_SLOTS := 2
const EVENTS_PER_DESIGN_SLOT := 30

## 「我的方塊」：{id, base, top: PackedColorArray, side: PackedColorArray}
## 做好的自訂方塊數量放在 inventory["custom:<id>"]。
var custom_designs: Array = []
var next_design_id := 1


# --- 自訂方塊 -------------------------------------------------------------

func design_slots() -> int:
	return BASE_DESIGN_SLOTS + total_completed / EVENTS_PER_DESIGN_SLOT


func can_add_design() -> bool:
	return custom_designs.size() < design_slots()


## 距離下一個設計格還差幾件。
func events_to_next_slot() -> int:
	return (total_completed / EVENTS_PER_DESIGN_SLOT + 1) * EVENTS_PER_DESIGN_SLOT - total_completed


## 儲存新的設計（不需要取名）。回傳設計 id，沒有空的設計格則回傳 -1。
func save_design(base: String, top: PackedColorArray, side: PackedColorArray) -> int:
	if not can_add_design() or not Materials.is_valid(base):
		return -1
	if top.size() != CustomBlocks.SIZE * CustomBlocks.SIZE or side.size() != top.size():
		return -1
	var d := {"id": next_design_id, "base": base, "top": top, "side": side}
	next_design_id += 1
	custom_designs.append(d)
	inventory[CustomBlocks.type_of(d.id)] = 0
	CustomBlocks.set_designs(custom_designs)
	return d.id


## 快速製作：消耗 1 個基礎素材，做出 1 個自訂方塊。
func make_custom(design_id: int) -> bool:
	var d := find_design(design_id)
	if d.is_empty() or int(inventory.get(d.base, 0)) <= 0:
		return false
	inventory[d.base] -= 1
	var type := CustomBlocks.type_of(design_id)
	inventory[type] = int(inventory.get(type, 0)) + 1
	return true


func find_design(design_id: int) -> Dictionary:
	for d in custom_designs:
		if d.id == design_id:
			return d
	return {}


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


## 依累計完成件數可以擁有幾座島（第一座免費，之後每 100 件一座）。
func islands_unlocked() -> int:
	return 1 + total_completed / EVENTS_PER_ISLAND


func can_create_island() -> bool:
	return island_ids.size() < islands_unlocked()


## 距離下一座島還差幾件。
func events_to_next_island() -> int:
	return EVENTS_PER_ISLAND * island_ids.size() - total_completed


## 素材交換：EXCHANGE_COST 個 from 換 1 個 to。
func exchange(from_type: String, to_type: String) -> bool:
	if from_type == to_type or not Materials.is_valid(from_type) or not Materials.is_valid(to_type):
		return false
	if int(inventory.get(from_type, 0)) < EXCHANGE_COST:
		return false
	inventory[from_type] -= EXCHANGE_COST
	inventory[to_type] += 1
	return true


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
		"seen_animals": seen_animals.duplicate(),
		"tutorial_step": tutorial_step,
		"tips_shown": tips_shown.duplicate(),
		"island_ids": island_ids.duplicate(),
		"current_island": current_island,
		"custom_designs": custom_designs.map(func(d): return {
			"id": d.id, "base": d.base,
			"top": CustomBlocks.to_hex(d.top), "side": CustomBlocks.to_hex(d.side)}),
		"next_design_id": next_design_id,
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
	var seen = d.get("seen_animals", {})
	if typeof(seen) == TYPE_DICTIONARY:
		for species in seen:
			if Catalog.is_animal(str(species)):
				g.seen_animals[str(species)] = str(seen[species])
	g.tutorial_step = clampi(int(d.get("tutorial_step", Tutorial.Step.DONE)), 0, Tutorial.Step.DONE)
	for raw in d.get("custom_designs", []):
		if typeof(raw) != TYPE_DICTIONARY or not Materials.is_valid(str(raw.get("base", ""))):
			continue
		var base := str(raw.base)
		g.custom_designs.append({"id": int(raw.get("id", 0)), "base": base,
			"top": CustomBlocks.from_hex(raw.get("top"), base, CustomBlocks.FACE_TOP),
			"side": CustomBlocks.from_hex(raw.get("side"), base, CustomBlocks.FACE_SIDE)})
	g.next_design_id = int(d.get("next_design_id", 1))
	for design in g.custom_designs:
		g.next_design_id = maxi(g.next_design_id, design.id + 1)
		var type := CustomBlocks.type_of(design.id)
		g.inventory[type] = int(inv.get(type, 0))
	# 讀島嶼之前要先知道有哪些自訂方塊
	CustomBlocks.set_designs(g.custom_designs)
	var ids: Array = []
	for raw_id in d.get("island_ids", [0]):
		if not ids.has(int(raw_id)):
			ids.append(int(raw_id))
	g.island_ids = ids if not ids.is_empty() else [0]
	g.current_island = int(d.get("current_island", g.island_ids[0]))
	if not g.island_ids.has(g.current_island):
		g.current_island = g.island_ids[0]
	var tips = d.get("tips_shown", {})
	if typeof(tips) == TYPE_DICTIONARY:
		for k in tips:
			g.tips_shown[str(k)] = true
	return g
