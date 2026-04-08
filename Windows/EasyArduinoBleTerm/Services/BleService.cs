using System.Runtime.InteropServices.WindowsRuntime;
using System.Text;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;

namespace EasyArduinoBleTerm.Services;

/// <summary>
/// ESP32_BleSerial (Nordic UART Service) との BLE 通信を管理するサービス。
/// Service UUID  : 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
/// TX Char (Read): 6E400003-B5A3-F393-E0A9-E50E24DCCA9E  (ESP32→PC)
/// RX Char (Write):6E400002-B5A3-F393-E0A9-E50E24DCCA9E  (PC→ESP32)
/// </summary>
public class BleService : IDisposable
{
    // Nordic UART Service UUIDs
    public static readonly Guid NusServiceUuid  = Guid.Parse("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
    public static readonly Guid NusTxCharUuid   = Guid.Parse("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");
    public static readonly Guid NusRxCharUuid   = Guid.Parse("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");

    // ---- Events ----
    public event EventHandler<BleDeviceInfo>? DeviceDiscovered;
    public event EventHandler<string>?        DataReceived;
    public event EventHandler<BleState>?      StateChanged;

    // ---- State ----
    public BleState State { get; private set; } = BleState.Disconnected;
    public string?  ConnectedDeviceName { get; private set; }

    private BluetoothLEAdvertisementWatcher? _watcher;
    private BluetoothLEDevice?               _device;
    private GattCharacteristic?              _txChar;   // Notify (ESP32→PC)
    private GattCharacteristic?              _rxChar;   // Write  (PC→ESP32)

    private readonly Dictionary<ulong, BleDeviceInfo> _discovered = new();
    private readonly object _lock = new();
    private string _lineBuffer = string.Empty;

    // ---- Scan ----

    public void StartScan()
    {
        StopScan();
        lock (_lock) { _discovered.Clear(); }

        _watcher = new BluetoothLEAdvertisementWatcher
        {
            ScanningMode = BluetoothLEScanningMode.Active
        };
        _watcher.Received += OnAdvertisementReceived;
        _watcher.Start();
    }

    public void StopScan()
    {
        if (_watcher != null)
        {
            _watcher.Stop();
            _watcher.Received -= OnAdvertisementReceived;
            _watcher = null;
        }
    }

    private void OnAdvertisementReceived(
        BluetoothLEAdvertisementWatcher sender,
        BluetoothLEAdvertisementReceivedEventArgs args)
    {
        var name = args.Advertisement.LocalName;
        if (string.IsNullOrWhiteSpace(name)) return;

        var info = new BleDeviceInfo(args.BluetoothAddress, name, args.RawSignalStrengthInDBm);
        lock (_lock) { _discovered[args.BluetoothAddress] = info; }
        DeviceDiscovered?.Invoke(this, info);
    }

    // ---- Connect ----

    public async Task ConnectAsync(ulong bluetoothAddress)
    {
        SetState(BleState.Connecting);
        try
        {
            _device = await BluetoothLEDevice.FromBluetoothAddressAsync(bluetoothAddress)
                      ?? throw new Exception("デバイスが見つかりません");

            var svcResult = await _device.GetGattServicesForUuidAsync(NusServiceUuid,
                                BluetoothCacheMode.Uncached);
            if (svcResult.Status != GattCommunicationStatus.Success || svcResult.Services.Count == 0)
                throw new Exception("Nordic UART Service が見つかりません");

            var service = svcResult.Services[0];

            // TX Characteristic (Notify: ESP32→PC)
            var txResult = await service.GetCharacteristicsForUuidAsync(NusTxCharUuid,
                               BluetoothCacheMode.Uncached);
            if (txResult.Status != GattCommunicationStatus.Success || txResult.Characteristics.Count == 0)
                throw new Exception("TX Characteristic が見つかりません");
            _txChar = txResult.Characteristics[0];

            // RX Characteristic (Write: PC→ESP32)
            var rxResult = await service.GetCharacteristicsForUuidAsync(NusRxCharUuid,
                               BluetoothCacheMode.Uncached);
            if (rxResult.Status != GattCommunicationStatus.Success || rxResult.Characteristics.Count == 0)
                throw new Exception("RX Characteristic が見つかりません");
            _rxChar = rxResult.Characteristics[0];

            // Notify を有効化
            var notifyStatus = await _txChar.WriteClientCharacteristicConfigurationDescriptorAsync(
                GattClientCharacteristicConfigurationDescriptorValue.Notify);
            if (notifyStatus != GattCommunicationStatus.Success)
                throw new Exception("Notify の有効化に失敗しました");

            _txChar.ValueChanged += OnCharacteristicValueChanged;
            _device.ConnectionStatusChanged += OnConnectionStatusChanged;

            ConnectedDeviceName = _device.Name;
            SetState(BleState.Connected);
        }
        catch (Exception ex)
        {
            Disconnect();
            SetState(BleState.Failed(ex.Message));
        }
    }

    public void Disconnect()
    {
        if (_txChar != null)
        {
            _txChar.ValueChanged -= OnCharacteristicValueChanged;
            _txChar = null;
        }
        if (_device != null)
        {
            _device.ConnectionStatusChanged -= OnConnectionStatusChanged;
            _device.Dispose();
            _device = null;
        }
        _rxChar = null;
        ConnectedDeviceName = null;
        _lineBuffer = string.Empty;
        SetState(BleState.Disconnected);
    }

    // ---- Send ----

    public async Task SendAsync(string text)
    {
        if (_rxChar == null) return;
        var bytes = Encoding.UTF8.GetBytes(text);
        var writer = new DataWriter();
        writer.WriteBytes(bytes);
        await _rxChar.WriteValueAsync(writer.DetachBuffer(),
            GattWriteOption.WriteWithoutResponse);
    }

    // ---- Receive ----

    private void OnCharacteristicValueChanged(
        GattCharacteristic sender,
        GattValueChangedEventArgs args)
    {
        var bytes = args.CharacteristicValue.ToArray();
        var text  = Encoding.UTF8.GetString(bytes);

        // 行単位に分割してイベント発行
        _lineBuffer += text;
        while (true)
        {
            var idx = _lineBuffer.IndexOf('\n');
            if (idx < 0) break;
            var line = _lineBuffer[..idx].TrimEnd('\r');
            _lineBuffer = _lineBuffer[(idx + 1)..];
            if (line.Length > 0)
                DataReceived?.Invoke(this, line);
        }
    }

    private void OnConnectionStatusChanged(BluetoothLEDevice sender,
                                            object args)
    {
        if (sender.ConnectionStatus == BluetoothConnectionStatus.Disconnected)
            Disconnect();
    }

    // ---- Helpers ----

    private void SetState(BleState state)
    {
        State = state;
        StateChanged?.Invoke(this, state);
    }

    public void Dispose()
    {
        StopScan();
        Disconnect();
    }
}

// ---- Supporting types ----

public record BleDeviceInfo(ulong Address, string Name, short Rssi)
{
    public string RssiText => $"{Rssi} dBm";
    public string RssiIcon => Rssi >= -60 ? "📶" : Rssi >= -75 ? "🔵" : Rssi >= -90 ? "🟡" : "🔴";
}

public abstract record BleState
{
    public static readonly BleState Disconnected = new DisconnectedState();
    public static readonly BleState Connecting   = new ConnectingState();
    public static readonly BleState Connected    = new ConnectedState();
    public static BleState Failed(string msg)    => new FailedState(msg);

    public record DisconnectedState : BleState;
    public record ConnectingState   : BleState;
    public record ConnectedState    : BleState;
    public record FailedState(string Message) : BleState;
}
