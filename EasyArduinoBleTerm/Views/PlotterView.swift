import SwiftUI
import UIKit

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
    let gestureHint: String?   // nil = 通常, "ピンチ操作中", "スクロール中" など

    var body: some View {
        VStack {
            if let hint = gestureHint {
                HStack {
                    Text(hint)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.orange)
                        .padding(4)
                        .background(Color(UIColor.systemBackground).opacity(0.85))
                        .cornerRadius(4)
                        .padding(.leading, 6)
                        .padding(.top, 4)
                    Spacer()
                }
            }
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

// MARK: - Graph Interaction View
/// グラフ全体を覆う UIViewRepresentable。
/// ・UIPinchGestureRecognizer: 2本指の水平距離 → 横軸ズーム、垂直距離 → 縦軸ズーム
/// ・UIPanGestureRecognizer (2本指): 上下移動 → 縦軸オフセット（スクロール）
struct GraphInteractionView: UIViewRepresentable {

    // ピンチコールバック
    var onPinchBegan:   () -> Void
    var onPinchChanged: (_ hScale: CGFloat, _ vScale: CGFloat) -> Void
    var onPinchEnded:   () -> Void

    // パン（2本指スクロール）コールバック
    var onPanBegan:   () -> Void
    var onPanChanged: (_ deltaY: CGFloat) -> Void  // ポイント単位の移動量
    var onPanEnded:   () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        // delegateを設定することで shouldRecognizeSimultaneouslyWith が呼ばれる
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator
        // require(toFail:) は使わない—ピンチがパンの失敗を待つことになり動作しなくなるため
        view.addGestureRecognizer(pan)

        context.coordinator.pinchRecognizer = pinch
        context.coordinator.panRecognizer   = pan

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let c = context.coordinator
        c.onPinchBegan   = onPinchBegan
        c.onPinchChanged = onPinchChanged
        c.onPinchEnded   = onPinchEnded
        c.onPanBegan     = onPanBegan
        c.onPanChanged   = onPanChanged
        c.onPanEnded     = onPanEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPinchBegan:   onPinchBegan,
            onPinchChanged: onPinchChanged,
            onPinchEnded:   onPinchEnded,
            onPanBegan:     onPanBegan,
            onPanChanged:   onPanChanged,
            onPanEnded:     onPanEnded
        )
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPinchBegan:   () -> Void
        var onPinchChanged: (CGFloat, CGFloat) -> Void
        var onPinchEnded:   () -> Void
        var onPanBegan:     () -> Void
        var onPanChanged:   (CGFloat) -> Void
        var onPanEnded:     () -> Void

        weak var pinchRecognizer: UIPinchGestureRecognizer?
        weak var panRecognizer:   UIPanGestureRecognizer?

        // ピンチ開始時の2本指間距離
        private var startHDist: CGFloat = 1
        private var startVDist: CGFloat = 1

        // パン開始時の位置
        private var panStartY: CGFloat = 0

        init(onPinchBegan:   @escaping () -> Void,
             onPinchChanged: @escaping (CGFloat, CGFloat) -> Void,
             onPinchEnded:   @escaping () -> Void,
             onPanBegan:     @escaping () -> Void,
             onPanChanged:   @escaping (CGFloat) -> Void,
             onPanEnded:     @escaping () -> Void) {
            self.onPinchBegan   = onPinchBegan
            self.onPinchChanged = onPinchChanged
            self.onPinchEnded   = onPinchEnded
            self.onPanBegan     = onPanBegan
            self.onPanChanged   = onPanChanged
            self.onPanEnded     = onPanEnded
        }

        // ピンチとパンを同時認識させる
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }

        @objc func handlePinch(_ r: UIPinchGestureRecognizer) {
            switch r.state {
            case .began:
                // .began時は numberOfTouches が 1 の場合もあるので、初期値はデフォルトで記録しておく
                startHDist = 1
                startVDist = 1
                if r.numberOfTouches == 2, let view = r.view {
                    let p0 = r.location(ofTouch: 0, in: view)
                    let p1 = r.location(ofTouch: 1, in: view)
                    startHDist = max(abs(p0.x - p1.x), 1)
                    startVDist = max(abs(p0.y - p1.y), 1)
                }
                onPinchBegan()

            case .changed:
                guard r.numberOfTouches == 2, let view = r.view else { return }
                let p0 = r.location(ofTouch: 0, in: view)
                let p1 = r.location(ofTouch: 1, in: view)
                let hDist  = max(abs(p0.x - p1.x), 1)
                let vDist  = max(abs(p0.y - p1.y), 1)
                // 開始時の距離が小さすぎる場合は今の値で上書きして安定させる
                if startHDist < 2 { startHDist = hDist }
                if startVDist < 2 { startVDist = vDist }
                let hScale = hDist / startHDist   // >1 = 広がった
                let vScale = vDist / startVDist
                onPinchChanged(hScale, vScale)

            case .ended, .cancelled:
                onPinchEnded()

            default:
                break
            }
        }

        @objc func handlePan(_ r: UIPanGestureRecognizer) {
            guard let view = r.view else { return }
            let loc = r.translation(in: view)

            switch r.state {
            case .began:
                panStartY = 0
                onPanBegan()
            case .changed:
                // loc.y は開始からの累積移動量（下方向が正）
                let delta = loc.y - panStartY
                panStartY = loc.y
                onPanChanged(delta)
            case .ended, .cancelled:
                onPanEnded()
            default:
                break
            }
        }
    }
}

// MARK: - Main PlotterView
struct PlotterView: View {
    @ObservedObject var vm: PlotterViewModel

    // ピンチ開始時の初期値
    @State private var pinchStartTimeSpan: Double = 1.0
    @State private var pinchStartYMin: Double = -10.0
    @State private var pinchStartYMax: Double = 10.0
    @State private var gestureHint: String? = nil

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

                // 縦軸モード: タップするたびに自動⇔固定をトグル
                Button {
                    vm.toggleYAxisMode()
                } label: {
                    Label(vm.yAxisMode == .auto ? "自動" : "固定",
                          systemImage: vm.yAxisMode == .auto
                              ? "arrow.up.arrow.down.circle"
                              : "lock.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(vm.yAxisMode == .fixed ? .orange : .primary)

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

                    // Graph canvas
                    GeometryReader { geo in
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
                                gridInterval: vm.timeScale.gridInterval,
                                gestureHint: gestureHint
                            )

                            // ジェスチャー受付レイヤー
                            GraphInteractionView(
                                onPinchBegan: {
                                    pinchStartTimeSpan = vm.pinchTimeSpan
                                    let r = vm.yRange
                                    pinchStartYMin = r.min
                                    pinchStartYMax = r.max
                                    if vm.yAxisMode == .auto {
                                        vm.yFixedMin = r.min
                                        vm.yFixedMax = r.max
                                        vm.yAxisMode = .fixed
                                    }
                                    vm.pauseDisplay()
                                    gestureHint = "ピンチ操作中"
                                },
                                onPinchChanged: { hScale, vScale in
                                    // 横軸: 水平距離が広がった → 時間幅を縮小（ズームイン）
                                    let newSpan = pinchStartTimeSpan / Double(hScale)
                                    vm.pinchTimeSpan = min(max(newSpan, 0.05), 300.0)

                                    // 縦軸: 垂直距離が広がった → Y範囲を縮小（ズームイン）
                                    let center   = (pinchStartYMin + pinchStartYMax) / 2
                                    let halfSpan = (pinchStartYMax - pinchStartYMin) / 2
                                    let newHalf  = min(max(halfSpan / Double(vScale), 1e-6), 1e9)
                                    vm.yFixedMin = center - newHalf
                                    vm.yFixedMax = center + newHalf
                                },
                                onPinchEnded: {
                                    vm.resumeDisplay()
                                    gestureHint = nil
                                },
                                onPanBegan: {
                                    let r = vm.yRange
                                    pinchStartYMin = r.min
                                    pinchStartYMax = r.max
                                    if vm.yAxisMode == .auto {
                                        vm.yFixedMin = r.min
                                        vm.yFixedMax = r.max
                                        vm.yAxisMode = .fixed
                                    }
                                    vm.pauseDisplay()
                                    gestureHint = "スクロール中"
                                },
                                onPanChanged: { deltaY in
                                    // deltaY: 下方向が正（ポイント）
                                    // グラフ高さに対する割合でY値に変換
                                    let graphH = geo.size.height
                                    guard graphH > 0 else { return }
                                    let ySpan = vm.yFixedMax - vm.yFixedMin
                                    // 下にドラッグ → 値が小さい方向へシフト
                                    let shift = Double(deltaY) / Double(graphH) * ySpan
                                    vm.yFixedMin += shift
                                    vm.yFixedMax += shift
                                },
                                onPanEnded: {
                                    vm.resumeDisplay()
                                    gestureHint = nil
                                }
                            )
                        }
                    }
                    .clipped()
                }
            }
        }
    }
}
