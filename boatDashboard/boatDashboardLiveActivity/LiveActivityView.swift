import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let val = UInt64(hex, radix: 16) ?? 0
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8)  & 0xFF) / 255
        let b = Double(val         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Elapsed Formatter

private func formatElapsed(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%02d:%02d", m, s)
}

private func formatRemaining(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

// MARK: - Widget

struct DragonBoatLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DragonBoatActivityAttributes.self) { context in
            // Lock Screen / Notification Banner
            LockScreenView(state: context.state, attrs: context.attributes)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(state: context.state)
                }
            } compactLeading: {
                // 搏動橘點
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                // 心率 + 區間色
                let zone = Color(hex: context.state.hrZoneColorHex)
                HStack(spacing: 3) {
                    Circle().fill(zone).frame(width: 6, height: 6)
                    Text(context.state.heartRate > 0 ? "\(context.state.heartRate)" : "--")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            } minimal: {
                Circle().fill(Color.orange).frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let state: DragonBoatActivityAttributes.ContentState
    let attrs: DragonBoatActivityAttributes
    private var zoneColor: Color { Color(hex: state.hrZoneColorHex) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("訓練進行中", systemImage: "oar.2.crossed")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                Spacer()
                Text(formatElapsed(state.elapsedSeconds))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().background(Color.gray.opacity(0.3)).padding(.vertical, 8)

            // Speed + Distance
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f", state.speedKmh))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                    Text("km/h").font(.caption).foregroundStyle(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f", state.distanceKm))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                        .monospacedDigit()
                    Text("km").font(.caption).foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)

            Divider().background(Color.gray.opacity(0.3)).padding(.vertical, 8)

            // HR + Cadence
            HStack {
                // Heart Rate
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Circle().fill(zoneColor).frame(width: 6, height: 6)
                        Text(state.hrZoneName).font(.system(size: 9, weight: .bold)).foregroundStyle(zoneColor)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(state.heartRate > 0 ? "\(state.heartRate)" : "--")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(state.heartRate > 0 ? zoneColor : .gray)
                            .monospacedDigit()
                        Text("bpm").font(.system(size: 10)).foregroundStyle(.gray)
                    }
                    Text("心率").font(.caption2).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 44).background(Color.gray.opacity(0.3))

                // Cadence
                VStack(spacing: 4) {
                    Text("槳頻").font(.caption2).foregroundStyle(.gray).opacity(0)  // spacer
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(state.cadenceSpm > 0 ? "\(state.cadenceSpm)" : "--")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.cyan)
                            .monospacedDigit()
                        Text("spm").font(.system(size: 10)).foregroundStyle(.gray)
                    }
                    Text("槳頻").font(.caption2).foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            // Interval bar (if workout)
            if state.totalIntervals > 0 {
                Divider().background(Color.gray.opacity(0.3)).padding(.vertical, 6)
                HStack {
                    Text("段 \(state.intervalIndex)/\(state.totalIntervals)")
                        .font(.caption2).foregroundStyle(.gray)
                    Spacer()
                    Text("剩 \(formatRemaining(state.intervalRemainingSeconds))")
                        .font(.caption2.bold()).foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(zoneColor)
                            .frame(width: geo.size.width * (state.totalIntervals > 0
                                ? Double(state.intervalIndex) / Double(state.totalIntervals) : 0))
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else {
                Spacer(minLength: 12)
            }
        }
        .background(Color.black)
    }
}

// MARK: - Expanded Island Views

struct ExpandedLeadingView: View {
    let state: DragonBoatActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatElapsed(state.elapsedSeconds))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text("時間").font(.system(size: 9)).foregroundStyle(.gray)
        }
        .padding(.leading, 8)
    }
}

struct ExpandedTrailingView: View {
    let state: DragonBoatActivityAttributes.ContentState
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.2f", state.distanceKm))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
                .monospacedDigit()
            Text("km").font(.system(size: 9)).foregroundStyle(.gray)
        }
        .padding(.trailing, 8)
    }
}

struct ExpandedCenterView: View {
    let state: DragonBoatActivityAttributes.ContentState
    var body: some View {
        VStack(spacing: 0) {
            Text(String(format: "%.1f", state.speedKmh))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
                .monospacedDigit()
            Text("km/h").font(.caption2).foregroundStyle(.gray)
        }
    }
}

struct ExpandedBottomView: View {
    let state: DragonBoatActivityAttributes.ContentState
    private var zoneColor: Color { Color(hex: state.hrZoneColorHex) }

    var body: some View {
        HStack {
            // HR
            HStack(spacing: 4) {
                Circle().fill(zoneColor).frame(width: 6, height: 6)
                Text(state.heartRate > 0 ? "\(state.heartRate) bpm" : "-- bpm")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(state.heartRate > 0 ? zoneColor : .gray)
                    .monospacedDigit()
            }

            Spacer()

            // Cadence
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.cyan)
                Text(state.cadenceSpm > 0 ? "\(state.cadenceSpm) spm" : "-- spm")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .monospacedDigit()
            }

            // Interval (if any)
            if state.totalIntervals > 0 {
                Spacer()
                Text("\(state.intervalIndex)/\(state.totalIntervals) · \(formatRemaining(state.intervalRemainingSeconds))")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Bundle

@main
struct boatDashboardLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        DragonBoatLiveActivityWidget()
    }
}
