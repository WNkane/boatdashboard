import SwiftUI
import MapKit
#if canImport(ActivityKit)
import ActivityKit
#endif

// MARK: - Live Dashboard

struct LiveDashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var locationManager: LocationManager
    @Binding var currentRoute: AppRoute

    let workoutPlan: WorkoutPlan?

    @State private var position: MapCameraPosition = .userLocation(
        followsHeading: true, fallback: .automatic
    )
    @State private var showSummary    = false

    // Audio
    @StateObject private var audioManager = TrainingAudioManager()

    // Device pickers
    @State private var showHRPicker      = false
    @State private var showCadencePicker = false

    // Live Activity
    #if canImport(ActivityKit)
    @State private var liveActivity: Activity<DragonBoatActivityAttributes>?
    #endif

    // Workout session
    @State private var currentIntervalIndex = 0
    @State private var intervalElapsed: TimeInterval = 0
    @State private var sessionElapsed:  TimeInterval = 0
    @State private var rideStartTime:   Date? = nil
    @State private var timer: Timer? = nil

    private var currentInterval: WorkoutInterval? {
        guard let plan = workoutPlan,
              currentIntervalIndex < plan.intervals.count
        else { return nil }
        return plan.intervals[currentIntervalIndex]
    }

    private var intervalRemaining: TimeInterval {
        guard let iv = currentInterval else { return 0 }
        return max(0, Double(iv.durationSeconds) - intervalElapsed)
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack(alignment: .center) {
                if isLandscape {
                    // ── Landscape: 地圖左 45% ／ 指標右 55% ──────────────
                    HStack(spacing: 0) {
                        Map(position: $position) {
                            if locationManager.routeCoordinates.count > 1 {
                                MapPolyline(coordinates: locationManager.routeCoordinates)
                                    .stroke(.orange, lineWidth: 4)
                            }
                            UserAnnotation()
                        }
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                        }
                        .frame(width: geo.size.width * 0.45)

                        LiveMetricsView(
                            showCadencePicker: $showCadencePicker,
                            showHRPicker: $showHRPicker,
                            currentInterval: currentInterval,
                            intervalRemaining: intervalRemaining,
                            intervalIndex: currentIntervalIndex,
                            totalIntervals: workoutPlan?.intervals.count ?? 0,
                            isCompact: true
                        )
                        .frame(width: geo.size.width * 0.55)
                    }
                } else {
                    // ── Portrait: 地圖上 50% ／ 指標下 50% ───────────────
                    VStack(spacing: 0) {
                        Map(position: $position) {
                            if locationManager.routeCoordinates.count > 1 {
                                MapPolyline(coordinates: locationManager.routeCoordinates)
                                    .stroke(.orange, lineWidth: 4)
                            }
                            UserAnnotation()
                        }
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                        }
                        .frame(height: geo.size.height * 0.5)

                        LiveMetricsView(
                            showCadencePicker: $showCadencePicker,
                            showHRPicker: $showHRPicker,
                            currentInterval: currentInterval,
                            intervalRemaining: intervalRemaining,
                            intervalIndex: currentIntervalIndex,
                            totalIntervals: workoutPlan?.intervals.count ?? 0,
                            isCompact: false
                        )
                        .frame(height: geo.size.height * 0.5)
                    }
                }

                // ── Top overlay: back + mute ──────────────────────────────
                VStack {
                    HStack {
                        Button(action: {
                            if locationManager.isRiding { endRide() }
                            currentRoute = .dashboard
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title3.bold())
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, isLandscape ? 16 : 56)

                        Spacer()

                        Button(action: { audioManager.isMuted.toggle() }) {
                            Image(systemName: audioManager.isMuted
                                  ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.title3.bold())
                                .foregroundStyle(audioManager.isMuted ? .gray : .white)
                                .padding(10)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, isLandscape ? geo.size.width * 0.55 + 16 : 16)
                        .padding(.top, isLandscape ? 16 : 56)
                    }
                    Spacer()
                }
                .ignoresSafeArea()

                // ── Start / Stop 按鈕 ─────────────────────────────────────
                Button(action: toggleRide) {
                    Label(
                        locationManager.isRiding
                            ? "結束划槳"
                            : (workoutPlan != nil ? "開始課表" : "開始划槳"),
                        systemImage: locationManager.isRiding ? "stop.fill" : "play.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(locationManager.isRiding ? .white : .black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(locationManager.isRiding ? Color.red : Color.orange)
                            .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                    )
                }
                .offset(
                    x: isLandscape ? geo.size.width * 0.225 : 0,
                    y: isLandscape ? geo.size.height * 0.5 - 36 : geo.size.height * 0.5 - 44
                )
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSummary) {
            RideSavedSheet(onDismiss: { showSummary = false; currentRoute = .records })
        }
        .sheet(isPresented: $showHRPicker) {
            HeartRateDevicePickerView(hrManager: locationManager.hrManager)
        }
        .sheet(isPresented: $showCadencePicker) {
            CadenceDevicePickerView(cadenceManager: locationManager.cadenceManager)
        }
        .onDisappear { stopTimer() }
    }

    // MARK: - Ride control

    private func toggleRide() {
        locationManager.isRiding ? endRide() : startRide()
    }

    private func startRide() {
        locationManager.startRide()
        rideStartTime = Date()
        currentIntervalIndex = 0
        intervalElapsed = 0
        sessionElapsed = 0
        audioManager.announceStart()
        if workoutPlan != nil {
            startTimer()
            // Announce first interval after "開始" finishes speaking
            if let iv = currentInterval {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    audioManager.announceNextInterval(index: 1, interval: iv)
                }
            }
        }
        startLiveActivity()
    }

    private func endRide() {
        let points = locationManager.stopRide()
        stopTimer()

        let endTime   = Date()
        let startTime = rideStartTime ?? endTime

        dataStore.saveActivity(
            points:               points,
            startTime:            startTime,
            endTime:              endTime,
            totalDistanceMeters:  locationManager.totalDistance,
            averageSpeedKmh:      locationManager.averageSpeed,
            maxSpeedKmh:          locationManager.maxSpeed,
            averageHeartRate:     locationManager.averageHeartRate,
            maxHeartRate:         locationManager.maxHeartRate,
            workoutName:          workoutPlan?.name
        )
        endLiveActivity()
        showSummary = true
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            sessionElapsed  += 1
            intervalElapsed += 1
            updateLiveActivity()

            guard let iv = currentInterval else { return }

            // Countdown beep at 3 / 2 / 1 seconds remaining
            let remaining = Double(iv.durationSeconds) - intervalElapsed
            if remaining >= 1 && remaining <= 3 {
                audioManager.playCountdown(Int(remaining))
            }

            if intervalElapsed >= Double(iv.durationSeconds) {
                intervalElapsed = 0
                currentIntervalIndex += 1

                if let plan = workoutPlan, currentIntervalIndex >= plan.intervals.count {
                    audioManager.announceFinish()
                    endRide()
                } else if let nextIv = currentInterval {
                    audioManager.announceNextInterval(
                        index: currentIntervalIndex + 1,
                        interval: nextIv
                    )
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let zone = HRZone.zone(for: locationManager.heartRate)
        let initialState = DragonBoatActivityAttributes.ContentState(
            speedKmh:                locationManager.speed,
            heartRate:               locationManager.heartRate,
            hrZoneName:              zone.name,
            hrZoneColorHex:          zone.colorHex,
            cadenceSpm:              locationManager.cadence,
            elapsedSeconds:          Int(sessionElapsed),
            distanceKm:              locationManager.totalDistance / 1000,
            intervalIndex:           currentIntervalIndex,
            totalIntervals:          workoutPlan?.intervals.count ?? 0,
            intervalRemainingSeconds: Int(intervalRemaining)
        )
        let attrs = DragonBoatActivityAttributes(
            workoutName: workoutPlan?.name,
            startTime:   rideStartTime ?? Date()
        )
        do {
            liveActivity = try Activity.request(
                attributes: attrs,
                content: .init(state: initialState, staleDate: nil)
            )
        } catch {
            // Live Activity not available (simulator / older OS) — silently skip
        }
        #endif
    }

    private func updateLiveActivity() {
        #if canImport(ActivityKit)
        guard let activity = liveActivity else { return }
        let zone = HRZone.zone(for: locationManager.heartRate)
        let state = DragonBoatActivityAttributes.ContentState(
            speedKmh:                locationManager.speed,
            heartRate:               locationManager.heartRate,
            hrZoneName:              zone.name,
            hrZoneColorHex:          zone.colorHex,
            cadenceSpm:              locationManager.cadence,
            elapsedSeconds:          Int(sessionElapsed),
            distanceKm:              locationManager.totalDistance / 1000,
            intervalIndex:           currentIntervalIndex,
            totalIntervals:          workoutPlan?.intervals.count ?? 0,
            intervalRemainingSeconds: Int(intervalRemaining)
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
        #endif
    }

    private func endLiveActivity() {
        #if canImport(ActivityKit)
        guard let activity = liveActivity else { return }
        Task {
            await activity.end(dismissalPolicy: .immediate)
        }
        liveActivity = nil
        #endif
    }
}

// MARK: - Live Metrics View

struct LiveMetricsView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Binding var showCadencePicker: Bool
    @Binding var showHRPicker: Bool

    let currentInterval: WorkoutInterval?
    let intervalRemaining: TimeInterval
    let intervalIndex: Int
    let totalIntervals: Int
    var isCompact: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Speed
                VStack(spacing: 2) {
                    Text("時速")
                        .font(.caption).foregroundStyle(.gray)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", locationManager.speed))
                            .font(.system(size: isCompact ? 60 : 88, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        Text("km/h").font(isCompact ? .callout : .title3).foregroundStyle(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, isCompact ? 8 : 12)

                Divider().background(Color.gray.opacity(0.3)).padding(.vertical, isCompact ? 4 : 6)

                // 2-column grid: 槳頻 | 心率區間
                HStack(spacing: 4) {
                    CadenceMetricCell(
                        spm: locationManager.cadence,
                        state: locationManager.cadenceManager.connectionState,
                        isCompact: isCompact
                    )
                    .onTapGesture { showCadencePicker = true }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .frame(height: isCompact ? 50 : 70)

                    HRZoneCell(
                        bpm: locationManager.heartRate,
                        state: locationManager.hrManager.connectionState,
                        isCompact: isCompact
                    )
                    .onTapGesture { showHRPicker = true }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 8)

                // Weather row
                WeatherStatusRow(weather: locationManager.stationWeather)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)

                // Workout interval bar
                if let interval = currentInterval {
                    Divider().background(Color.gray.opacity(0.3)).padding(.vertical, isCompact ? 4 : 6)
                    WorkoutIntervalBar(
                        targetHeartRate: interval.targetHeartRate,
                        currentHeartRate: locationManager.heartRate,
                        intervalRemaining: intervalRemaining,
                        intervalIndex: intervalIndex,
                        totalIntervals: totalIntervals
                    )
                    .padding(.horizontal, 12)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Metric Cell (shared within this module)

struct MetricCell: View {
    let value: String
    let unit: String
    let label: String
    let color: Color
    var isCompact: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: isCompact ? 28 : 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(unit).font(.caption2).foregroundStyle(.gray)
            }
        }
        .padding(.vertical, isCompact ? 4 : 6)
    }
}

// MARK: - Cadence Metric Cell (with BLE status dot)

struct CadenceMetricCell: View {
    let spm: Int
    let state: HRConnectionState
    var isCompact: Bool = false

    private var dotColor: Color {
        switch state {
        case .connected:  return .green
        case .connecting: return .yellow
        case .scanning:   return .orange
        default:          return .gray
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text("槳頻").font(.caption2).foregroundStyle(.gray)
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(spm > 0 ? "\(spm)" : "--")
                    .font(.system(size: isCompact ? 28 : 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .monospacedDigit()
                Text("spm").font(.caption2).foregroundStyle(.gray)
            }
        }
        .padding(.vertical, isCompact ? 4 : 6)
    }
}

// MARK: - Heart Rate Zone Cell (with BLE status dot + zone badge)

struct HRZoneCell: View {
    let bpm: Int
    let state: HRConnectionState
    var isCompact: Bool = false

    private var zone: HRZone { HRZone.zone(for: bpm) }

    private var dotColor: Color {
        switch state {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .scanning:     return .orange
        default:            return .gray
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            // Label + BLE dot
            HStack(spacing: 4) {
                Text("心率").font(.caption2).foregroundStyle(.gray)
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }

            // Zone badge
            if bpm > 0 {
                Text("\(zone.label) \(zone.name)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(zone.color))
            }

            // BPM value
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(bpm > 0 ? "\(bpm)" : "--")
                    .font(.system(size: isCompact ? 28 : 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(bpm > 0 ? zone.color : Color(white: 0.5))
                    .monospacedDigit()
                Text("bpm").font(.caption2).foregroundStyle(.gray)
            }

            // Source badge
            if let sourceLabel = sourceBadgeLabel {
                Text(sourceLabel)
                    .font(.system(size: 8))
                    .foregroundStyle(.gray.opacity(0.6))
            }
        }
        .padding(.vertical, isCompact ? 4 : 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bpm > 0 ? zone.color.opacity(0.08) : Color.clear)
        )
    }

    private var sourceBadgeLabel: String? {
        switch state {
        case .connected: return "BLE"
        default:
            return bpm > 0 ? "Apple Watch" : nil
        }
    }
}

// MARK: - Workout Interval Bar (HR-based)

struct WorkoutIntervalBar: View {
    let targetHeartRate: Int
    let currentHeartRate: Int
    let intervalRemaining: TimeInterval
    let intervalIndex: Int
    let totalIntervals: Int

    private var targetZone: HRZone { HRZone.zone(for: targetHeartRate) }
    private var delta: Int { currentHeartRate - targetHeartRate }
    private var statusColor: Color {
        abs(delta) <= 5 ? .green : (delta > 0 ? .orange : .blue)
    }

    private var remainingFormatted: String {
        let m = Int(intervalRemaining) / 60
        let s = Int(intervalRemaining) % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Target HR + Zone badge
            VStack(alignment: .leading, spacing: 4) {
                Text("目標心率").font(.caption2).foregroundStyle(.gray)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(targetHeartRate)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(targetZone.color)
                        .monospacedDigit()
                    Text("bpm").font(.caption).foregroundStyle(.gray)
                }
                Text("\(targetZone.label) \(targetZone.name)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(targetZone.color))
            }

            // Delta
            VStack(alignment: .leading, spacing: 2) {
                Text("差值").font(.caption2).foregroundStyle(.gray)
                Text(currentHeartRate > 0 ? String(format: "%+d", delta) : "--")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(currentHeartRate > 0 ? statusColor : .gray)
                    .monospacedDigit()
            }

            Spacer()

            // Remaining time
            VStack(alignment: .trailing, spacing: 2) {
                Text("剩餘時間").font(.caption2).foregroundStyle(.gray)
                Text(remainingFormatted)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            // Progress ring
            VStack(spacing: 2) {
                Text("\(intervalIndex + 1)/\(totalIntervals)")
                    .font(.caption2).foregroundStyle(.gray)
                ZStack {
                    Circle().stroke(targetZone.color.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: totalIntervals > 0 ? Double(intervalIndex) / Double(totalIntervals) : 0)
                        .stroke(targetZone.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
    }
}

// MARK: - Cadence Device Picker

struct CadenceDevicePickerView: View {
    @ObservedObject var cadenceManager: BluetoothCadenceManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Bryton 踏頻器配對說明", systemImage: "info.circle")
                            .font(.caption.bold()).foregroundStyle(.orange)
                        Text("1. 裝上踏頻器並確認電池充足\n2. 轉動曲柄或晃動感應器使其喚醒\n3. 點擊下方「掃描裝置」")
                            .font(.caption2).foregroundStyle(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("支援所有 BLE CSC 標準裝置（Bryton / Garmin / Wahoo 等）")
                            .font(.caption2).foregroundStyle(.gray.opacity(0.7))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                    Divider().background(Color.gray.opacity(0.3))

                    // Connected banner
                    if cadenceManager.connectionState.isConnected {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(.cyan).font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cadenceManager.connectionState.label)
                                    .font(.subheadline.bold()).foregroundStyle(.white)
                                Text(cadenceManager.cadence > 0 ? "\(cadenceManager.cadence) spm" : "等待數據…")
                                    .font(.caption).foregroundStyle(.gray)
                            }
                            Spacer()
                            Button("斷開") { cadenceManager.disconnect() }
                                .font(.caption.bold()).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.red.opacity(0.8)).clipShape(Capsule())
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3)))
                        .padding()
                    }

                    // Scan controls
                    HStack {
                        Text(scanLabel).font(.caption).foregroundStyle(.gray)
                        Spacer()
                        if case .scanning = cadenceManager.connectionState {
                            ProgressView().tint(.cyan).padding(.trailing, 4)
                            Button("停止") { cadenceManager.stopScanning() }
                                .font(.caption.bold()).foregroundStyle(.cyan)
                        } else if !cadenceManager.connectionState.isConnected {
                            Button("掃描裝置") { cadenceManager.startScanning() }
                                .font(.caption.bold()).foregroundStyle(.cyan)
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)

                    // Device list
                    if cadenceManager.discoveredDevices.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 40)).foregroundStyle(.gray)
                            Text("尚未發現裝置").font(.subheadline).foregroundStyle(.gray)
                            Text("請晃動踏頻器喚醒後再掃描")
                                .font(.caption).foregroundStyle(.gray.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        List(cadenceManager.discoveredDevices) { device in
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.title2).foregroundStyle(.cyan)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name).font(.subheadline.bold()).foregroundStyle(.white)
                                    Text("訊號 \(device.rssi) dBm").font(.caption2).foregroundStyle(.gray)
                                }
                                Spacer()
                                Button("連接") {
                                    cadenceManager.connect(device)
                                    dismiss()
                                }
                                .font(.caption.bold()).foregroundStyle(.black)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.cyan).clipShape(Capsule())
                            }
                            .padding(.vertical, 6)
                            .listRowBackground(Color(white: 0.1))
                            .listRowSeparatorTint(Color.gray.opacity(0.3))
                        }
                        .listStyle(.plain).scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("連接踏頻裝置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.foregroundStyle(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if !cadenceManager.connectionState.isConnected { cadenceManager.startScanning() } }
        .onDisappear { cadenceManager.stopScanning() }
    }

    private var scanLabel: String {
        switch cadenceManager.connectionState {
        case .scanning:     return "掃描 BLE CSC 裝置中…"
        case .connecting:   return "連線中…"
        case .bluetoothOff: return "請開啟藍牙"
        default:            return "附近裝置（\(cadenceManager.discoveredDevices.count) 個）"
        }
    }
}

// MARK: - Ride Saved Sheet

struct RideSavedSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange)
                    Text("訓練已儲存")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("前往訓練紀錄查看詳細圖表分析")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                    Button(action: onDismiss) {
                        Text("查看紀錄")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.orange))
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { onDismiss() }.foregroundStyle(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Weather Status Row

struct WeatherStatusRow: View {
    let weather: StationWeather?

    var body: some View {
        HStack(spacing: 14) {
            if let wx = weather {
                // Temperature
                Label(String(format: "%.1f°C", wx.temperature), systemImage: "thermometer.medium")
                    .font(.caption.bold())
                    .foregroundStyle(.white)

                // Wind direction + speed
                Label("\(wx.windDirectionLabel) \(String(format: "%.1f", wx.windSpeed)) m/s",
                      systemImage: "wind")
                    .font(.caption.bold())
                    .foregroundStyle(windColor(wx.windSpeed))

                // Weather description
                Text(wx.description)
                    .font(.caption2)
                    .foregroundStyle(.gray)

                Spacer()

                // Station name
                Text(wx.stationName)
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.6))
            } else {
                Label("取得氣象中…", systemImage: "cloud")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Spacer()
            }
        }
    }

    private func windColor(_ ms: Double) -> Color {
        switch ms {
        case ..<3:  return .cyan
        case ..<7:  return .yellow
        default:    return .orange
        }
    }
}
