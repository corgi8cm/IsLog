class_name UiKit
extends RefCounted
## 小工具：建立統一樣式的 UI 元件。

const TEXT_COLOR := Color("2b3a4a")
const BUTTON_BG := Color(1, 1, 1, 0.85)


static func make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK TC", "Noto Sans TC", "Source Han Sans TC",
		"Microsoft JhengHei", "PingFang TC", "sans-serif",
	])
	theme.default_font = font
	theme.default_font_size = 28
	for type in ["Label", "Button", "LineEdit"]:
		theme.set_color("font_color", type, TEXT_COLOR)
	theme.set_color("font_pressed_color", "Button", TEXT_COLOR)
	theme.set_color("font_hover_color", "Button", TEXT_COLOR)
	theme.set_color("font_hover_pressed_color", "Button", TEXT_COLOR)
	theme.set_color("font_focus_color", "Button", TEXT_COLOR)
	theme.set_color("font_placeholder_color", "LineEdit", Color(TEXT_COLOR, 0.45))

	theme.set_stylebox("normal", "Button", box(BUTTON_BG, 14))
	theme.set_stylebox("hover", "Button", box(Color(1, 1, 1, 0.95), 14))
	theme.set_stylebox("pressed", "Button", box(Color("dceefc"), 14))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", box(Color.WHITE, 14))
	theme.set_stylebox("focus", "LineEdit", box(Color.WHITE, 14, Color("7cc35a")))
	return theme


static func box(bg: Color, radius: int = 14, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border.a > 0:
		sb.set_border_width_all(3)
		sb.border_color = border
	return sb


static func label(text: String, font_size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 可切換的工具按鈕（同一組只能選一個），選取時加粗框。
static func tool_button(group: ButtonGroup, color: Color) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_stylebox_override("normal", box(color, 14))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.1), 14))
	b.add_theme_stylebox_override("pressed", box(color, 14, Color("2b3a4a")))
	b.add_theme_stylebox_override("hover_pressed", box(color.lightened(0.1), 14, Color("2b3a4a")))
	return b


## 在 host 上開一個置中的對話框。回傳 [遮罩, 內容 VBox]；呼叫 遮罩.queue_free() 關閉。
static func open_modal(host: Control, title: String) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0.15, 0.2, 0.45)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var sb := box(Color.WHITE, 20)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	panel.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	var t := label(title, 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(button("關閉", overlay.queue_free))
	return [overlay, body]


## 把元件包進圓角色塊。
static func chip(content: Control, bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 12))
	p.add_child(content)
	return p
