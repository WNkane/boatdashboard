# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

龍舟儀表板 (Dragon Boat Dashboard) — an iOS SwiftUI app for real-time dragon boat training. UI text and TTS announcements are in Traditional Chinese (繁體中文).

The Xcode project lives in `boatDashboard/boatDashboard.xcodeproj`. The `app/` directory contains early prototype files (not part of the Xcode build). The `openspec/` directory contains AI agent behavioral constraints and change specs.

## Build & Run

Open `boatDashboard/boatDashboard.xcodeproj` in Xcode, select a simulator or device, and press ⌘R.

There is no CLI build script. To build from the command line:
```bash
xcodebuild -project boatDashboard/boatDashboard.xcodeproj \
           -scheme boatDashboard \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build
```

Simulator default location is 碧潭 (Bitan), 新北市 (24.9603, 121.5399). BLE sensors and GPS are mocked automatically in the simulator via `#if targetEnvironment(simulator)` guards.

## Architecture

**Pattern:** MVVM with SwiftUI environment objects. No third-party dependencies.  
**Min iOS:** 17.5 (required for SwiftData)

### Data Flow

```
boatDashboardApp
  └─ .modelContainer(DragonBoatActivity, ActivityDataPoint)   ← SwiftData

AppView (root)
  ├─ environmentObject: DataStore      ← WorkoutPlan CRUD (UserDefaults)
  │                                       + saveActivity() → SwiftData
  └─ environmentObject: LocationManager ← GPS + BLE bridge
       ├─ BluetoothHeartRateManager  (BLE HR Profile 0x180D / 0x2A37)
       └─ BluetoothCadenceManager    (BLE CSC Profile 0x1816 / 0x2A5B)
```

`LocationManager` is the single source of truth for live metrics (`speed`, `heartRate`, `cadence`, `heading`, `stationWeather`). During a ride it accumulates `pendingDataPoints: [PendingDataPoint]` every second. On `stopRide()` it returns the full array for batch persistence.

### Persistence

| 資料 | 儲存層 | 說明 |
|------|--------|------|
| `DragonBoatActivity` + `ActivityDataPoint` | **SwiftData** | 訓練紀錄與每秒數據點，CASCADE delete |
| `WorkoutPlan` | UserDefaults (`savedWorkouts_v3`) | 課表，JSON encoded |
| BLE last-connected UUID | UserDefaults | HR: `hr_saved_device_uuid`；Cadence: `cadence_saved_device_uuid` |

`DataStore.modelContext` is injected from `AppView` via `.onAppear`. When adding fields to `WorkoutPlan`, bump the UserDefaults key version to avoid decode failures.

### Navigation

`AppView` owns a `currentRoute: AppRoute` enum that drives the entire view hierarchy — no TabView. Routes: `.dashboard`, `.workout`, `.records`, `.live(WorkoutPlan?)`. A slide-in `SideMenuView` mutates `currentRoute` directly. Within `RecordsView`, `navigationDestination(item:)` pushes `ActivityDetailView`.

### Key Files

| File | Responsibility |
|------|----------------|
| `AppView.swift` | Root view, `AppRoute` enum, `SideMenuView`, ModelContext injection |
| `DataStore.swift` | `WorkoutPlan` CRUD (UserDefaults) + `saveActivity()` batch write to SwiftData |
| `Models.swift` | `HRZone`, `WorkoutInterval`, `WorkoutPlan`, `TrainingRecord` (legacy), `DragonBoatActivity`, `ActivityDataPoint` (@Model), `PendingDataPoint` |
| `LocationManager.swift` | GPS processing, 1-second DataPoint timer, session accumulators, weather fetch |
| `LiveDashboardView.swift` | Active session UI, workout interval timer, `RideSavedSheet`; also `LiveMetricsView`, `WorkoutIntervalBar`, `CadenceDevicePickerView`, `WeatherStatusRow` |
| `RecordsView.swift` | `@Query` DragonBoatActivity list, right-swipe delete (CASCADE) |
| `ActivityDetailView.swift` | Route map + Speed/HR/Cadence charts + synchronized scrubbing (`ScrubState`) |
| `DashboardHomeView.swift` | Last activity card + weekly mileage chart (both via `@Query`) |
| `ActivitySummaryView.swift` | Post-ride summary sheet with route map, ring gauges, speed chart, save-to-Photos |
| `BluetoothHeartRateManager.swift` | BLE HR Profile; defines `HRConnectionState`, `DiscoveredHRDevice` |
| `BluetoothCadenceManager.swift` | BLE CSC Profile, CSC measurement parser |
| `WeatherService.swift` | CWA OpenData API (`opendata.cwa.gov.tw`), nearest-station lookup, 10-min cache |
| `TrainingAudioManager.swift` | AVSpeechSynthesizer zh-TW TTS for workout interval announcements |

### Heart Rate Zones

Defined in `Models.swift` `HRZone` (hardcoded, no user profile):
- Z1 < 115 bpm — 恢復 (gray)
- Z2 115–137 — 有氧基礎 (blue)
- Z3 138–154 — 有氧 (green)
- Z4 155–170 — 臨界 (orange)
- Z5 ≥ 171 — 最大強度 (red)

### BLE Compatibility

| 裝置類型 | Profile | 支援 |
|---------|---------|------|
| Polar / Garmin / Wahoo HR 胸帶 | BLE HR 0x180D | ✓ |
| Vaaka 槳頻器 | BLE CSC 0x1816 (crank) | ✓ |
| Rockbros 踏頻器 | BLE CSC 0x1816 (crank) | ✓ (需 crank bit=1) |
| Apple Watch | — | ✗ (非 BLE Peripheral) |

Both BLE managers auto-reconnect on `poweredOn` and after disconnect (3-second delay).

### ActivityDetailView — Chart Architecture

```
ActivityDetailView
  ├─ ActivityRouteMap (UIViewRepresentable, MKPolyline + ScrubAnnotation)
  ├─ SpeedChartView    ─┐
  ├─ HeartRateChartView ├─ 共用 ScrubState (@ObservableObject)
  └─ CadenceChartView  ─┘
```

`ScrubState.time: Date?` is updated by `ScrubGestureOverlay` (DragGesture on each chart). All charts and the map react to the same `scrubTime` for synchronized scrubbing. `movingAverage(_:window:)` (window=5) smooths speed and HR data before rendering.

## OpenSpec Workflow

Changes are proposed and tracked under `openspec/changes/`. Use `openspec status --change <name>` to check progress. See `openspec/AGENTS.md` for AI behavioral constraints (anti-hallucination, no speculative language).

Slash commands: `/opsx:explore`, `/opsx:propose`, `/opsx:apply`, `/opsx:archive`
