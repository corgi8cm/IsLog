class_name IslandData
extends RefCounted
## 一座島：10×10×10 空間，方塊以稀疏格式 (x, y, z) → 種類 儲存。

const SIZE := 10
const SAVE_VERSION := 1

var id := 0
var blocks: Dictionary = {}  # Vector3i -> String


static func in_bounds(p: Vector3i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.z >= 0 \
		and p.x < SIZE and p.y < SIZE and p.z < SIZE


func get_block(p: Vector3i) -> String:
	return blocks.get(p, "")


func has_block(p: Vector3i) -> bool:
	return blocks.has(p)


func block_count() -> int:
	return blocks.size()


## 從背包扣一個素材放上方塊。成功回傳 true。
func place(p: Vector3i, type: String, inventory: Dictionary) -> bool:
	if not in_bounds(p) or blocks.has(p) or not Materials.is_valid(type):
		return false
	if int(inventory.get(type, 0)) <= 0:
		return false
	inventory[type] -= 1
	blocks[p] = type
	return true


## 移除方塊並退回素材。回傳被移除的種類，沒有方塊則回傳空字串。
func remove(p: Vector3i, inventory: Dictionary) -> String:
	if not blocks.has(p):
		return ""
	var type: String = blocks[p]
	blocks.erase(p)
	inventory[type] = int(inventory.get(type, 0)) + 1
	return type


func to_dict() -> Dictionary:
	var list := []
	for p in blocks:
		list.append([p.x, p.y, p.z, blocks[p]])
	return {"version": SAVE_VERSION, "id": id, "size": SIZE, "blocks": list}


static func from_dict(d: Dictionary) -> IslandData:
	var island := IslandData.new()
	island.id = int(d.get("id", 0))
	for raw in d.get("blocks", []):
		if typeof(raw) != TYPE_ARRAY or raw.size() < 4:
			continue
		var p := Vector3i(int(raw[0]), int(raw[1]), int(raw[2]))
		var type := str(raw[3])
		if in_bounds(p) and Materials.is_valid(type):
			island.blocks[p] = type
	return island
