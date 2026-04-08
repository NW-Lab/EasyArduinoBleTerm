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

    // ---- Constructor ----

    public TerminalViewModel(BleService ble, DispatcherQueue dispatcher)
    {
        _ble        = ble;
        _dispatcher = dispatcher;
        _ble.DataReceived += OnDataReceived;
    }

    // ---- Data Receive ----

    private void OnDataReceived(object? sender, string line)
    {
        var msg = new TerminalMessage { Timestamp = DateTime.Now, Text = line };

        _dispatcher.TryEnqueue(() =>
        {
            _messages.Add(msg);
            Lines.Add(msg.DisplayText(ShowTimestamp));

            // バッファー上限を超えたら古いものを削除
            if (_messages.Count > MaxMessages)
            {
                int excess = _messages.Count - MaxMessages;
                _messages.RemoveRange(0, excess);
                for (int i = 0; i < excess; i++)
                    if (Lines.Count > 0) Lines.RemoveAt(0);
            }
        });
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
        _messages.Clear();
        Lines.Clear();
    }

    public void Dispose()
    {
        _ble.DataReceived -= OnDataReceived;
    }
}
