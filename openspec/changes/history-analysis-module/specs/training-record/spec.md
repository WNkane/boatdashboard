## MODIFIED Requirements

### Requirement: 訓練紀錄列表讀取來源
`RecordsView` SHALL 從 SwiftData（`@Query`）讀取 `DragonBoatActivity`，依 `startTime` 降冪排列。

**原行為**：從 `DataStore.records: [TrainingRecord]`（UserDefaults）讀取

**新行為**：使用 `@Query(sort: \DragonBoatActivity.startTime, order: .reverse)` 讀取

#### Scenario: 新版 App 首次開啟紀錄頁
- **WHEN** 使用者升級至新版後開啟「訓練紀錄」
- **THEN** 列表顯示 SwiftData 中的活動（升級後為空），不顯示舊 UserDefaults 資料，不崩潰

#### Scenario: 完成一次划槳後的列表
- **WHEN** 使用者結束划槳，返回「訓練紀錄」頁
- **THEN** 新活動出現在列表最上方
