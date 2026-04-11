using System.Collections.Generic;
using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EasyArduinoBleTerm.Models;
using EasyArduinoBleTerm.Services;
using Microsoft.UI.Dispatching;

namespace EasyArduinoBleTerm.ViewModels;

public partial class TerminalViewModel : ObservableObject
{
    private const int MaxMessages = 2000;

    private readonly BleService _ble;
    private readonly DispatcherQueue _dispatcher;

    // ---- Observable Properties ----

    [ObservableProperty]
    private bool _showTimestamp = true;

    [ObservableProperty]
    private bool _autoScroll = true;

    [ObservableProperty]
    private string _sendText = string.Empty;

    // UI から直接バインドするコレクション（表示用テキスト行）
    public ObservableCollection<string> Lines { get; } = new();

    // 生データ（タイムスタンプ付き）
    private readonly List<TerminalMessage> _messages = new();

    // 受信バッファ（BLEスレッドからアクセス → lock で保護）
    private readonly List<TerminalMessage> _pending = new();
    private readonly object _pendingLock = new();

    // 30fps 表示タイマー
    private readonly DispatcherQueueTimer _displayTimer;

    // ---- Constructor ----

    public TerminalViewModel(BleService ble, DispatcherQueue dispatcher)
    {
        _ble        = ble;
        _dispatcher = dispatcher;
        _ble.DataReceived += OnDataReceived;

        _displayTimer = dispatcher.CreateTimer();
        _displayTimer.Interval = TimeSpan.FromMilliseconds(33); // ~30fps
        _displayTimer.Tick += OnDisplayTimerTick;
        _displayTimer.Start();
    }

    // ---- Data Receive（BLEスレッドから呼ばれる）----

    private void OnDataReceived(object? sender, string line)
    {
        var msg = new TerminalMessage { Timestamp = DateTime.Now, Text = line };
        lock (_pendingLock)
        {
            _pending.Add(msg);
        }
    }

    // ---- Display Timer（UIスレッド、33ms毎）----

    private void OnDisplayTimerTick(DispatcherQueueTimer timer, object args)
    {
        List<TerminalMessage> batch;
        lock (_pendingLock)
        {
            if (_pending.Count == 0) return;
            batch = new List<TerminalMessage>(_pending);
            _pending.Clear();
        }

        foreach (var msg in batch)
        {
            _messages.Add(msg);
            Lines.Add(msg.DisplayText(ShowTimestamp));
        }

        // バッファ上限を超えたら古いものを削除
        if (_messages.Count > MaxMessages)
        {
            int excess = _messages.Count - MaxMessages;
            _messages.RemoveRange(0, excess);
            for (int i = 0; i < excess; i++)
                if (Lines.Count > 0) Lines.RemoveAt(0);
        }
    }

    // ---- Timestamp Toggle ----

    partial void OnShowTimestampChanged(bool value)
    {
        // 表示テキストを全行再生成
        _dispatcher.TryEnqueue(() =>
        {
            Lines.Clear();
            foreach (var msg in _messages)
                Lines.Add(msg.DisplayText(value));
        });
    }

    // ---- Send ----

    [RelayCommand]
    private async Task SendAsync()
    {
        if (string.IsNullOrEmpty(SendText)) return;
        await _ble.SendAsync(SendText + "\n");
        SendText = string.Empty;
    }

    // ---- Clear ----

    [RelayCommand]
    private void Clear()
    {
        lock (_pendingLock) { _pending.Clear(); }
        _messages.Clear();
        Lines.Clear();
    }

    public void Dispose()
    {
        _displayTimer.Stop();
        _ble.DataReceived -= OnDataReceived;
    }
}
