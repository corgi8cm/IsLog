@tool
extends EditorPlugin
## 匯出 Android 時加入通知外掛的 AAR（需要 Gradle 建置）。

var _export_plugin: IslogNotifyExport


func _enter_tree() -> void:
	_export_plugin = IslogNotifyExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class IslogNotifyExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "IslogNotify"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	# 路徑相對於 res://addons/
	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["islog_notify/bin/islog_notify.aar"])
