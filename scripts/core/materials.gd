class_name Materials
extends RefCounted
## 方塊素材的種類、名稱與顏色。

const DIRT := "dirt"
const WATER := "water"
const STONE := "stone"
const SAND := "sand"

const TYPES := [DIRT, WATER, STONE, SAND]

const NAMES := {
	DIRT: "土",
	WATER: "水",
	STONE: "石",
	SAND: "沙",
}

static var _top_colors := {
	DIRT: Color("7cc35a"),
	WATER: Color("5cbcf0"),
	STONE: Color("aab1b9"),
	SAND: Color("efdca2"),
}

static var _side_colors := {
	DIRT: Color("9a6b45"),
	WATER: Color("3a8fd0"),
	STONE: Color("838a93"),
	SAND: Color("d8c07f"),
}


static func is_valid(type: String) -> bool:
	return TYPES.has(type)


static func display_name(type: String) -> String:
	return NAMES.get(type, "?")


static func top_color(type: String) -> Color:
	return _top_colors.get(type, Color.MAGENTA)


static func side_color(type: String) -> Color:
	return _side_colors.get(type, Color.MAGENTA)


## 素材清單 → 「土×2、水、石」。
static func summary(rewards: Array, empty_text: String = "沒有素材") -> String:
	if rewards.is_empty():
		return empty_text
	var parts := []
	for t in TYPES:
		var n := rewards.count(t)
		if n > 0:
			parts.append(display_name(t) + ("×%d" % n if n > 1 else ""))
	return "、".join(parts)


static func empty_inventory() -> Dictionary:
	var inv := {}
	for t in TYPES:
		inv[t] = 0
	return inv
