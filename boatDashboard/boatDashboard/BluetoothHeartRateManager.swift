import CoreBluetooth
import Foundation

// MARK: - Connection State

enum HRConnectionState: Equatable {
    case bluetoothOff
    case idle
    case scanning
    case connecting
    case connected(deviceName: String)
    case disconnected

    var label: String {
        switch self {
        case .bluetoothOff:              return "藍牙已關閉"
        case .idle:                      return "未連接"
        case .scanning:                  return "掃描中…"
        case .connecting:                return "連線中…"
        case .connected(let name):       return name
        case .disconnected:              return "已斷線"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

// MARK: - Discovered Device

struct DiscoveredHRDevice: Identifiable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
    var rssi: Int

    init(peripheral: CBPeripheral, rssi: Int) {
        self.id         = peripheral.identifier
        self.name       = peripheral.name ?? "未知裝置"
        self.peripheral = peripheral
        self.rssi       = rssi
    }
}

// MARK: - Manager

class BluetoothHeartRateManager: NSObject, ObservableObject {

    // BLE standard Heart Rate Profile UUIDs
    private let hrServiceUUID        = CBUUID(string: "180D")
    private let hrMeasurementUUID    = CBUUID(string: "2A37")
    private let deviceInfoServiceUUID = CBUUID(string: "180A")

    // Published state
    @Published var heartRate: Int = 0
    @Published var connectionState: HRConnectionState = .idle
    @Published var discoveredDevices: [DiscoveredHRDevice] = []

    // Callback for LocationManager integration
    var onHeartRateUpdate: ((Int) -> Void)?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?

    // Persist last-connected device UUID for auto-reconnect
    private let savedDeviceKey = "hr_saved_device_uuid"
    private var savedDeviceUUID: UUID? {
        get {
            UserDefaults.standard.string(forKey: savedDeviceKey)
                .flatMap { UUID(uuidString: $0) }
        }
        set {
            UserDefaults.standard.set(newValue?.uuidString, forKey: savedDeviceKey)
        }
    }

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        injectSimulatorHeartRate()
        #else
        centralManager = CBCentralManager(delegate: self, queue: .main)
        #endif
    }

    // MARK: - Simulator mock

    #if targetEnvironment(simulator)
    private var simulatorTimer: Timer?

    private func injectSimulatorHeartRate() {
        connectionState = .connected(deviceName: "Garmin (模擬)")
        heartRate = 72
        onHeartRateUpdate?(72)
        // Simulate realistic HR fluctuation every 2 seconds
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let delta = Int.random(in: -3...3)
            let bpm = max(55, min(185, self.heartRate + delta))
            self.heartRate = bpm
            self.onHeartRateUpdate?(bpm)
        }
    }
    #endif

    // MARK: - Public API

    func startScanning() {
        #if !targetEnvironment(simulator)
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [hrServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        // Auto-stop after 15 s if nothing selected
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.stopScanning()
        }
        #endif
    }

    func stopScanning() {
        #if !targetEnvironment(simulator)
        centralManager.stopScan()
        if case .scanning = connectionState { connectionState = .idle }
        #endif
    }

    func connect(_ device: DiscoveredHRDevice) {
        #if !targetEnvironment(simulator)
        stopScanning()
        connectionState = .connecting
        connectedPeripheral = device.peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(device.peripheral, options: nil)
        #endif
    }

    func disconnect() {
        #if !targetEnvironment(simulator)
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        savedDeviceUUID = nil
        heartRate = 0
        connectionState = .idle
        #endif
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothHeartRateManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionState = .idle
            // Try to auto-reconnect to last known device
            if let uuid = savedDeviceUUID {
                let known = central.retrievePeripherals(withIdentifiers: [uuid])
                if let p = known.first {
                    connectedPeripheral = p
                    p.delegate = self
                    connectionState = .connecting
                    central.connect(p, options: nil)
                }
            }
        case .poweredOff, .unauthorized, .unsupported:
            connectionState = .bluetoothOff
            heartRate = 0
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        if let idx = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[idx].rssi = rssi
        } else {
            discoveredDevices.append(DiscoveredHRDevice(peripheral: peripheral, rssi: rssi))
            // Sort by signal strength (closest first)
            discoveredDevices.sort { $0.rssi > $1.rssi }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        savedDeviceUUID = peripheral.identifier
        connectionState = .connected(deviceName: peripheral.name ?? "未知裝置")
        peripheral.discoverServices([hrServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .disconnected
        print("BLE connect failed: \(error?.localizedDescription ?? "unknown")")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        heartRate = 0
        connectionState = .disconnected
        // Auto-reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, let p = self.connectedPeripheral else { return }
            self.connectionState = .connecting
            central.connect(p, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothHeartRateManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil else { return }
        peripheral.services?
            .filter { $0.uuid == hrServiceUUID }
            .forEach { peripheral.discoverCharacteristics([hrMeasurementUUID], for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else { return }
        service.characteristics?
            .filter { $0.uuid == hrMeasurementUUID }
            .forEach { peripheral.setNotifyValue(true, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil,
              characteristic.uuid == hrMeasurementUUID,
              let data = characteristic.value
        else { return }

        let bpm = parseHeartRate(from: data)
        heartRate = bpm
        onHeartRateUpdate?(bpm)
    }
}

// MARK: - Heart Rate Data Parsing
// BLE Heart Rate Measurement format (Bluetooth SIG spec):
// Byte 0 — Flags:  bit0 = value format (0=UINT8, 1=UINT16)
// Byte 1 (or 1-2) — Heart Rate Value

private extension BluetoothHeartRateManager {
    func parseHeartRate(from data: Data) -> Int {
        guard data.count >= 2 else { return 0 }
        let flags  = data[0]
        let isU16  = (flags & 0x01) != 0
        if isU16 {
            guard data.count >= 3 else { return 0 }
            return Int(data[1]) | (Int(data[2]) << 8)
        } else {
            return Int(data[1])
        }
    }
}
