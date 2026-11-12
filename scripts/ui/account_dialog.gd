class_name AccountDialog
extends RefCounted
## 「帳號與備份」：綁定帳號、立即備份、解除綁定；兩邊都有進度時讓玩家選要留哪一份。

const MUTED := Color("6b7480")


static func open(host: Control) -> void:
	var parts := UiKit.open_modal(host, "帳號與備份")
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	body.add_child(content)
	var cloud: CloudSync = Game.cloud
	var rebuild := func():
		if not is_instance_valid(content):
			return
		for c in content.get_children():
			c.queue_free()
		_fill(content, cloud)
	cloud.status_changed.connect(rebuild)
	overlay.tree_exiting.connect(func(): cloud.status_changed.disconnect(rebuild))
	rebuild.call()


static func _fill(content: VBoxContainer, cloud: CloudSync) -> void:
	content.add_child(_muted("綁定帳號後，進度會自動備份到雲端。換新手機時登入同一個帳號，就能把島嶼和事件紀錄都拿回來。"))
	if not cloud.is_available():
		var na := UiKit.label("雲端備份還沒開放，上架 Google Play 之後就能使用。", 26)
		na.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(na)
		return
	var service := _muted("服務：" + cloud.backend.service_name())
	content.add_child(service)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color("e8f5e0") if cloud.linked else Color("f1f4f7"), 14))
	content.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	if cloud.linked:
		var who: String = cloud.backend.player_name()
		col.add_child(UiKit.label("已綁定" + ("：" + who if who != "" else ""), 28))
		col.add_child(_muted("上次備份：" + CloudSave.time_text(cloud.last_backup_at)))
		col.add_child(_muted("這台手機：" + CloudSave.summary_text(Game.export_summary())))
	else:
		col.add_child(UiKit.label("還沒綁定", 28))

	if cloud.message != "":
		var msg := UiKit.label(cloud.message, 24)
		msg.add_theme_color_override("font_color", Color("c0392b") if cloud.status == "error" else Color("4f8a34"))
		content.add_child(msg)

	if cloud.has_pending_choice():
		var again := UiKit.button("選擇要保留哪一份", func(): cloud.sync())
		content.add_child(again)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	if cloud.linked:
		var now_btn := UiKit.button("立即備份", cloud.sync)
		now_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		now_btn.custom_minimum_size = Vector2(0, 72)
		now_btn.disabled = cloud.is_busy()
		now_btn.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
		row.add_child(now_btn)
		var off := UiKit.button("解除綁定", cloud.unlink)
		off.custom_minimum_size = Vector2(0, 72)
		off.disabled = cloud.is_busy()
		row.add_child(off)
		content.add_child(_muted("解除綁定後不會刪除雲端存檔，之後可以再綁定。"))
	else:
		var link := UiKit.button("綁定帳號", cloud.link)
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.custom_minimum_size = Vector2(0, 72)
		link.disabled = cloud.is_busy()
		link.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
		row.add_child(link)


## 雲端和這台手機都有新進度：列出兩邊的摘要讓玩家選。
static func open_choice(host: Control, local_summary: Dictionary, remote: Dictionary) -> void:
	var parts := UiKit.open_modal(host, "要保留哪一份進度？")
	var overlay: Control = parts[0]
	var body: VBoxContainer = parts[1]
	body.add_child(_muted("雲端存檔和這台手機上的進度不一樣。選一份保留，另一份會被取代（這台手機原本的存檔會另外留一份備份）。"))
	var remote_summary: Dictionary = remote.get("summary", {})
	var device := str(remote.get("device", ""))
	var options := [
		["這台手機", CloudSave.summary_text(local_summary), true],
		["雲端" + ("（" + device + "）" if device != "" else ""),
			CloudSave.summary_text(remote_summary) + "\n備份於 " + CloudSave.time_text(int(remote.get("saved_at", 0))), false],
	]
	for o in options:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiKit.box(Color("f1f4f7"), 14))
		body.add_child(card)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		card.add_child(col)
		col.add_child(UiKit.label(o[0], 28))
		var info := _muted(o[1])
		col.add_child(info)
		var keep_local: bool = o[2]
		var b := UiKit.button("保留" + o[0].split("（")[0], func():
			Game.cloud.resolve(keep_local)
			overlay.queue_free())
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_stylebox_override("normal", UiKit.box(Color("d8f0c8"), 14))
		col.add_child(b)
	body.add_child(_muted("還不確定的話可以先關閉，之後在「帳號與備份」再選。"))


static func _muted(text: String) -> Label:
	var l := UiKit.label(text, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(540, 0)
	l.add_theme_color_override("font_color", MUTED)
	return l
