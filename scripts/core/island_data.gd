class_name IslandData
extends RefCounted
## 一座島：10×10×10 空間，方塊以稀疏格式 (x, y, z) → 種類 儲存；
## 另外記錄種在方塊上的植物、來訪的動物，以及褪色狀態。

const SIZE := 10
const SAVE_VERSION := 2

## 褪色：整天沒完成事件的日子累積到第 2 天開始褪色，第 5 天全灰。
## 只漏一天不會褪色，所以恢復期間中斷一天時進度只是暫停。
const FADE_PER_DAY := 0.25
## 恢復：每個有完成事件的日子恢復 1/3，全灰需要 3 天。
const RECOVER_PER_DAY := 1.0 / 3.0
## 動物的棲地消失後，冒問號多久才離開（秒）。
const CONFUSED_LEAVE_SECONDS := 86400
## 同一種動物最多幾隻。
const MAX_PER_SPECIES := 2

const NEIGHBORS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var id := 0
var blocks: Dictionary = {}  # Vector3i -> 方塊種類
var plants: Dictionary = {}  # Vector3i（植物所在的方塊）-> 植物 id
## 每隻動物：{id, species, pos: Vector3i（站在哪個方塊上）, arrived, confused_since}
var animals: Array = []
var next_animal_id := 1
var last_care_date := ""
var fade_base := 0.0
var name := ""
## 封存：收起來的島時間停止。記下封存當天與時間，拿出來時把褪色與動物的計時往後推。
var archived := false
var archived_on := ""
var archived_at := 0


static func in_bounds(p: Vector3i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.z >= 0 \
		and p.x < SIZE and p.y < SIZE and p.z < SIZE


func get_block(p: Vector3i) -> String:
	return blocks.get(p, "")


## 方塊的功能類型（自訂方塊算它的基礎類型）；沒有方塊回傳空字串。
func base_at(p: Vector3i) -> String:
	return Materials.base_of(blocks.get(p, ""))


func has_block(p: Vector3i) -> bool:
	return blocks.has(p)


func block_count() -> int:
	return blocks.size()


## 方塊頂面是否露在外面（上方沒有方塊）。
func is_top_open(p: Vector3i) -> bool:
	return not blocks.has(p + Vector3i(0, 0, 1))


# --- 方塊 ---------------------------------------------------------------

## 放置方塊不行的原因；可以放則回傳空字串。
func place_problem(p: Vector3i, type: String, inventory: Dictionary) -> String:
	if not in_bounds(p) or not Materials.is_placeable(type):
		return "out_of_bounds"
	if blocks.has(p):
		return "occupied"
	if plants.has(p - Vector3i(0, 0, 1)):
		return "plant_below"
	if int(inventory.get(type, 0)) <= 0:
		return "no_material"
	return ""


## 從背包扣一個素材放上方塊。成功回傳 true。
func place(p: Vector3i, type: String, inventory: Dictionary) -> bool:
	if place_problem(p, type, inventory) != "":
		return false
	inventory[type] -= 1
	blocks[p] = type
	return true


## 移除方塊並退回素材；上面若有植物一併退回。回傳被移除的方塊種類，沒有方塊則回傳空字串。
func remove(p: Vector3i, inventory: Dictionary, plant_inventory: Dictionary = {}) -> String:
	if not blocks.has(p):
		return ""
	if plants.has(p):
		remove_plant(p, plant_inventory)
	var type: String = blocks[p]
	blocks.erase(p)
	inventory[type] = int(inventory.get(type, 0)) + 1
	return type


# --- 植物 ---------------------------------------------------------------

## 種植不行的原因；可以種則回傳空字串。
func plant_problem(p: Vector3i, plant_id: String, plant_inventory: Dictionary) -> String:
	if not Catalog.is_plant(plant_id):
		return "invalid"
	if not blocks.has(p):
		return "no_block"
	if base_at(p) != Catalog.plant_base(plant_id):
		return "wrong_base"
	if plants.has(p):
		return "occupied"
	if not is_top_open(p):
		return "covered"
	if int(plant_inventory.get(plant_id, 0)) <= 0:
		return "no_plant"
	return ""


func plant(p: Vector3i, plant_id: String, plant_inventory: Dictionary) -> bool:
	if plant_problem(p, plant_id, plant_inventory) != "":
		return false
	plant_inventory[plant_id] -= 1
	plants[p] = plant_id
	return true


## 移除植物並退回背包。回傳植物 id，沒有則回傳空字串。
func remove_plant(p: Vector3i, plant_inventory: Dictionary) -> String:
	if not plants.has(p):
		return ""
	var plant_id: String = plants[p]
	plants.erase(p)
	plant_inventory[plant_id] = int(plant_inventory.get(plant_id, 0)) + 1
	return plant_id


# --- 褪色與恢復 -----------------------------------------------------------

static func days_between(from_date: String, to_date: String) -> int:
	var a := Time.get_unix_time_from_datetime_string(from_date + "T00:00:00")
	var b := Time.get_unix_time_from_datetime_string(to_date + "T00:00:00")
	return int(round((b - a) / 86400.0))


## date 往前推 n 天的日期字串。
static func days_ago(date: String, n: int) -> String:
	var t := Time.get_unix_time_from_datetime_string(date + "T00:00:00") - n * 86400
	return Time.get_date_string_from_unix_time(t)


## 某一天的褪色程度（0 = 完整色彩，1 = 全灰）。
func fade_on(today: String) -> float:
	if last_care_date == "":
		return fade_base
	var missed_days := days_between(last_care_date, today) - 1
	return clampf(fade_base + maxi(0, missed_days - 1) * FADE_PER_DAY, 0.0, 1.0)


## 完成事件時呼叫：每天第一次照顧會恢復一些顏色。
func care(today: String) -> void:
	if last_care_date == today:
		return
	var f := fade_on(today)
	fade_base = maxf(0.0, f - RECOVER_PER_DAY)
	if fade_base < 0.01:
		fade_base = 0.0
	last_care_date = today


# --- 封存 ---------------------------------------------------------------

func archive(today: String, now_unix: int) -> void:
	if archived:
		return
	archived = true
	archived_on = today
	archived_at = now_unix


## 拿出來：封存期間不算，褪色從封存當時的狀態繼續。
func restore(today: String, now_unix: int) -> void:
	if not archived:
		return
	var days := days_between(archived_on, today)
	if last_care_date != "" and days > 0:
		last_care_date = days_ago(last_care_date, -days)
	var seconds := maxi(0, now_unix - archived_at)
	for a in animals:
		if a.confused_since != 0:
			a.confused_since += seconds
	archived = false
	archived_on = ""
	archived_at = 0


func display_name() -> String:
	return name if name != "" else "第 %d 座島" % (id + 1)


# --- 動物 ---------------------------------------------------------------

## 「附近」：周圍 8 格、高度差一層以內。
static func nearby_cells(p: Vector3i) -> Array:
	var cells := []
	for d in NEIGHBORS:
		for dz in [-1, 0, 1]:
			cells.append(p + Vector3i(d.x, d.y, dz))
	return cells


## 動物的棲地條件在 p 是否成立。
func condition_met(species: String, p: Vector3i) -> bool:
	var cond := Catalog.animal_condition(species)
	if cond.is_empty():
		return true
	match cond[0]:
		"near_block":
			for q in nearby_cells(p):
				if base_at(q) == cond[1]:
					return true
			return false
		"near_plant":
			for q in nearby_cells(p):
				if plants.get(q, "") == cond[1]:
					return true
			return false
		"grassland":
			var n := 0
			for q in nearby_cells(p):
				if base_at(q) == Materials.DIRT and is_top_open(q):
					n += 1
			return n >= int(cond[1])
		"stone_stack":
			# 周圍（含自己這一欄）有一欄石頭連續疊到 cond[1] 層
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var run := 0
					for z in SIZE:
						if base_at(Vector3i(p.x + dx, p.y + dy, z)) == Materials.STONE:
							run += 1
							if run >= int(cond[1]):
								return true
						else:
							run = 0
			return false
	return false


## 某種動物可以站的方塊：棲地種類、頂面露出、棲地條件成立。
func habitat_cells(species: String) -> Array:
	var habitat := Catalog.animal_habitat(species)
	var cells := []
	for p in blocks:
		if base_at(p) == habitat and is_top_open(p) and condition_met(species, p):
			cells.append(p)
	return cells


func is_habitat(species: String, p: Vector3i) -> bool:
	return base_at(p) == Catalog.animal_habitat(species) and is_top_open(p) and condition_met(species, p)


func species_count(species: String) -> int:
	var n := 0
	for a in animals:
		if a.species == species:
			n += 1
	return n


## 褪色時島上能住的動物數量：顏色越少，動物越少。
static func animal_capacity(fade: float) -> int:
	return roundi(Catalog.animal_ids().size() * MAX_PER_SPECIES * (1.0 - fade))


## 完成事件時呼叫：條件滿足的動物來訪，一次一隻。回傳來訪的物種，沒有則回傳空字串。
## seen：圖鑑裡已經來過的物種；有還沒來過的候選時優先讓牠來。
func try_visit(fade: float, now_unix: int, rng: RandomNumberGenerator, seen: Dictionary = {}) -> String:
	if animals.size() >= animal_capacity(fade):
		return ""
	var candidates := []
	for species in Catalog.animal_ids():
		if species_count(species) < MAX_PER_SPECIES and not habitat_cells(species).is_empty():
			candidates.append(species)
	if candidates.is_empty():
		return ""
	var unseen := candidates.filter(func(s): return not seen.has(s))
	if not unseen.is_empty():
		candidates = unseen
	var species: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var cells := habitat_cells(species)
	cells.sort()
	# 盡量站在沒有其他動物的格子
	var free := cells.filter(func(c): return not _animal_at(c, -1))
	if not free.is_empty():
		cells = free
	animals.append({
		"id": next_animal_id,
		"species": species,
		"pos": cells[rng.randi_range(0, cells.size() - 1)],
		"arrived": now_unix,
		"confused_since": 0,
	})
	next_animal_id += 1
	return species


## 島嶼變動或時間經過後更新動物：超過容量的離開、腳下方塊不見的換位置，
## 沒有棲地的冒問號，問號超過一天就離開。回傳是否有變化。
func update_animals(fade: float, now_unix: int) -> bool:
	var changed := false
	var capacity := animal_capacity(fade)
	while animals.size() > capacity:
		animals.pop_back()
		changed = true
	for a in animals.duplicate():
		if is_habitat(a.species, a.pos):
			if a.confused_since != 0:
				a.confused_since = 0
				changed = true
			continue
		var cells := habitat_cells(a.species)
		if not cells.is_empty():
			a.pos = _nearest(cells, a.pos)
			a.confused_since = 0
			changed = true
		elif a.confused_since == 0:
			a.confused_since = now_unix
			changed = true
		elif now_unix - a.confused_since >= CONFUSED_LEAVE_SECONDS:
			animals.erase(a)
			changed = true
	return changed


## 動物漫步：每隻隨機走到周圍 8 格（高度差一層以內）的棲地，或留在原地。
func wander(rng: RandomNumberGenerator) -> void:
	for a in animals:
		if a.confused_since != 0:
			continue
		var options := [a.pos]
		for d in NEIGHBORS:
			for dz in [-1, 0, 1]:
				var q: Vector3i = a.pos + Vector3i(d.x, d.y, dz)
				if is_habitat(a.species, q) and not _animal_at(q, a.id):
					options.append(q)
		a.pos = options[rng.randi_range(0, options.size() - 1)]


func _animal_at(p: Vector3i, except_id: int) -> bool:
	for a in animals:
		if a.id != except_id and a.pos == p:
			return true
	return false


static func _nearest(cells: Array, from: Vector3i) -> Vector3i:
	var best: Vector3i = cells[0]
	var best_d := INF
	for c in cells:
		var d := Vector3(c - from).length_squared()
		if d < best_d or (d == best_d and c < best):
			best_d = d
			best = c
	return best


# --- 存檔 ---------------------------------------------------------------

func to_dict() -> Dictionary:
	var block_list := []
	for p in blocks:
		block_list.append([p.x, p.y, p.z, blocks[p]])
	var plant_list := []
	for p in plants:
		plant_list.append([p.x, p.y, p.z, plants[p]])
	var animal_list := []
	for a in animals:
		animal_list.append({
			"id": a.id, "species": a.species,
			"pos": [a.pos.x, a.pos.y, a.pos.z],
			"arrived": a.arrived, "confused_since": a.confused_since,
		})
	return {
		"version": SAVE_VERSION,
		"id": id,
		"size": SIZE,
		"blocks": block_list,
		"plants": plant_list,
		"animals": animal_list,
		"next_animal_id": next_animal_id,
		"last_care_date": last_care_date,
		"fade_base": fade_base,
		"name": name,
		"archived": archived,
		"archived_on": archived_on,
		"archived_at": archived_at,
	}


static func from_dict(d: Dictionary) -> IslandData:
	var island := IslandData.new()
	island.id = int(d.get("id", 0))
	for raw in d.get("blocks", []):
		if typeof(raw) != TYPE_ARRAY or raw.size() < 4:
			continue
		var p := Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
		var type := str(raw[3])
		if in_bounds(p) and Materials.is_placeable(type):
			island.blocks[p] = type
	for raw in d.get("plants", []):
		if typeof(raw) != TYPE_ARRAY or raw.size() < 4:
			continue
		var p := Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
		var plant_id := str(raw[3])
		if island.blocks.has(p) and Catalog.is_plant(plant_id):
			island.plants[p] = plant_id
	for raw in d.get("animals", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var species := str(raw.get("species", ""))
		var pos: Array = raw.get("pos", [])
		if not Catalog.is_animal(species) or pos.size() < 3:
			continue
		island.animals.append({
			"id": int(raw.get("id", 0)),
			"species": species,
			"pos": Vector3i(int(pos[0]), int(pos[1]), int(pos[2])),
			"arrived": int(raw.get("arrived", 0)),
			"confused_since": int(raw.get("confused_since", 0)),
		})
	island.next_animal_id = int(d.get("next_animal_id", 1))
	for a in island.animals:
		island.next_animal_id = maxi(island.next_animal_id, a.id + 1)
	island.last_care_date = str(d.get("last_care_date", ""))
	island.fade_base = clampf(float(d.get("fade_base", 0.0)), 0.0, 1.0)
	island.name = str(d.get("name", ""))
	island.archived = bool(d.get("archived", false))
	island.archived_on = str(d.get("archived_on", ""))
	island.archived_at = int(d.get("archived_at", 0))
	return island
