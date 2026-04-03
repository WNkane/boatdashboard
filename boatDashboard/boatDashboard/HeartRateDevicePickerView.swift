import SwiftUI

// MARK: - Device Picker Sheet

struct HeartRateDevicePickerView: View {
    @ObservedObject var hrManager: BluetoothHeartRateManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    // ── Garmin pairing instructions ─────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Label("如何開啟 Garmin 心率廣播", systemImage: "info.circle")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text("手錶 → 活動選單 → 廣播心率\n或長按上鍵 → 感應器與配件 → 廣播心率")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                    Divider().background(Color.gray.opacity(0.3))

                    // ── Currently connected ──────────────────────────────────
                    if hrManager.connectionState.isConnected {
                        ConnectedBanner(state: hrManager.connectionState, bpm: hrManager.heartRate) {
                            hrManager.disconnect()
                        }
                        .padding()
                    }

                    // ── Scan controls ────────────────────────────────────────
                    HStack {
                        Text(scanStatusText)
                            .font(.caption)
                            .foregroundStyle(.gray)
                        Spacer()
                        if case .scanning = hrManager.connectionState {
                            ProgressView().tint(.orange)
                                .padding(.trailing, 4)
                            Button("停止") { hrManager.stopScanning() }
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        } else if !hrManager.connectionState.isConnected {
                            Button("掃描裝置") { hrManager.startScanning() }
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    // ── Device list ──────────────────────────────────────────
                    if hrManager.discoveredDevices.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "heart.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray)
                            Text("尚未發現裝置")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                            Text("請確認 Garmin 手錶已開啟心率廣播")
                                .font(.caption)
                                .foregroundStyle(.gray.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } else {
                        List(hrManager.discoveredDevices) { device in
                            DeviceRow(device: device) {
                                hrManager.connect(device)
                                dismiss()
                            }
                            .listRowBackground(Color(white: 0.1))
                            .listRowSeparatorTint(Color.gray.opacity(0.3))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("連接心率裝置")
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
        .onAppear {
            if !hrManager.connectionState.isConnected {
                hrManager.startScanning()
            }
        }
        .onDisappear { hrManager.stopScanning() }
    }

    private var scanStatusText: String {
        switch hrManager.connectionState {
        case .scanning:    return "掃描附近心率裝置中…"
        case .connecting:  return "連線中…"
        case .bluetoothOff: return "請開啟藍牙"
        default:           return "附近裝置（\(hrManager.discoveredDevices.count) 個）"
        }
    }
}

// MARK: - Connected Banner

private struct ConnectedBanner: View {
    let state: HRConnectionState
    let bpm: Int
    let onDisconnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(bpm > 0 ? "\(bpm) bpm" : "等待數據…")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Button(action: onDisconnect) {
                Text("斷開")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3)))
    }
}

// MARK: - Device Row

private struct DeviceRow: View {
    let device: DiscoveredHRDevice
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("訊號強度 \(device.rssi) dBm")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Button(action: onConnect) {
                Text("連接")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}
