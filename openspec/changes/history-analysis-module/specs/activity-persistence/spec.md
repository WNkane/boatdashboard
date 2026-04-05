## ADDED Requirements

### Requirement: 逐秒數據點暫存
划行中，系統 SHALL 每隔 1 秒從 LocationManager 取得快照（速度、槳頻、心率、GPS 座標、高度），並暫存於記憶體陣列。

#### Scenario: 正常划行取樣
- **WHEN** `isRiding == true` 且 Timer 每秒觸發
- **THEN** 系統新增一筆 `ActivityDataPoint`，包含當下 timestamp、speedKmh、cadenceSpm、heartRateBpm、latitude、longitude、altitudeMeters

#### Scenario: GPS 訊號遺失時的處理
- **WHEN** GPS speed < 0（`CLLocation.speed` 回傳 -1）
- **THEN** `speedKmh` 記錄為 0.0，座標仍照最後已知位置填入

---

### Requirement: 結束時批次寫入 SwiftData
使用者點擊「結束划槳」時，系統 SHALL 將記憶體中所有暫存 `ActivityDataPoint` 與統計摘要一次寫入 SwiftData。

#### Scenario: 正常結束並儲存
- **WHEN** 使用者點擊「結束划槳」且至少有 1 筆 DataPoint
- **THEN** 系統建立 `DragonBoatActivity`，關聯所有 DataPoints，寫入 ModelContext，並清空暫存陣列

#### Scenario: 極短時間立即結束（< 3 秒）
- **WHEN** 使用者在開始後 3 秒內結束
- **THEN** 系統仍儲存現有（可能為空或只有 1–2 筆）DataPoints，不拋出錯誤

---

### Requirement: SwiftData ModelContainer 初始化
App 啟動時，系統 SHALL 在 `boatDashboardApp.swift` 注入 `ModelContainer`，包含 `DragonBoatActivity` 與 `ActivityDataPoint`。

#### Scenario: 首次安裝啟動
- **WHEN** App 第一次安裝後啟動
- **THEN** SwiftData 自動建立資料庫，不需要任何使用者操作

#### Scenario: 升級後啟動（版本更新）
- **WHEN** 使用者從舊版升級，舊版使用 UserDefaults 儲存
- **THEN** SwiftData 資料庫為空，舊 UserDefaults 資料不遷移，App 正常啟動不崩潰

---

### Requirement: 刪除活動
使用者 SHALL 可以從列表右滑刪除單筆 `DragonBoatActivity`，刪除時 CASCADE 清除所有關聯 DataPoints。

#### Scenario: 右滑刪除
- **WHEN** 使用者在 RecordsView 右滑某一列，點擊「刪除」
- **THEN** 該 `DragonBoatActivity` 及其所有 `ActivityDataPoint` 從 SwiftData 移除，列表即時更新
