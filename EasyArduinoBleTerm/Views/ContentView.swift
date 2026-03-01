import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var plotterVM = PlotterViewModel()
    @State private var selectedTab: Int = 0
    @State private var showDeviceSelection: Bool = false

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                TerminalView(bleManager: bleManager)
                    .tabItem {
                        Label("ターミナル", systemImage: "terminal")
                    }
                    .tag(0)

                PlotterView(vm: plotterVM)
                    .tabItem {
                        Label("プロッター", systemImage: "waveform.path.ecg")
                    }
                    .tag(1)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Connection status / connect button
                ToolbarItem(placement: .navigationBarLeading) {
                    connectionStatusView
                }

                // Device selection button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if bleManager.connectedPeripheral != nil {
                            bleManager.disconnect()
                        } else {
                            showDeviceSelection = true
                        }
                    } label: {
                        if bleManager.connectedPeripheral != nil {
                            Label("切断", systemImage: "xmark.circle")
                        } else {
                            Label("接続", systemImage: "plus.circle")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDeviceSelection) {
            DeviceSelectionView(bleManager: bleManager)
        }
        .onAppear {
            // BLEManagerのデータ受信コールバックをPlotterVMに接続
            bleManager.onDataReceived = { [weak plotterVM] line, timestamp in
                plotterVM?.processLine(line, timestamp: timestamp)
            }
        }
    }

    private var navigationTitle: String {
        if let peripheral = bleManager.connectedPeripheral {
            return peripheral.name ?? "接続済み"
        }
        return "EasyArduinoBleTerm"
    }

    @ViewBuilder
    private var connectionStatusView: some View {
        switch bleManager.connectionState {
        case .connected:
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("接続中")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .connecting:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("接続中...")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        case .disconnected:
            HStack(spacing: 4) {
                Circle()
                    .fill(.gray)
                    .frame(width: 8, height: 8)
                Text("未接続")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        case .failed(let msg):
            HStack(spacing: 4) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text("エラー")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .help(msg)
        }
    }
}

#Preview {
    ContentView()
}
