## Why

App 切換到背景後 GPS 停止更新、計時器暫停、TTS 語音中斷，導致訓練數據中斷且無法在鎖定螢幕上得知訓練狀態。本次變更補上背景執行能力與 Dynamic Island / Lock Screen Live Activity，讓選手將手機放入口袋後仍能接收語音播報，並在鎖定螢幕看到即時速度、心率、槳頻。

## What Changes

- **加入 `UIBackgroundModes: [location, audio]`** 至 build settings，解鎖背景 GPS 與背景音訊
- **`TrainingAudioManager` 加入 AVAudioSession 中斷處理**（電話來電自動暫停，掛斷後恢復）
- **新增 Widget Extension target `boatDashboardLiveActivity`**，包含：
  - `DragonBoatActivityAttributes`（ActivityKit）
  - Compact / Expanded / Lock Screen / StandBy UI
- **`LiveDashboardView` 整合 ActivityKit**：開始划槳 → 啟動 Live Activity；每秒更新數據；結束划槳 → 結束 Live Activity
- **非目標（Non-goals）**：
  - Apple Watch companion app
  - Notification 推播
  - 多裝置同步
  - StandBy 以外的 Always-On 顯示（Apple Watch）

## Capabilities

### New Capabilities

- `background-execution`: 背景 GPS 持續更新 + 背景音訊播報，含中斷事件處理
- `live-activity`: Dynamic Island（Compact / Expanded）與 Lock Screen 即時訓練數據顯示

### Modified Capabilities

- `training-record`: `LiveDashboardView` 在 `startRide()` / `stopRide()` 生命週期增加 Live Activity 啟停

## Impact

| 項目 | 影響說明 |
|------|---------|
| `project.pbxproj` | 新增 Widget Extension target、新增 `UIBackgroundModes` build setting key |
| `TrainingAudioManager.swift` | 新增 `AVAudioSession.interruptionNotification` 觀察者 |
| `LiveDashboardView.swift` | 新增 `ActivityKit` import、`startLiveActivity()` / `updateLiveActivity()` / `endLiveActivity()` |
| `Models.swift` | 新增 `DragonBoatActivityAttributes: ActivityAttributes` |
| 新增檔案 | `boatDashboardLiveActivity/LiveActivityView.swift`（Widget Extension） |
| 相依套件 | ActivityKit（iOS 16.1+，已內建）；WidgetKit（iOS 14+，已內建） |
| 最低 iOS 版本 | 17.5（已符合，無需調整） |
| App Entitlements | 需加入 `com.apple.developer.live-activities` |
