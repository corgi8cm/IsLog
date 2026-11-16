class_name UiKit
extends RefCounted
## 小工具：手帳風格的配色、主題與 UI 元件。
## 白天是米色紙張，夜晚換成深藍色；換主題時所有元件會一起更新。

## 目前是不是夜晚配色（由主畫面依時間切換後重建主題）。
static var night := false

const DAY := {
	"ink": Color("5a4636"),
	"muted": Color("9a8370"),
	"panel": Color("fffaf0"),
	"soft": Color("f3e6d0"),
	"border": Color("cdb89a"),
	"accent": Color("d9825b"),
	"on_accent": Color("fffaf0"),
	"sel": Color("f6d9c6"),
	"danger": Color("c0574a"),
	"overlay": Color(0.24, 0.16, 0.08, 0.35),
}
const NIGHT := {
	"ink": Color("f3e6cf"),
	"muted": Color("a9a7bd"),
	"panel": Color("3b4265"),
	"soft": Color("343a5c"),
	"border": Color("59618a"),
	"accent": Color("f2b36b"),
	"on_accent": Color("2f3553"),
	"sel": Color(0.95, 0.7, 0.42, 0.25),
	"danger": Color("ef9a8a"),
	"overlay": Color(0.04, 0.04, 0.12, 0.55),
}

## 舊程式用的文字色（白天）。
const TEXT_COLOR := Color("5a4636")


static func color(role: String) -> Color:
	return (NIGHT if night else DAY)[role]


static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK TC", "Noto Sans TC", "Source Han Sans TC",
		"Microsoft JhengHei", "PingFang TC", "sans-serif",
	])
	theme.default_font = font
	theme.default_font_size = 28
	var ink := color("ink")
	var muted := color("muted")
	for type in ["Label", "Button", "LineEdit"]:
		theme.set_color("font_color", type, ink)
	for key in ["font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(key, "Button", ink)
	theme.set_color("font_disabled_color", "Button", muted)
	theme.set_color("font_placeholder_color", "LineEdit", muted)
	theme.set_color("caret_color", "LineEdit", ink)
	theme.set_color("font_uneditable_color", "LineEdit", muted)

	var panel := color("panel")
	var border := color("border")
	theme.set_stylebox("normal", "Button", box(panel, 20, border, 2))
	theme.set_stylebox("hover", "Button", box(panel.lerp(color("soft"), 0.5), 20, border, 2))
	theme.set_stylebox("pressed", "Button", box(color("sel"), 20, border, 2))
	theme.set_stylebox("disabled", "Button", box(Color(panel, 0.6), 20, Color(border, 0.6), 2))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", box(panel, 26, border, 2))
	theme.set_stylebox("focus", "LineEdit", box(panel, 26, color("accent"), 3))
	theme.set_stylebox("read_only", "LineEdit", box(color("soft"), 26))
	theme.set_stylebox("panel", "PanelContainer", box(panel, 22, border, 2))

	# 主要按鈕：強調色底
	_variation(theme, "AccentButton", "Button")
	var acc := color("accent")
	theme.set_stylebox("normal", "AccentButton", box(acc, 20))
	theme.set_stylebox("hover", "AccentButton", box(acc.lightened(0.08), 20))
	theme.set_stylebox("pressed", "AccentButton", box(acc.darkened(0.1), 20))
	theme.set_stylebox("disabled", "AccentButton", box(Color(acc, 0.4), 20))
	for key in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(key, "AccentButton", color("on_accent"))

	# 沒有底的按鈕（「⋯」、樓層箭頭）
	_variation(theme, "FlatButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "FlatButton", _empty(8))

	# 刪除之類的按鈕：文字用紅色
	_variation(theme, "DangerButton", "Button")
	for key in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(key, "DangerButton", color("danger"))

	# 工具、分頁：平常透明，選到時有底色與框
	_variation(theme, "ToolButton", "Button")
	theme.set_stylebox("normal", "ToolButton", _empty(4))
	theme.set_stylebox("hover", "ToolButton", box(Color(color("soft"), 0.6), 18))
	theme.set_stylebox("pressed", "ToolButton", box(color("sel"), 18, acc, 3))
	theme.set_stylebox("hover_pressed", "ToolButton", box(color("sel"), 18, acc, 3))
	theme.set_stylebox("disabled", "ToolButton", _empty(4))

	# 分頁：選到時只有底色
	_variation(theme, "TabButton", "Button")
	theme.set_stylebox("normal", "TabButton", _empty(4))
	theme.set_stylebox("hover", "TabButton", box(Color(color("soft"), 0.6), 22))
	theme.set_stylebox("pressed", "TabButton", box(color("sel"), 22))
	theme.set_stylebox("hover_pressed", "TabButton", box(color("sel"), 22))

	# 圓形圖示按鈕
	_variation(theme, "IconButton", "Button")
	for state in ["normal", "hover", "pressed"]:
		var bg := panel if state == "normal" else (color("sel") if state == "pressed" else panel.lerp(color("soft"), 0.5))
		var sb := box(bg, 40, border, 2)
		sb.set_content_margin_all(0)
		theme.set_stylebox(state, "IconButton", sb)

	# 卡片、長條、淡色區塊
	_variation(theme, "Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", box(panel, 22, border, 2))
	_variation(theme, "Bar", "PanelContainer")
	theme.set_stylebox("panel", "Bar", box(panel, 26, border, 2))
	_variation(theme, "Soft", "PanelContainer")
	theme.set_stylebox("panel", "Soft", box(color("soft"), 20))
	_variation(theme, "Clear", "PanelContainer")
	theme.set_stylebox("panel", "Clear", _empty(0))

	# 次要文字、標題
	_variation(theme, "Muted", "Label")
	theme.set_color("font_color", "Muted", muted)
	_variation(theme, "Accent", "Label")
	theme.set_color("font_color", "Accent", acc)

	# 捲軸細一點
	var grab := box(Color(muted, 0.5), 6)
	grab.set_content_margin_all(3)
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, _empty(2))
		theme.set_stylebox("grabber", bar, grab)
		theme.set_stylebox("grabber_highlight", bar, grab)
		theme.set_stylebox("grabber_pressed", bar, grab)
	return theme


static func _variation(theme: Theme, name: String, base: String) -> void:
	theme.set_type_variation(name, base)


static func _empty(margin: int) -> StyleBoxEmpty:
	var e := StyleBoxEmpty.new()
	e.set_content_margin_all(margin)
	return e


static func box(bg: Color, radius: int = 14, border := Color.TRANSPARENT, border_w := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.anti_aliasing = true
	if border.a > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border
	return sb


static func label(text: String, font_size: int = 0, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	if variation != "":
		l.theme_type_variation = variation
	return l


static func button(text: String, on_pressed: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	if variation != "":
		b.theme_type_variation = variation
	return b


## 圓形圖示按鈕；name 寫在 tooltip_text（測試和無障礙用）。
static func icon_button(kind: String, name: String, on_pressed: Callable, diameter := 72.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = "IconButton"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = name
	b.custom_minimum_size = Vector2(diameter, diameter)
	b.pressed.connect(on_pressed)
	var ic := Icon.new()
	ic.kind = kind
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return b


## 上面一個圖、下面一行字的切換按鈕（工具列、分頁列）。回傳按鈕，字在 meta "caption"。
static func tile_button(group: ButtonGroup, picture: Control, caption: String, variation := "ToolButton") -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = variation
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 96)
	b.tooltip_text = caption
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.custom_minimum_size = Vector2(0, 46)
	col.add_child(picture)
	var l := label(caption, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	b.set_meta("caption", l)
	return b


static func icon(kind: String, role := "ink") -> Icon:
	var ic := Icon.new()
	ic.kind = kind
	ic.role = role
	return ic


static func mini_cube(type: String) -> MiniCube:
	var c := MiniCube.new()
	c.type = type
	return c


## 可切換的工具按鈕（同一組只能選一個），用顏色區分種類，選取時加粗框。
static func tool_button(group: ButtonGroup, bg: Color) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 72)
	var ink := Color("5a4636")
	b.add_theme_stylebox_override("normal", box(bg, 18))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.1), 18))
	b.add_theme_stylebox_override("pressed", box(bg, 18, color("accent")))
	b.add_theme_stylebox_override("hover_pressed", box(bg.lightened(0.1), 18, color("accent")))
	# 底色固定是淺色，字也固定用深色
	for key in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, ink)
	return b


## 在 host 上開一個置中的對話框。回傳 [遮罩, 內容 VBox]；呼叫 遮罩.queue_free() 關閉。
static func open_modal(host: Control, title: String) -> Array:
	var overlay := ColorRect.new()
	overlay.color = color("overlay")
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card"
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	pad.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	var t := label(title, 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(button("關閉", overlay.queue_free, "FlatButton"))
	return [overlay, body]


## 把元件包進圓角色塊。
static func chip(content: Control, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 12))
	p.add_child(content)
	return p
