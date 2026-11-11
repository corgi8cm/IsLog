class_name Iso
extends RefCounted
## 等角投影與 90 度旋轉的座標換算。
##
## 「格子座標」是存檔用的 (x, y)；「旋轉座標」是依鏡頭旋轉後用來繪製的 (rx, ry)。
## 投影：螢幕 x 往右 = rx 增加、ry 減少；螢幕 y 往下 = rx、ry 增加；高度往上。

const TILE_W := 64.0
const TILE_H := 32.0
const BLOCK_H := 32.0


## 格子座標 → 旋轉座標（step 為 0..3，每一步順時針 90 度）。
static func rotate_cell(c: Vector2i, step: int, n: int = IslandData.SIZE) -> Vector2i:
	match posmod(step, 4):
		1:
			return Vector2i(n - 1 - c.y, c.x)
		2:
			return Vector2i(n - 1 - c.x, n - 1 - c.y)
		3:
			return Vector2i(c.y, n - 1 - c.x)
	return c


## 旋轉座標 → 格子座標。
static func unrotate_cell(c: Vector2i, step: int, n: int = IslandData.SIZE) -> Vector2i:
	return rotate_cell(c, 4 - posmod(step, 4), n)


## 旋轉空間中的點（可為小數）→ 螢幕上的投影位置（未含鏡頭位移與縮放）。
static func to_screen(gx: float, gy: float, h: float) -> Vector2:
	return Vector2((gx - gy) * TILE_W * 0.5, (gx + gy) * TILE_H * 0.5 - h * BLOCK_H)


## 投影位置 → 在高度 h 平面上的旋轉空間座標（小數）。
static func from_screen(p: Vector2, h: float) -> Vector2:
	var y := p.y + h * BLOCK_H
	var a := p.x / (TILE_W * 0.5)
	var b := y / (TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## 點選高度 h 的地板，回傳格子座標（可能超出範圍，呼叫端自行檢查）。
static func pick_floor(p: Vector2, h: int, step: int) -> Vector2i:
	var g := from_screen(p, h)
	return unrotate_cell(Vector2i(floori(g.x), floori(g.y)), step)


## 方塊在旋轉座標 (rx, ry, z) 的外框六邊形（用於點選判定）。
static func cube_outline(rc: Vector2i, z: int) -> PackedVector2Array:
	var x := float(rc.x)
	var y := float(rc.y)
	return PackedVector2Array([
		to_screen(x, y, z + 1),
		to_screen(x + 1, y, z + 1),
		to_screen(x + 1, y, z),
		to_screen(x + 1, y + 1, z),
		to_screen(x, y + 1, z),
		to_screen(x, y + 1, z + 1),
	])


## 由後往前的繪製排序鍵：先依 rx+ry，再依高度。
static func draw_key(rc: Vector2i, z: int) -> int:
	return (rc.x + rc.y) * 100 + z
