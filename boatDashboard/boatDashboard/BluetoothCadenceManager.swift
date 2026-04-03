import CoreBluetooth
import Foundation

// MARK: - Cadence Manager
// Implements BLE Cycling Speed and Cadence (CSC) profile — Bluetooth SIG standard.
// Compatible with: Bryton cadence sensor, Garmin cadence sensor, Wahoo RPM, etc.
//
// Service:        0x1816  Cycling Speed and Cadence
// Characteristic: 0x2A5B  CSC Measurement  (notify)
// Characteristic: 0x2A5C  CSC Feature      (read — tells us what data is present)

class BluetoothCadenceManager: NSObject, ObservableObject {

    // BLE UUIDs (Bluetooth SIG standard)
    private let cscServiceUUID      = CBUUID(string: "1816")
    private let cscMeasurementUUID  = CBUUID(string: "2A5B")
    private let cscFeatureUUID      = CBUUID(string: "2A5C")

    // Published state
    @Published var cadence: Int = 0                        // spm / rpm
    @Published var connectionState: HRConnectionState = .idle
    @Published var discoveredDevices: [DiscoveredHRDevice] = []

    var onCadenceUpdate: ((Int) -> Void)?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?

    // CSC rolling-window state for delta calculation
    private var prevCrankRevs:  UInt16?
    private var prevCrankTime:  UInt16?  // units of 1/1024 s

    // Persist last-connected device
    private let savedDeviceKey = "cadence_saved_device_uuid"
    private var savedDeviceUUID: UUID? {
        get { UserDefaults.standard.string(forKey: savedDeviceKey).flatMap { UUID(uuidString: $0) } }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: savedDeviceKey) }
    }

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        injectSimulatorCadence()
        #else
        centralManager = CBCentralManager(delegate: self, queue: .main)
        #endif
    }

    // MARK: - Public API

    func startScanning() {
        #if !targetEnvironment(simulator)
        guard centralManager.state == .poweredOn else { return }
        discoveredDevices.removeAll()
        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [cscServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
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
        if let p = connectedPeripheral { centralManager.cancelPeripheralConnection(p) }
        savedDeviceUUID = nil
        cadence = 0
        connectionState = .idle
        prevCrankRevs = nil
        prevCrankTime = nil
        #endif
    }

    // MARK: - Simulator mock

    #if targetEnvironment(simulator)
    private var simulatorTimer: Timer?

    private func injectSimulatorCadence() {
        connectionState = .connected(deviceName: "Bryton (模擬)")
        cadence = 68
        onCadenceUpdate?(68)
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let delta = Int.random(in: -4...4)
            let spm = max(30, min(120, self.cadence + delta))
            self.cadence = spm
            self.onCadenceUpdate?(spm)
        }
    }
    #endif
}

// MARK: - CBCentralManagerDelegate

extension BluetoothCadenceManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            connectionState = .idle
            // Auto-reconnect last known device
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
            cadence = 0
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
            discoveredDevices.sort { $0.rssi > $1.rssi }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        savedDeviceUUID = peripheral.identifier
        connectionState = .connected(deviceName: peripheral.name ?? "踏頻器")
        peripheral.discoverServices([cscServiceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        cadence = 0
        connectionState = .disconnected
        prevCrankRevs = nil
        prevCrankTime = nil
        // Auto-reconnect
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, let p = self.connectedPeripheral else { return }
            self.connectionState = .connecting
            central.connect(p, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothCadenceManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        peripheral.services?
            .filter { $0.uuid == cscServiceUUID }
            .forEach {
                peripheral.discoverCharacteristics(
                    [cscMeasurementUUID, cscFeatureUUID], for: $0)
            }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        service.characteristics?.forEach { char in
            if char.uuid == cscMeasurementUUID {
                peripheral.setNotifyValue(true, for: char)
            } else if char.uuid == cscFeatureUUID {
                peripheral.readValue(for: char)  // optional: log supported features
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == cscMeasurementUUID,
              let data = characteristic.value
        else { return }

        if let spm = parseCSCMeasurement(data) {
            cadence = spm
            onCadenceUpdate?(spm)
        }
    }
}

// MARK: - CSC Measurement Parser
//
// Packet layout (Bluetooth SIG Vol 3, Part G, 3.131):
//
//  Byte 0      — Flags
//                  bit 0: Wheel Revolution Data Present
//                  bit 1: Crank Revolution Data Present
//
//  [If bit0=1]
//  Bytes 1–4   — Cumulative Wheel Revolutions  (UINT32 LE)
//  Bytes 5–6   — Last Wheel Event Time         (UINT16 LE, 1/1024 s)
//
//  [If bit1=1, after wheel data]
//  Bytes n–n+1 — Cumulative Crank Revolutions  (UINT16 LE)
//  Bytes n+2–n+3 — Last Crank Event Time       (UINT16 LE, 1/1024 s)

private extension BluetoothCadenceManager {

    func parseCSCMeasurement(_ data: Data) -> Int? {
        guard data.count >= 1 else { return nil }

        let flags = data[0]
        let hasWheel  = (flags & 0x01) != 0
        let hasCrank  = (flags & 0x02) != 0

        guard hasCrank else { return nil }

        // Skip over wheel data if present (4 bytes revs + 2 bytes time = 6 bytes)
        let crankOffset = hasWheel ? 7 : 1

        guard data.count >= crankOffset + 4 else { return nil }

        let crankRevs = data.leUInt16(at: crankOffset)
        let crankTime = data.leUInt16(at: crankOffset + 2)

        defer {
            prevCrankRevs = crankRevs
            prevCrankTime = crankTime
        }

        guard let prevRevs = prevCrankRevs,
              let prevTime = prevCrankTime
        else { return nil }

        // Handle 16-bit rollover
        let deltaRevs = Int(crankRevs &- prevRevs)
        let deltaTime = Int(crankTime &- prevTime)

        guard deltaRevs >= 0, deltaTime > 0 else { return nil }

        // deltaTime is in 1/1024 second units
        let seconds = Double(deltaTime) / 1024.0
        let rpm = Int((Double(deltaRevs) / seconds * 60.0).rounded())

        // Sanity check: 0–250 spm is physically plausible
        return (0...250).contains(rpm) ? rpm : nil
    }
}

// MARK: - Data helper

private extension Data {
    func leUInt16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
}
