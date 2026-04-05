import SwiftUI
import SwiftData
import Charts
import MapKit

// MARK: - Moving Average (Task 5.3)

func movingAverage(_ data: [Double], window: Int = 5) -> [Double] {
    guard !data.isEmpty, window > 0 else { return data }
    return data.enumerated().map { i, _ in
        let lo = max(0, i - window / 2)
        let hi = min(data.count - 1, i + window / 2)
        let slice = data[lo...hi]
        return slice.reduce(0, +) / Double(slice.count)
    }
}

// MARK: - Scrub State (shared across charts)

class ScrubState: ObservableObject {
    @Published var time: Date? = nil
}

// MARK: - Activity Detail View (Task 5.1)

struct ActivityDetailView: View {
    let activity: DragonBoatActivity

    @StateObject private var scrub = ScrubState()

    // Sorted data points
    private var points: [ActivityDataPoint] {
        activity.dataPoints.sorted { $0.timestamp < $1.timestamp }
    }

    // GPS coordinates for map
    private var coordinates: [CLLocationCoordinate2D] {
        points.compactMap { p in
            guard p.latitude != 0 || p.longitude != 0 else { return nil }
            return CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude)
        }
    }

    // Scrub annotation coordinate
    private var scrubCoordinate: CLLocationCoordinate2D? {
        guard let t = scrub.time else { return nil }
        return points.min(by: { abs($0.timestamp.timeIntervalSince(t)) < abs($1.timestamp.timeIntervalSince(t)) })
            .flatMap { p in
                guard p.latitude != 0 || p.longitude != 0 else { return nil }
                return CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude)
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Top map (Task 5.2) ─────────────────────────────
                ActivityRouteMap(coordinates: coordinates, scrubCoord: scrubCoordinate)
                    .frame(height: 220)

                // ── Stats strip ───────────────────────────────────
                ActivityStatStrip(activity: activity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider().background(Color.gray.opacity(0.2))

                // ── Three charts (Tasks 6.1–6.4, 7.1–7.3) ────────
                VStack(spacing: 0) {
                    SpeedChartView(points: points, scrub: scrub)
                        .frame(height: 160)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Divider().background(Color.gray.opacity(0.15))

                    HeartRateChartView(points: points, scrub: scrub,
                                       avgBpm: activity.averageHeartRate,
                                       maxBpm: activity.maxHeartRate)
                        .frame(height: 160)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Divider().background(Color.gray.opacity(0.15))

                    CadenceChartView(points: points, scrub: scrub)
                        .frame(height: 160)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(activity.dateFormatted)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Route Map (Task 5.2)

struct ActivityRouteMap: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let scrubCoord: CLLocationCoordinate2D?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled   = false
        map.isUserInteractionEnabled = false
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

        if coordinates.count > 1 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(polyline)
            map.setVisibleMapRect(
                polyline.boundingMapRect.insetBy(dx: -polyline.boundingMapRect.width * 0.15,
                                                 dy: -polyline.boundingMapRect.height * 0.15),
                animated: false
            )
        } else {
            // Default to 碧潭
            let bitan = CLLocationCoordinate2D(latitude: 24.9603, longitude: 121.5399)
            map.setRegion(MKCoordinateRegion(center: bitan,
                                             span: MKCoordinateSpan(latitudeDelta: 0.01,
                                                                    longitudeDelta: 0.01)),
                          animated: false)
        }

        if let c = scrubCoord {
            let pin = ScrubAnnotation(coordinate: c)
            map.addAnnotation(pin)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let pl = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let r = MKPolylineRenderer(polyline: pl)
            r.strokeColor = UIColor.orange
            r.lineWidth   = 4
            return r
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is ScrubAnnotation else { return nil }
            let v = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "scrub")
            v.markerTintColor = .systemOrange
            v.glyphImage = UIImage(systemName: "circle.fill")
            return v
        }
    }
}

class ScrubAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

// MARK: - Stat Strip

struct ActivityStatStrip: View {
    let activity: DragonBoatActivity

    var body: some View {
        HStack(spacing: 0) {
            StatPill(label: "距離", value: String(format: "%.2f", activity.distanceKm), unit: "km", color: .cyan)
            StatPill(label: "時間", value: activity.durationFormatted, unit: "", color: .white)
            StatPill(label: "均速", value: String(format: "%.1f", activity.averageSpeedKmh), unit: "km/h", color: .orange)
            StatPill(label: "均心率", value: activity.averageHeartRate > 0 ? "\(activity.averageHeartRate)" : "--",
                     unit: "bpm", color: HRZone.zone(for: activity.averageHeartRate).color)
        }
    }
}

struct StatPill: View {
    let label: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color).monospacedDigit()
                if !unit.isEmpty { Text(unit).font(.system(size: 9)).foregroundStyle(.gray) }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Chart Helper: Scrub Gesture (Task 7.1)

struct ScrubGestureOverlay: View {
    let timestamps: [Date]
    @ObservedObject var scrub: ScrubState

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard !timestamps.isEmpty else { return }
                            let fraction = max(0, min(1, v.location.x / geo.size.width))
                            let idx = Int(fraction * Double(timestamps.count - 1))
                            scrub.time = timestamps[idx]
                        }
                        .onEnded { _ in scrub.time = nil }
                )
        }
    }
}

// MARK: - Speed Chart View (Task 6.1)

struct SpeedChartView: View {
    let points: [ActivityDataPoint]
    @ObservedObject var scrub: ScrubState

    private var smoothed: [(ts: Date, v: Double)] {
        let raw = points.map { $0.speedKmh }
        let avg = movingAverage(raw)
        return zip(points, avg).map { (ts: $0.timestamp, v: $1) }
    }

    private var scrubValue: Double? {
        guard let t = scrub.time else { return nil }
        return smoothed.min(by: { abs($0.ts.timeIntervalSince(t)) < abs($1.ts.timeIntervalSince(t)) })?.v
    }

    private let lineColor = Color(red: 0.4, green: 0.8, blue: 1.0)

    var body: some View {
        ChartContainer(label: "時速", unit: "km/h", color: lineColor, scrubValue: scrubValue.map { String(format: "%.1f", $0) }) {
            Chart(smoothed, id: \.ts) { item in
                AreaMark(x: .value("時間", item.ts), y: .value("km/h", item.v))
                    .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.4), lineColor.opacity(0.05)],
                                                   startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("時間", item.ts), y: .value("km/h", item.v))
                    .foregroundStyle(lineColor).lineStyle(StrokeStyle(lineWidth: 2))
                if let t = scrub.time {
                    RuleMark(x: .value("scrub", t))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis { AxisMarks { AxisGridLine(stroke: StrokeStyle(dash: [4])).foregroundStyle(Color.gray.opacity(0.25)); AxisValueLabel().foregroundStyle(Color.gray) } }
            .chartPlotStyle { $0.background(Color(white: 0.08)) }
            .overlay { ScrubGestureOverlay(timestamps: smoothed.map(\.ts), scrub: scrub) }
        }
    }
}

// MARK: - Heart Rate Chart View (Task 6.2)

struct HeartRateChartView: View {
    let points: [ActivityDataPoint]
    @ObservedObject var scrub: ScrubState
    let avgBpm: Int
    let maxBpm: Int

    private var smoothed: [(ts: Date, v: Double)] {
        let filtered = points.filter { $0.heartRateBpm > 0 }
        let raw = filtered.map { Double($0.heartRateBpm) }
        let avg = movingAverage(raw)
        return zip(filtered, avg).map { (ts: $0.timestamp, v: $1) }
    }

    private var scrubValue: Double? {
        guard let t = scrub.time else { return nil }
        return smoothed.min(by: { abs($0.ts.timeIntervalSince(t)) < abs($1.ts.timeIntervalSince(t)) })?.v
    }

    private let lineColor = Color(red: 1.0, green: 0.2, blue: 0.3)

    var body: some View {
        ChartContainer(label: "心率", unit: "bpm", color: lineColor,
                       scrubValue: scrubValue.map { String(format: "%.0f", $0) }) {
            if smoothed.isEmpty {
                ZStack {
                    Color(white: 0.08)
                    Text("無心率數據").foregroundStyle(.gray).font(.caption)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Chart(smoothed, id: \.ts) { item in
                    AreaMark(x: .value("時間", item.ts), y: .value("bpm", item.v))
                        .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.4), lineColor.opacity(0.05)],
                                                       startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("時間", item.ts), y: .value("bpm", item.v))
                        .foregroundStyle(lineColor).lineStyle(StrokeStyle(lineWidth: 2))
                    if avgBpm > 0 {
                        RuleMark(y: .value("平均", Double(avgBpm)))
                            .foregroundStyle(lineColor.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .annotation(position: .trailing) {
                                Text("均\(avgBpm)").font(.system(size: 9)).foregroundStyle(lineColor.opacity(0.8))
                            }
                    }
                    if maxBpm > 0 {
                        RuleMark(y: .value("最高", Double(maxBpm)))
                            .foregroundStyle(lineColor.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                            .annotation(position: .trailing) {
                                Text("最高\(maxBpm)").font(.system(size: 9)).foregroundStyle(lineColor.opacity(0.6))
                            }
                    }
                    if let t = scrub.time {
                        RuleMark(x: .value("scrub", t))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { AxisGridLine(stroke: StrokeStyle(dash: [4])).foregroundStyle(Color.gray.opacity(0.25)); AxisValueLabel().foregroundStyle(Color.gray) } }
                .chartPlotStyle { $0.background(Color(white: 0.08)) }
                .overlay { ScrubGestureOverlay(timestamps: smoothed.map(\.ts), scrub: scrub) }
            }
        }
    }
}

// MARK: - Cadence Chart View (Task 6.3)

struct CadenceChartView: View {
    let points: [ActivityDataPoint]
    @ObservedObject var scrub: ScrubState

    private var data: [(ts: Date, v: Double)] {
        points.filter { $0.cadenceSpm > 0 }.map { (ts: $0.timestamp, v: Double($0.cadenceSpm)) }
    }

    private var scrubValue: Double? {
        guard let t = scrub.time else { return nil }
        return data.min(by: { abs($0.ts.timeIntervalSince(t)) < abs($1.ts.timeIntervalSince(t)) })?.v
    }

    var body: some View {
        ChartContainer(label: "槳頻", unit: "spm", color: .orange,
                       scrubValue: scrubValue.map { String(format: "%.0f", $0) }) {
            if data.isEmpty {
                ZStack {
                    Color(white: 0.08)
                    Text("無槳頻數據").foregroundStyle(.gray).font(.caption)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Chart(data, id: \.ts) { item in
                    AreaMark(x: .value("時間", item.ts), y: .value("spm", item.v))
                        .foregroundStyle(LinearGradient(colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.05)],
                                                       startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("時間", item.ts), y: .value("spm", item.v))
                        .foregroundStyle(Color.orange).lineStyle(StrokeStyle(lineWidth: 2))
                    if let t = scrub.time {
                        RuleMark(x: .value("scrub", t))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { AxisGridLine(stroke: StrokeStyle(dash: [4])).foregroundStyle(Color.gray.opacity(0.25)); AxisValueLabel().foregroundStyle(Color.gray) } }
                .chartPlotStyle { $0.background(Color(white: 0.08)) }
                .overlay { ScrubGestureOverlay(timestamps: data.map(\.ts), scrub: scrub) }
            }
        }
    }
}

// MARK: - Chart Container (shared chrome)

struct ChartContainer<Content: View>: View {
    let label: String
    let unit: String
    let color: Color
    let scrubValue: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption.bold()).foregroundStyle(color)
                if let val = scrubValue {
                    Text("▸ \(val) \(unit)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(color.opacity(0.25)))
                }
                Spacer()
                Text(unit).font(.caption2).foregroundStyle(.gray)
            }
            content()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
