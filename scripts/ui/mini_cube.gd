class_name MiniCube
extends Control
## 小方塊圖示：素材列、工具列、事件的獎勵都用它表示素材。

var type := "":
	set(v):
		type = v
		queue_redraw()
## 方塊寬度的一半（像素）。
var half := 13.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(half * 2 + 4, half * 2 + 6)


func _draw() -> void:
	draw_cube(self, size * 0.5 + Vector2(0, 1), type, half)


static func draw_cube(ci: CanvasItem, c: Vector2, t: String, h: float) -> void:
	var k := h / 12.0
	var top := PackedVector2Array([c + Vector2(0, -12) * k, c + Vector2(12, -6) * k, c + Vector2(0, 0) * k, c + Vector2(-12, -6) * k])
	var left := PackedVector2Array([c + Vector2(-12, -6) * k, c + Vector2(0, 0) * k, c + Vector2(0, 12) * k, c + Vector2(-12, 6) * k])
	var right := PackedVector2Array([c + Vector2(0, 0) * k, c + Vector2(12, -6) * k, c + Vector2(12, 6) * k, c + Vector2(0, 12) * k])
	var side := Materials.side_color(t)
	var line := side.darkened(0.5)
	if CustomBlocks.is_custom(t):
		var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		var top_tex := CustomBlocks.texture(t, CustomBlocks.FACE_TOP)
		var side_tex := CustomBlocks.texture(t, CustomBlocks.FACE_SIDE)
		var w := Color.WHITE
		ci.draw_polygon(left, PackedColorArray([w, w, w, w]), uv, side_tex)
		var d := Color(0.8, 0.8, 0.8)
		ci.draw_polygon(right, PackedColorArray([d, d, d, d]), uv, side_tex)
		ci.draw_polygon(PackedVector2Array([top[0], top[1], top[2], top[3]]), PackedColorArray([w, w, w, w]), uv, top_tex)
	else:
		ci.draw_colored_polygon(left, side.darkened(0.05))
		ci.draw_colored_polygon(right, side.darkened(0.2))
		ci.draw_colored_polygon(top, Materials.top_color(t))
	for poly in [top, left, right]:
		var closed: PackedVector2Array = poly.duplicate()
		closed.append(poly[0])
		ci.draw_polyline(closed, line, 1.4, true)
