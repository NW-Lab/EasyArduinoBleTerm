import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var plotterVM = PlotterViewModel()
    @State private var selectedTab: Int = 0
    @State private var showDeviceSelection: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Picker("表示", selection: $selectedTab) {
                        Text("ターミナル").tag(0)
                        Text("プロッター").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    TabView(selection: $selectedTab) {
                        TerminalView(bleManager: bleManager)
                            .tag(0)

                        PlotterView(vm: plotterVM)
                            .tag(1)
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            let horizontalDistance = value.translation.width
                            let verticalDistance = value.translation.height
                            guard value.startLocation.x >= geometry.size.width - 24,
                                  horizontalDistance <= -50,
                                  abs(horizontalDistance) > abs(verticalDistance) * 1.5 else {
                                return
                            }
                            selectedTab = selectedTab == 0 ? 1 : 0
                        }
                )
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
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
                Text("接続中")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            .frame(minWidth: 80, alignment: .leading)
        case .connecting:
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("接続中...")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            .frame(minWidth: 80, alignment: .leading)
        case .disconnected:
            HStack(spacing: 6) {
                Circle()
                    .fill(.gray)
                    .frame(width: 10, height: 10)
                Text("未接続")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 80, alignment: .leading)
        case .failed(let msg):
            HStack(spacing: 6) {
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
                Text("エラー")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .frame(minWidth: 80, alignment: .leading)
            .help(msg)
        }
    }
}

#Preview {
    ContentView()
}
