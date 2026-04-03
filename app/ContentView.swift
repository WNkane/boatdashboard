import SwiftUI
import MapKit

struct ContentView: View {

    @StateObject private var locationManager = LocationManager()

    // 地圖相機位置（跟隨用戶）
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                // MARK: 上半部 — 地圖 (50%)
                Map(position: $position) {
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .frame(height: geo.size.height * 0.5)
                .ignoresSafeArea(edges: .top)

                // MARK: 下半部 — 數據儀表板 (50%)
                dashboardView
                    .frame(height: geo.size.height * 0.5)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 儀表板

    private var dashboardView: some View {
        ZStack {
            Color.black.ignoresSafeArea(edges: .bottom)

            VStack(spacing: 20) {

                // 時速（GPS 實體數據）
                metricBlock(
                    value: String(format: "%.1f", locationManager.speedKmh),
                    unit: "km/h",
                    label: "時速",
                    valueFont: .system(size: 80, weight: .bold, design: .rounded),
                    color: .white
                )

                Divider().background(Color.gray.opacity(0.4))

                // 踏頻 & 心率（模擬數據）
                HStack(spacing: 0) {
                    metricBlock(
                        value: "\(locationManager.cadence)",
                        unit: "rpm",
                        label: "踏頻 (模擬)",
                        valueFont: .system(size: 44, weight: .semibold, design: .rounded),
                        color: .green
                    )

                    Divider()
                        .background(Color.gray.opacity(0.4))
                        .frame(height: 60)

                    metricBlock(
                        value: "\(locationManager.heartRate)",
                        unit: "bpm",
                        label: "心率 (模擬)",
                        valueFont: .system(size: 44, weight: .semibold, design: .rounded),
                        color: .red
                    )
                }
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - 共用數據方塊

    @ViewBuilder
    private func metricBlock(
        value: String,
        unit: String,
        label: String,
        valueFont: Font,
        color: Color
    ) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(valueFont)
                    .foregroundColor(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: value)

                Text(unit)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color.opacity(0.7))
            }
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.gray)
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
}
