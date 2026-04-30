## ADDED Requirements

### Requirement: HealthKit 授權請求
App 啟動時 SHALL 向使用者請求 HealthKit 心率讀取授權（`HKQuantityType.heartRate`）。若使用者拒絕，系統 SHALL 靜默降級，BLE 心率帶功能不受影響。

#### Scenario: 首次授權成功
- **WHEN** 使用者首次開啟 app 並同意 HealthKit 心率讀取
- **THEN** `HealthKitHeartRateManager.isAuthorized` 為 `true`，開始監聽心率

#### Scenario: 授權被拒絕
- **WHEN** 使用者拒絕 HealthKit 心率讀取授權
- **THEN** `HealthKitHeartRateManager.heartRate` 維持 0，app 其他功能正常運作

#### Scenario: 重複授權請求
- **WHEN** 使用者再次開啟 app（已授權過）
- **THEN** 系統不再顯示授權對話框，直接開始監聽

---

### Requirement: 即時心率讀取
`HealthKitHeartRateManager` SHALL 使用 `HKObserverQuery` + `HKAnchoredObjectQuery` 組合，在 Apple Watch 寫入新心率樣本後 10 秒內更新 `heartRate` 值。

#### Scenario: Apple Watch 訓練中輸出心率
- **WHEN** Apple Watch 上有進行中的運動，且 HealthKit 收到新心率樣本
- **THEN** `HealthKitHeartRateManager.heartRate` 在 10 秒內更新為最新 bpm 值

#### Scenario: Apple Watch 未啟動運動
- **WHEN** Apple Watch 未進行任何運動活動
- **THEN** `HealthKitHeartRateManager.heartRate` 維持上一個已知值或 0

#### Scenario: 無 Apple Watch 配對
- **WHEN** 裝置未配對 Apple Watch
- **THEN** `HealthKitHeartRateManager.heartRate` 維持 0

---

### Requirement: 心率來源優先序
`LocationManager.heartRate` SHALL 依以下優先序決定最終值：
1. BLE 心率帶已連線（`hrManager` isConnected）→ 使用 BLE 值
2. BLE 未連線 → 使用 `healthKitManager.heartRate`

#### Scenario: BLE 連線中，HealthKit 同時有值
- **WHEN** BLE 心率帶已連線，且 HealthKit 同時有心率資料
- **THEN** `LocationManager.heartRate` 回傳 BLE 值

#### Scenario: BLE 斷線後切換至 HealthKit
- **WHEN** BLE 心率帶連線中途斷線，HealthKit 有心率資料
- **THEN** `LocationManager.heartRate` 自動切換至 HealthKit 值，不需使用者手動操作

#### Scenario: 兩者皆無資料
- **WHEN** BLE 未連線且 HealthKit 心率為 0
- **THEN** `LocationManager.heartRate` 回傳 0，UI 顯示 `--`

---

### Requirement: 背景心率更新
訓練進行中（`isRiding == true`），`HealthKitHeartRateManager` SHALL 啟用 `enableBackgroundDelivery`，讓 app 在背景時仍能接收心率推送。

#### Scenario: App 進入背景，訓練進行中
- **WHEN** 訓練進行中 app 進入背景，Apple Watch 輸出新心率
- **THEN** `LocationManager.heartRate` 在下次回到前景時已更新為最新值

#### Scenario: 訓練結束後停止背景更新
- **WHEN** 呼叫 `stopRide()`
- **THEN** 停止 HKObserverQuery，`healthKitManager.heartRate` 不再更新

---

### Requirement: 心率來源 UI 標示
`HRZoneCell` SHALL 在心率數值下方顯示來源 badge，讓使用者知道心率來自哪個裝置。

#### Scenario: 心率來自 BLE 心率帶
- **WHEN** BLE 心率帶已連線且提供心率
- **THEN** HRZoneCell 顯示「BLE」badge（灰色小字）

#### Scenario: 心率來自 Apple Watch
- **WHEN** BLE 未連線，HealthKit 提供心率
- **THEN** HRZoneCell 顯示「Apple Watch」badge（灰色小字）

#### Scenario: 無心率資料
- **WHEN** BLE 未連線且 HealthKit 無資料
- **THEN** HRZoneCell 顯示 `--`，無 badge
