# CLAUDE.md
2
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

### Data Flow

```
AppView (root)
  └─ environmentObject: DataStore      ← workouts + records (UserDefaults)
  └─ environmentObject: LocationManager ← GPS + BLE bridge

LocationManager owns:
  ├─ BluetoothHeartRateManager  (BLE HR Profile 0x180D / 0x2A37)
  └─ BluetoothCadenceManager    (BLE CSC Profile 0x1816 / 0x2A5B)
```

`LocationManager` is the single source of truth for live metrics (`speed`, `heartRate`, `cadence`, `heading`, `stationWeather`). BLE managers use `onHeartRateUpdate` / `onCadenceUpdate` callbacks to push values into `LocationManager`'s `@Published` properties.

### Navigation

`AppView` owns a `currentRoute: AppRoute` enum that drives the entire view hierarchy — no NavigationStack push/pop, no TabView. Routes: `.dashboard`, `.workout`, `.records`, `.live(WorkoutPlan?)`. A slide-in `SideMenuView` mutates `currentRoute` directly.

### Key Files

| File | Responsibility |
|---|---|
| `AppView.swift` | Root view, `AppRoute` enum, `SideMenuView` |
| `DataStore.swift` | `WorkoutPlan` / `TrainingRecord` CRUD, UserDefaults persistence |
| `LocationManager.swift` | GPS processing, session accumulators, weather fetch trigger |
| `LiveDashboardView.swift` | Active session UI + workout interval timer, also contains `LiveMetricsView`, `WorkoutIntervalBar`, `CadenceDevicePickerView`, `WeatherStatusRow` |
| `BluetoothHeartRateManager.swift` | BLE HR Profile; defines `HRConnectionState`, `DiscoveredHRDevice` (shared by cadence manager) |
| `BluetoothCadenceManager.swift` | BLE CSC Profile, CSC measurement parser |
| `WeatherService.swift` | CWA OpenData API (`opendata.cwa.gov.tw`), nearest-station lookup, 10-min cache |
| `TrainingAudioManager.swift` | AVSpeechSynthesizer zh-TW TTS for workout interval announcements |
| `Models.swift` | `HRZone`, `WorkoutInterval`, `WorkoutPlan`, `TrainingRecord` |

### Persistence

`DataStore` uses `UserDefaults` with versioned keys (`savedWorkouts_v3`, `savedRecords_v2`). When adding fields to `WorkoutPlan` or `TrainingRecord`, bump the key version to avoid decoding failures with existing data.

### Heart Rate Zones

Defined in `Models.swift` `HRZone`:
- Z1 < 115 bpm — 恢復
- Z2 115–137 — 有氧基礎
- Z3 138–154 — 有氧
- Z4 155–170 — 臨界
- Z5 ≥ 171 — 最大強度

Zone colors: Z1 gray / Z2 blue / Z3 green / Z4 orange / Z5 red.

### BLE Auto-Reconnect

Both BLE managers persist the last-connected device UUID to `UserDefaults` and attempt auto-reconnect on `centralManagerDidUpdateState(.poweredOn)` and after disconnect (3-second delay).

## OpenSpec Workflow

Changes are proposed and tracked under `openspec/changes/`. The `openspec/config.yaml` defines the project context for spec generation. See `openspec/AGENTS.md` for AI behavioral constraints (anti-hallucination protocol, no speculative language).
