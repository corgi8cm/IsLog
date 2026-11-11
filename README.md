# 空島事記（Islog）

完成自己訂的生活小事，換到方塊素材，蓋出屬於自己的空中花園島。Android 離線養成遊戲，使用 Godot 4（GDScript，2D 等角視角）。

企劃書：[docs/PLAN.md](docs/PLAN.md)

## 目前版本：v0.1.0 核心原型

- 事件新增、完成、刪除（完成的事件可按「再一次」重新加入）
- 完成事件拿 3 個隨機素材（土、水、石、沙），每天前 10 件給素材
- 一座 10×10×10 的島：選素材點格子放置，「移除」模式點方塊退回素材
- 等角視角：拖曳平移、滾輪／雙指縮放、旋轉 90 度、左側切換樓層
- 本機存檔（`user://save.json` 與 `user://islands/island_0.json`）

## 開發

需要 [Godot 4.7](https://godotengine.org/download)（標準版，非 .NET）。

```bash
# 用編輯器開啟
godot --editor --path .

# 執行遊戲
godot --path .

# 核心邏輯測試
godot --headless --path . -s res://tests/run_tests.gd

# UI 冒煙測試（模擬點擊與拖曳）
godot --headless --path . -s res://tests/ui_smoke.gd

# 用示範資料截圖（輸出到指定資料夾）
godot --path . -s res://tests/screenshot.gd -- ./shots
```

## 專案結構

```
scripts/core/   純邏輯（素材、玩家資料、島嶼、等角座標），不依賴畫面
scripts/game.gd 全域狀態 Autoload（Game）：串接邏輯、存檔、發出 changed 訊號
scripts/ui/     畫面（主畫面、事件頁、島嶼頁、等角繪製）
scenes/         場景
tests/          測試與開發工具腳本
docs/           企劃
```
