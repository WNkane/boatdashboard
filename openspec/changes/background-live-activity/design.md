## Context

專案 iOS Target 17.5，ActivityKit 與 WidgetKit 均已內建。目前 `UIBackgroundModes` 完全缺失，`LocationManager.enableBackgroundUpdatesIfPossible()` 的 guard 因此永遠無法通過。`TrainingAudioManager` 的 `AVAudioSession` 設定正確（`.playback` + `.mixWithOthers`）但缺少 `audio` background mode，App 進背景即被 suspend。

## Goals / Non-Goals

**Goals:**
- 背景 GPS + DataPoint Timer 持續運作
- 背景 TTS 語音播報（含電話中斷後自動恢復）
- Dynamic Island Compact / Expanded + Lock Screen Live Activity
- 課表進度、速度、心率、槳頻即時更新

**Non-Goals:**
- Apple Watch、iCloud、Notification 推播
- Always-On Display / StandBy 以外的自訂顯示

## Decisions

### D1：背景執行保持方式 — location + audio 雙模式

**決定**：同時啟用 `UIBackgroundModes: [location, audio]`

**理由**：
- `location` 保持 CLLocationManager 持續更新，`enableBackgroundUpdatesIfPossible()` guard 通過
- `audio` 讓 AVAudioSession 維持 active，AVSpeechSynthesizer 可在背景播報
- 兩者同時活躍時 app 主 RunLoop 不被 suspend，現有 1 秒 DataPoint Timer 與課表倒數 Timer 可繼續運作，無需重寫 Timer 邏輯

**替代方案**：BGTaskScheduler — 過重，適合長時間離線任務，非即時訓練場景

---

### D2：Live Activity 資料結構

```swift
struct DragonBoatActivityAttributes: ActivityAttributes {
    // Static（啟動時固定）
    struct ContentState: Codable, Hashable {
        var speedKmh: Double
        var heartRate: Int
        var hrZoneName: String
        var hrZoneColorHex: String   // 傳色碼避免 Color 無法 Codable
        var cadenceSpm: Int
        var elapsedSeconds: Int
        var distanceKm: Double
        var intervalIndex: Int       // 0 = 無課表
        var totalIntervals: Int
        var intervalRemainingSeconds: Int
    }
    var workoutName: String?         // static
    var startTime: Date              // static，供 timerInterval 計算
}
```

**理由**：ContentState 全部 Codable，避免傳遞 SwiftUI Color（無法序列化）；色碼在 Widget 端轉回 Color。

---

### D3：Live Activity 更新時機 — 每秒 piggyback DataPoint Timer

**決定**：在 `LiveDashboardView.startTimer()` 的 1 秒 loop 內，每秒呼叫 `updateLiveActivity()`

**理由**：複用現有 Timer，不增加額外計時器。Live Activity 更新頻率上限為系統自行節流（背景約 4–5 秒一次），前景每秒更新使 UI 流暢。

---

### D4：Widget Extension Target 加入方式

**決定**：直接編輯 `project.pbxproj` 加入完整 Widget Extension target

**理由**：無法透過 Xcode GUI 操作（CLI 環境），需手動寫入 pbxproj。Widget Extension 需要獨立 target、Bundle ID、Entitlements。

---

### D5：AVAudioSession 中斷處理

**決定**：訂閱 `AVAudioSession.interruptionNotification`，中斷開始時不做任何事（系統自動暫停），中斷結束且 `shouldResume` 為 true 時重新 `setActive(true)`

```
電話進來 → interruptionBegan → 系統暫停 synthesizer（自動）
電話掛斷 → interruptionEnded（shouldResume=true） → setActive(true) → synthesizer 恢復
```

---

### D6：Entitlements

**決定**：在主 app target 的 Entitlements 檔加入 `com.apple.developer.live-activities = YES`

Widget Extension 本身不需要額外 entitlement，但主 app 需要宣告。

## Risks / Trade-offs

| 風險 | 緩解策略 |
|------|---------|
| Live Activity 背景更新被系統節流（約 15 秒/次） | 前景時每秒更新正常；背景節流為系統限制，可接受 |
| Widget Extension pbxproj 手動加入易出錯 | 新增後以 `xcodebuild` 驗證 build |
| 電話中斷後 TTS 恢復時機不準確 | `shouldResume` flag 判斷，僅在系統確認可恢復時重啟 |
| `UIBackgroundModes: location` 需 Apple 審核說明 | App Store 說明欄位需填寫訓練追蹤用途（已有 NSLocationAlways 描述） |

## Open Questions

- [ ] Widget Extension Bundle ID 命名：`com.xxx.boatDashboard.liveactivity`（TBD — 需與現有 Bundle ID 確認前綴）
