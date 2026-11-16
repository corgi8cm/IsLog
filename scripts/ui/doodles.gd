class_name Doodles
extends RefCounted
## 手帳風格的背景：點點紙張，以及依時段畫在紙上的太陽、月亮、星星塗鴉。

const INK_DAY := Color("8a6a50")
const INK_NIGHT := Color("f3e6cf")
const DOT_GAP := 28.0


static func ink(night: float) -> Color:
	return INK_NIGHT if night >= 0.5 else INK_DAY


## 點點紙。fade：島褪色時紙也跟著淡一點。
static func paper(ci: CanvasItem, rect: Rect2, minutes: int, fade := 0.0) -> void:
	var bg := DayCycle.paper(minutes)
	var dot := DayCycle.dots(minutes)
	if fade > 0.0:
		var l := bg.get_luminance()
		bg = bg.lerp(Color(l, l, l), fade * 0.5)
		dot = dot.lerp(Color(l, l, l), fade * 0.5)
	ci.draw_rect(rect, bg)
	var y := rect.position.y + DOT_GAP * 0.5
	while y < rect.end.y:
		var x := rect.position.x + DOT_GAP * 0.5
		while x < rect.end.x:
			ci.draw_circle(Vector2(x, y), 1.4, dot)
			x += DOT_GAP
		y += DOT_GAP


## 依時段在 at 附近畫天空塗鴉。
static func sky(ci: CanvasItem, at: Vector2, minutes: int, fade := 0.0) -> void:
	var night := DayCycle.night_amount(minutes)
	var line := ink(night)
	var a := 1.0 - fade * 0.6
	match DayCycle.phase(minutes):
		DayCycle.MORNING:
			sun(ci, at + Vector2(-60, 40), 40, Color(Color("f6b48f"), a), Color(line, a), true)
			for i in 3:
				var y := at.y + 70.0 + i * 20
				wobble(ci, Vector2(at.x - 170 + i * 30, y), Vector2(at.x + 60 - i * 20, y), Color(line, 0.35 * a))
		DayCycle.DAY:
			sun(ci, at + Vector2(-40, 0), 34, Color(Color("f7d27a"), a), Color(line, a), false)
			cloud(ci, at + Vector2(110, 50), Color(line, a))
		DayCycle.EVENING:
			sun(ci, at + Vector2(0, 60), 46, Color(Color("f2925a"), a), Color(line, a), true)
			for b in [Vector2(-110, -10), Vector2(-70, -34), Vector2(130, 10)]:
				var p: Vector2 = at + b
				wobble(ci, p + Vector2(-9, -4), p, Color(line, a))
				wobble(ci, p, p + Vector2(9, -4), Color(line, a))
		_:
			moon(ci, at, 38, Color(line, a))
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in 14:
				var q := at + Vector2(rng.randf_range(-220, 220), rng.randf_range(-90, 140))
				if q.distance_to(at) < 64:
					continue
				star(ci, q, rng.randf_range(4, 8), Color(Color("f7d98a"), a))


static func wobble(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, w := 2.2) -> void:
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		var n := (b - a).orthogonal().normalized() * sin(t * 9.0 + a.x) * 1.2
		pts.append(a.lerp(b, t) + n)
	ci.draw_polyline(pts, c, w, true)


static func sun(ci: CanvasItem, c: Vector2, r: float, fill: Color, line: Color, half: bool) -> void:
	if half:
		var pts := PackedVector2Array()
		for i in 21:
			var t := PI + PI * i / 20.0
			pts.append(c + Vector2(cos(t), sin(t)) * r)
		ci.draw_colored_polygon(pts, fill)
		ci.draw_polyline(pts, line, 2.4, true)
		wobble(ci, c + Vector2(-r - 40, 0), c + Vector2(r + 40, 0), line)
		for i in 7:
			var t := PI + PI * (i + 0.5) / 7.0
			var d := Vector2(cos(t), sin(t))
			wobble(ci, c + d * (r + 10), c + d * (r + 22), line)
	else:
		ci.draw_circle(c, r, fill)
		ci.draw_arc(c, r, 0, TAU, 40, line, 2.4, true)
		for i in 10:
			var d := Vector2.from_angle(TAU * i / 10.0)
			wobble(ci, c + d * (r + 9), c + d * (r + 21), line)


static func cloud(ci: CanvasItem, c: Vector2, line: Color) -> void:
	var parts := [Vector2(-20, 4), Vector2(0, -7), Vector2(22, 2)]
	for o in parts:
		ci.draw_circle(c + o, 18, Color(1, 1, 1, 0.9 * line.a))
	for o in parts:
		ci.draw_arc(c + o, 18, PI * 0.95, PI * 2.05, 16, line, 2.0, true)


static func moon(ci: CanvasItem, c: Vector2, r: float, line: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := -PI * 0.5 + PI * i / 24.0
		pts.append(c + Vector2(cos(t), sin(t)) * r)
	for i in 25:
		var t := PI * 0.5 - PI * i / 24.0
		pts.append(c + Vector2(cos(t) * r * 0.45, sin(t) * r))
	ci.draw_colored_polygon(pts, Color(Color("f7e3a8"), line.a))
	pts.append(pts[0])
	ci.draw_polyline(pts, line, 2.4, true)


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(c + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * rr)
	ci.draw_colored_polygon(pts, col)


## 螢火蟲的光。
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, strength := 1.0) -> void:
	for i in 6:
		var k := 1.0 - i / 6.0
		ci.draw_circle(c, r * (0.3 + k), Color(col, (0.08 + 0.02 * i) * strength))
	ci.draw_circle(c, r * 0.25, Color(1, 1, 0.85, 0.95 * strength))
