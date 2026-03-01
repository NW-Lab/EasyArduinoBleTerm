import SwiftUI

// MARK: - Channel Color Helper
extension PlotChannelColor {
    var color: Color {
        switch self {
        case .blue:   return .blue
        case .red:    return .red
        case .green:  return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

// MARK: - Graph Canvas
struct GraphCanvas: View {
    let channels: [PlotChannel]
    let visibleStartTime: Double
    let displayTimeSpan: Double
    let yMin: Double
    let yMax: Double
    let gridInterval: Double

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let ySpan = max(yMax - yMin, 1e-9)

            // Background
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color(UIColor.systemBackground))
            )

            // Vertical grid lines (time axis)
            guard gridInterval > 0, displayTimeSpan > 0 else { return }
            let firstGrid = (visibleStartTime / gridInterval).rounded(.up) * gridInterval
            var t = firstGrid
            let endT = visibleStartTime + displayTimeSpan
            // 最大グリッド線数を制限して無限ループを防止
            let maxGridLines = Int(displayTimeSpan / gridInterval) + 2
            var gridCount = 0
            while t <= endT + gridInterval * 0.001 && gridCount < maxGridLines {
                let x = CGFloat((t - visibleStartTime) / displayTimeSpan) * w
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: h))
                context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 0.5)
                t += gridInterval
                gridCount += 1
            }

            // Zero line
            if yMin < 0 && yMax > 0 {
                let zeroY = h - CGFloat((0 - yMin) / ySpan) * h
                var zeroPath = Path()
                zeroPath.move(to: CGPoint(x: 0, y: zeroY))
                zeroPath.addLine(to: CGPoint(x: w, y: zeroY))
                context.stroke(zeroPath, with: .color(.gray.opacity(0.6)), lineWidth: 1)
            }

            // Plot each enabled channel
            for channel in channels where channel.isEnabled {
                let lo = visibleStartTime - gridInterval
                let hi = endT + gridInterval
                let visiblePoints = channel.points.filter { $0.time >= lo && $0.time <= hi }
                guard visiblePoints.count >= 2 else { continue }

                var path = Path()
                var started = false
                for pt in visiblePoints {
                    let x = CGFloat((pt.time - visibleStartTime) / displayTimeSpan) * w
                    let rawY = h - CGFloat((pt.value - yMin) / ySpan) * h
                    let clampedY = max(-5, min(h + 5, rawY))
                    let point = CGPoint(x: x, y: clampedY)
                    if !started {
                        path.move(to: point)
                        started = true
                    } else {
                        path.addLine(to: point)
                    }
                }
                context.stroke(path, with: .color(channel.color.color), lineWidth: 2)
            }
        }
    }
}

// MARK: - Y Axis Labels
struct YAxisLabels: View {
    let yMin: Double
    let yMax: Double
    let width: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let ySpan = yMax - yMin
            let steps = 5
            ForEach(0...steps, id: \.self) { i in
                let fraction = Double(i) / Double(steps)
                let value = yMin + fraction * ySpan
                let y = h - CGFloat(fraction) * h
                Text(formatValue(value))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: width, alignment: .trailing)
                    .position(x: width / 2, y: y)
            }
        }
        .frame(width: width)
    }

    private func formatValue(_ v: Double) -> String {
        if abs(v) >= 1000 { return String(format: "%.0f", v) }
        if abs(v) >= 100  { return String(format: "%.1f", v) }
        return String(format: "%.2f", v)
    }
}

// MARK: - Time Scale Label Overlay
struct TimeScaleOverlay: View {
    let displayTimeSpan: Double
    let gridInterval: Double

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("表示幅: \(formatSpan(displayTimeSpan)) / 目盛: \(formatSpan(gridInterval))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Color(UIColor.systemBackground).opacity(0.7))
                    .cornerRadius(4)
                    .padding(6)
            }
        }
    }

    private func formatSpan(_ s: Double) -> String {
        String(format: "%.4g s", s)
    }
}

// MARK: - Channel Selector
/// Bindingを使わず vm.toggleChannel() 経由で変更することで
/// channels 配列全体の再評価による無限再描画を防止する
struct ChannelSelectorView: View {
    let channels: [PlotChannel]
    let onToggle: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(channels) { ch in
                    Button {
                        onToggle(ch.id)
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ch.color.color)
                                .frame(width: 8, height: 8)
                            Text(ch.label)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            ch.isEnabled
                                ? ch.color.color.opacity(0.15)
                                : Color(UIColor.secondarySystemBackground)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ch.color.color, lineWidth: ch.isEnabled ? 1.5 : 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Y Axis Settings Sheet
struct YAxisSettingsSheet: View {
    @ObservedObject var vm: PlotterViewModel
    @Environment(\.dismiss) var dismiss

    @State private var minText: String = ""
    @State private var maxText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("縦軸モード") {
                    Picker("モード", selection: $vm.yAxisMode) {
                        Text("自動").tag(YAxisMode.auto)
                        Text("固定").tag(YAxisMode.fixed)
                    }
                    .pickerStyle(.segmented)
                }

                if vm.yAxisMode == .fixed {
                    Section("固定範囲") {
                        HStack {
                            Text("最小値")
                            Spacer()
                            TextField("最小値", text: $minText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        HStack {
                            Text("最大値")
                            Spacer()
                            TextField("最大値", text: $maxText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
            }
            .navigationTitle("縦軸設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        if let mn = Double(minText), let mx = Double(maxText), mn < mx {
                            vm.yFixedMin = mn
                            vm.yFixedMax = mx
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                minText = String(format: "%.2f", vm.yFixedMin)
                maxText = String(format: "%.2f", vm.yFixedMax)
            }
        }
    }
}

// MARK: - Main PlotterView
struct PlotterView: View {
    @ObservedObject var vm: PlotterViewModel
    @State private var showYSettings: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack(spacing: 8) {
                Picker("時間幅", selection: Binding(
                    get: { vm.timeScale },
                    set: { vm.applyTimeScale($0) }
                )) {
                    ForEach(TimeScale.allCases) { scale in
                        Text(scale.label).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)

                Spacer()

                Button {
                    showYSettings = true
                } label: {
                    Label(vm.yAxisMode == .auto ? "自動" : "固定",
                          systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    vm.clearData()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.secondarySystemBackground))

            Divider()

            // Channel selector (スナップショットを使用)
            if !vm.channelSnapshots.isEmpty {
                ChannelSelectorView(
                    channels: vm.channelSnapshots,
                    onToggle: { vm.toggleChannel($0) }
                )
                .padding(.vertical, 4)
                .background(Color(UIColor.secondarySystemBackground))
                Divider()
            }

            // Graph area
            if vm.channelSnapshots.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("データ待機中...")
                        .foregroundColor(.secondary)
                    Text("カンマ区切りの数値データを受信するとグラフが表示されます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Spacer()
            } else {
                HStack(spacing: 0) {
                    // Y axis labels
                    YAxisLabels(yMin: vm.yRange.min, yMax: vm.yRange.max)

                    // Graph canvas + pinch gesture
                    ZStack {
                        GraphCanvas(
                            channels: vm.channelSnapshots,
                            visibleStartTime: vm.visibleStartTime,
                            displayTimeSpan: vm.displayTimeSpan,
                            yMin: vm.yRange.min,
                            yMax: vm.yRange.max,
                            gridInterval: vm.timeScale.gridInterval
                        )

                        TimeScaleOverlay(
                            displayTimeSpan: vm.displayTimeSpan,
                            gridInterval: vm.timeScale.gridInterval
                        )
                    }
                    .gesture(
                        MagnificationGesture()
                            .onEnded { scale in
                                vm.applyPinch(scale: scale)
                            }
                    )
                    .clipped()
                }
            }
        }
        .sheet(isPresented: $showYSettings) {
            YAxisSettingsSheet(vm: vm)
        }
    }
}
