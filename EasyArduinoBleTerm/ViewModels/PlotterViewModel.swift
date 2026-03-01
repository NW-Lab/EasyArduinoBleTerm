import Foundation
import SwiftUI
import Combine

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

/// 縦軸モード
enum YAxisMode {
    case auto    // データに合わせて自動調整
    case fixed   // ユーザー指定の固定範囲
}

class PlotterViewModel: ObservableObject {
    // MARK: - Published
    @Published var channels: [PlotChannel] = []
    @Published var timeScale: TimeScale = .medium
    @Published var yAxisMode: YAxisMode = .auto
    @Published var yFixedMin: Double = -10.0
    @Published var yFixedMax: Double = 10.0
    @Published var pinchTimeSpan: Double = 1.0   // 現在の表示時間幅（ピンチで変更）

    // MARK: - Private
    private var startTime: Date? = nil
    private let maxPoints = 10000

    // MARK: - Computed

    /// 全チャンネルのうち有効なものだけ返す
    var enabledChannels: [PlotChannel] {
        channels.filter { $0.isEnabled }
    }

    /// 現在の表示時間幅（ピンチ値とtimeScaleを組み合わせ）
    var displayTimeSpan: Double {
        pinchTimeSpan
    }

    /// 最新の時刻（秒）
    var latestTime: Double {
        channels.flatMap { $0.points }.map { $0.time }.max() ?? 0
    }

    /// 表示範囲の開始時刻
    var visibleStartTime: Double {
        max(0, latestTime - displayTimeSpan)
    }

    /// 縦軸の表示範囲
    var yRange: (min: Double, max: Double) {
        switch yAxisMode {
        case .fixed:
            return (yFixedMin, yFixedMax)
        case .auto:
            let visiblePoints = enabledChannels.flatMap { ch in
                ch.points.filter { $0.time >= visibleStartTime }
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

    // MARK: - Data Ingestion

    /// BLEで受信した1行のデータを解析してチャンネルに追加する
    func processLine(_ line: String, timestamp: Date) {
        let parts = line.components(separatedBy: ",")
        let values = parts.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !values.isEmpty else { return }

        // 開始時刻を記録
        if startTime == nil {
            startTime = timestamp
        }
        let elapsed = timestamp.timeIntervalSince(startTime!)

        // チャンネル数を動的に拡張（最大5）
        let needed = min(values.count, 5)
        while channels.count < needed {
            channels.append(PlotChannel(id: channels.count))
        }

        for (i, value) in values.prefix(5).enumerated() {
            let point = PlotPoint(time: elapsed, value: value)
            channels[i].points.append(point)
            // 古いデータを削除してメモリ節約
            if channels[i].points.count > maxPoints {
                channels[i].points.removeFirst(channels[i].points.count - maxPoints)
            }
        }
    }

    func clearData() {
        for i in channels.indices {
            channels[i].points.removeAll()
        }
        startTime = nil
    }

    /// ピンチ操作で表示時間幅を変更する
    func applyPinch(scale: CGFloat) {
        let newSpan = pinchTimeSpan / Double(scale)
        // 0.05秒〜300秒の範囲でクランプ
        pinchTimeSpan = min(max(newSpan, 0.05), 300.0)
    }

    /// タイムスケールプリセットを適用する
    func applyTimeScale(_ scale: TimeScale) {
        timeScale = scale
        pinchTimeSpan = scale.rawValue
    }
}
