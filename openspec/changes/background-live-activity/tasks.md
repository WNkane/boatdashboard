## 1. 背景執行 — Build Settings

- [ ] 1.1 在 `project.pbxproj` Debug + Release build settings 加入 `INFOPLIST_KEY_UIBackgroundModes_location = location` 與 `INFOPLIST_KEY_UIBackgroundModes_audio = audio`（或直接加 `UIBackgroundModes` array key）
- [ ] 1.2 確認 `LocationManager.enableBackgroundUpdatesIfPossible()` 的 guard 現在可通過（Runtime 確認 `UIBackgroundModes` 包含 `location`）

## 2. AVAudioSession 中斷處理

- [ ] 2.1 在 `TrainingAudioManager.swift` 加入 `NotificationCenter.addObserver` 訂閱 `AVAudioSession.interruptionNotification`
- [ ] 2.2 實作 `handleAudioInterruption(_ notification: Notification)`：`began` 時不做任何事；`ended` 且 `shouldResume` 時呼叫 `AVAudioSession.setActive(true)`

## 3. DragonBoatActivityAttributes 資料模型

- [ ] 3.1 在 `Models.swift` 新增 `DragonBoatActivityAttributes: ActivityAttributes`，ContentState 包含：`speedKmh`, `heartRate`, `hrZoneName`, `hrZoneColorHex`, `cadenceSpm`, `elapsedSeconds`, `distanceKm`, `intervalIndex`, `totalIntervals`, `intervalRemainingSeconds`
- [ ] 3.2 在 `Models.swift` 加入 `import ActivityKit`（條件編譯 `#if canImport(ActivityKit)`）

## 4. Widget Extension Target

- [ ] 4.1 在 Xcode 手動新增 Widget Extension target（名稱：`boatDashboardLiveActivity`，Bundle ID：`boatDashboard.boatDashboard.liveactivity`）
- [ ] 4.2 建立 `boatDashboardLiveActivity/LiveActivityView.swift`：實作 Compact Leading / Trailing、Expanded、Lock Screen 四種佈局
- [ ] 4.3 建立 `boatDashboardLiveActivity/boatDashboardLiveActivityBundle.swift`：`@main WidgetBundle`
- [ ] 4.4 在主 app 的 Entitlements 檔加入 `com.apple.developer.live-activities = YES`

## 5. LiveDashboardView — ActivityKit 整合

- [x] 5.1 在 `LiveDashboardView.swift` 加入 `import ActivityKit`
- [x] 5.2 實作 `startLiveActivity()`：`ActivityAuthorizationInfo` 確認後呼叫 `Activity.request()`
- [x] 5.3 實作 `updateLiveActivity()`：建構最新 `ContentState` 並呼叫 `activity?.update()`
- [x] 5.4 實作 `endLiveActivity()`：呼叫 `activity?.end(dismissalPolicy: .immediate)`
- [x] 5.5 在 `startRide()` 末尾呼叫 `startLiveActivity()`
- [x] 5.6 在 `startTimer()` 的每秒 loop 末尾呼叫 `updateLiveActivity()`
- [x] 5.7 在 `endRide()` 末尾呼叫 `endLiveActivity()`

## 6. 單元測試

- [x] 6.1 `test_activityAttributes_contentState_encodable()`：ContentState 可 JSON encode/decode
- [x] 6.2 `test_hrZoneColorHex_allZones()`：五個 HRZone 各自回傳非空 hex 字串
- [x] 6.3 `test_audioInterruption_resumesSession()`：模擬中斷通知，驗證 `isMuted` 不受影響
- [x] 6.4 `test_backgroundModes_containsLocationAndAudio()`：從 Bundle 讀取 `UIBackgroundModes`，驗證同時包含 `location` 與 `audio`

## 7. 收尾

- [ ] 7.1 實機測試（需實體裝置）：確認 Dynamic Island 顯示、背景 GPS 持續、TTS 在背景播報
- [ ] 7.2 git commit & push
