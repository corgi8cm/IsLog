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


static func open(host: Control) -> void:
	var parts := UiKit.open_modal(host, "圖鑑")
	var body: VBoxContainer = parts[1]
	var seen: Dictionary = Game.data.seen_animals
	var progress := UiKit.label("已發現 %d / %d 種動物" % [seen.size(), Catalog.animal_ids().size()], 24)
	progress.add_theme_color_override("font_color", Color("6b7480"))
	body.add_child(progress)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	for species in Catalog.animal_ids():
		var is_seen := seen.has(species)
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bg := Materials.top_color(Catalog.animal_habitat(species)).lightened(0.6)
		card.add_theme_stylebox_override("panel", UiKit.box(bg if is_seen else Color("eef1f4"), 14))
		grid.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		card.add_child(col)
		var icon := AnimalIcon.new()
		icon.species = species
		icon.seen = is_seen
		icon.custom_minimum_size = Vector2(0, 110)
		col.add_child(icon)
		var name_label := UiKit.label(Catalog.animal_name(species) if is_seen else "？？？", 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(name_label)
		# 出現條件不寫出來，讓玩家自己發現（新手引導只說明每種動物條件不同）
		var info := "第一次來訪\n%s" % Review.label(seen[species]) if is_seen else "還沒來過"
		var hint := UiKit.label(info, 20)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Color("6b7480"))
		col.add_child(hint)
