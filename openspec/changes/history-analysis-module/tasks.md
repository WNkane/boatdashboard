## 1. SwiftData 資料模型建立

- [x] 1.1 在 `Models.swift` 新增 `@Model class ActivityDataPoint`（timestamp, speedKmh, cadenceSpm, heartRateBpm, latitude, longitude, altitudeMeters）
- [x] 1.2 在 `Models.swift` 新增 `@Model class DragonBoatActivity`（統計欄位 + `@Relationship(.cascade) dataPoints`）
- [x] 1.3 在 `boatDashboardApp.swift` 加入 `.modelContainer(for: [DragonBoatActivity.self, ActivityDataPoint.self])`

## 2. LocationManager — 逐秒暫存

- [x] 2.1 在 `LocationManager.swift` 新增 `private var pendingDataPoints: [PendingDataPoint] = []`（值型別暫存結構）
- [x] 2.2 在 `startRide()` 清空 `pendingDataPoints`；啟動 1 秒 Timer 每秒 append 快照
- [x] 2.3 在 `stopRide()` 停止 Timer，回傳 `[PendingDataPoint]` 給呼叫端
- [x] 2.4 處理 GPS speed < 0 時 speedKmh 記為 0.0（spec: activity-persistence §逐秒數據點暫存）

## 3. DataStore — 批次寫入 SwiftData

- [x] 3.1 在 `DataStore.swift` 注入 `ModelContext`（透過 `@Environment(\.modelContext)` 或 init 傳入）
- [x] 3.2 實作 `func saveActivity(_ points: [PendingDataPoint], summary: ActivitySummary)`：建立 `DragonBoatActivity` + 批次 insert DataPoints
- [x] 3.3 修改 `LiveDashboardView.endRide()` 改呼叫 `dataStore.saveActivity(...)`（移除舊 `dataStore.saveRecord`）

## 4. RecordsView 改版

- [ ] 4.1 修改 `RecordsView.swift`：將 `dataStore.records` 改為 `@Query(sort: \DragonBoatActivity.startTime, order: .reverse) var activities`
- [ ] 4.2 實作右滑刪除（`.onDelete`）呼叫 `modelContext.delete(activity)`（CASCADE 自動刪除 DataPoints）
- [ ] 4.3 更新 `RecordRow` 改用 `DragonBoatActivity` 屬性（name, startTime, totalDistanceMeters, duration）

## 5. ActivityDetailView — 基礎框架

- [ ] 5.1 新建 `ActivityDetailView.swift`，接受 `DragonBoatActivity` 參數
- [ ] 5.2 頂部靜態地圖：以 `Map` + `MapPolyline` 繪製軌跡，`MKMapRect` fit 範圍（spec: activity-detail-chart §頂部靜態軌跡地圖）
- [ ] 5.3 新增 `movingAverage(_ data: [Double], window: Int = 5) -> [Double]` 工具函式（spec: activity-detail-chart §數據平滑）

## 6. ActivityDetailView — 三圖表實作

- [ ] 6.1 實作 `SpeedChartView`（Area + Line，淺藍色，X 軸時間，Y 軸 km/h）
- [ ] 6.2 實作 `HeartRateChartView`（螢光紅，加平均心率虛線 + 最高心率點線）（spec: activity-detail-chart §心率參考線）
- [ ] 6.3 實作 `CadenceChartView`（Vaaka 橘，SPM）
- [ ] 6.4 三張圖共用 `@State var scrubTime: Date?`，傳入各圖作 `Binding`

## 7. 同步滑動互動（Synchronized Scrubbing）

- [ ] 7.1 在每張圖表 overlay `DragGesture`，將 x 偏移換算為時間戳更新 `scrubTime`
- [ ] 7.2 各圖表根據 `scrubTime` 繪製垂直線（`RuleMark`）與 data label（`annotation`）
- [ ] 7.3 地圖根據 `scrubTime` 找最近 DataPoint 座標，更新 `MapAnnotation` 標記位置（spec: activity-detail-chart §同步滑動標記）

## 8. 收尾與整合

- [ ] 8.1 在 `RecordsView` 的 `.sheet` 改為推送 `ActivityDetailView`（或 `NavigationLink`）
- [ ] 8.2 模擬器測試：用 `simulatePaddling` 產生測試資料，確認圖表與地圖正常渲染
- [ ] 8.3 確認 SwiftData 刪除功能：刪除一筆 Activity 後 DataPoints 也一併清除
- [ ] 8.4 git commit & push（附 change name tag）
