## ADDED Requirements

### Requirement: Live Activity 啟動
點擊「開始划槳」時，系統 SHALL 啟動一個 `Activity<DragonBoatActivityAttributes>`，在 Dynamic Island 與 Lock Screen 顯示訓練狀態。

#### Scenario: 正常啟動
- **WHEN** 使用者點擊「開始划槳」
- **THEN** Dynamic Island 出現 Compact 形態，顯示搏動指示點（左）與即時心率 + 區間（右）

#### Scenario: 裝置不支援 Live Activity
- **WHEN** 裝置為 iPhone 13 以下（不支援 Dynamic Island）或使用者停用 Live Activities
- **THEN** App 正常划槳，不崩潰，僅略過 Live Activity 啟動

---

### Requirement: Compact 形態
Dynamic Island Compact 形態 SHALL 顯示：
- 左側：橘色搏動圓點（訓練中指示）
- 右側：即時心率 bpm + HRZone 色碼

#### Scenario: 心率無數據
- **WHEN** HR 感測器未連接（heartRate = 0）
- **THEN** 右側顯示「-- bpm」，顏色為灰色

---

### Requirement: Expanded 形態
長按 Dynamic Island 展開，SHALL 顯示四項數據：
- 頂列：已划時間 | 距離
- 中央大字：時速 km/h
- 底列：心率（含區間色碼）| 槳頻 spm

#### Scenario: 有課表
- **WHEN** 訓練有綁定 WorkoutPlan
- **THEN** 底部加一列：「段N/M · 剩 X:XX」

---

### Requirement: Lock Screen 形態
鎖定螢幕 SHALL 顯示完整 Live Activity Banner：
- 標頭：龍舟圖示 + 「訓練進行中」 + 已划時間
- 主體：大時速 + 距離
- 卡片：心率（區間色碼）| 槳頻
- 課表進度列（有課表時）

#### Scenario: StandBy 模式
- **WHEN** iPhone 橫置充電進入 StandBy
- **THEN** Lock Screen Live Activity 以 StandBy 樣式顯示（系統自動適配）

---

### Requirement: 每秒數據更新
划槳中 SHALL 每秒更新 `Activity.update()`，ContentState 包含最新速度、心率、槳頻、距離、已划時間、課表進度。

#### Scenario: 前景更新
- **WHEN** App 在前景，每秒 Timer 觸發
- **THEN** Live Activity 數據與儀表板同步更新

#### Scenario: 背景節流
- **WHEN** App 在背景，系統對 `Activity.update()` 節流
- **THEN** Live Activity 數據最多延遲約 15 秒，不影響 GPS 與語音功能

---

### Requirement: Live Activity 結束
點擊「結束划槳」時，系統 SHALL 以 `.immediate` 模式結束 Live Activity。

#### Scenario: 正常結束
- **WHEN** 使用者點擊「結束划槳」
- **THEN** Dynamic Island 與 Lock Screen 的 Live Activity 立即消失
