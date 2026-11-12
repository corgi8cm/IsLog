class_name CloudBackend
extends Node
## 雲端存檔服務的共同介面。實際服務（Play 遊戲服務）與測試用假雲端都繼承它。
## 所有操作都是非同步的，完成時呼叫傳入的 callback。


## 這台裝置能不能用這個服務（例如沒裝 Play 遊戲服務外掛時為 false）。
func is_available() -> bool:
	return false


## 顯示給玩家看的服務名稱。
func service_name() -> String:
	return ""


## 登入。done.call(ok: bool, player_name: String)
## silent 為 true 時不跳出登入畫面（開遊戲時自動嘗試）。
func sign_in(_silent: bool, done: Callable) -> void:
	done.call_deferred(false, "")


func is_signed_in() -> bool:
	return false


func player_name() -> String:
	return ""


## 讀取雲端存檔包。done.call(ok: bool, bundle: Dictionary)；沒有雲端存檔時 ok 為 true、bundle 為空。
func load_bundle(done: Callable) -> void:
	done.call_deferred(false, {})


## 上傳存檔包。done.call(ok: bool)
func save_bundle(_bundle: Dictionary, done: Callable) -> void:
	done.call_deferred(false)


## 解除綁定（登出）。雲端存檔保留。
func sign_out() -> void:
	pass
