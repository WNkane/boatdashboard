## ADDED Requirements

### Requirement: 頂部靜態軌跡地圖
`ActivityDetailView` 頂部 SHALL 顯示一張靜態地圖，以橘色 Polyline 繪製本次活動的 GPS 軌跡。

#### Scenario: 有 GPS 數據的活動
- **WHEN** 使用者開啟一筆含 GPS 座標的活動詳情
- **THEN** 地圖自動縮放至軌跡範圍（`MKMapRect` fit），以橘色線條繪製完整路線

#### Scenario: 無 GPS 數據的活動
- **WHEN** 活動的所有 DataPoints 座標均為 (0, 0) 或為空
- **THEN** 地圖顯示預設位置（碧潭），不繪製 Polyline

---

### Requirement: 三圖疊加圖表

系統 SHALL 在地圖下方垂直排列三張面積圖（Area Mark + Line Mark）：

| 圖表 | Y 軸 | 顏色 |
|------|------|------|
| 速度 | km/h | 淺藍（`Color(red: 0.4, green: 0.8, blue: 1.0)`） |
| 心率 | BPM  | 螢光紅（`Color(red: 1.0, green: 0.2, blue: 0.3)`） |
| 槳頻 | SPM  | Vaaka 橘（`.orange`） |

每張圖表背景 SHALL 為深灰色（`Color(white: 0.08)`），格線使用虛線（`StrokeStyle(dash: [4])`）。

#### Scenario: 正常顯示圖表
- **WHEN** 使用者開啟含 10 筆以上 DataPoints 的活動
- **THEN** 三張圖表各自顯示對應數據的面積圖，X 軸為時間軸

#### Scenario: 心率數據缺失
- **WHEN** 活動所有 DataPoints 的 `heartRateBpm == 0`
- **THEN** 心率圖表顯示空白區域並標示「無心率數據」

---

### Requirement: 心率參考線
心率圖表 SHALL 標記兩條水平參考線：平均心率（虛線）與最高心率（點線）。

#### Scenario: 顯示心率參考線
- **WHEN** 心率圖表渲染完成且有心率數據
- **THEN** 圖表上顯示平均心率的虛線與最高心率的點線，並附帶數值標籤

---

### Requirement: 同步滑動標記（Synchronized Scrubbing）
使用者在任一圖表上水平滑動時，系統 SHALL 同步更新所有圖表與地圖上的時間點標記。

#### Scenario: 滑動觸發同步
- **WHEN** 使用者在速度圖上按住並水平拖曳
- **THEN** 三張圖表同時顯示對應時間的垂直線與 data label；地圖上的標記點移動至對應 GPS 座標

#### Scenario: 滑動釋放
- **WHEN** 使用者放開手指
- **THEN** 垂直線與 data label 消失，恢復靜態圖表狀態

#### Scenario: 時間點無對應 DataPoint
- **WHEN** 滑動到兩個 DataPoint 中間的時間點
- **THEN** 系統顯示最近一筆 DataPoint 的數值（nearest neighbor）

---

### Requirement: 數據平滑（Moving Average）
顯示速度與心率圖表前，系統 SHALL 對數據套用 5 秒滑動平均，過濾感測器雜訊。

#### Scenario: 平滑後的速度圖
- **WHEN** 原始速度數據有短暫跳動（如 GPS 飄移造成的 ±3 km/h）
- **THEN** 圖表顯示平滑後的曲線，不顯示原始尖波

#### Scenario: 數據點不足 5 筆（活動初期）
- **WHEN** DataPoints 總數 < 5
- **THEN** 使用現有所有點計算平均，不崩潰
