## Why

目前 App 結束划槳後只保留基本統計數字（距離、均速、心率），GPS 座標與每秒數據點均未持久化，使用者無法回顧訓練軌跡或分析速度／心率／槳頻的時序變化。本次變更補上完整的訓練數據儲存與多維度圖表分析，讓教練與選手能夠量化訓練成效。

## What Changes

- **引入 SwiftData** 取代 UserDefaults，建立結構化的訓練資料庫
- **新增 `DragonBoatActivity` 主活動模型**，儲存標頭統計與關聯的每秒數據點
- **新增 `ActivityDataPoint` 模型**，每秒記錄：時間戳、速度、槳頻/踏頻、心率、GPS 座標、高度
- **修改 `LocationManager`**：划行中每秒暫存 `ActivityDataPoint`
- **修改 `DataStore`**：結束時將暫存點批次寫入 SwiftData
- **修改 `RecordsView`**：改從 SwiftData 撈取，支援右滑刪除
- **新增 `ActivityDetailView`**：三圖疊加（速度 / 心率 / 槳頻）+ 頂部靜態地圖 + 同步滑動標記
- **非目標（Non-goals）**：
  - Apple Watch companion app
  - 雲端同步 / iCloud 備份
  - 多人比較 / 社群分享
  - 匯出 GPX / FIT 檔案
  - 即時訓練頁面（LiveDashboardView）的圖表改版

## Capabilities

### New Capabilities

- `activity-persistence`: 以 SwiftData 完整持久化每次訓練的逐秒數據點與 GPS 軌跡
- `activity-detail-chart`: 多曲線疊加圖表分析頁，含同步滑動互動與地圖軌跡重播

### Modified Capabilities

- `training-record`: 現有 `TrainingRecord`（UserDefaults）需遷移至 SwiftData `DragonBoatActivity`；`RecordsView` 改為從新資料層讀取

## Impact

| 項目 | 影響說明 |
|------|---------|
| `DataStore.swift` | 加入 SwiftData ModelContainer；移除舊 UserDefaults records 邏輯 |
| `LocationManager.swift` | 加入每秒 DataPoint 暫存陣列；`stopRide()` 回傳完整點陣列 |
| `Models.swift` | 新增 `DragonBoatActivity`、`ActivityDataPoint` SwiftData 模型 |
| `RecordsView.swift` | `@Query` 取代手動 fetch；支援 `.onDelete` |
| `ActivityDetailView.swift` | 全新檔案，依賴 Swift Charts + MapKit |
| `boatDashboardApp.swift` | 注入 `.modelContainer` |
| 相依套件 | Swift Charts（iOS 16+，已內建）、SwiftData（iOS 17+） |
| 最低 iOS 版本 | **需確認**：SwiftData 要求 iOS 17；TBD — 若目前 target < 17 需調整 |
