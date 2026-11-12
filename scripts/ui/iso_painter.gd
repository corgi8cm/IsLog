class_name IsoPainter
extends RefCounted
## 在等角畫面上畫植物與動物（簡單向量圖形，之後可換成美術圖）。
## 顏色會依褪色程度變灰，並套用透明度（目前樓層以上的東西會變淡）。

var ci: CanvasItem
var fade := 0.0
var alpha := 1.0
## 剪影模式：圖鑑裡還沒來過的動物只畫出深色輪廓。
var silhouette := false


func _init(canvas: CanvasItem) -> void:
	ci = canvas


func col(c: Color) -> Color:
	if silhouette:
		return Color(0.32, 0.36, 0.42, c.a * alpha) if c.a > 0.5 else Color(0, 0, 0, 0)
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
		"rabbit":
			ellipse(at + Vector2(0, 1), 8, 3, Color(0, 0, 0, 0.15))
			ellipse(p + Vector2(-1 * s, -5), 6, 4.5, Color("f5efe6"))
			circle(p + Vector2(-6 * s, -6), 2.4, Color.WHITE)
			circle(p + Vector2(5 * s, -9), 3.6, Color("f5efe6"))
			ellipse(p + Vector2(4 * s, -16), 1.4, 4.5, Color("f5efe6"))
			ellipse(p + Vector2(7 * s, -15.5), 1.4, 4.5, Color("f5efe6"))
			ellipse(p + Vector2(4 * s, -16), 0.6, 3, Color("f4b6c2"))
			circle(p + Vector2(7 * s, -9.5), 0.9, Color("263238"))
		"corgi":
			ellipse(at + Vector2(0, 1), 12, 4, Color(0, 0, 0, 0.15))
			_corgi(p, s)
		"turtle":
			var body := p + Vector2(0, 1)
			for o in [Vector2(-6, 1), Vector2(6, 1), Vector2(-5, -2), Vector2(5, -2)]:
				ellipse(body + Vector2(o.x * s, o.y), 2.2, 1.4, Color("8bbf6a"))
			ellipse(body + Vector2(8 * s, -1), 2.8, 2.2, Color("8bbf6a"))
			ellipse(body + Vector2(0, -2), 7, 4, Color("5d8a3c"))
			ellipse(body + Vector2(-1 * s, -3), 4, 2.2, Color("74a64d"))
			circle(body + Vector2(9 * s, -1.6), 0.7, Color("263238"))
		"duck":
			var body := p + Vector2(0, 1)
			ellipse(body + Vector2(0, -3), 7, 4, Color("fafafa"))
			poly(PackedVector2Array([body + Vector2(-6 * s, -4), body + Vector2(-10 * s, -7),
				body + Vector2(-7 * s, -2)]), Color("eeeeee"))
			circle(body + Vector2(5 * s, -9), 3.4, Color("fafafa"))
			poly(PackedVector2Array([body + Vector2(7.5 * s, -9.5), body + Vector2(11 * s, -8.5),
				body + Vector2(7.5 * s, -7.5)]), Color("ffa726"))
			circle(body + Vector2(6 * s, -10), 0.8, Color("263238"))
		"goat":
			ellipse(at + Vector2(0, 1), 10, 4, Color(0, 0, 0, 0.15))
			for x in [-5, -2, 3, 6]:
				line(p + Vector2(x * s, -3), p + Vector2(x * s, 1), Color("5d4a3a"), 1.8)
			ellipse(p + Vector2(0, -7), 8, 4.5, Color("ece7df"))
			ellipse(p + Vector2(8 * s, -11), 3, 3.6, Color("ece7df"))
			ci.draw_polyline(PackedVector2Array([p + Vector2(7 * s, -14), p + Vector2(5 * s, -18),
				p + Vector2(3 * s, -17)]), col(Color("8d7b68")), 1.8, true)
			line(p + Vector2(9 * s, -8), p + Vector2(9 * s, -5), Color("cfc6b8"), 1.6)
			circle(p + Vector2(9 * s, -11.5), 0.8, Color("263238"))
		"crab":
			ellipse(at + Vector2(0, 1), 9, 3, Color(0, 0, 0, 0.15))
			for x in [-6, -4, 4, 6]:
				line(p + Vector2(x, -2), p + Vector2(x * 1.4, 1), Color("c62828"), 1.4)
			ellipse(p + Vector2(0, -4), 7, 4, Color("e53935"))
			for x in [-1, 1]:
				line(p + Vector2(x * 5, -6), p + Vector2(x * 9, -10), Color("e53935"), 1.6)
				circle(p + Vector2(x * 10, -11), 2.6, Color("ef5350"))
				line(p + Vector2(x * 2, -7), p + Vector2(x * 2, -10), Color("c62828"), 1)
				circle(p + Vector2(x * 2, -10.5), 1, Color("263238"))
	if confused:
		var b := at + Vector2(0, -30)
		circle(b, 7, Color(1, 1, 1, 0.95))
		var font := ThemeDB.fallback_font
		ci.draw_string(font, b + Vector2(-3.5, 4.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col(Color("e65100")))


# --- 柯基（吐司趴姿、側臉、張嘴笑）-------------------------------------------
# 座標沿用圖示原稿（512×512），(255, 438) 是腳底中心，再縮小成遊戲裡的大小。

const CORGI_SCALE := 0.05
const CORGI_LINE := 0.45
const CORGI_ORANGE := Color("e9963f")
const CORGI_DARK := Color("c97a2e")
const CORGI_CREAM := Color("fff6e8")
const CORGI_OUTLINE := Color("2b3a4a")
const CORGI_PINK := Color("f4a3a3")

var _cp := Vector2.ZERO
var _cs := 1.0


func _q(x: float, y: float) -> Vector2:
	return _cp + Vector2((x - 255.0) * CORGI_SCALE * _cs, (y - 438.0) * CORGI_SCALE)


func _c_ellipse(x: float, y: float, rx: float, ry: float, c: Color, outlined := false) -> void:
	var k := CORGI_SCALE
	if outlined:
		ellipse(_q(x, y), rx * k + CORGI_LINE, ry * k + CORGI_LINE, CORGI_OUTLINE)
	ellipse(_q(x, y), rx * k, ry * k, c)


func _c_capsule(x0: float, x1: float, cy: float, r: float, c: Color, outlined := false) -> void:
	var layers := [[CORGI_OUTLINE, CORGI_LINE], [c, 0.0]] if outlined else [[c, 0.0]]
	for layer in layers:
		var grow: float = layer[1]
		var rr := r * CORGI_SCALE + grow
		circle(_q(x0 + r, cy), rr, layer[0])
		circle(_q(x1 - r, cy), rr, layer[0])
		var a := _q(x0 + r, cy)
		var b := _q(x1 - r, cy)
		poly(PackedVector2Array([a + Vector2(0, -rr), b + Vector2(0, -rr), b + Vector2(0, rr), a + Vector2(0, rr)]), layer[0])


## 圓頭的耳朵：尖端改成弧線（和圖示原稿相同的算法）。
const EAR_ROUND := 0.55
const EAR_SHRINK := 0.88


func _c_ear(a: Vector2, tip: Vector2, b: Vector2, c: Color, outlined := false) -> void:
	var mid := (a + b) * 0.5
	var t := mid + (tip - mid) * EAR_SHRINK
	var a2 := a + (t - a) * EAR_ROUND
	var b2 := b + (t - b) * EAR_ROUND
	var pts := [a]
	for i in 9:
		var k := i / 8.0
		pts.append(a2.lerp(t, k).lerp(t.lerp(b2, k), k))
	pts.append(b)
	var v := PackedVector2Array()
	for q in pts:
		v.append(_q(q.x, q.y))
	if outlined:
		var center := Vector2.ZERO
		for q in v:
			center += q
		center /= v.size()
		var big := PackedVector2Array()
		for q in v:
			big.append(q + (q - center).normalized() * CORGI_LINE * 1.6)
		poly(big, CORGI_OUTLINE)
	poly(v, c)


func _corgi(p: Vector2, s: float) -> void:
	_cp = p
	_cs = s
	# 身體、肚子、腳、尾巴
	_c_capsule(50, 380, 335, 85, CORGI_ORANGE, true)
	_c_capsule(90, 350, 395, 25, CORGI_CREAM)
	_c_ellipse(130, 420, 34, 18, CORGI_CREAM, true)
	_c_ellipse(310, 420, 34, 18, CORGI_CREAM, true)
	_c_ellipse(50, 300, 26, 22, CORGI_ORANGE, true)
	# 耳朵（耳根被頭蓋住）
	_c_ear(Vector2(298, 230), Vector2(308, 140), Vector2(354, 210), CORGI_DARK, true)
	_c_ear(Vector2(330, 220), Vector2(364, 130), Vector2(402, 218), CORGI_ORANGE, true)
	# 頭
	_c_ellipse(360, 260, 72, 64, CORGI_ORANGE, true)
	_c_ear(Vector2(350, 194), Vector2(366, 150), Vector2(384, 194), CORGI_PINK)
	# 額頭白線（斜的橢圓）
	var blaze := PackedVector2Array()
	for i in 14:
		var t := TAU * i / 14.0
		var lx := cos(t) * 34.0
		var ly := sin(t) * 11.0
		blaze.append(_q(402 + lx * 0.5 - ly * 0.866, 242 + lx * 0.866 + ly * 0.5))
	poly(blaze, CORGI_CREAM)
	_c_ellipse(390, 294, 46, 26, CORGI_CREAM)
	# 嘴巴：張開笑、吐舌頭
	_c_ellipse(421.8, 272, 36.6, 22.2, CORGI_CREAM, true)
	_c_ellipse(409.8, 278, 34.6, 18.2, CORGI_CREAM)
	var mouth := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var a := Vector2(401, 286)
		var c := Vector2(424.7, 318.4)
		var b := Vector2(450.4, 282)
		var m := a.lerp(c, t).lerp(c.lerp(b, t), t)
		mouth.append(_q(m.x, m.y))
	poly(mouth, Color("5a2a2a"))
	_c_ellipse(427.7, 298.6, 12.6, 8.1, Color("ff8a8a"))
	_c_ellipse(454.4, 266, 11, 9, Color("263238"))
	# 眼睛與腮紅
	_c_ellipse(400, 246, 13, 15, Color("263238"))
	_c_ellipse(404, 241, 5, 5, Color.WHITE)
	_c_ellipse(382, 280, 15, 8, Color(CORGI_PINK, 0.75))
