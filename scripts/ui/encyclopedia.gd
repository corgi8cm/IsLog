class_name Encyclopedia
extends RefCounted
## 圖鑑：來過的動物顯示圖案與第一次來訪日期，還沒來的顯示剪影和提示。


class AnimalIcon:
	extends Control
	var species := ""
	var seen := false
	var _painter := IsoPainter.new(self)

	func _draw() -> void:
		_painter.silhouette = not seen
		var scale_factor := size.y / 30.0
		draw_set_transform(Vector2(size.x * 0.5, size.y * 0.82), 0.0, Vector2(scale_factor, scale_factor))
		_painter.animal(species, Vector2.ZERO, false, false, 0.0)
		draw_set_transform(Vector2.ZERO)


class LightIcon:
	extends Control
	var id := ""
	var seen := false
	var _painter := IsoPainter.new(self)

	func _draw() -> void:
		_painter.silhouette = not seen
		var k := size.y / 105.0
		draw_set_transform(Vector2(size.x * 0.5, size.y * 0.94), 0.0, Vector2(k, k))
		_painter.light(id, Vector2.ZERO, UiKit.night and seen, 0.4)
		draw_set_transform(Vector2.ZERO)


static func open(host: Control) -> void:
	var parts := UiKit.open_modal(host, "圖鑑")
	var body: VBoxContainer = parts[1]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	body.add_child(page)
	var group := ButtonGroup.new()
	for item in [["動物", _animals_page], ["光源", _lights_page]]:
		var b := Button.new()
		b.text = item[0]
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = "FlatButton"
		b.custom_minimum_size = Vector2(120, 52)
		b.focus_mode = Control.FOCUS_NONE
		var build: Callable = item[1]
		b.toggled.connect(func(on: bool):
			b.theme_type_variation = "AccentButton" if on else "FlatButton"
			if on:
				_show(page, build))
		tabs.add_child(b)
	tabs.get_child(0).button_pressed = true


static func _show(page: VBoxContainer, build: Callable) -> void:
	for c in page.get_children():
		page.remove_child(c)
		c.queue_free()
	build.call(page)


static func _grid(body: VBoxContainer, progress_text: String) -> GridContainer:
	var progress := UiKit.label(progress_text, 24)
	progress.theme_type_variation = "Muted"
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress.custom_minimum_size = Vector2(560, 0)
	body.add_child(progress)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	return grid


static func _lights_page(body: VBoxContainer) -> void:
	var seen: Dictionary = Game.data.seen_lights
	var grid := _grid(body, "已拿到 %d / %d 種光源
重複事件連續準時完成 %d 次送一個" % [
		seen.size(), Catalog.light_ids().size(), Catalog.LIGHT_STREAK])
	for id in Catalog.light_ids():
		var is_seen := seen.has(id)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_seen:
			card.add_theme_stylebox_override("panel", UiKit.box(UiKit.color("panel"), 18, Color("e0a85a"), 3))
		else:
			card.theme_type_variation = "Soft"
		grid.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		card.add_child(col)
		var icon := LightIcon.new()
		icon.id = id
		icon.seen = is_seen
		icon.custom_minimum_size = Vector2(0, 110)
		col.add_child(icon)
		var name_label := UiKit.label(Catalog.light_name(id) if is_seen else "???", 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		var info := "第一次拿到\n%s" % Review.label(seen[id]) if is_seen else "還沒拿到"
		var hint := UiKit.label(info, 20)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.theme_type_variation = "Muted"
		col.add_child(hint)


static func _animals_page(body: VBoxContainer) -> void:
	var seen: Dictionary = Game.data.seen_animals
	var grid := _grid(body, "已發現 %d / %d 種動物" % [seen.size(), Catalog.animal_ids().size()])

	for species in Catalog.animal_ids():
		var is_seen := seen.has(species)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# 來過的動物：卡片框線是牠住的地方的顏色
		if is_seen:
			card.add_theme_stylebox_override("panel", UiKit.box(UiKit.color("panel"), 18,
				Materials.side_color(Catalog.animal_habitat(species)), 3))
		else:
			card.theme_type_variation = "Soft"
		grid.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		card.add_child(col)
		var icon := AnimalIcon.new()
		icon.species = species
		icon.seen = is_seen
		icon.custom_minimum_size = Vector2(0, 110)
		col.add_child(icon)
		var name_label := UiKit.label(Catalog.animal_name(species) if is_seen else "???", 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		# 出現條件不寫出來，讓玩家自己發現（新手引導只說明每種動物條件不同）
		var info := "第一次來訪\n%s" % Review.label(seen[species]) if is_seen else "還沒來過"
		var hint := UiKit.label(info, 20)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.theme_type_variation = "Muted"
		col.add_child(hint)
