# Google Play Console 設定步驟

接上 Play 遊戲服務（雲端存檔）與上架前，需要由開發者本人在 Google 那邊完成的設定。
Play Console 的介面會改版，中文名稱可能略有不同，括號內附英文名稱方便對照。

整體順序：

1. 註冊開發者帳號（你）
2. 建立 App（你）
3. 上傳第一個測試版（我準備好正式簽署的 AAB 後，你上傳）
4. 設定 Play 遊戲服務與雲端存檔（你）
5. 把 App ID 給我，接上外掛（我）
6. 封閉測試 12 人 × 14 天，申請正式上架（你）

---

## 1. 註冊開發者帳號

1. 前往 <https://play.google.com/console/signup>，用要長期管理這個遊戲的 Google 帳號登入
2. 帳號類型選「個人」（Personal）。「機構」（Organization）需要 D-U-N-S 編號
3. 付一次性註冊費 25 美元
4. 完成身分驗證：上傳身分證件、驗證電話與 Email；也可能要求用 Android 手機安裝 Play Console App 驗證裝置
5. 驗證通過通常需要幾天

> **注意：2023-11-13 之後註冊的個人帳號，正式上架前必須先做封閉測試：至少 12 位測試人員，連續 14 天保持加入。**
> 這段時間可以跟朋友試玩一起進行，見第 6 步。

## 2. 建立 App

Play Console 首頁 →「所有應用程式」（All apps）→「建立應用程式」（Create app）

| 欄位 | 填寫 |
| --- | --- |
| 應用程式名稱 | 空島事記（之後可以改；建立前可在 Play 商店搜尋確認沒有撞名） |
| 預設語言 | 中文（繁體）– zh-TW |
| 應用程式或遊戲 | 遊戲 |
| 免費或付費 | 免費（之後不能改成付費，但免費 App 仍可以有 Pro 訂閱） |
| 聲明 | 勾選開發人員計畫政策與美國出口法規 |

套件名稱這時還不用填，會在第一次上傳 AAB 時鎖定為 `io.github.corgi8cm.islog`。

## 3. 上傳第一個測試版（內部測試）

Play 商店不接受目前 GitHub 上用除錯金鑰簽署的 APK，需要：

- 另外一把「上傳金鑰」（upload key）：我會在你的電腦上產生，放在 `~/tools/android-keys`，再請你把它加到 GitHub Secrets（跟之前設定除錯金鑰的方式一樣）
- GitHub Actions 改成輸出正式簽署的 AAB

準備好後：

1. 左側「測試與發布」（Test and release）→「測試」→「內部測試」（Internal testing）→「建立新版本」
2. 第一次會詢問「Play 應用程式簽署」（Play App Signing），選「使用 Google 產生的金鑰」（預設）
3. 上傳 AAB、填版本說明 → 儲存 → 發布到內部測試
4. 「測試人員」分頁建立 Email 清單，加入你自己的 Google 帳號，用頁面上的連結加入測試並從 Play 商店安裝

上傳後到「測試與發布」→「設定」→「應用程式完整性」（App integrity）→「應用程式簽署」（App signing），
記下 **應用程式簽署金鑰憑證的 SHA-1**，第 4 步要用。

## 4. 設定 Play 遊戲服務

1. 左側「使用者成長」（Grow users）→「Play 遊戲服務」（Play Games Services）→「設定與管理」（Setup and management）→「設定」（Configuration）
2. 「你的遊戲是否已使用 Google API？」選「否，建立新的遊戲」→ 建立。Google 會自動建立一個 Google Cloud 專案
3. 「屬性」（Properties）→「編輯屬性」→ 把「已儲存的遊戲」（Saved Games）切到「開啟」→ 儲存
4. 「憑證」（Credentials）→「新增憑證」→ 類型選 **Android**
   - 第一次會要求先設定 OAuth 同意畫面（OAuth consent screen）：照頁面上的連結到 Google Cloud 填應用程式名稱與 Email，類型選「外部」（External）即可
   - 回到 Play Console 建立 OAuth 用戶端，**要建兩個**：

| 用途 | 套件名稱 | SHA-1 |
| --- | --- | --- |
| 從 Play 商店安裝的版本 | `io.github.corgi8cm.islog` | 第 3 步記下的「應用程式簽署金鑰」SHA-1 |
| 從 GitHub 下載的測試版 | `io.github.corgi8cm.islog` | `57:14:65:8B:45:FB:93:95:15:04:F7:D9:74:5B:AD:30:70:AE:54:EF` |

   第二個是 GitHub 測試版使用的固定除錯金鑰（`islog-debug.keystore`）的 SHA-1。這是公開資訊，可以放心貼。
5. 「測試人員」（Testers）→ 加入你和朋友的 Google 帳號。遊戲服務還沒發布前，只有這裡的帳號能登入
6. 回到「設定」頁面頂端，記下 **App ID**（一串數字，例如 `123456789012`）

## 5. 把 App ID 給我

我會：

- 加入 Play 遊戲服務的 Godot 外掛，把雲端備份接上真正的服務
- 把 GitHub Actions 改成可以使用外掛的建置方式

之後你從 Play 內部測試安裝新版本，在「帳號與備份」按「綁定帳號」驗證。

## 6. 封閉測試與正式上架

1. 「測試與發布」→「封閉測試」（Closed testing）→ 建立測試群組，加入至少 12 位朋友的 Google 帳號
2. 每位朋友都要用邀請連結「加入測試」並安裝。要連續 14 天保持加入，中途暫停測試群組會重新計算
3. 同時完成「主控台首頁」的上架必填項目：商店資訊、截圖、隱私權政策網址、內容分級問卷、目標年齡、資料安全表單
4. 滿 14 天後，在主控台首頁「申請正式版存取權」（Apply for production），回答幾個測試狀況的問題
5. 審核通過後就能發布到正式版
6. 正式上架前，Play 遊戲服務的設定頁也要按「審查並發布」（Review and publish），所有玩家才能登入

## 參考

- [Play 遊戲服務設定（Android Developers）](https://developer.android.com/games/pgs/console/setup)
- [新個人開發者帳號的測試規定（Play Console 說明）](https://support.google.com/googleplay/android-developer/answer/14151465)
