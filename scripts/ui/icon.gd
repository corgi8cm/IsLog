class_name Icon
extends Control
## 線條圖示（手繪感的簡單圖形），顏色跟著主題的墨水色，換日夜時自動重畫。

var kind := "":
	set(v):
		kind = v
		queue_redraw()
## UiKit 的顏色名稱（ink / accent / muted ...）。
var role := "ink":
	set(v):
		role = v
		queue_redraw()
## 圖示大小（設計稿以 40×40 為準）。
var icon_size := 40.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var col := UiKit.color(role)
	var k := icon_size / 40.0
	draw_set_transform(size * 0.5, 0.0, Vector2(k, k))
	draw_glyph(self, kind, col)
	draw_set_transform(Vector2.ZERO)


## 在 ci 的原點畫圖示（範圍約 ±18）。
static func draw_glyph(ci: CanvasItem, what: String, col: Color) -> void:
	var w := 3.0
	match what:
		"rotate":
			ci.draw_arc(Vector2.ZERO, 13, -2.6, 1.6, 20, col, w, true)
			var tip := Vector2(cos(1.6), sin(1.6)) * 13
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, -2), tip + Vector2(4, -6), tip + Vector2(2, 6)]), col)
		"zoom_in", "zoom_out":
			ci.draw_arc(Vector2(-3, -3), 10, 0, TAU, 24, col, w, true)
			ci.draw_line(Vector2(4, 4), Vector2(12, 12), col, w + 1, true)
			ci.draw_line(Vector2(-8, -3), Vector2(2, -3), col, 2.5, true)
			if what == "zoom_in":
				ci.draw_line(Vector2(-3, -8), Vector2(-3, 2), col, 2.5, true)
		"center":
			ci.draw_arc(Vector2.ZERO, 10, 0, TAU, 24, col, w, true)
			ci.draw_circle(Vector2.ZERO, 3.5, col)
			for v in [Vector2(0, -1), Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0)]:
				ci.draw_line(v * 12, v * 17, col, w, true)
		"book":
			ci.draw_rect(Rect2(Vector2(-13, -14), Vector2(26, 28)), col, false, w)
			ci.draw_line(Vector2(-7, -14), Vector2(-7, 14), col, w)
			ci.draw_circle(Vector2(4, -2), 4, col)
		"camera":
			_round_rect(ci, Rect2(-15, -9, 30, 22), 5, col, w)
			ci.draw_rect(Rect2(-6, -14, 12, 5), col)
			ci.draw_arc(Vector2(0, 2), 6, 0, TAU, 20, col, w, true)
		"islands":
			# 兩座小浮島
			for o in [[Vector2(-6, -4), 1.0], [Vector2(9, 8), 0.6]]:
				var c: Vector2 = o[0]
				var k: float = o[1]
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-11, 0) * k, c + Vector2(11, 0) * k, c + Vector2(0, 12) * k]), Color(col, 0.6))
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5) * k, c + Vector2(11, 0) * k, c + Vector2(0, 5) * k, c + Vector2(-11, 0) * k]), col)
		"up", "down":
			var dy := 1.0 if what == "up" else -1.0
			ci.draw_polyline(PackedVector2Array([Vector2(-10, 5 * dy), Vector2(0, -5 * dy), Vector2(10, 5 * dy)]), col, 3.5, true)
		"events":
			for i in 3:
				var y := -10 + i * 10
				ci.draw_rect(Rect2(Vector2(-14, y - 3), Vector2(6, 6)), col, false, 2)
				ci.draw_line(Vector2(-4, y), Vector2(14, y), col, 2.5)
		"island":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(16, -4), Vector2(0, 4), Vector2(-16, -4)]), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-16, -4), Vector2(0, 4), Vector2(16, -4), Vector2(0, 16)]), Color(col, 0.6))
		"review":
			_round_rect(ci, Rect2(-14, -12, 28, 26), 4, col, w)
			ci.draw_line(Vector2(-14, -4), Vector2(14, -4), col, 3)
			for i in 3:
				ci.draw_circle(Vector2(-7 + i * 7, 5), 2.2, col)
		"plant":
			ci.draw_line(Vector2(0, 14), Vector2(0, -2), col, 3, true)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-12, -6), Vector2(-4, -14)]), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(12, -12), Vector2(6, -2)]), col)
		"lamp":
			ci.draw_line(Vector2(0, 16), Vector2(0, -2), col, 3, true)
			ci.draw_line(Vector2(-6, 16), Vector2(6, 16), col, 3, true)
			ci.draw_polyline(PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(5, -11), Vector2(-5, -11), Vector2(-6, -2)]), col, 2.5, true)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -11), Vector2(8, -11), Vector2(0, -17)]), col)
			for a in [-0.5, 0.0, 0.5]:
				var d := Vector2(sin(a), -cos(a) * 0.4)
				ci.draw_line(Vector2(0, -6) + Vector2(d.x * 11, 0), Vector2(0, -6) + Vector2(d.x * 16, 0), col, 2, true)
		"brush":
			ci.draw_line(Vector2(-10, 12), Vector2(8, -10), col, 4, true)
			ci.draw_circle(Vector2(-11, 13), 4, col)
		"erase", "close":
			ci.draw_line(Vector2(-10, -10), Vector2(10, 10), col, 4, true)
			ci.draw_line(Vector2(10, -10), Vector2(-10, 10), col, 4, true)
		"plus":
			ci.draw_line(Vector2(-12, 0), Vector2(12, 0), col, 4.5, true)
			ci.draw_line(Vector2(0, -12), Vector2(0, 12), col, 4.5, true)
		"more":
			for i in 3:
				ci.draw_circle(Vector2(-10 + i * 10, 0), 3.2, col)
		"check":
			ci.draw_polyline(PackedVector2Array([Vector2(-11, 0), Vector2(-3, 8), Vector2(12, -9)]), col, 4, true)
		"clock":
			ci.draw_arc(Vector2.ZERO, 14, 0, TAU, 32, col, w, true)
			ci.draw_line(Vector2.ZERO, Vector2(0, -8), col, w, true)
			ci.draw_line(Vector2.ZERO, Vector2(6, 4), col, w, true)
		"bell":
			ci.draw_arc(Vector2(0, -1), 10, PI, TAU, 16, col, w, true)
			ci.draw_line(Vector2(-10, -1), Vector2(-12, 10), col, w, true)
			ci.draw_line(Vector2(10, -1), Vector2(12, 10), col, w, true)
			ci.draw_line(Vector2(-14, 10), Vector2(14, 10), col, w, true)
			ci.draw_circle(Vector2(0, 14), 3, col)
		"account":
			ci.draw_arc(Vector2(0, -6), 7, 0, TAU, 20, col, w, true)
			ci.draw_arc(Vector2(0, 16), 14, PI * 1.15, PI * 1.85, 16, col, w, true)
		"sun":
			ci.draw_circle(Vector2.ZERO, 9, Color("f7d27a"))
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(d * 12, d * 16, Color("e0a93a"), 2.5, true)
		"sunrise", "sunset":
			var pts := PackedVector2Array()
			for i in 13:
				var t := PI + PI * i / 12.0
				pts.append(Vector2(0, 6) + Vector2(cos(t), sin(t)) * 11)
			ci.draw_colored_polygon(pts, Color("f6b48f") if what == "sunrise" else Color("f2925a"))
			ci.draw_line(Vector2(-16, 6), Vector2(16, 6), col, 2.5, true)
		"moon":
			var pts := PackedVector2Array()
			for i in 17:
				var t := -PI * 0.5 + PI * i / 16.0
				pts.append(Vector2(cos(t), sin(t)) * 14)
			for i in 17:
				var t := PI * 0.5 - PI * i / 16.0
				pts.append(Vector2(cos(t) * 3.0, sin(t) * 14))
			ci.draw_colored_polygon(pts, Color("f7e3a8"))


static func _round_rect(ci: CanvasItem, r: Rect2, radius: float, col: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(int(radius))
	sb.border_color = col
	sb.set_border_width_all(int(w))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)
