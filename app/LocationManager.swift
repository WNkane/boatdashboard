import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    // 即時時速 (km/h)，CLLocation.speed 單位為 m/s，轉換 × 3.6
    @Published var speedKmh: Double = 0.0

    // 模擬踏頻 & 心率（等藍牙感測器購入後替換）
    @Published var cadence: Int = 0
    @Published var heartRate: Int = 0

    private var simulationTimer: Timer?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 1  // 每移動 1m 更新一次
        manager.activityType = .fitness
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        startSimulation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let rawSpeed = location.speed  // m/s，靜止時可能為 -1
        speedKmh = rawSpeed > 0 ? rawSpeed * 3.6 : 0.0
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }

    // MARK: - 模擬數據（踏頻 & 心率）

    private func startSimulation() {
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // 踏頻：模擬 70–95 rpm 的自然波動
            self.cadence = Int.random(in: 70...95)
            // 心率：模擬 130–160 bpm 的自然波動
            self.heartRate = Int.random(in: 130...160)
        }
    }

    deinit {
        simulationTimer?.invalidate()
    }
}
