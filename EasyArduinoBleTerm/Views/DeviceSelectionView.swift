import SwiftUI
import CoreBluetooth

struct DeviceSelectionView: View {
    @ObservedObject var bleManager: BLEManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if bleManager.discoveredPeripherals.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                if bleManager.isScanning {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    Text("スキャン中...")
                                        .foregroundColor(.secondary)
                                } else {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("デバイスが見つかりません")
                                        .foregroundColor(.secondary)
                                    Text("スキャンを開始してください")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    }
                } else {
                    Section("検出されたデバイス") {
                        ForEach(bleManager.discoveredPeripherals) { device in
                            Button {
                                bleManager.connect(to: device)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name)
                                            .foregroundColor(.primary)
                                            .font(.body)
                                        Text(device.id.uuidString)
                                            .foregroundColor(.secondary)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: rssiIcon(device.rssi))
                                            .foregroundColor(rssiColor(device.rssi))
                                        Text("\(device.rssi) dBm")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("デバイス選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        bleManager.stopScanning()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if bleManager.isScanning {
                            bleManager.stopScanning()
                        } else {
                            bleManager.startScanning()
                        }
                    } label: {
                        if bleManager.isScanning {
                            Label("停止", systemImage: "stop.circle")
                        } else {
                            Label("スキャン", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                bleManager.startScanning()
            }
            .onDisappear {
                bleManager.stopScanning()
            }
        }
    }

    private func rssiIcon(_ rssi: Int) -> String {
        if rssi >= -60 { return "wifi" }
        if rssi >= -75 { return "wifi" }
        if rssi >= -90 { return "wifi" }
        return "wifi.slash"
    }

    private func rssiColor(_ rssi: Int) -> Color {
        if rssi >= -60 { return .green }
        if rssi >= -75 { return .yellow }
        if rssi >= -90 { return .orange }
        return .red
    }
}
