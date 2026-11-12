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

## 動物：住在哪一種方塊上，以及棲地條件（「附近」= 周圍 8 格、高度差一層以內）。
## condition：[種類, 參數]；空陣列為無條件的基本動物。hint：圖鑑上的提示。
const ANIMALS := {
	"sheep": {"name": "綿羊", "habitat": Materials.DIRT, "condition": [], "hint": ""},
	"rabbit": {"name": "兔子", "habitat": Materials.DIRT,
		"condition": ["near_plant", "shrub"], "hint": "附近有灌木"},
	"corgi": {"name": "柯基", "habitat": Materials.DIRT,
		"condition": ["grassland", 5], "hint": "附近有一片草地（至少 5 格露天的土）"},
	"fish": {"name": "小魚", "habitat": Materials.WATER, "condition": [], "hint": ""},
	"turtle": {"name": "烏龜", "habitat": Materials.WATER,
		"condition": ["near_block", Materials.SAND], "hint": "附近有沙"},
	"duck": {"name": "鴨子", "habitat": Materials.WATER,
		"condition": ["near_block", Materials.DIRT], "hint": "附近有土"},
	"lizard": {"name": "蜥蜴", "habitat": Materials.STONE, "condition": [], "hint": ""},
	"goat": {"name": "山羊", "habitat": Materials.STONE,
		"condition": ["stone_stack", 3], "hint": "附近的石頭疊到 3 層"},
	"hermit_crab": {"name": "寄居蟹", "habitat": Materials.SAND, "condition": [], "hint": ""},
	"crab": {"name": "螃蟹", "habitat": Materials.SAND,
		"condition": ["near_block", Materials.WATER], "hint": "附近有水"},
}

## 稀有毛色：每種動物來訪時有小機率是另一種顏色（圖鑑算同一格）。
const VARIANTS := {
	"sheep": {"id": "black", "name": "黑毛白臉"},
	"rabbit": {"id": "black", "name": "黑兔"},
	"corgi": {"id": "tricolor", "name": "三色"},
	"fish": {"id": "red", "name": "紅色"},
	"duck": {"id": "mallard", "name": "綠頭鴨"},
	"lizard": {"id": "blue", "name": "藍色"},
	"goat": {"id": "brown", "name": "棕色"},
	"hermit_crab": {"id": "pink", "name": "粉紅殼"},
	"crab": {"id": "blue", "name": "藍色"},
}
const VARIANT_CHANCE := 0.1


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


static func animal_condition(id: String) -> Array:
	return ANIMALS[id].condition if ANIMALS.has(id) else []


## 這種動物的稀有毛色 id，沒有則回傳空字串。
static func animal_variant(id: String) -> String:
	return VARIANTS[id].id if VARIANTS.has(id) else ""


static func is_valid_variant(id: String, variant: String) -> bool:
	return variant == "" or variant == animal_variant(id)


static func is_basic_animal(id: String) -> bool:
	return animal_condition(id).is_empty()


## 圖鑑提示：「住在土上，附近有灌木」。
static func animal_hint(id: String) -> String:
	if not ANIMALS.has(id):
		return ""
	var text := "住在%s上" % Materials.display_name(animal_habitat(id))
	if ANIMALS[id].hint != "":
		text += "，" + ANIMALS[id].hint
	return text


static func empty_plant_inventory() -> Dictionary:
	var inv := {}
	for id in PLANTS:
		inv[id] = 0
	return inv
