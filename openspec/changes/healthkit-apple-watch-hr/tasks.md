## 1. 環境設定

- [x] 1.1 在 Xcode 為主 app target 啟用 HealthKit capability（Signing & Capabilities → + → HealthKit），自動產生 entitlement `com.apple.developer.healthkit = YES`
- [x] 1.2 在 `Info.plist` 新增 `NSHealthShareUsageDescription`（繁體中文說明：「龍舟訓練儀表板需要讀取您的心率資料，以便在訓練時顯示即時心跳與心率區間。」）

## 2. HealthKitHeartRateManager

- [x] 2.1 建立 `boatDashboard/boatDashboard/HealthKitHeartRateManager.swift`：定義 `class HealthKitHeartRateManager: ObservableObject`，含 `@Published var heartRate: Int = 0`、`@Published var isAuthorized: Bool = false`
- [x] 2.2 實作 `requestAuthorization()`：呼叫 `HKHealthStore.requestAuthorization(toShare:[], read:[heartRateType])`，成功後設 `isAuthorized = true` 並呼叫 `startObserving()`
- [x] 2.3 實作 `startObserving()`：建立 `HKObserverQuery`，收到通知後在 callback 呼叫 `fetchLatestHeartRate()`
- [x] 2.4 實作 `fetchLatestHeartRate()`：用 `HKAnchoredObjectQuery`（limit=1, predicate 最近 60 秒）讀取最新心率樣本，轉換為 bpm 後更新 `heartRate`（需 DispatchQueue.main.async）
- [x] 2.5 實作 `enableBackgroundDelivery()` / `disableBackgroundDelivery()`：呼叫 `HKHealthStore.enableBackgroundDelivery(for:frequency:.immediate)` 與對應停止方法
- [x] 2.6 實作 `stop()`：invalidate observer query，停止背景推送

## 3. LocationManager 整合

- [x] 3.1 在 `LocationManager.swift` 新增 `let healthKitManager = HealthKitHeartRateManager()`，並在 `init()` 呼叫 `healthKitManager.requestAuthorization()`
- [x] 3.2 修改 `LocationManager.heartRate` computed property（或對應欄位）：BLE `hrManager.connectionState.isConnected` 時使用 `hrManager.heartRate`，否則使用 `healthKitManager.heartRate`
- [x] 3.3 在 `startRide()` 呼叫 `healthKitManager.enableBackgroundDelivery()`
- [x] 3.4 在 `stopRide()` 呼叫 `healthKitManager.disableBackgroundDelivery()` 與 `healthKitManager.stop()`

## 4. UI 來源 Badge

- [x] 4.1 在 `LocationManager` 新增 `var heartRateSource: HeartRateSource`（enum: `.ble`, `.appleWatch`, `.none`），依優先序計算
- [x] 4.2 在 `LiveDashboardView.swift` 的 `HRZoneCell` 新增小字 badge：`.ble` → 灰色「BLE」，`.appleWatch` → 灰色「Apple Watch」，`.none` → 不顯示

## 5. 單元測試

- [x] 5.1 `test_heartRateSource_BLEPriority()`：BLE 已連線時，`heartRateSource` 為 `.ble`，即使 HealthKit 有值
- [x] 5.2 `test_heartRateSource_fallbackToHealthKit()`：BLE 未連線時，`heartRateSource` 為 `.appleWatch`（mock HealthKit HR > 0）
- [x] 5.3 `test_heartRateSource_none()`：BLE 未連線且 HealthKit HR = 0 時，`heartRateSource` 為 `.none`
- [x] 5.4 `test_healthKitManager_authorizationDenied_heartRateStaysZero()`：授權拒絕後 `heartRate` 維持 0

## 6. 登錄 Xcode 專案

- [x] 6.1 將 `HealthKitHeartRateManager.swift` 加入 `project.pbxproj`（PBXBuildFile、PBXFileReference、PBXGroup、PBXSourcesBuildPhase 四處）

## 7. 驗收

- [ ] 7.1 實機測試：Apple Watch 開始運動後，app 未連接 BLE 心率帶，確認心率更新
- [ ] 7.2 實機測試：連接 BLE 心率帶後，確認顯示 BLE 值，badge 顯示「BLE」
- [ ] 7.3 git commit & push
