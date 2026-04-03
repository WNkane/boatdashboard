import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    // MARK: - Live metrics
    @Published var speed: Double = 0.0         // km/h
    @Published var cadence: Int = 0            // spm  (Bluetooth stub)
    @Published var heartRate: Int = 0          // bpm  (Bluetooth stub)
    @Published var heading: Double = -1        // degrees true north; -1 = unavailable
    @Published var stationWeather: StationWeather? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private var lastWeatherFetch: Date?

    // MARK: - Bluetooth sensors
    let hrManager      = BluetoothHeartRateManager()
    let cadenceManager = BluetoothCadenceManager()

    // MARK: - Session state
    @Published var isRiding: Bool = false

    // MARK: - Session accumulators (reset on startRide)
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var speedHistory: [Double] = []
    @Published var heartRateHistory: [Int] = []
    @Published var maxSpeed: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var totalDistance: Double = 0.0       // metres
    @Published var totalElevationGain: Double = 0.0  // metres
    @Published var maxHeartRate: Int = 0
    @Published var averageHeartRate: Int = 0

    private var previousLocation: CLLocation?

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 2
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()

        // Forward BLE sensors to published properties
        hrManager.onHeartRateUpdate = { [weak self] bpm in
            self?.heartRate = bpm
        }
        cadenceManager.onCadenceUpdate = { [weak self] spm in
            self?.cadence = spm
        }

        #if targetEnvironment(simulator)
        injectBitanLocation()
        #endif
    }

    // MARK: - Session control

    func startRide() {
        routeCoordinates = []
        speedHistory = []
        heartRateHistory = []
        maxSpeed = 0
        averageSpeed = 0
        totalDistance = 0
        totalElevationGain = 0
        maxHeartRate = 0
        averageHeartRate = 0
        previousLocation = nil
        isRiding = true
    }

    func stopRide() {
        isRiding = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        #if !targetEnvironment(simulator)
        guard let location = locations.last else { return }
        processLocation(location)
        #endif
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            enableBackgroundUpdatesIfPossible()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager error: \(error.localizedDescription)")
    }

    // MARK: - Core location processing (shared by real GPS and simulator mock)

    private func processLocation(_ location: CLLocation) {
        let rawSpeed = location.speed
        let kmh = rawSpeed >= 0 ? rawSpeed * 3.6 : 0
        speed = kmh
        heading = location.course  // -1 when unavailable

        // (功率計算已移除，改以心率為訓練指標)

        // Refresh CWA weather at most once every 10 minutes
        let now = Date()
        if lastWeatherFetch == nil || now.timeIntervalSince(lastWeatherFetch!) > 600 {
            lastWeatherFetch = now
            fetchWeather(location)
        }

        guard isRiding else { return }

        routeCoordinates.append(location.coordinate)

        if let prev = previousLocation {
            let delta = location.distance(from: prev)
            totalDistance += delta
            let gain = location.altitude - prev.altitude
            if gain > 0 { totalElevationGain += gain }
        }
        previousLocation = location

        speedHistory.append(kmh)
        if kmh > maxSpeed { maxSpeed = kmh }
        averageSpeed = speedHistory.reduce(0, +) / Double(speedHistory.count)

        // Track HR history
        if heartRate > 0 {
            heartRateHistory.append(heartRate)
            if heartRate > maxHeartRate { maxHeartRate = heartRate }
            averageHeartRate = heartRateHistory.reduce(0, +) / heartRateHistory.count
        }
    }

    // MARK: - Simulator: inject 碧潭 mock location

    #if targetEnvironment(simulator)
    /// 碧潭 (Bitan), 新店區, 新北市 — used as the default dev location.
    private static let bitanCoordinate = CLLocationCoordinate2D(
        latitude:  24.9603,
        longitude: 121.5399
    )

    private func injectBitanLocation() {
        let mock = CLLocation(
            coordinate:         Self.bitanCoordinate,
            altitude:           12,
            horizontalAccuracy: 5,
            verticalAccuracy:   5,
            course:             0,      // heading north
            speed:              0,
            timestamp:          Date()
        )
        // Trigger weather fetch immediately on launch
        fetchWeather(mock)
    }

    /// Call from preview / debug UI to simulate active paddling at Bitan.
    func simulatePaddling(speedKmh: Double = 8.0, courseAngle: Double = 45) {
        let mock = CLLocation(
            coordinate:         Self.bitanCoordinate,
            altitude:           12,
            horizontalAccuracy: 5,
            verticalAccuracy:   5,
            course:             courseAngle,
            speed:              speedKmh / 3.6,
            timestamp:          Date()
        )
        processLocation(mock)
    }
    #endif

    // MARK: - Weather (CWA — nearest station)

    private func fetchWeather(_ location: CLLocation) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        Task {
            do {
                let wx = try await WeatherService.shared.fetchNearest(latitude: lat, longitude: lon)
                await MainActor.run { self.stationWeather = wx }
            } catch {
                print("WeatherService error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Background location guard

    private func enableBackgroundUpdatesIfPossible() {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        let modes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String]
        guard modes?.contains("location") == true else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }
}
