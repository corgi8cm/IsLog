class_name AndroidNotifier
extends Notifier
## Android：呼叫 IslogNotify 外掛（addons/islog_notify，原始碼在 android_plugin/）。

const SINGLETON := "IslogNotify"

var _plugin: Object


static func available() -> bool:
	return Engine.has_singleton(SINGLETON)


func _init() -> void:
	if available():
		_plugin = Engine.get_singleton(SINGLETON)


func is_real() -> bool:
	return _plugin != null


func has_permission() -> bool:
	return _plugin != null and bool(_plugin.call("hasPermission"))


func request_permission() -> void:
	if _plugin != null:
		_plugin.call("requestPermission")


func replace_all(items: Array) -> void:
	super.replace_all(items)
	if _plugin == null:
		return
	var list: Array = []
	for it in items:
		# 外掛用毫秒
		list.append({"id": int(it.id), "at": int(it.at) * 1000, "title": str(it.title), "body": str(it.body)})
	_plugin.call("scheduleJson", JSON.stringify(list))
