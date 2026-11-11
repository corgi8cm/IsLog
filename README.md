# 空島事記（Islog）

完成自己訂的生活小事，換到方塊素材，蓋出屬於自己的空中花園島。Android 離線養成遊戲，使用 Godot 4（GDScript，2D 等角視角）。

企劃書：[docs/PLAN.md](docs/PLAN.md)

## 目前版本：v0.2.0 島有了生命

v0.1.0 核心原型：
- 事件新增、完成、刪除（完成的事件可按「再一次」重新加入）
- 完成事件拿 3 個隨機素材（土、水、石、沙），每天前 10 件給素材
- 一座 10×10×10 的島：選素材點格子放置，「移除」模式點方塊退回素材
- 等角視角：拖曳平移、滾輪／雙指縮放、旋轉 90 度、左側切換樓層
- 本機存檔（`user://save.json` 與 `user://islands/island_0.json`）

v0.2.0 新增：
- 植物：有素材的事件 30% 掉落，每天第一件必掉；12 種植物各自種在對應的方塊上（「植物」工具）
- 四種基本動物：綿羊（土）、小魚（水）、蜥蜴（石）、寄居蟹（沙），完成事件時一次來一隻，同一種最多兩隻，在棲地上漫步
- 棲地消失時動物換位置；完全沒有棲地會冒問號，一天後離開
- 褪色與恢復：整天沒完成事件累積 2 天開始褪色、5 天全灰，動物跟著減少；之後每天完成事件恢復 1/3

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

## Android 建置（GitHub Actions）

每次推到 `main`、推 `v*` tag 或手動執行 workflow，[Android build](.github/workflows/android.yml) 會跑測試並匯出 debug APK。

**下載**：到 [Releases](https://github.com/corgi8cm/IsLog/releases) 下載 APK，直接在手機上安裝（需允許「安裝未知來源應用程式」）。

- **最新測試版**（[`latest`](https://github.com/corgi8cm/IsLog/releases/tag/latest)）：`main` 每次建置都會覆蓋更新。
- **版本 Release**：推 `v*` tag（例如 `v0.1.1`）時建立，APK 附在該版本底下。
- 每次建置的 APK 也會保留在 Actions 的 Artifacts 30 天。

- `version/name` 取自 `project.godot` 的 `config/version`，`version/code` 用 workflow 的執行編號，新版可以直接覆蓋安裝。
- 簽章：repo secret `ANDROID_DEBUG_KEYSTORE_BASE64`（debug keystore 的 base64，alias `androiddebugkey`、密碼 `android`）。
  沒設定時每次會用臨時簽章，手機上要先解除安裝舊版才能裝新版。

## 專案結構

```
scripts/core/   純邏輯（素材、玩家資料、島嶼、等角座標），不依賴畫面
scripts/game.gd 全域狀態 Autoload（Game）：串接邏輯、存檔、發出 changed 訊號
scripts/ui/     畫面（主畫面、事件頁、島嶼頁、等角繪製）
scenes/         場景
tests/          測試與開發工具腳本
docs/           企劃
```
