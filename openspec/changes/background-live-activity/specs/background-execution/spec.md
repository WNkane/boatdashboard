## ADDED Requirements

### Requirement: 背景 GPS 持續更新
App 進入背景且划槳進行中，系統 SHALL 持續觸發 `CLLocationManager.didUpdateLocations`，DataPoint 每秒累積不中斷。

#### Scenario: 手機進入背景
- **WHEN** 使用者按 Home 鍵或切換 App，且 `isRiding == true`
- **THEN** `CLLocationManager` 仍持續更新，`pendingDataPoints` 每秒繼續 append

#### Scenario: 鎖定螢幕
- **WHEN** 螢幕鎖定，且 `isRiding == true`
- **THEN** GPS 更新不中斷，速度與距離計算持續進行

---

### Requirement: 背景 TTS 語音播報
划槳中進入背景，`AVSpeechSynthesizer` SHALL 仍可播報課表切換語音與倒數提示。

#### Scenario: 背景中課表切換
- **WHEN** App 在背景且課表 interval 計時到達
- **THEN** `TrainingAudioManager` 播報「第N段，有氧，X分鐘」語音正常輸出

---

### Requirement: 電話中斷後恢復
來電時語音中斷，通話結束後 `AVAudioSession` SHALL 自動恢復 active 狀態。

#### Scenario: 來電中斷
- **WHEN** 划槳中收到來電，系統觸發 `AVAudioSession.interruptionNotification`（began）
- **THEN** 語音自動停止，不崩潰

#### Scenario: 通話結束恢復
- **WHEN** 通話結束，系統觸發中斷通知（ended，shouldResume = true）
- **THEN** `AVAudioSession` 重新 `setActive(true)`，後續語音播報恢復正常
