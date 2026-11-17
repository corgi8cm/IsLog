class_name DayCycle
extends RefCounted
## 晝夜：依一天中的時間（分鐘）算出時段、島的染色和紙張顏色，時段之間平滑漸變。

const MORNING := "morning"
const DAY := "day"
const EVENING := "evening"
const NIGHT := "night"

## 各時段的樣子：tint 乘在島上，paper / dots 是背景紙張和點點。
const LOOKS := {
	MORNING: {"tint": Color(1.0, 0.94, 0.92), "paper": Color("fbf0ea"), "dots": Color("ecd6cb")},
	DAY: {"tint": Color(1, 1, 1), "paper": Color("f7f0e3"), "dots": Color("e0d4bf")},
	EVENING: {"tint": Color(1.0, 0.84, 0.70), "paper": Color("f6e1cb"), "dots": Color("e3c3a2")},
	NIGHT: {"tint": Color(0.52, 0.58, 0.86), "paper": Color("2f3553"), "dots": Color("454c6e")},
}

## [分鐘, 時段]：相鄰兩點之間漸變。
const KEYS := [
	[0, NIGHT],
	[300, NIGHT],      # 05:00
	[390, MORNING],    # 06:30
	[480, MORNING],    # 08:00
	[570, DAY],        # 09:30
	[990, DAY],        # 16:30
	[1050, EVENING],   # 17:30
	[1110, EVENING],   # 18:30
	[1170, NIGHT],     # 19:30
	[1440, NIGHT],
]


static func minutes_of(hour: int, minute: int) -> int:
	return posmod(hour * 60 + minute, 1440)


## 目前所在的兩個關鍵點與漸變比例：[前一個時段, 後一個時段, 0..1]
static func _span(minutes: int) -> Array:
	var m := posmod(minutes, 1440)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if m >= a[0] and m < b[0]:
			return [a[1], b[1], float(m - a[0]) / float(b[0] - a[0])]
	return [NIGHT, NIGHT, 0.0]


## 這個時間主要是哪個時段（漸變時取比重大的那個）。
static func phase(minutes: int) -> String:
	var s := _span(minutes)
	return s[0] if s[2] < 0.5 else s[1]


## 0..1：夜晚的程度（介面在 0.5 以上換成深色）。
static func night_amount(minutes: int) -> float:
	var s := _span(minutes)
	var a := 1.0 if s[0] == NIGHT else 0.0
	var b := 1.0 if s[1] == NIGHT else 0.0
	return lerpf(a, b, s[2])


static func is_night(minutes: int) -> bool:
	return night_amount(minutes) >= 0.5


static func _blend(minutes: int, key: String) -> Color:
	var s := _span(minutes)
	var a: Color = LOOKS[s[0]][key]
	var b: Color = LOOKS[s[1]][key]
	return a.lerp(b, s[2])


static func tint(minutes: int) -> Color:
	return _blend(minutes, "tint")


static func paper(minutes: int) -> Color:
	return _blend(minutes, "paper")


static func dots(minutes: int) -> Color:
	return _blend(minutes, "dots")
