## Context

現有資料層以 `UserDefaults` + `JSONEncoder` 儲存 `TrainingRecord`，只保留統計摘要（均速、最高心率等），不含每秒數據點與 GPS 座標。`RecordsView` 直接讀取 `DataStore.records: [TrainingRecord]`。

專案 iOS Deployment Target：**17.5**，可直接使用 SwiftData 與 Swift Charts，無需引入第三方套件。

## Goals / Non-Goals

**Goals:**
- 以 SwiftData 建立結構化訓練資料庫，持久化每秒 DataPoint
- `LocationManager` 划行中逐秒暫存，結束時批次寫入
- `RecordsView` 改用 `@Query`，支援刪除
- `ActivityDetailView`：頂部軌跡地圖 + 三張同步圖表（速度 / 心率 / 槳頻）+ 同步滑動標記

**Non-Goals:**
- 雲端同步、iCloud、GPX 匯出
- Apple Watch companion
- `LiveDashboardView` 即時頁圖表改版
- 舊 `TrainingRecord` 資料自動遷移（首版清空重建）

## Decisions

### D1：採用 SwiftData 而非 Core Data / SQLite

**決定**：使用 SwiftData（`@Model`）

**理由**：iOS 17+ 原生支援，與 SwiftUI `@Query` 無縫整合，宣告式語法減少 boilerplate。Core Data 在此規模下過重。

**替代方案**：
- Core Data：成熟但需大量設定，不適合小型 App
- SQLite（GRDB）：效能佳但引入第三方依賴，非必要

---

### D2：資料模型結構 — 1 Activity : N DataPoints（`@Relationship`）

```
DragonBoatActivity                ActivityDataPoint
─────────────────────             ─────────────────────
id: UUID                          id: UUID
name: String                      timestamp: Date
startTime: Date                   speedKmh: Double
endTime: Date?                    cadenceSpm: Int
totalDistanceMeters: Double       heartRateBpm: Int
averageSpeedKmh: Double           latitude: Double
maxSpeedKmh: Double               longitude: Double
averageCadence: Double            altitudeMeters: Double
averageHeartRate: Int             ↑ activity: DragonBoatActivity
maxHeartRate: Int
workoutName: String?
@Relationship(.cascade)
dataPoints: [ActivityDataPoint]
```

**理由**：統計欄位存在 Activity 層，圖表頁才 lazy load DataPoints，首頁列表不需要全部點位。

---

### D3：DataPoint 取樣頻率 — 每 1 秒一筆

**決定**：`Timer`（1 秒）觸發，從 `LocationManager` 讀取當下快照

**理由**：
- 1 小時訓練 ≈ 3,600 筆，每筆 ~60 bytes → 約 216 KB，StorageFootprint 可接受
- 與現有 `speedHistory` 取樣方式一致

---

### D4：批次寫入而非即時寫入

**決定**：划行中資料暫存於記憶體 `[PendingDataPoint]`（值型別），結束時一次 `modelContext.insert`

**理由**：避免每秒寫入造成 I/O 壓力與 UI 卡頓；如 App crash，資料會遺失（可接受的 trade-off，不需要 crash recovery）

---

### D5：圖表同步滑動 — `@State scrubTime: Date?` + `chartOverlay`

```
LiveDashboardView
    │
    ├── SpeedChartView    ┐
    ├── HeartRateChartView├─ 共用 scrubTime: Binding<Date?>
    └── CadenceChartView  ┘
            │
            └── MapScrubAnnotation（地圖上標記點）
```

**決定**：用 `.chartGesture` + `DragGesture` 更新共用 `scrubTime`，其他圖表 observe 同一 binding 繪製垂直線與 data label

**替代方案**：
- `ScrollView` 橫向同步：複雜度高，不符合需求（垂直排列圖表）

---

### D6：舊 TrainingRecord 遷移策略

**決定**：首版**不遷移**，`DataStore.records` 與 SwiftData 並行存在，`RecordsView` 改為只讀 SwiftData，舊 UserDefaults 資料自然淡出

**理由**：舊格式欠缺 DataPoints，圖表頁無法顯示；強制遷移只能產生空圖表，體驗更差

---

### D7：Moving Average 平滑演算法

**決定**：Window size = 5 秒的簡易滑動平均

```swift
func movingAverage(_ data: [Double], window: Int = 5) -> [Double]
```

**理由**：心率感測器有 ±5 bpm 跳動雜訊，5 秒視窗足以過濾而不過度延遲

## Risks / Trade-offs

| 風險 | 緩解策略 |
|------|---------|
| SwiftData `@Query` 在 iOS 17.0–17.3 有已知 bug（predicate crash） | Target 已設 17.5，規避大部分已知問題；避免複雜 predicate |
| 大量 DataPoints 導致 `ActivityDetailView` 載入慢（>10,000 筆） | 先用 `@Query` sort limit；如有需要再做分頁或 background fetch |
| `chartGesture` API 在 Swift Charts 仍屬實驗性 | fallback 使用 `GeometryReader` + `DragGesture` 手動計算 x 偏移 |
| App crash 時當次訓練資料遺失（批次寫入策略） | 接受此 trade-off；未來可加 checkpoint（每 5 分鐘寫一次） |
| `DataStore` 與 SwiftData 雙軌並存造成混淆 | 明確文件說明：新 records 走 SwiftData，舊 records 只讀不寫 |

## Open Questions

- [ ] **App Icon / 名稱**：`ActivityDetailView` 的 navigation title 用活動名稱還是日期？（TBD — 實作時決定）
- [ ] **DataPoint 座標精度**：`latitude/longitude` 儲存 Double（~1cm 精度），是否足夠？（假設足夠，若有疑慮需確認）
