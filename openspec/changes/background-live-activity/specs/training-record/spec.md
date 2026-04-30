## MODIFIED Requirements

### Requirement: 划槳生命週期整合 Live Activity
`LiveDashboardView.startRide()` / `endRide()` SHALL 分別啟動與結束 Live Activity。

**原行為**：`startRide()` 只呼叫 `locationManager.startRide()` 與 `audioManager.announceStart()`
**新行為**：額外呼叫 `startLiveActivity()`；`endRide()` 額外呼叫 `endLiveActivity()`

#### Scenario: 開始划槳同時啟動 Live Activity
- **WHEN** 使用者點擊「開始划槳」
- **THEN** Live Activity 與 GPS / Timer 同步啟動

#### Scenario: 結束划槳同時結束 Live Activity
- **WHEN** 使用者點擊「結束划槳」或課表完成自動結束
- **THEN** Live Activity 立即結束，不殘留在通知中心
