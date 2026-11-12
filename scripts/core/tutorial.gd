class_name Tutorial
extends RefCounted
## 新手引導的步驟：每一步顯示在哪一頁、說什麼、等玩家做完哪件事才往下。

enum Step { INTRO, ADD_EVENT, COMPLETE, PLACE, PLANT, VISIT, MEET, OUTRO, DONE }

const PAGE_EVENTS := 0
const PAGE_ISLAND := 1

## 每一步：{page, text, trigger, button}（text 是柯基在對話框裡說的話）
## trigger：完成哪個動作會進到下一步；button：對話框上的按鈕文字（空字串表示要玩家自己操作亮起來的地方）。
const STEPS := {
	Step.INTRO: {"page": PAGE_ISLAND, "trigger": "button", "button": "開始",
		"text": "嗨！我是柯基。這塊灰灰的方塊就是你的島，你完成的每件小事，都會讓它長出顏色。"},
	Step.ADD_EVENT: {"page": PAGE_EVENTS, "trigger": "event_added", "button": "",
		"text": "先訂一件今天想完成的小事吧！在亮起來的地方輸入，或直接挑一個："},
	Step.COMPLETE: {"page": PAGE_EVENTS, "trigger": "completed", "button": "",
		"text": "做完了嗎？按「完成」打勾，素材就會掉出來！"},
	Step.PLACE: {"page": PAGE_ISLAND, "trigger": "placed", "button": "",
		"text": "點亮起來的格子，把土方塊放到島上。"},
	Step.PLANT: {"page": PAGE_ISLAND, "trigger": "planted", "button": "",
		"text": "島有顏色了！接著選「植物」，把花種下去。"},
	Step.VISIT: {"page": PAGE_EVENTS, "trigger": "completed", "button": "",
		"text": "再訂一件小事，完成後看看誰會來拜訪："},
	Step.MEET: {"page": PAGE_ISLAND, "trigger": "button", "button": "",
		"text": "綿羊來了！按「圖鑑」看看，來過的動物都會記在裡面，還沒來的會顯示剪影和提示。"},
	Step.OUTRO: {"page": PAGE_ISLAND, "trigger": "button", "button": "開始我的空島",
		"text": "這是 10×10×10 的空間，都可以自由蓋。之後就照自己的步調，完成小事、慢慢長出你的島吧！"},
}

## 引導時建議放土方塊的格子（在一開始那塊灰色方塊旁邊）。
const PLACE_CELL := Vector3i(5, 4, 0)

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
