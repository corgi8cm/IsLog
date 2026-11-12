class_name CustomBlocks
extends RefCounted
## 自訂方塊：玩家選基礎類型，再用 8×8 像素畫頂面與側面（四個側面共用一張）。
## 功能（棲地、可種的植物）都從基礎類型繼承，只有外觀不同。
## 在方塊與背包裡用 "custom:<id>" 當作種類。

const PREFIX := "custom:"
const SIZE := 8
const FACE_TOP := "top"
const FACE_SIDE := "side"

## 目前載入的設計：id → {id, base, top: PackedColorArray, side: PackedColorArray}
static var designs: Dictionary = {}
static var _textures: Dictionary = {}


static func type_of(design_id: int) -> String:
	return PREFIX + str(design_id)


static func is_custom(type: String) -> bool:
	return type.begins_with(PREFIX)


static func id_of(type: String) -> int:
	return int(type.substr(PREFIX.length())) if is_custom(type) else -1


static func has(type: String) -> bool:
	return designs.has(id_of(type))


static func design(type: String) -> Dictionary:
	return designs.get(id_of(type), {})


## 自訂方塊的基礎類型；一般方塊回傳自己。
static func base_of(type: String) -> String:
	if not is_custom(type):
		return type
	return design(type).get("base", "")


static func set_designs(list: Array) -> void:
	designs.clear()
	_textures.clear()
	for d in list:
		designs[d.id] = d


# --- 像素 ---------------------------------------------------------------

## 基礎類型的起點圖案（混合式：先帶入基礎類型的圖再修改）。
static func default_pixels(base: String, face: String) -> PackedColorArray:
	var top := Materials.top_color(base)
	var side := Materials.side_color(base)
	var px := PackedColorArray()
	px.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			# 固定的雜訊，讓每次的起點都一樣
			var n := ((x * 7 + y * 13 + x * y * 3) % 5) / 4.0
			var c: Color
			if face == FACE_TOP:
				c = top.darkened(0.08 * n) if n > 0.4 else top.lightened(0.06 * n)
			else:
				if base == Materials.DIRT and y < 2:
					c = top.darkened(0.05 * n)  # 草地的邊
				else:
					c = side.darkened(0.1 * n) if n > 0.4 else side.lightened(0.05 * n)
			px[y * SIZE + x] = c
	return px


static func to_hex(px: PackedColorArray) -> Array:
	var out := []
	for c in px:
		out.append(c.to_html(false))
	return out


static func from_hex(list, base: String, face: String) -> PackedColorArray:
	if typeof(list) != TYPE_ARRAY or list.size() != SIZE * SIZE:
		return default_pixels(base, face)
	var px := PackedColorArray()
	for h in list:
		px.append(Color.html(str(h)) if Color.html_is_valid(str(h)) else Color.MAGENTA)
	return px


## 一面的貼圖（8×8，最近點取樣）。
static func texture(type: String, face: String) -> Texture2D:
	var key := type + "/" + face
	if _textures.has(key):
		return _textures[key]
	var d := design(type)
	if d.is_empty():
		return null
	var tex := make_texture(d[face])
	_textures[key] = tex
	return tex


static func make_texture(px: PackedColorArray) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			img.set_pixel(x, y, px[y * SIZE + x])
	return ImageTexture.create_from_image(img)
