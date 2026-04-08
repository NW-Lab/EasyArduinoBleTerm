using Microsoft.UI;
using Windows.UI;

namespace EasyArduinoBleTerm.Models;

/// <summary>
/// プロッターの1チャンネル分のデータと表示設定
/// </summary>
public class PlotChannel
{
    public int Id { get; init; }
    public string Label { get; init; } = string.Empty;
    public Color LineColor { get; init; }
    public bool IsEnabled { get; set; } = true;

    /// <summary>
    /// (time秒, value) のリスト。time は受信時刻のUnixSeconds。
    /// </summary>
    public List<PlotPoint> Points { get; } = new();

    public static readonly Color[] DefaultColors =
    [
        Color.FromArgb(255, 59, 130, 246),   // Blue
        Color.FromArgb(255, 239, 68,  68),   // Red
        Color.FromArgb(255, 34,  197, 94),   // Green
        Color.FromArgb(255, 249, 115, 22),   // Orange
        Color.FromArgb(255, 168, 85,  247),  // Purple
    ];
}

public record struct PlotPoint(double Time, double Value);
