class_name Notifier
extends RefCounted
## 手機通知的介面。電腦版用這個基底類別：只記下排了哪些通知（測試、截圖用），不會真的發。
## Android 版是 AndroidNotifier（透過 IslogNotify 外掛排程系統鬧鐘）。

## 最後一次排的通知清單（NotifyPlan.build 的結果）。
var scheduled: Array = []


## 這台裝置能不能真的發通知。
func is_real() -> bool:
	return false


func has_permission() -> bool:
	return true


## Android 13 以上要先問使用者；問完的結果下次 has_permission() 才會知道。
func request_permission() -> void:
	pass


## 取消之前排的所有通知，換成 items。
func replace_all(items: Array) -> void:
	scheduled = items.duplicate(true)
