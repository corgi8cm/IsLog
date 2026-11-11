class_name Catalog
extends RefCounted
## 植物與動物的資料表。

## 植物：名稱與可以種在哪一種方塊上。
const PLANTS := {
	"flower": {"name": "花", "base": Materials.DIRT},
	"shrub": {"name": "灌木", "base": Materials.DIRT},
	"fruit_tree": {"name": "果樹", "base": Materials.DIRT},
	"mushroom": {"name": "蘑菇", "base": Materials.DIRT},
	"water_lily": {"name": "睡蓮", "base": Materials.WATER},
	"waterweed": {"name": "水草", "base": Materials.WATER},
	"reed": {"name": "蘆葦", "base": Materials.WATER},
	"moss": {"name": "苔蘚", "base": Materials.STONE},
	"succulent": {"name": "多肉", "base": Materials.STONE},
	"alpine_flower": {"name": "高山小花", "base": Materials.STONE},
	"cactus": {"name": "仙人掌", "base": Materials.SAND},
	"palm": {"name": "椰子樹", "base": Materials.SAND},
}

## 基本動物（無條件）：住在哪一種方塊上。
const ANIMALS := {
	"sheep": {"name": "綿羊", "habitat": Materials.DIRT},
	"fish": {"name": "小魚", "habitat": Materials.WATER},
	"lizard": {"name": "蜥蜴", "habitat": Materials.STONE},
	"hermit_crab": {"name": "寄居蟹", "habitat": Materials.SAND},
}


static func plant_ids() -> Array:
	return PLANTS.keys()


static func animal_ids() -> Array:
	return ANIMALS.keys()


static func is_plant(id: String) -> bool:
	return PLANTS.has(id)


static func is_animal(id: String) -> bool:
	return ANIMALS.has(id)


static func plant_name(id: String) -> String:
	return PLANTS[id].name if PLANTS.has(id) else "?"


static func plant_base(id: String) -> String:
	return PLANTS[id].base if PLANTS.has(id) else ""


static func animal_name(id: String) -> String:
	return ANIMALS[id].name if ANIMALS.has(id) else "?"


static func animal_habitat(id: String) -> String:
	return ANIMALS[id].habitat if ANIMALS.has(id) else ""


static func empty_plant_inventory() -> Dictionary:
	var inv := {}
	for id in PLANTS:
		inv[id] = 0
	return inv
