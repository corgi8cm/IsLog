class_name Tutorial
extends RefCounted
## 新手引導的步驟：每一步顯示在哪一頁、說什麼、等玩家做完哪件事才往下。

enum Step { INTRO, ADD_EVENT, COMPLETE, PLACE, PLANT, VISIT, MEET, OUTRO, DONE }

const PAGE_EVENTS := 0
const PAGE_ISLAND := 1

## 每一步：{page, text, trigger, button}
## trigger：完成哪個動作會進到下一步；button：卡片上的按鈕文字（空字串表示要玩家自己操作）。
const STEPS := {
	Step.INTRO: {"page": PAGE_ISLAND, "trigger": "button", "button": "開始",
		"text": "這是你的島。你完成的每件小事，都會讓它長出顏色。"},
	Step.ADD_EVENT: {"page": PAGE_EVENTS, "trigger": "event_added", "button": "",
		"text": "先訂一件今天想完成的小事。可以自己輸入，或從下面挑一個："},
	Step.COMPLETE: {"page": PAGE_EVENTS, "trigger": "completed", "button": "",
		"text": "做完了嗎？按「完成」打勾，就能拿到素材。"},
	Step.PLACE: {"page": PAGE_ISLAND, "trigger": "placed", "button": "",
		"text": "拿到素材和一株花了！選「土」，點格子把方塊放到島上。"},
	Step.PLANT: {"page": PAGE_ISLAND, "trigger": "planted", "button": "",
		"text": "島有顏色了！選「植物」，再點一塊土，把花種下去。"},
	Step.VISIT: {"page": PAGE_EVENTS, "trigger": "completed", "button": "",
		"text": "再完成一件小事，看看誰會來拜訪。"},
	Step.MEET: {"page": PAGE_ISLAND, "trigger": "button", "button": "看圖鑑",
		"text": "綿羊來了！來過的動物都會記在圖鑑裡，還沒來的會顯示剪影和提示。"},
	Step.OUTRO: {"page": PAGE_ISLAND, "trigger": "button", "button": "開始我的空島",
		"text": "這是 10×10×10 的空間，都可以自由蓋。之後就照自己的步調，完成小事、慢慢長出你的島吧！"},
}

const SUGGESTIONS := ["喝一杯水", "伸展一分鐘", "整理桌面"]


static func info(step: int) -> Dictionary:
	return STEPS.get(step, {})


static func is_active(step: int) -> bool:
	return step >= 0 and step < Step.DONE


## 玩家做了某個動作；符合目前這一步的 trigger 就回傳下一步，否則回傳原本的步驟。
static func advance(step: int, trigger: String) -> int:
	if not is_active(step):
		return step
	if info(step).trigger == trigger:
		return step + 1
	return step
