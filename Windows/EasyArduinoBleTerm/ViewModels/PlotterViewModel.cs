using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EasyArduinoBleTerm.Models;
using EasyArduinoBleTerm.Services;
using Microsoft.UI.Dispatching;

namespace EasyArduinoBleTerm.ViewModels;

public enum YAxisMode { Auto, Fixed }

public partial class PlotterViewModel : ObservableObject
{
    private const int MaxPointsPerChannel = 50_000;

    private readonly BleService _ble;
    private readonly DispatcherQueue _dispatcher;

    // ---- Display timer ----
    private readonly DispatcherQueueTimer _displayTimer;
    private bool _dataDirty = false;
    private readonly object _dataLock = new();

    // ---- Raw data (written from BLE thread) ----
    private readonly List<PlotChannel> _rawChannels = new();

    // ---- Snapshot (read from UI thread) ----
    private List<PlotChannel> _channelSnapshots = new();
    public IReadOnlyList<PlotChannel> ChannelSnapshots => _channelSnapshots;

    // ---- Observable Properties ----

    [ObservableProperty]
    private double _displayTimeSpan = 10.0;   // 表示幅（秒）

    [ObservableProperty]
    private double _gridInterval = 1.0;       // 目盛間隔（秒）

    [ObservableProperty]
    private YAxisMode _yAxisMode = YAxisMode.Auto;

    [ObservableProperty]
    private double _yFixedMin = -10.0;

    [ObservableProperty]
    private double _yFixedMax = 10.0;

    // 計算済みの表示範囲（UI描画で使用）
    public (double Min, double Max) YRange { get; private set; } = (-10, 10);

    // 表示開始時刻（秒）
    public double VisibleStartTime { get; private set; } = 0;

    // ---- Time Scale Presets ----
    public static readonly (string Label, double Span, double Grid)[] TimeScales =
    [
        ("0.1s", 0.5,  0.1),
        ("1s",   10.0, 1.0),
        ("10s",  100.0, 10.0),
    ];

    [ObservableProperty]
    private int _selectedTimeScaleIndex = 1;

    partial void OnSelectedTimeScaleIndexChanged(int value)
    {
        if (value < 0 || value >= TimeScales.Length) return;
        DisplayTimeSpan = TimeScales[value].Span;
        GridInterval    = TimeScales[value].Grid;
    }

    // ---- Constructor ----

    public PlotterViewModel(BleService ble, DispatcherQueue dispatcher)
    {
        _ble        = ble;
        _dispatcher = dispatcher;
        _ble.DataReceived += OnDataReceived;

        // 30fps で表示更新
        _displayTimer = dispatcher.CreateTimer();
        _displayTimer.Interval = TimeSpan.FromMilliseconds(33);
        _displayTimer.Tick += OnDisplayTimerTick;
        _displayTimer.Start();
    }

    // ---- Data Receive ----

    private void OnDataReceived(object? sender, string line)
    {
        var parts = line.Split(',');
        if (parts.Length == 0) return;

        double now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
        bool changed = false;

        lock (_dataLock)
        {
            for (int i = 0; i < Math.Min(parts.Length, 5); i++)
            {
                if (!double.TryParse(parts[i].Trim(),
                    System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture,
                    out double val)) continue;

                // チャンネルを必要に応じて追加
                while (_rawChannels.Count <= i)
                {
                    int idx = _rawChannels.Count;
                    _rawChannels.Add(new PlotChannel
                    {
                        Id        = idx,
                        Label     = $"Ch{idx + 1}",
                        LineColor = PlotChannel.DefaultColors[idx % PlotChannel.DefaultColors.Length],
                        IsEnabled = true,
                    });
                }

                var ch = _rawChannels[i];
                ch.Points.Add(new PlotPoint(now, val));

                // 古いポイントを削除
                if (ch.Points.Count > MaxPointsPerChannel)
                    ch.Points.RemoveRange(0, ch.Points.Count - MaxPointsPerChannel);

                changed = true;
            }
        }

        if (changed) _dataDirty = true;
    }

    // ---- Display Timer ----

    private void OnDisplayTimerTick(DispatcherQueueTimer timer, object args)
    {
        if (!_dataDirty) return;
        _dataDirty = false;

        List<PlotChannel> snapshot;
        lock (_dataLock)
        {
            snapshot = _rawChannels.Select(ch => new PlotChannel
            {
                Id        = ch.Id,
                Label     = ch.Label,
                LineColor = ch.LineColor,
                IsEnabled = ch.IsEnabled,
            }).ToList();

            for (int i = 0; i < _rawChannels.Count; i++)
            {
                var src = _rawChannels[i];
                snapshot[i].Points.AddRange(src.Points);
            }
        }

        _channelSnapshots = snapshot;

        // 表示範囲を計算
        double now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() / 1000.0;
        VisibleStartTime = now - DisplayTimeSpan;

        // Y軸範囲
        if (YAxisMode == YAxisMode.Auto)
        {
            double min = double.MaxValue, max = double.MinValue;
            foreach (var ch in snapshot.Where(c => c.IsEnabled))
            {
                foreach (var pt in ch.Points.Where(p => p.Time >= VisibleStartTime))
                {
                    if (pt.Value < min) min = pt.Value;
                    if (pt.Value > max) max = pt.Value;
                }
            }
            if (min == double.MaxValue) { min = -1; max = 1; }
            double margin = Math.Max((max - min) * 0.1, 0.1);
            YRange = (min - margin, max + margin);
        }
        else
        {
            YRange = (YFixedMin, YFixedMax);
        }

        OnPropertyChanged(nameof(ChannelSnapshots));
        OnPropertyChanged(nameof(YRange));
        OnPropertyChanged(nameof(VisibleStartTime));
        PlotRefreshRequested?.Invoke(this, EventArgs.Empty);
    }

    // ---- Events ----

    /// <summary>プロッターの再描画が必要なときに発火</summary>
    public event EventHandler? PlotRefreshRequested;

    // ---- Commands ----

    [RelayCommand]
    private void ClearData()
    {
        lock (_dataLock) { _rawChannels.Clear(); }
        _channelSnapshots = new();
        OnPropertyChanged(nameof(ChannelSnapshots));
        PlotRefreshRequested?.Invoke(this, EventArgs.Empty);
    }

    public void ToggleChannel(int id)
    {
        lock (_dataLock)
        {
            var ch = _rawChannels.FirstOrDefault(c => c.Id == id);
            if (ch != null) ch.IsEnabled = !ch.IsEnabled;
        }
        _dataDirty = true;
    }

    public void ToggleYAxisMode()
    {
        if (YAxisMode == YAxisMode.Auto)
        {
            YFixedMin = YRange.Min;
            YFixedMax = YRange.Max;
            YAxisMode = YAxisMode.Fixed;
        }
        else
        {
            YAxisMode = YAxisMode.Auto;
        }
    }

    public void PauseDisplay() => _displayTimer.Stop();
    public void ResumeDisplay()
    {
        _dataDirty = true;
        _displayTimer.Start();
    }

    public void Dispose()
    {
        _displayTimer.Stop();
        _ble.DataReceived -= OnDataReceived;
    }
}
