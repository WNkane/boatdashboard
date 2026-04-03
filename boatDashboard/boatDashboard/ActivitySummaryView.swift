import SwiftUI
import MapKit
import Charts
import Photos

// MARK: - Main Summary View

struct ActivitySummaryView: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var saveStatus: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // 1. Static route map with polyline
                    RouteMapView(coordinates: locationManager.routeCoordinates)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    // 2. Three ring gauges
                    HStack(spacing: 12) {
                        RingGauge(
                            value: locationManager.averageSpeed,
                            maxValue: max(locationManager.maxSpeed, 1),
                            label: "均速",
                            unit: "km/h",
                            color: .orange
                        )
                        RingGauge(
                            value: Double(locationManager.averageHeartRate),
                            maxValue: max(Double(locationManager.maxHeartRate), 1),
                            label: "平均心率",
                            unit: "bpm",
                            color: HRZone.zone(for: locationManager.averageHeartRate).color
                        )
                        RingGauge(
                            value: Double(locationManager.maxHeartRate),
                            maxValue: 200,
                            label: "最高心率",
                            unit: "bpm",
                            color: HRZone.zone(for: locationManager.maxHeartRate).color
                        )
                    }
                    .padding(.horizontal)

                    // 3. Speed history chart
                    SpeedChart(speedHistory: locationManager.speedHistory)
                        .frame(height: 180)
                        .padding(.horizontal)

                    // 4. Stat boxes
                    HStack(spacing: 12) {
                        StatBox(
                            label: "總距離",
                            value: String(format: "%.2f", locationManager.totalDistance / 1000),
                            unit: "km",
                            color: .cyan
                        )
                        StatBox(
                            label: "最高時速",
                            value: String(format: "%.1f", locationManager.maxSpeed),
                            unit: "km/h",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // 5. Save to Photos
                    Button(action: saveSnapshot) {
                        Label("Save to Photo", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    }

                    if let status = saveStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("騎乘總結")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(.orange)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Save snapshot

    private func saveSnapshot() {
        let snapshot = SummarySnapshot(
            averageSpeed: locationManager.averageSpeed,
            maxSpeed: locationManager.maxSpeed,
            averageHeartRate: locationManager.averageHeartRate,
            maxHeartRate: locationManager.maxHeartRate,
            totalDistanceKm: locationManager.totalDistance / 1000,
            totalElevationGain: locationManager.totalElevationGain,
            speedHistory: locationManager.speedHistory
        )

        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else {
            saveStatus = "圖片渲染失敗"
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self.saveStatus = "相簿存取被拒絕" }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }) { success, error in
                DispatchQueue.main.async {
                    self.saveStatus = success ? "已儲存到相簿！" : "儲存失敗"
                }
            }
        }
    }
}

// MARK: - Static Route Map (UIViewRepresentable for reliable polyline + custom pins)

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)
        map.removeAnnotations(map.annotations)

        guard coordinates.count > 1 else {
            return
        }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        map.addOverlay(polyline)
        map.setRegion(regionFor(coordinates), animated: false)

        let start = PinAnnotation(coordinate: coordinates.first!, color: .systemGreen)
        let end   = PinAnnotation(coordinate: coordinates.last!,  color: .systemRed)
        map.addAnnotations([start, end])
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: polyline)
            r.strokeColor = .orange
            r.lineWidth = 4
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pin = annotation as? PinAnnotation else { return nil }
            let id = "pin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.markerTintColor = pin.pinColor
            view.annotation = annotation
            return view
        }
    }

    private func regionFor(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta:  max((lats.max()! - lats.min()!) * 1.4, 0.002),
                longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.002)
            )
        )
    }
}

class PinAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let pinColor: UIColor
    init(coordinate: CLLocationCoordinate2D, color: UIColor) {
        self.coordinate = coordinate
        self.pinColor = color
    }
}

// MARK: - Ring Gauge

struct RingGauge: View {
    let value: Double
    let maxValue: Double
    let label: String
    let unit: String
    let color: Color

    private var fraction: Double { min(maxValue > 0 ? value / maxValue : 0, 1.0) }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0), value: fraction)
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 84, height: 84)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Speed Chart

struct SpeedChart: View {
    let speedHistory: [Double]

    private var data: [(index: Int, speed: Double)] {
        speedHistory.enumerated().map { (index: $0.offset, speed: $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("時速曲線")
                .font(.caption)
                .foregroundStyle(.gray)

            if data.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.1))
                    .overlay(Text("無資料").foregroundStyle(.gray))
            } else {
                Chart(data, id: \.index) { item in
                    AreaMark(
                        x: .value("樣本", item.index),
                        y: .value("時速", item.speed)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.45), Color.orange.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("樣本", item.index),
                        y: .value("時速", item.speed)
                    )
                    .foregroundStyle(Color.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(dash: [4]))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(Color.gray)
                    }
                }
                .chartPlotStyle { plot in
                    plot.background(Color(white: 0.08))
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1)))
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1)))
    }
}

// MARK: - Summary Snapshot (plain let values — safe for ImageRenderer)

struct SummarySnapshot: View {
    let averageSpeed: Double
    let maxSpeed: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let totalDistanceKm: Double
    let totalElevationGain: Double
    let speedHistory: [Double]

    var body: some View {
        VStack(spacing: 16) {
            Text("划槳總結")
                .font(.title2.bold())
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                RingGauge(value: averageSpeed, maxValue: max(maxSpeed, 1),
                          label: "均速", unit: "km/h", color: .orange)
                RingGauge(value: Double(averageHeartRate), maxValue: max(Double(maxHeartRate), 1),
                          label: "平均心率", unit: "bpm",
                          color: HRZone.zone(for: averageHeartRate).color)
                RingGauge(value: Double(maxHeartRate), maxValue: 200,
                          label: "最高心率", unit: "bpm",
                          color: HRZone.zone(for: maxHeartRate).color)
            }

            HStack(spacing: 12) {
                StatBox(label: "總距離",   value: String(format: "%.2f", totalDistanceKm), unit: "km",   color: .cyan)
                StatBox(label: "最高時速", value: String(format: "%.1f", maxSpeed),        unit: "km/h", color: .orange)
            }

            SpeedChart(speedHistory: speedHistory)
                .frame(height: 140)
        }
        .padding(20)
        .background(Color.black)
        .frame(width: 390)
    }
}
