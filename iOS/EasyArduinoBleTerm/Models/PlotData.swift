import Foundation

struct PlotPoint: Identifiable {
    let id = UUID()
    let time: Double   // seconds since first data point
    let value: Double
}

struct PlotChannel: Identifiable {
    let id: Int        // column index (0-based)
    var label: String
    var isEnabled: Bool
    var points: [PlotPoint]
    var color: PlotChannelColor

    init(id: Int, label: String? = nil) {
        self.id = id
        self.label = label ?? "Ch\(id + 1)"
        self.isEnabled = true
        self.points = []
        self.color = PlotChannelColor.allCases[id % PlotChannelColor.allCases.count]
    }
}

enum PlotChannelColor: CaseIterable {
    case blue, red, green, orange, purple

    var swiftUIColor: String {
        switch self {
        case .blue:   return "blue"
        case .red:    return "red"
        case .green:  return "green"
        case .orange: return "orange"
        case .purple: return "purple"
        }
    }
}
