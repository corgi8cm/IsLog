class_name IslandsDialog
extends RefCounted
## 「我的島」：列出所有島嶼，切換目前在蓋的島、建立新島。


static func open(host: Control) -> void:
	var parts := UiKit.open_modal(host, "我的島")
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var note := UiKit.label("一次只蓋一座島。收起來的島時間會停止，不會褪色。", 22)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color("6b7480"))
	body.add_child(note)

	for s in Game.island_summaries():
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.box(Color("e8f5e0") if s.current else Color("f1f4f7"), 14))
		body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UiKit.label(s.name, 28))
		var info := UiKit.label("方塊 %d · 植物 %d · 動物 %d" % [s.blocks, s.plants, s.animals], 22)
		info.add_theme_color_override("font_color", Color("6b7480"))
		col.add_child(info)
		if s.current:
			var cur := UiKit.label("目前", 24)
			cur.add_theme_color_override("font_color", Color("4f8a34"))
			cur.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(cur)
		else:
			var island_id: int = s.id
			row.add_child(UiKit.button("拿出來", func():
				Game.switch_island(island_id)
				overlay.queue_free()))

	if Game.data.can_create_island():
		var b := UiKit.button("建立新島（目前的島會收起來）", func():
			Game.create_island()
			overlay.queue_free())
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
		body.add_child(b)
	else:
		var left := UiKit.label("再完成 %d 件事件，就能解鎖新的島。" % Game.data.events_to_next_island(), 24)
		left.add_theme_color_override("font_color", Color("6b7480"))
		body.add_child(left)
