using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using EasyArduinoBleTerm.Services;
using Microsoft.UI.Dispatching;

namespace EasyArduinoBleTerm.ViewModels;

public partial class MainViewModel : ObservableObject
{
    public BleService Ble { get; }
    public TerminalViewModel Terminal { get; }
    public PlotterViewModel  Plotter  { get; }

    private readonly DispatcherQueue _dispatcher;

    // ---- BLE State ----

    [ObservableProperty]
    private string _connectionStatusText = "未接続";

    [ObservableProperty]
    private bool _isConnected = false;

    [ObservableProperty]
    private bool _isScanning = false;

    // ---- Device List ----

    public ObservableCollection<BleDeviceInfo> DiscoveredDevices { get; } = new();

    [ObservableProperty]
    private BleDeviceInfo? _selectedDevice;

    // ---- Constructor ----

    public MainViewModel(DispatcherQueue dispatcher)
    {
        _dispatcher = dispatcher;
        Ble         = new BleService();
        Terminal    = new TerminalViewModel(Ble, dispatcher);
        Plotter     = new PlotterViewModel(Ble, dispatcher);

        Ble.StateChanged      += OnBleStateChanged;
        Ble.DeviceDiscovered  += OnDeviceDiscovered;
    }

    // ---- Scan ----

    [RelayCommand]
    private void StartScan()
    {
        DiscoveredDevices.Clear();
        SelectedDevice = null;
        IsScanning = true;
        Ble.StartScan();
    }

    [RelayCommand]
    private void StopScan()
    {
        Ble.StopScan();
        IsScanning = false;
    }

    private void OnDeviceDiscovered(object? sender, BleDeviceInfo info)
    {
        _dispatcher.TryEnqueue(() =>
        {
            // 同じアドレスがあれば更新、なければ追加
            var existing = DiscoveredDevices.FirstOrDefault(d => d.Address == info.Address);
            if (existing != null)
            {
                int idx = DiscoveredDevices.IndexOf(existing);
                DiscoveredDevices[idx] = info;
            }
            else
            {
                DiscoveredDevices.Add(info);
            }
        });
    }

    // ---- Connect / Disconnect ----

    [RelayCommand]
    private async Task ConnectAsync()
    {
        if (SelectedDevice == null) return;
        StopScan();
        await Ble.ConnectAsync(SelectedDevice.Address);
    }

    [RelayCommand]
    private void Disconnect()
    {
        Ble.Disconnect();
    }

    // ---- State ----

    private void OnBleStateChanged(object? sender, BleState state)
    {
        _dispatcher.TryEnqueue(() =>
        {
            switch (state)
            {
                case BleState.ConnectedState:
                    ConnectionStatusText = $"接続中: {Ble.ConnectedDeviceName}";
                    IsConnected = true;
                    break;
                case BleState.ConnectingState:
                    ConnectionStatusText = "接続中...";
                    IsConnected = false;
                    break;
                case BleState.DisconnectedState:
                    ConnectionStatusText = "未接続";
                    IsConnected = false;
                    break;
                case BleState.FailedState f:
                    ConnectionStatusText = $"エラー: {f.Message}";
                    IsConnected = false;
                    break;
            }
        });
    }

    public void Dispose()
    {
        Ble.StateChanged     -= OnBleStateChanged;
        Ble.DeviceDiscovered -= OnDeviceDiscovered;
        Terminal.Dispose();
        Plotter.Dispose();
        Ble.Dispose();
    }
}
