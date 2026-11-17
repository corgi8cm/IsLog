extends Control
## 等角島嶼畫面：繪製方塊、目前樓層格線；處理拖曳、縮放、點選。

signal cell_tapped(screen_pos: Vector2)

const TAP_SLOP := 14.0
const MIN_ZOOM := 0.4
const MAX_ZOOM := 3.0
const ABOVE_ALPHA := 0.22
const OUTLINE := 1.4
## 動物、植物畫得比方塊比例大一點，才看得清楚。
const ANIMAL_SCALE := 1.5
const PLANT_SCALE := 1.25
const LIGHT_SCALE := 1.0

var layer := 0:
	set(v):
		layer = clampi(v, 0, IslandData.SIZE - 1)
		queue_redraw()
var rotation_step := 0:
	set(v):
		rotation_step = posmod(v, 4)
		queue_redraw()
var zoom := 1.0:
	set(v):
		zoom = clampf(v, MIN_ZOOM, MAX_ZOOM)
		queue_redraw()
## 拍照模式：不畫格線與外框，所有樓層都完整顯示。
var photo_mode := false:
	set(v):
		photo_mode = v
		queue_redraw()
var pan := Vector2.ZERO:
	set(v):
		pan = v
		queue_redraw()

var _hover := Vector2(-1, -1)
var _pressing := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _touches := {}
var _pinching := false
var _pinch_dist := 0.0
var _pinch_zoom := 1.0
var _painter := IsoPainter.new(self)
## 動物目前畫在哪裡（格子座標，可為小數），漫步時慢慢移向目標格。
var _animal_draw_pos := {}
var _animal_flip := {}
var _animal_moving := {}
var _time := 0.0
var _fx_clock := 0.0
var _night := 0.0
var _base := Transform2D()
## 旋轉座標 → 方塊種類（每次重畫時建立，用來判斷哪些面露在外面）。
var _rot_blocks := {}


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	Game.changed.connect(queue_redraw)
	Game.animals_moved.connect(queue_redraw)
	Game.daytime_changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	# 夜晚的螢火蟲會飄：大約每秒重畫 15 次
	if _night >= 0.5:
		_fx_clock += delta
		if _fx_clock > 1.0 / 15.0:
			_fx_clock = 0.0
			queue_redraw()
	if Game.island.animals.is_empty():
		return
	var any_moving := false
	var alive := {}
	for a in Game.island.animals:
		alive[a.id] = true
		var target := Vector3(a.pos.x, a.pos.y, a.pos.z)
		var cur: Vector3 = _animal_draw_pos.get(a.id, target)
		# 距離太遠（例如換了一座島）直接跳過去
		if cur.distance_to(target) > 2.5:
			cur = target
		var moving := cur.distance_to(target) > 0.001
		_animal_moving[a.id] = moving
		any_moving = any_moving or moving
		if moving:
			var next := cur.move_toward(target, delta * 1.2)
			var before := Iso.to_screen(cur.x, cur.y, cur.z)
			var after := Iso.to_screen(next.x, next.y, next.z)
			if absf(after.x - before.x) > 0.0001:
				_animal_flip[a.id] = after.x < before.x
			cur = next
		_animal_draw_pos[a.id] = cur
	for id in _animal_draw_pos.keys():
		if not alive.has(id):
			_animal_draw_pos.erase(id)
			_animal_moving.erase(id)
	# 只有動物在走的時候才每幀重畫，省電。
	if any_moving:
		queue_redraw()


# --- 座標換算 -------------------------------------------------------------

func _origin() -> Vector2:
	var n := IslandData.SIZE
	return size * 0.5 + pan - Iso.to_screen(n * 0.5, n * 0.5, n * 0.35) * zoom


func to_iso(local_pos: Vector2) -> Vector2:
	return (local_pos - _origin()) / zoom


## 點選目前樓層地板的格子（格子座標，可能超出範圍）。
func floor_cell_at(local_pos: Vector2) -> Vector3i:
	var c := Iso.pick_floor(to_iso(local_pos), layer, rotation_step)
	return Vector3i(c.x, c.y, layer)


## 點選目前樓層上的方塊（最前面那一個）；沒有則回傳 (-1, -1, -1)。
func block_at(local_pos: Vector2) -> Vector3i:
	var p := to_iso(local_pos)
	var best := Vector3i(-1, -1, -1)
	var best_key := -1
	for cell in Game.island.blocks:
		if cell.z != layer:
			continue
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		if Geometry2D.is_point_in_polygon(p, Iso.cube_outline(rc, cell.z)):
			var key := Iso.draw_key(rc, cell.z)
			if key > best_key:
				best_key = key
				best = cell
	return best


func zoom_at(factor: float, local_pos: Vector2) -> void:
	var before := to_iso(local_pos)
	zoom *= factor
	# 讓手指／游標下的點保持不動
	pan += local_pos - (_origin() + before * zoom)


func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO


# --- 輸入 ---------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_pressing = true
					_dragging = false
					_press_pos = mb.position
					_pinching = _touches.size() >= 2
				else:
					if _pressing and not _dragging and not _pinching:
						cell_tapped.emit(mb.position)
					_pressing = false
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom_at(1.1, mb.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom_at(1.0 / 1.1, mb.position)
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_hover = mm.position
		if _pressing and not _pinching:
			if not _dragging and mm.position.distance_to(_press_pos) > TAP_SLOP:
				_dragging = true
			if _dragging:
				pan += mm.relative
		queue_redraw()
		accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.factor, mg.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2(-1, -1)
		queue_redraw()


## 雙指縮放：直接追蹤觸控點（第一指同時會被模擬成滑鼠，用來拖曳與點選）。
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if get_global_rect().has_point(st.position):
				_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() == 2:
			_pinching = true
			_pinch_dist = _touch_distance()
			_pinch_zoom = zoom
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return
		_touches[sd.index] = sd.position
		if _touches.size() >= 2 and _pinch_dist > 1.0:
			var center := _touch_center() - global_position
			var before := to_iso(center)
			zoom = _pinch_zoom * _touch_distance() / _pinch_dist
			pan += center - (_origin() + before * zoom)


func _touch_distance() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _touch_center() -> Vector2:
	var pts: Array = _touches.values()
	return ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


# --- 繪製 ---------------------------------------------------------------

## 小數格子座標的旋轉（以格子中心為準）。
func _rotate_point(x: float, y: float) -> Vector2:
	var n := IslandData.SIZE - 1
	match rotation_step:
		1:
			return Vector2(n - y, x)
		2:
			return Vector2(n - x, n - y)
		3:
			return Vector2(y, n - x)
	return Vector2(x, y)


func _draw() -> void:
	var fade := Game.current_fade()
	var minutes := Game.now_minutes()
	_painter.fade = fade
	_painter.tint = DayCycle.tint(minutes)
	_night = DayCycle.night_amount(minutes)
	Doodles.paper(self, Rect2(Vector2.ZERO, size), minutes, fade)
	Doodles.sky(self, Vector2(size.x * 0.5, size.y * 0.16), minutes, fade)
	_base = Transform2D(0.0, Vector2(zoom, zoom), 0.0, _origin())
	draw_set_transform_matrix(_base)

	var n := IslandData.SIZE
	_draw_ground_shadow()

	# 旋轉座標下的方塊表（判斷哪些面露在外面）
	_rot_blocks.clear()
	var island := Game.island
	for cell in island.blocks:
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		_rot_blocks[Vector3i(rc.x, rc.y, cell.z)] = island.blocks[cell]

	# 繪製清單：[排序鍵, 種類(0 方塊, 1 植物, 2 動物), 高度, 資料...]
	var below := []
	var upper := []
	for cell in island.blocks:
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		var key := Iso.draw_key(rc, cell.z)
		var list: Array = below if cell.z < layer else upper
		list.append([key, 0, cell.z, rc, island.blocks[cell]])
		if island.plants.has(cell):
			list.append([key, 1, cell.z, rc, island.plants[cell]])
	for a in island.animals:
		var dp: Vector3 = _animal_draw_pos.get(a.id, Vector3(a.pos.x, a.pos.y, a.pos.z))
		var rp := _rotate_point(dp.x, dp.y)
		var key := Iso.draw_key(Vector2i(roundi(rp.x), roundi(rp.y)), roundi(dp.z))
		var list: Array = below if roundi(dp.z) < layer else upper
		list.append([key, 2, roundi(dp.z), rp, dp.z, a])
	var order := func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])
	below.sort_custom(order)
	upper.sort_custom(order)

	for it in below:
		_draw_item(it, 1.0)
	if not photo_mode:
		_draw_layer_grid(n)
	for it in upper:
		_draw_item(it, 1.0 if it[2] == layer or photo_mode else ABOVE_ALPHA)
	_draw_night_fx()
	draw_set_transform(Vector2.ZERO)


## 以 at 為中心放大 k 倍來畫（動物、植物比方塊大一點才看得清楚）。
func _scaled(at: Vector2, k: float) -> void:
	draw_set_transform_matrix(_base * Transform2D(0.0, Vector2(k, k), 0.0, at))


func _draw_item(it: Array, alpha: float) -> void:
	_painter.alpha = alpha
	match it[1]:
		0:
			_draw_cube(it[3], it[2], it[4], alpha)
		1:
			var rc: Vector2i = it[3]
			var h := float(it[2]) + (0.85 if _rot_blocks.get(Vector3i(rc.x, rc.y, it[2])) == Materials.WATER else 1.0)
			if Catalog.is_light(it[4]):
				_scaled(Iso.to_screen(rc.x + 0.5, rc.y + 0.5, h), LIGHT_SCALE)
				_painter.light(it[4], Vector2.ZERO, _night >= 0.5, _time)
			else:
				_scaled(Iso.to_screen(rc.x + 0.5, rc.y + 0.5, h), PLANT_SCALE)
				_painter.plant(it[4], Vector2.ZERO)
			draw_set_transform_matrix(_base)
		2:
			var rp: Vector2 = it[3]
			var a: Dictionary = it[5]
			var h: float = it[4] + 1.0
			if a.species == "fish" or _rot_blocks.get(Vector3i(roundi(rp.x), roundi(rp.y), it[2])) == Materials.WATER:
				h -= 0.12
			var bob := absf(sin(_time * 8.0 + a.id)) * 1.5 if _animal_moving.get(a.id, false) else 0.0
			_painter.variant = a.get("variant", "")
			_scaled(Iso.to_screen(rp.x + 0.5, rp.y + 0.5, h), ANIMAL_SCALE)
			_painter.animal(a.species, Vector2.ZERO, _animal_flip.get(a.id, false), a.confused_since != 0, bob)
			draw_set_transform_matrix(_base)
			_painter.variant = ""


## 島底下淡淡的影子，像貼在手帳上的貼紙。
func _draw_ground_shadow() -> void:
	if Game.island.blocks.is_empty():
		return
	# 依島最底層的範圍決定影子大小
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var bottom := 99
	for cell in Game.island.blocks:
		bottom = mini(bottom, cell.z)
	for cell in Game.island.blocks:
		if cell.z != bottom:
			continue
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		for q in [Iso.to_screen(rc.x, rc.y + 1, bottom), Iso.to_screen(rc.x + 1, rc.y, bottom),
				Iso.to_screen(rc.x + 1, rc.y + 1, bottom), Iso.to_screen(rc.x, rc.y, bottom)]:
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var c := (lo + hi) * 0.5 + Vector2(0, 22)
	var rx := (hi.x - lo.x) * 0.5 + 40.0
	var ry := (hi.y - lo.y) * 0.5 + 18.0
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	var shade := Color(0.05, 0.05, 0.15, 0.18) if _night > 0.5 else Color(0.55, 0.42, 0.28, 0.12)
	draw_colored_polygon(pts, shade)


func _draw_layer_grid(n: int) -> void:
	var h := float(layer)
	var ink := Doodles.ink(_night)
	var fill := PackedVector2Array([
		Iso.to_screen(0, 0, h), Iso.to_screen(n, 0, h),
		Iso.to_screen(n, n, h), Iso.to_screen(0, n, h),
	])
	draw_colored_polygon(fill, Color(ink, 0.05))
	var grid := Color(ink, 0.22)
	for i in n + 1:
		draw_line(Iso.to_screen(i, 0, h), Iso.to_screen(i, n, h), grid, -1.0)
		draw_line(Iso.to_screen(0, i, h), Iso.to_screen(n, i, h), grid, -1.0)
	draw_polyline(PackedVector2Array([fill[0], fill[1], fill[2], fill[3], fill[0]]), Color(ink, 0.4), 1.5, true)

	# 滑鼠所在格（桌機預覽用）
	if _hover.x >= 0:
		var c := floor_cell_at(_hover)
		if IslandData.in_bounds(c):
			var rc := Iso.rotate_cell(Vector2i(c.x, c.y), rotation_step)
			var x := float(rc.x)
			var y := float(rc.y)
			var d := PackedVector2Array([
				Iso.to_screen(x, y, h), Iso.to_screen(x + 1, y, h),
				Iso.to_screen(x + 1, y + 1, h), Iso.to_screen(x, y + 1, h),
			])
			draw_colored_polygon(d, Color(1, 0.85, 0.5, 0.45))


# --- 方塊（手帳風格：描邊、草皮、紋理）----------------------------------------

## 旁邊的格子會不會把這一面遮住（水是半透明的，不遮別人）。
func _covers(me: String, rc: Vector3i) -> bool:
	if not _rot_blocks.has(rc):
		return false
	var other: String = _rot_blocks[rc]
	return other != Materials.WATER or me == Materials.WATER


func _draw_cube(rc: Vector2i, z: int, type: String, alpha: float) -> void:
	var x := float(rc.x)
	var y := float(rc.y)
	var here := Vector3i(rc.x, rc.y, z)
	var top_h := z + (0.88 if type == Materials.WATER and not _rot_blocks.has(here + Vector3i(0, 0, 1)) else 1.0)
	var t0 := Iso.to_screen(x, y, top_h)
	var t1 := Iso.to_screen(x + 1, y, top_h)
	var t2 := Iso.to_screen(x + 1, y + 1, top_h)
	var t3 := Iso.to_screen(x, y + 1, top_h)
	var b1 := Iso.to_screen(x + 1, y, z)
	var b2 := Iso.to_screen(x + 1, y + 1, z)
	var b3 := Iso.to_screen(x, y + 1, z)
	var show_top := not _rot_blocks.has(here + Vector3i(0, 0, 1))
	var show_left := not _covers(type, here + Vector3i(0, 1, 0))
	var show_right := not _covers(type, here + Vector3i(1, 0, 0))

	if CustomBlocks.is_custom(type):
		_draw_custom_cube([t0, t1, t2, t3], [b1, b2, b3], type, alpha, show_top, show_left, show_right)
		return

	var a := alpha * (0.88 if type == Materials.WATER else 1.0)
	var top_c := _c(Materials.top_color(type), a)
	var left_c := _c(Materials.side_color(type).darkened(0.05), a)
	var right_c := _c(Materials.side_color(type).darkened(0.2), a)
	var line_c := _c(Materials.side_color(type).darkened(0.5), alpha * 0.9)
	var soft_line := Color(line_c, line_c.a * 0.25)
	var grass := type == Materials.DIRT and show_top

	if show_left:
		var f := PackedVector2Array([t3, t2, b2, b3])
		draw_colored_polygon(f, left_c)
		_side_detail(type, t3, t2, b2, b3, a, grass, 0.06)
		draw_polyline(_closed(f), line_c, OUTLINE, true)
	if show_right:
		var f := PackedVector2Array([t2, t1, b1, b2])
		draw_colored_polygon(f, right_c)
		_side_detail(type, t2, t1, b1, b2, a, grass, 0.16)
		draw_polyline(_closed(f), line_c, OUTLINE, true)
	if show_top:
		var f := PackedVector2Array([t0, t1, t2, t3])
		draw_colored_polygon(f, top_c)
		_top_detail(type, here, t0, t1, t2, t3, a)
		# 和同種方塊相連的邊淡一點，看起來像一整片地
		draw_polyline(_closed(f), soft_line, 1.0, true)
		var edges := [[t3, t2, Vector3i(0, 1, 0)], [t2, t1, Vector3i(1, 0, 0)],
			[t0, t3, Vector3i(-1, 0, 0)], [t0, t1, Vector3i(0, -1, 0)]]
		for e in edges:
			var nb: Vector3i = here + e[2]
			if _rot_blocks.get(nb, "") != type or _rot_blocks.has(nb + Vector3i(0, 0, 1)):
				draw_line(e[0], e[1], line_c, OUTLINE, true)


func _c(c: Color, a: float) -> Color:
	var out := _painter.col(c)
	out.a = a
	return out


func _closed(v: PackedVector2Array) -> PackedVector2Array:
	var o := v.duplicate()
	o.append(v[0])
	return o


## 側面的紋理：土的草皮垂下來和土粒、石頭裂紋、沙粒、水的反光。
func _side_detail(type: String, t0: Vector2, t1: Vector2, b1: Vector2, b0: Vector2, a: float, grass: bool, dark: float) -> void:
	var hgt := b0.y - t0.y
	match type:
		Materials.DIRT:
			if grass:
				var pts := PackedVector2Array([t0, t1])
				for i in range(6, -1, -1):
					var k := i / 6.0
					pts.append(t0.lerp(t1, k) + Vector2(0, hgt * (0.26 if i % 2 == 0 else 0.4)))
				draw_colored_polygon(pts, _c(Materials.top_color(type).darkened(dark), a))
			for i in 3:
				var m := t0.lerp(t1, 0.25 + i * 0.27) + Vector2(0, hgt * (0.62 + 0.12 * (i % 2)))
				draw_circle(m, 1.6, _c(Materials.side_color(type).darkened(0.3), a))
		Materials.STONE:
			var m := t0.lerp(t1, 0.4) + Vector2(0, hgt * 0.35)
			draw_polyline(PackedVector2Array([m, m + Vector2(4.5, 5), m + Vector2(1.5, 10)]),
				_c(Materials.side_color(type).darkened(0.35), a), 1.2, true)
		Materials.SAND:
			for i in 4:
				var m := t0.lerp(t1, 0.2 + i * 0.2) + Vector2(0, hgt * (0.35 + 0.25 * (i % 2)))
				draw_circle(m, 1.0, _c(Materials.side_color(type).darkened(0.2), a))
		Materials.WATER:
			draw_line(t0 + Vector2(0, hgt * 0.15), t1 + Vector2(0, hgt * 0.15), Color(1, 1, 1, 0.35 * a), 1.5, true)


func _top_detail(type: String, cell: Vector3i, t0: Vector2, t1: Vector2, t2: Vector2, t3: Vector2, a: float) -> void:
	var center := (t0 + t2) * 0.5
	# 固定亂數：同一格每次畫都一樣
	var seed_v := absi(cell.x * 73856093 ^ cell.y * 19349663 ^ cell.z * 83492791)
	var r := func(i: int, span: float) -> float:
		return (float((seed_v >> (i * 3)) % 97) / 96.0 - 0.5) * 2.0 * span
	match type:
		Materials.DIRT:
			draw_colored_polygon(PackedVector2Array([t0, (t0 + t1) * 0.5, center, (t0 + t3) * 0.5]), Color(1, 1, 1, 0.10 * a))
			var gc := _c(Materials.top_color(type).darkened(0.2), a)
			for i in 3:
				var q := center + Vector2(r.call(i, 14.0), r.call(i + 4, 5.0))
				draw_line(q, q + Vector2(-1.2, -3), gc, 1.2, true)
				draw_line(q, q + Vector2(1.2, -3.4), gc, 1.2, true)
		Materials.WATER:
			for i in 2:
				var q := center + Vector2(r.call(i, 10.0), r.call(i + 3, 4.0))
				draw_line(q, q + Vector2(7, 0), Color(1, 1, 1, 0.6 * a), 1.6, true)
		Materials.STONE:
			draw_colored_polygon(PackedVector2Array([t0, (t0 + t1) * 0.5, center, (t0 + t3) * 0.5]), Color(1, 1, 1, 0.12 * a))
			var q := center + Vector2(r.call(0, 8.0), r.call(1, 3.0))
			draw_polyline(PackedVector2Array([q, q + Vector2(4.5, 1.5), q + Vector2(7.5, 0)]),
				_c(Materials.side_color(type).darkened(0.25), a), 1.1, true)
		Materials.SAND:
			for i in 5:
				var q := center + Vector2(r.call(i, 15.0), r.call(i + 5, 6.0))
				draw_circle(q, 0.9, _c(Materials.side_color(type), a))


## 自訂方塊：頂面與兩個看得到的側面貼上 8×8 像素圖，側面用明暗區分。
func _draw_custom_cube(t: Array, b: Array, type: String, alpha: float, show_top: bool, show_left: bool, show_right: bool) -> void:
	var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var top_tex := CustomBlocks.texture(type, CustomBlocks.FACE_TOP)
	var side_tex := CustomBlocks.texture(type, CustomBlocks.FACE_SIDE)
	var faces := []
	if show_left:
		faces.append([PackedVector2Array([t[3], t[2], b[1], b[2]]), side_tex, 0.92])
	if show_right:
		faces.append([PackedVector2Array([t[2], t[1], b[0], b[1]]), side_tex, 0.75])
	if show_top:
		faces.append([PackedVector2Array([t[0], t[1], t[2], t[3]]), top_tex, 1.0])
	var fade := _painter.fade
	var tint := _painter.tint
	var edge := Color(Doodles.INK_DAY.darkened(0.2), 0.8 * alpha)
	for f in faces:
		var shade: float = f[2]
		var c := Color(shade * tint.r, shade * tint.g, shade * tint.b, alpha)
		draw_polygon(f[0], PackedColorArray([c, c, c, c]), uv, f[1])
		if fade > 0.0:
			# 褪色：蓋一層灰
			draw_colored_polygon(f[0], Color(0.72, 0.74, 0.76, fade * 0.85 * alpha))
		draw_polyline(_closed(f[0]), edge, OUTLINE, true)


# --- 夜晚：螢火蟲與睡覺的動物 -------------------------------------------------

## 光源的光：地上一圈暖色光，加上燈或火本身的光暈（會微微閃爍）。
func _draw_light_glow(k: float) -> void:
	var island := Game.island
	for cell in island.plants:
		var id: String = island.plants[cell]
		if not Catalog.is_light(id) or (cell.z > layer and not photo_mode):
			continue
		var g: Array = IsoPainter.LIGHT_GLOW[id]
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		var at := Iso.to_screen(rc.x + 0.5, rc.y + 0.5, cell.z + 1)
		var flicker := 1.0 if id == "lamp" or id == "lantern" else 0.88 + 0.12 * sin(_time * 7.0 + cell.x)
		var col: Color = g[2]
		var ground: float = g[3] * LIGHT_SCALE
		draw_set_transform_matrix(_base * Transform2D(0.0, Vector2(1.0, 0.5), 0.0, at))
		for i in 7:
			var f := 1.0 - i / 7.0
			draw_circle(Vector2.ZERO, ground * (0.25 + f), Color(col, (0.045 + 0.012 * i) * k * flicker))
		draw_set_transform_matrix(_base)
		var head: Vector2 = at + g[0] * LIGHT_SCALE
		for i in 6:
			var f := 1.0 - i / 6.0
			draw_circle(head, g[1] * LIGHT_SCALE * (0.3 + f), Color(col, (0.07 + 0.025 * i) * k * flicker))


func _draw_night_fx() -> void:
	if _night < 0.5:
		return
	var k := (_night - 0.5) * 2.0
	var island := Game.island
	_draw_light_glow(k)
	for cell in island.plants:
		if cell.z > layer and not photo_mode:
			continue
		if not island.plants[cell] in ["flower", "shrub", "fruit_tree", "water_lily", "reed", "alpine_flower"]:
			continue
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		var seed_v := float(cell.x * 7 + cell.y * 13 + cell.z * 3)
		var drift := Vector2(sin(_time * 0.9 + seed_v) * 9.0, cos(_time * 0.7 + seed_v) * 6.0)
		var c := Iso.to_screen(rc.x + 0.5, rc.y + 0.5, cell.z + 1) + Vector2(0, -26) + drift
		var pulse := 0.6 + 0.4 * sin(_time * 2.4 + seed_v)
		Doodles.glow(self, c, 9.0, Color("ffe27a"), k * pulse)
	var font := get_theme_default_font()
	for a in island.animals:
		if not Catalog.sleeps_at_night(a.species) or a.confused_since != 0:
			continue
		if a.pos.z > layer and not photo_mode:
			continue
		var dp: Vector3 = _animal_draw_pos.get(a.id, Vector3(a.pos.x, a.pos.y, a.pos.z))
		var rp := _rotate_point(dp.x, dp.y)
		var at := Iso.to_screen(rp.x + 0.5, rp.y + 0.5, dp.z + 1) + Vector2(8, -30)
		var bob := sin(_time * 1.5 + a.id) * 2.0
		var zc := Color(Doodles.INK_NIGHT, k)
		draw_string(font, at + Vector2(0, bob), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, zc)
		draw_string(font, at + Vector2(8, -9 + bob), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, zc)
