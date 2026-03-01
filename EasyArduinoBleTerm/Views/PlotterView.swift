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
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let ySpan = yMax - yMin

            Canvas { context, size in
                // Background
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(UIColor.systemBackground)))

                // Grid lines (vertical / time)
                let firstGrid = (visibleStartTime / gridInterval).rounded(.up) * gridInterval
                var t = firstGrid
                while t <= visibleStartTime + displayTimeSpan {
                    let x = CGFloat((t - visibleStartTime) / displayTimeSpan) * w
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                    context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 0.5)
                    t += gridInterval
                }

                // Zero line
                if yMin < 0 && yMax > 0 {
                    let zeroY = h - CGFloat((0 - yMin) / ySpan) * h
                    var zeroPath = Path()
                    zeroPath.move(to: CGPoint(x: 0, y: zeroY))
                    zeroPath.addLine(to: CGPoint(x: w, y: zeroY))
                    context.stroke(zeroPath, with: .color(.gray.opacity(0.6)), lineWidth: 1)
                }

                // Plot each channel
                for channel in channels where channel.isEnabled {
                    let visiblePoints = channel.points.filter {
                        $0.time >= visibleStartTime - 0.01 &&
                        $0.time <= visibleStartTime + displayTimeSpan + 0.01
                    }
                    guard visiblePoints.count >= 2 else { continue }

                    var path = Path()
                    var started = false
                    for pt in visiblePoints {
                        let x = CGFloat((pt.time - visibleStartTime) / displayTimeSpan) * w
                        let y = h - CGFloat((pt.value - yMin) / ySpan) * h
                        let clamped = CGPoint(x: x, y: max(-5, min(h + 5, y)))
                        if !started {
                            path.move(to: clamped)
                            started = true
                        } else {
                            path.addLine(to: clamped)
                        }
                    }
                    context.stroke(path, with: .color(channel.color.color), lineWidth: 2)
                }
            }
            .frame(width: w, height: h)
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
                Text("← \(formatSpan(displayTimeSpan)) / div: \(formatSpan(gridInterval)) →")
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
        if s >= 1 { return String(format: "%.4g s", s) }
        return String(format: "%.4g s", s)
    }
}

// MARK: - Channel Selector
struct ChannelSelectorView: View {
    @Binding var channels: [PlotChannel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach($channels) { $ch in
                    Button {
                        ch.isEnabled.toggle()
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
                        .background(ch.isEnabled ? ch.color.color.opacity(0.15) : Color(UIColor.secondarySystemBackground))
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
    @GestureState private var pinchScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack(spacing: 8) {
                // Time scale picker
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

                // Y axis mode button
                Button {
                    showYSettings = true
                } label: {
                    Label(vm.yAxisMode == .auto ? "自動" : "固定", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                // Clear button
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

            // Channel selector
            if !vm.channels.isEmpty {
                ChannelSelectorView(channels: $vm.channels)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.secondarySystemBackground))
                Divider()
            }

            // Graph area
            HStack(spacing: 0) {
                // Y axis labels
                YAxisLabels(yMin: vm.yRange.min, yMax: vm.yRange.max)

                // Graph canvas with pinch gesture
                ZStack {
                    GraphCanvas(
                        channels: vm.channels,
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
                        .onChanged { scale in
                            // リアルタイムプレビューのため直接適用
                        }
                        .onEnded { scale in
                            vm.applyPinch(scale: scale)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinchScale) { value, state, _ in
                            state = value
                        }
                )
                .clipped()
            }

            // Empty state
            if vm.channels.isEmpty {
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
            }
        }
        .sheet(isPresented: $showYSettings) {
            YAxisSettingsSheet(vm: vm)
        }
    }
}
