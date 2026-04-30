## Why

目前 app 只支援 BLE 心率帶（Polar/Garmin/Wahoo），Apple Watch 因非 BLE Peripheral 而無法直接連線。大量使用者配戴 Apple Watch，若能透過 HealthKit 讀取即時心率，可大幅擴展裝置相容性，無需額外購買心率帶即可開始訓練。

## What Changes

- 新增 `HealthKitHeartRateManager`：透過 `HKAnchoredObjectQuery` + `HKObserverQuery` 即時讀取 Apple Watch 心率
- `LocationManager` 整合新 manager，心率來源優先序：BLE 心率帶 > HealthKit（先連線者優先）
- App 啟動時請求 HealthKit 心率讀取授權（`NSHealthShareUsageDescription`）
- 新增 HealthKit entitlement（`com.apple.developer.healthkit`）
- `LiveDashboardView` 心率區域顯示來源 badge（BLE / Apple Watch）

## Capabilities

### New Capabilities

- `healthkit-hr-reader`: 透過 HealthKit HKAnchoredObjectQuery 即時讀取 Apple Watch 心率，包含授權流程、即時觀察、背景推送

### Modified Capabilities

（無既有 spec 需要修改）

## Impact

**程式碼：**
- 新增 `HealthKitHeartRateManager.swift`（新檔案）
- 修改 `LocationManager.swift`：整合 HealthKit HR 作為備援心率來源
- 修改 `LiveDashboardView.swift`：心率 cell 顯示來源 badge
- 修改 `Models.swift`：若需要新增心率來源 enum

**Info.plist：**
- 新增 `NSHealthShareUsageDescription`

**Entitlements：**
- 新增 `com.apple.developer.healthkit = YES`

**依賴：**
- HealthKit framework（Apple 內建，無第三方依賴）
- 需要實體裝置測試（模擬器 HealthKit 資料有限）

**非目標（Non-goals）：**
- 不寫入 HealthKit（僅讀取）
- 不支援 Workout Session API（不在 watchOS 側建立 app）
- 不支援 HRV、血氧等其他健康指標
- 不同步歷史心率至訓練紀錄（仍使用 BLE 即時值為主要資料來源）
