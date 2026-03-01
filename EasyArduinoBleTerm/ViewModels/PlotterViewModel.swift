import Foundation
import SwiftUI
import Combine

// MARK: - TimeScale

/// 横軸の表示幅（秒単位）の3段階
enum TimeScale: Double, CaseIterable, Identifiable {
    case fine   = 0.1
    case medium = 1.0
    case coarse = 10.0

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .fine:   return "0.1s"
        case .medium: return "1s"
        case .coarse: return "10s"
        }
    }

    /// グリッド線の間隔（秒）
    var gridInterval: Double {
        switch self {
        case .fine:   return 0.01
        case .medium: return 0.1
        case .coarse: return 1.0
        }
    }
}

// MARK: - YAxisMode

/// 縦軸モード
enum YAxisMode: Equatable {
    case auto
    case fixed
}

// MARK: - PlotterViewModel

class PlotterViewModel: ObservableObject {

    // MARK: Published (UI用スナップショット — 描画タイマーで間引いて更新)
    @Published var channelSnapshots: [PlotChannel] = []
    @Published var timeScale: TimeScale = .medium
    @Published var yAxisMode: YAxisMode = .auto
    @Published var yFixedMin: Double = -10.0
    @Published var yFixedMax: Double = 10.0
    @Published var pinchTimeSpan: Double = 1.0

    // MARK: Private raw storage (BLEスレッドから直接書き込む)
    private var rawChannels: [PlotChannel] = []
    private var startTime: Date? = nil
    private let maxPoints = 10000

    // 描画更新タイマー: 最大30fps に制限
    private var displayTimer: Timer?
    private let displayInterval: TimeInterval = 1.0 / 30.0

    // MARK: - Init / Deinit

    init() {
        startDisplayTimer()
    }

    deinit {
        displayTimer?.invalidate()
    }

    // MARK: - Display Timer

    private var isDisplayPaused = false

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: displayInterval, repeats: true) { [weak self] _ in
            self?.flushSnapshot()
        }
        // バックグラウンドでも動作するよう RunLoop に追加
        RunLoop.main.add(displayTimer!, forMode: .common)
    }

    /// rawChannels のスナップショットを UI スレッドに反映する
    private func flushSnapshot() {
        guard !rawChannels.isEmpty, !isDisplayPaused else { return }
        channelSnapshots = rawChannels
    }

    /// ピンチ操作中に描画更新を一時停止する
    func pauseDisplay() {
        isDisplayPaused = true
    }

    /// ピンチ操作終了後に描画更新を再開する
    func resumeDisplay() {
        isDisplayPaused = false
        // 再開直後に最新スナップショットを即時反映
        if !rawChannels.isEmpty {
            channelSnapshots = rawChannels
        }
    }

    // MARK: - Computed (スナップショットから計算)

    var enabledSnapshots: [PlotChannel] {
        channelSnapshots.filter { $0.isEnabled }
    }

    var displayTimeSpan: Double { pinchTimeSpan }

    var latestTime: Double {
        rawChannels.flatMap { $0.points }.map { $0.time }.max() ?? 0
    }

    var visibleStartTime: Double {
        max(0, latestTime - displayTimeSpan)
    }

    var yRange: (min: Double, max: Double) {
        switch yAxisMode {
        case .fixed:
            return (yFixedMin, yFixedMax)
        case .auto:
            let vst = visibleStartTime
            let visiblePoints = enabledSnapshots.flatMap { ch in
                ch.points.filter { $0.time >= vst }
            }
            guard !visiblePoints.isEmpty else { return (-1, 1) }
            let minV = visiblePoints.map { $0.value }.min()!
            let maxV = visiblePoints.map { $0.value }.max()!
            let margin = max((maxV - minV) * 0.1, 0.5)
            let center = (minV + maxV) / 2
            let halfSpan = max((maxV - minV) / 2 + margin, 1.0)
            return (center - halfSpan, center + halfSpan)
        }
    }

    // MARK: - Data Ingestion (BLEコールバックから呼ばれる)

    /// BLEで受信した1行のデータを解析してチャンネルに追加する
    /// メインスレッドから呼ばれることを前提とする
    func processLine(_ line: String, timestamp: Date) {
        let parts = line.components(separatedBy: ",")
        let values = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !values.isEmpty else { return }

        if startTime == nil { startTime = timestamp }
        let elapsed = timestamp.timeIntervalSince(startTime!)

        let needed = min(values.count, 5)
        while rawChannels.count < needed {
            let newCh = PlotChannel(id: rawChannels.count)
            rawChannels.append(newCh)
        }

        for (i, value) in values.prefix(5).enumerated() {
            let point = PlotPoint(time: elapsed, value: value)
            rawChannels[i].points.append(point)
            if rawChannels[i].points.count > maxPoints {
                rawChannels[i].points.removeFirst(rawChannels[i].points.count - maxPoints)
            }
        }
    }

    // MARK: - Channel Toggle (UIから呼ばれる)

    func toggleChannel(_ id: Int) {
        if let idx = rawChannels.firstIndex(where: { $0.id == id }) {
            rawChannels[idx].isEnabled.toggle()
        }
        // 即座にスナップショットへ反映
        flushSnapshot()
    }

    // MARK: - Clear

    func clearData() {
        for i in rawChannels.indices {
            rawChannels[i].points.removeAll()
        }
        startTime = nil
        channelSnapshots = rawChannels
    }

    // MARK: - Zoom (横軸)

    func applyPinch(scale: CGFloat) {
        let newSpan = pinchTimeSpan / Double(scale)
        pinchTimeSpan = min(max(newSpan, 0.05), 300.0)
    }

    func applyTimeScale(_ scale: TimeScale) {
        timeScale = scale
        pinchTimeSpan = scale.rawValue
    }

    // MARK: - Y Axis Pinch (縦軸)

    /// 縦軸のピンチ操作: 現在の中心を保ったまま表示範囲を拡大縮小する。
    /// 自動モードの場合は固定モードに切り替えてから操作する。
    func applyYPinch(scale: CGFloat) {
        // 自動モードなら現在の yRange を固定値として取り込んでから固定モードへ
        if yAxisMode == .auto {
            let r = yRange
            yFixedMin = r.min
            yFixedMax = r.max
            yAxisMode = .fixed
        }
        let center = (yFixedMin + yFixedMax) / 2
        let halfSpan = (yFixedMax - yFixedMin) / 2
        // scale > 1 でピンチアウト（拡大）→ 範囲を縮小、scale < 1 でピンチイン（縮小）→ 範囲を拡大
        let newHalf = halfSpan / Double(scale)
        let clamped = min(max(newHalf, 1e-6), 1e9)
        yFixedMin = center - clamped
        yFixedMax = center + clamped
    }
}
