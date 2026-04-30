## Context

目前 `LocationManager` 透過 `BluetoothHeartRateManager`（BLE 0x180D）取得心率，Apple Watch 因 watchOS 限制不廣播 BLE HR Profile，無法被掃描到。HealthKit 提供一個合法的橋接層：Apple Watch 訓練中持續將心率寫入 HealthKit，iOS app 可透過 `HKObserverQuery` 接收推送通知後，以 `HKAnchoredObjectQuery` 讀取最新值，達到準即時心率更新（延遲 3–10 秒）。

## Goals / Non-Goals

**Goals:**
- 在不影響現有 BLE 流程的前提下，新增 HealthKit 心率讀取路徑
- BLE 心率帶連線時優先使用 BLE；未連線時自動回退至 HealthKit
- 使用者授權一次，後續訓練自動生效
- 支援背景更新（`enableBackgroundDelivery`）

**Non-Goals:**
- 不寫入 HealthKit
- 不建立 watchOS companion app
- 不讀取 HRV、血氧或其他 HK 指標
- 不將 HealthKit 心率寫入 ActivityDataPoint 歷史紀錄（仍以 BLE 為主要持久化來源）

## Decisions

### 決策 1：新增獨立 `HealthKitHeartRateManager` 而非修改 BluetoothHeartRateManager

**選擇**：建立獨立類別 `HealthKitHeartRateManager: ObservableObject`  
**理由**：BLE 與 HealthKit 是完全不同的資料流，合併會使 `BluetoothHeartRateManager` 職責混亂。獨立類別更易測試，也符合現有架構（`BluetoothCadenceManager` 亦為獨立類別）。  
**替代方案**：在 `LocationManager` 直接寫 HealthKit 查詢 → 違反單一職責，難以 mock 測試。

### 決策 2：來源優先序由 `LocationManager` 協調

**選擇**：`LocationManager` 持有兩個 manager，用 computed property 決定最終 `heartRate`：
```
heartRate = BLE已連線 ? hrManager.heartRate : healthKitManager.heartRate
```
**理由**：LocationManager 已是所有感測器的 source of truth，在此彙整最自然，UI 不需感知來源。

### 決策 3：使用 HKObserverQuery + HKAnchoredObjectQuery 組合

**選擇**：`HKObserverQuery` 監聽新樣本到達 → callback 中以 `HKAnchoredObjectQuery` 讀取最新值  
**理由**：`HKObserverQuery` 單獨只通知有新資料，不提供值；`HKAnchoredObjectQuery` 可高效只取上次 anchor 之後的新樣本，避免重複讀取。  
**替代方案**：`HKSampleQuery` polling → 耗電且延遲不穩定。

### 決策 4：心率來源 badge 顯示在 HRZoneCell

**選擇**：在現有 `HRZoneCell` 加一行小字 badge（「Apple Watch」/ 「BLE」/ 「--」）  
**理由**：使用者需知道目前心率來自哪個裝置，以便判斷資料可信度。最小侵入式修改。

## Risks / Trade-offs

| 風險 | 緩解策略 |
|------|----------|
| Apple Watch 未開始運動 → HealthKit 不輸出即時心率 | 在 UI 顯示「需在 Watch 上開始運動」提示 |
| HealthKit 授權被拒絕 → 靜默降級，BLE 仍可用 | 授權失敗時 `healthKitManager.heartRate` 保持 0，UI 與 BLE 未連線時相同 |
| 背景 `enableBackgroundDelivery` 耗電 | 僅在 `isRiding == true` 時啟用背景推送；結束訓練後停止 |
| 模擬器 HealthKit 資料難以自動化測試 | 以 protocol 抽象 `HKHealthStore`，mock 後單元測試 |
| iOS 17.5 最低版本限制 | `HKQuantityType` 心率 API 於 iOS 8 即可用，無相容性問題 |

## Migration Plan

1. 新增 `HealthKitHeartRateManager.swift`
2. 修改 `LocationManager`：注入並持有新 manager
3. 修改 `Info.plist`：加 `NSHealthShareUsageDescription`
4. 在 Xcode 加 HealthKit entitlement（GUI 操作）
5. 修改 `HRZoneCell`：顯示來源 badge
6. 單元測試驗證優先序邏輯
7. 實機測試（需 Apple Watch 配對）

**Rollback**：HealthKit manager 為獨立模組，移除時只需刪除檔案與 LocationManager 中對應引用，不影響 BLE 路徑。
