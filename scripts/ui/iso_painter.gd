class_name IsoPainter
extends RefCounted
## 在等角畫面上畫植物與動物（簡單向量圖形，之後可換成美術圖）。
## 顏色會依褪色程度變灰，並套用透明度（目前樓層以上的東西會變淡）。

var ci: CanvasItem
var fade := 0.0
var alpha := 1.0


func _init(canvas: CanvasItem) -> void:
	ci = canvas


func col(c: Color) -> Color:
	var l := c.get_luminance()
	var out := c.lerp(Color(l, l, l, c.a), fade)
	out.a = c.a * alpha
	return out


func circle(center: Vector2, r: float, c: Color) -> void:
	ci.draw_circle(center, r, col(c))


func ellipse(center: Vector2, rx: float, ry: float, c: Color, segments: int = 18) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var t := TAU * i / segments
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	ci.draw_colored_polygon(pts, col(c))


func line(a: Vector2, b: Vector2, c: Color, width: float = 2.0) -> void:
	ci.draw_line(a, b, col(c), width, true)


func poly(points: PackedVector2Array, c: Color) -> void:
	ci.draw_colored_polygon(points, col(c))


# --- 植物 ---------------------------------------------------------------

## at：方塊頂面中心。
func plant(id: String, at: Vector2) -> void:
	match id:
		"flower":
			for o in [Vector2(-8, 2), Vector2(6, -2), Vector2(0, 6)]:
				var top: Vector2 = at + o + Vector2(0, -12)
				line(at + o, top, Color("4f9a3a"), 2)
				for k in 5:
					var a := TAU * k / 5
					circle(top + Vector2(cos(a), sin(a)) * 3.5, 2.6, Color("f48fb1"))
				circle(top, 2.2, Color("ffd54f"))
		"shrub":
			ellipse(at + Vector2(0, 1), 13, 6, Color(0, 0, 0, 0.15))
			circle(at + Vector2(-6, -6), 7, Color("3f8f3a"))
			circle(at + Vector2(6, -6), 7, Color("3f8f3a"))
			circle(at + Vector2(0, -11), 8, Color("55a84a"))
		"fruit_tree":
			ellipse(at + Vector2(0, 1), 12, 5, Color(0, 0, 0, 0.15))
			poly(PackedVector2Array([at + Vector2(-2.5, 0), at + Vector2(2.5, 0),
				at + Vector2(2, -20), at + Vector2(-2, -20)]), Color("7b5232"))
			circle(at + Vector2(0, -28), 13, Color("4c9a3f"))
			circle(at + Vector2(-6, -33), 8, Color("5fb04f"))
			for o in [Vector2(-6, -24), Vector2(5, -29), Vector2(1, -21), Vector2(7, -22)]:
				circle(at + o, 2.4, Color("e53935"))
		"mushroom":
			for m in [[Vector2(-5, 1), 1.0], [Vector2(6, -1), 0.7]]:
				var p: Vector2 = at + m[0]
				var s: float = m[1]
				poly(PackedVector2Array([p + Vector2(-2.5, 0) * s, p + Vector2(2.5, 0) * s,
					p + Vector2(2, -9) * s, p + Vector2(-2, -9) * s]), Color("f3ead8"))
				ellipse(p + Vector2(0, -10) * s, 8 * s, 5 * s, Color("d84a3a"))
				circle(p + Vector2(-3, -11) * s, 1.4 * s, Color.WHITE)
				circle(p + Vector2(3, -10) * s, 1.2 * s, Color.WHITE)
		"water_lily":
			ellipse(at + Vector2(-4, 2), 10, 5, Color("4c9a3f"))
			ellipse(at + Vector2(7, -3), 6, 3, Color("5fb04f"))
			for k in 6:
				var a := TAU * k / 6
				ellipse(at + Vector2(-4, -1) + Vector2(cos(a) * 3, sin(a) * 1.5), 2.6, 1.8, Color("f8bbd0"))
			circle(at + Vector2(-4, -2), 1.8, Color("ffd54f"))
		"waterweed":
			for x in [-7, -2, 4, 9]:
				var base: Vector2 = at + Vector2(x, 3)
				var pts := PackedVector2Array()
				for k in 5:
					pts.append(base + Vector2(sin(k * 1.3 + x) * 2.5, -k * 4))
				ci.draw_polyline(pts, col(Color("2e8b57")), 2.0, true)
		"reed":
			for x in [-8, -3, 2, 7]:
				var base: Vector2 = at + Vector2(x, 2 + absf(x) * 0.2)
				var top := base + Vector2(x * 0.3, -26 - (x % 3) * 3)
				line(base, top, Color("7da453"), 1.6)
				ellipse(top + Vector2(0, 3), 1.8, 4, Color("8d5a3b"))
		"moss":
			for o in [Vector2(-9, 0), Vector2(4, -4), Vector2(2, 5), Vector2(10, 2), Vector2(-3, -6)]:
				ellipse(at + o, 6, 3, Color("6f9e3a"))
				ellipse(at + o + Vector2(-1, -1), 3, 1.5, Color("8cbf4f"))
		"succulent":
			for k in 8:
				var a := TAU * k / 8
				ellipse(at + Vector2(cos(a) * 6, sin(a) * 3 - 3), 4, 2.6, Color("6fae9a"))
			for k in 5:
				var a := TAU * k / 5 + 0.4
				ellipse(at + Vector2(cos(a) * 3, sin(a) * 1.5 - 5), 3, 2, Color("8fd0b8"))
			circle(at + Vector2(0, -6), 1.6, Color("e57373"))
		"alpine_flower":
			for f in [[Vector2(-7, 2), Color("ba68c8")], [Vector2(3, -3), Color("fff176")],
					[Vector2(8, 3), Color("9575cd")], [Vector2(-1, 5), Color("fff176")]]:
				var p: Vector2 = at + f[0]
				line(p, p + Vector2(0, -6), Color("6b8f3a"), 1.5)
				circle(p + Vector2(0, -7), 2.4, f[1])
		"cactus":
			var c := Color("3f9a5a")
			poly(PackedVector2Array([at + Vector2(-4, 1), at + Vector2(4, 1),
				at + Vector2(4, -22), at + Vector2(-4, -22)]), c)
			circle(at + Vector2(0, -22), 4, c)
			poly(PackedVector2Array([at + Vector2(-4, -10), at + Vector2(-10, -10),
				at + Vector2(-10, -17), at + Vector2(-7, -17), at + Vector2(-7, -13), at + Vector2(-4, -13)]), c)
			poly(PackedVector2Array([at + Vector2(4, -6), at + Vector2(10, -6),
				at + Vector2(10, -14), at + Vector2(7, -14), at + Vector2(7, -9), at + Vector2(4, -9)]), c)
			circle(at + Vector2(0, -26), 1.8, Color("f06292"))
		"palm":
			var trunk := PackedVector2Array()
			for k in 7:
				trunk.append(at + Vector2(sin(k * 0.35) * 5, -k * 5.5))
			ci.draw_polyline(trunk, col(Color("8d6e4a")), 3.5, true)
			var crown: Vector2 = trunk[trunk.size() - 1]
			for a in [-2.8, -2.2, -1.5, -0.9, -0.3]:
				var tip := crown + Vector2(cos(a) * 16, sin(a) * 7 + 8)
				var mid := crown + Vector2(cos(a) * 9, sin(a) * 7 - 1)
				ci.draw_polyline(PackedVector2Array([crown, mid, tip]), col(Color("3f9a4a")), 3.0, true)
			circle(crown + Vector2(-2, 3), 2.4, Color("6d4c2f"))
			circle(crown + Vector2(2, 3), 2.4, Color("6d4c2f"))


# --- 動物 ---------------------------------------------------------------

## at：動物腳下（方塊頂面上的點）。flip：面向左邊。
func animal(species: String, at: Vector2, flip: bool, confused: bool, bob: float) -> void:
	var s := -1.0 if flip else 1.0
	var p := at + Vector2(0, -bob)
	match species:
		"sheep":
			ellipse(at + Vector2(0, 1), 10, 4, Color(0, 0, 0, 0.15))
			for x in [-5, 4]:
				line(p + Vector2(x * s, -2), p + Vector2(x * s, 1), Color("4a4a4a"), 2)
			for o in [Vector2(-5, -8), Vector2(0, -10), Vector2(5, -8), Vector2(-2, -6), Vector2(3, -6)]:
				circle(p + Vector2(o.x * s, o.y), 5, Color("fafafa"))
			ellipse(p + Vector2(9 * s, -9), 3.6, 3, Color("3d3d3d"))
			circle(p + Vector2(10 * s, -10), 0.9, Color.WHITE)
		"fish":
			var body := p + Vector2(0, 2)
			ellipse(body, 7, 3.5, Color("ff8a3d"))
			poly(PackedVector2Array([body + Vector2(-6 * s, 0), body + Vector2(-11 * s, -4),
				body + Vector2(-11 * s, 4)]), Color("ff7043"))
			circle(body + Vector2(3.5 * s, -0.8), 1, Color("263238"))
		"lizard":
			ellipse(at + Vector2(0, 1), 9, 3, Color(0, 0, 0, 0.15))
			var tail := PackedVector2Array([p + Vector2(-5 * s, -2), p + Vector2(-10 * s, 0),
				p + Vector2(-14 * s, -1)])
			ci.draw_polyline(tail, col(Color("7cb342")), 2.0, true)
			for x in [-3, 3]:
				line(p + Vector2(x * s, -2), p + Vector2((x + 1.5) * s, 1), Color("558b2f"), 1.5)
			ellipse(p + Vector2(0, -3), 6, 2.6, Color("8bc34a"))
			ellipse(p + Vector2(6 * s, -3.5), 3, 2.2, Color("8bc34a"))
			circle(p + Vector2(7 * s, -4.2), 0.8, Color("263238"))
		"hermit_crab":
			ellipse(at + Vector2(0, 1), 8, 3, Color(0, 0, 0, 0.15))
			for x in [-2, 2, 5]:
				line(p + Vector2(x * s, -2), p + Vector2((x + 2) * s, 1), Color("e64a19"), 1.4)
			circle(p + Vector2(-2 * s, -6), 6, Color("d7a86e"))
			circle(p + Vector2(-2 * s, -6), 3.5, Color("c28e52"))
			circle(p + Vector2(-2 * s, -6), 1.5, Color("a87440"))
			circle(p + Vector2(5 * s, -3), 2.6, Color("ef5350"))
			circle(p + Vector2(7 * s, -6), 1, Color("263238"))
	if confused:
		var b := at + Vector2(0, -30)
		circle(b, 7, Color(1, 1, 1, 0.95))
		var font := ThemeDB.fallback_font
		ci.draw_string(font, b + Vector2(-3.5, 4.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col(Color("e65100")))
