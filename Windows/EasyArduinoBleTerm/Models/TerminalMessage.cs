namespace EasyArduinoBleTerm.Models;

/// <summary>
/// ターミナルに表示する1行のメッセージ
/// </summary>
public class TerminalMessage
{
    public DateTime Timestamp { get; init; }
    public string Text { get; init; } = string.Empty;

    public string FormattedTimestamp => Timestamp.ToString("HH:mm:ss.fff");

    public string DisplayText(bool showTimestamp) =>
        showTimestamp ? $"[{FormattedTimestamp}] {Text}" : Text;
}
