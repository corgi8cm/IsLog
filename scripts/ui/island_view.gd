extends Control
## 等角島嶼畫面：繪製方塊、目前樓層格線；處理拖曳、縮放、點選。

signal cell_tapped(screen_pos: Vector2)

const TAP_SLOP := 14.0
const MIN_ZOOM := 0.4
const MAX_ZOOM := 3.0
const SKY_COLOR := Color("bfe4ff")
const GRID_COLOR := Color(1, 1, 1, 0.55)
const FRAME_COLOR := Color(1, 1, 1, 0.35)
const ABOVE_ALPHA := 0.22

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


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	clip_contents = true
	Game.changed.connect(queue_redraw)
	resized.connect(queue_redraw)


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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), SKY_COLOR)
	draw_set_transform(_origin(), 0.0, Vector2(zoom, zoom))

	var n := IslandData.SIZE
	_draw_frame_back(n)

	var below := []
	var upper := []
	for cell in Game.island.blocks:
		var rc := Iso.rotate_cell(Vector2i(cell.x, cell.y), rotation_step)
		var item := [Iso.draw_key(rc, cell.z), rc, cell.z, Game.island.blocks[cell]]
		if cell.z < layer:
			below.append(item)
		else:
			upper.append(item)
	below.sort_custom(func(a, b): return a[0] < b[0])
	upper.sort_custom(func(a, b): return a[0] < b[0])

	for it in below:
		_draw_cube(it[1], it[2], it[3], 1.0)
	_draw_layer_grid(n)
	for it in upper:
		_draw_cube(it[1], it[2], it[3], 1.0 if it[2] == layer else ABOVE_ALPHA)

	_draw_frame_front(n)
	draw_set_transform(Vector2.ZERO)


func _draw_layer_grid(n: int) -> void:
	var h := float(layer)
	var fill := PackedVector2Array([
		Iso.to_screen(0, 0, h), Iso.to_screen(n, 0, h),
		Iso.to_screen(n, n, h), Iso.to_screen(0, n, h),
	])
	draw_colored_polygon(fill, Color(1, 1, 1, 0.12))
	for i in n + 1:
		draw_line(Iso.to_screen(i, 0, h), Iso.to_screen(i, n, h), GRID_COLOR, -1.0)
		draw_line(Iso.to_screen(0, i, h), Iso.to_screen(n, i, h), GRID_COLOR, -1.0)

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
			draw_colored_polygon(d, Color(1, 1, 0.6, 0.45))


func _draw_frame_back(n: int) -> void:
	var top := float(n)
	# 後方三條直立邊與底部後方兩邊
	for c in [Vector2(0, 0), Vector2(n, 0), Vector2(0, n)]:
		draw_line(Iso.to_screen(c.x, c.y, 0), Iso.to_screen(c.x, c.y, top), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(0, 0, 0), Iso.to_screen(n, 0, 0), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(0, 0, 0), Iso.to_screen(0, n, 0), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(0, 0, top), Iso.to_screen(n, 0, top), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(0, 0, top), Iso.to_screen(0, n, top), FRAME_COLOR, -1.0)


func _draw_frame_front(n: int) -> void:
	var top := float(n)
	draw_line(Iso.to_screen(n, n, 0), Iso.to_screen(n, n, top), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(n, 0, 0), Iso.to_screen(n, n, 0), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(0, n, 0), Iso.to_screen(n, n, 0), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(n, 0, top), Iso.to_screen(n, n, top), FRAME_COLOR, -1.0)
	draw_line(Iso.to_screen(0, n, top), Iso.to_screen(n, n, top), FRAME_COLOR, -1.0)


func _draw_cube(rc: Vector2i, z: int, type: String, alpha: float) -> void:
	var x := float(rc.x)
	var y := float(rc.y)
	var t0 := Iso.to_screen(x, y, z + 1)
	var t1 := Iso.to_screen(x + 1, y, z + 1)
	var t2 := Iso.to_screen(x + 1, y + 1, z + 1)
	var t3 := Iso.to_screen(x, y + 1, z + 1)
	var b1 := Iso.to_screen(x + 1, y, z)
	var b2 := Iso.to_screen(x + 1, y + 1, z)
	var b3 := Iso.to_screen(x, y + 1, z)

	var top := Materials.top_color(type)
	var side := Materials.side_color(type)
	if type == Materials.WATER:
		alpha *= 0.85
	top.a = alpha
	var left := side.darkened(0.08)
	left.a = alpha
	var right := side.darkened(0.25)
	right.a = alpha
	var edge := side.darkened(0.45)
	edge.a = alpha * 0.6

	draw_colored_polygon(PackedVector2Array([t3, t2, b2, b3]), left)
	draw_colored_polygon(PackedVector2Array([t1, t2, b2, b1]), right)
	draw_colored_polygon(PackedVector2Array([t0, t1, t2, t3]), top)
	draw_polyline(PackedVector2Array([t0, t1, t2, t3, t0]), edge, -1.0)
	draw_line(t2, b2, edge, -1.0)
	draw_polyline(PackedVector2Array([t1, b1, b2, b3, t3]), edge, -1.0)
