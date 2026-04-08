package com.nwlab.easyarduinobleterm.ble

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

// Nordic UART Service UUIDs (ESP32_BleSerial)
val SERVICE_UUID: UUID  = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
val TX_CHAR_UUID: UUID  = UUID.fromString("6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // ESP32 → App (Notify)
val RX_CHAR_UUID: UUID  = UUID.fromString("6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // App → ESP32 (Write)
val CCCD_UUID: UUID     = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

data class BleDevice(
    val name: String,
    val address: String,
    val rssi: Int,
    val device: BluetoothDevice
)

sealed class BleState {
    object Disconnected : BleState()
    object Scanning     : BleState()
    object Connecting   : BleState()
    data class Connected(val deviceName: String) : BleState()
    data class Error(val message: String) : BleState()
}

@SuppressLint("MissingPermission")
class BleService(private val context: Context) {

    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? get() = bluetoothManager.adapter
    private var bleScanner: BluetoothLeScanner? = null
    private var gatt: BluetoothGatt? = null
    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // --- Public state flows ---
    private val _state = MutableStateFlow<BleState>(BleState.Disconnected)
    val state: StateFlow<BleState> = _state.asStateFlow()

    private val _scannedDevices = MutableStateFlow<List<BleDevice>>(emptyList())
    val scannedDevices: StateFlow<List<BleDevice>> = _scannedDevices.asStateFlow()

    // Callback for received data lines
    var onDataReceived: ((String) -> Unit)? = null

    // --- Scan ---

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.device.name ?: return
            val device = BleDevice(
                name    = name,
                address = result.device.address,
                rssi    = result.rssi,
                device  = result.device
            )
            val current = _scannedDevices.value.toMutableList()
            val idx = current.indexOfFirst { it.address == device.address }
            if (idx >= 0) current[idx] = device else current.add(device)
            current.sortByDescending { it.rssi }
            _scannedDevices.value = current
        }
    }

    fun startScan() {
        _scannedDevices.value = emptyList()
        _state.value = BleState.Scanning
        bleScanner = bluetoothAdapter?.bluetoothLeScanner
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        bleScanner?.startScan(null, settings, scanCallback)
        // 15秒後に自動停止
        mainHandler.postDelayed({ stopScan() }, 15_000)
    }

    fun stopScan() {
        bleScanner?.stopScan(scanCallback)
        bleScanner = null
        if (_state.value is BleState.Scanning) {
            _state.value = BleState.Disconnected
        }
    }

    // --- Connect ---

    fun connect(device: BleDevice) {
        stopScan()
        _state.value = BleState.Connecting
        gatt = device.device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    fun disconnect() {
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        txCharacteristic = null
        rxCharacteristic = null
        _state.value = BleState.Disconnected
    }

    // --- Send ---

    fun send(text: String) {
        val char = rxCharacteristic ?: return
        val bytes = (text + "\n").toByteArray(Charsets.UTF_8)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            gatt?.writeCharacteristic(char, bytes, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
        } else {
            @Suppress("DEPRECATION")
            char.value = bytes
            @Suppress("DEPRECATION")
            gatt?.writeCharacteristic(char)
        }
    }

    // --- GATT Callback ---

    private var receiveBuffer = StringBuilder()

    private val gattCallback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    gatt.discoverServices()
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    mainHandler.post {
                        _state.value = if (status == BluetoothGatt.GATT_SUCCESS)
                            BleState.Disconnected
                        else
                            BleState.Error("切断されました (status=$status)")
                    }
                    this@BleService.gatt = null
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                mainHandler.post { _state.value = BleState.Error("サービス検出失敗") }
                return
            }
            val service = gatt.getService(SERVICE_UUID)
            if (service == null) {
                mainHandler.post { _state.value = BleState.Error("Nordic UART Service が見つかりません") }
                return
            }
            txCharacteristic = service.getCharacteristic(TX_CHAR_UUID)
            rxCharacteristic = service.getCharacteristic(RX_CHAR_UUID)

            // TX の Notify を有効化
            txCharacteristic?.let { char ->
                gatt.setCharacteristicNotification(char, true)
                val descriptor = char.getDescriptor(CCCD_UUID)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                } else {
                    @Suppress("DEPRECATION")
                    descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    @Suppress("DEPRECATION")
                    gatt.writeDescriptor(descriptor)
                }
            }

            val deviceName = gatt.device.name ?: gatt.device.address
            mainHandler.post { _state.value = BleState.Connected(deviceName) }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            handleReceivedBytes(value)
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            handleReceivedBytes(characteristic.value ?: return)
        }
    }

    private fun handleReceivedBytes(bytes: ByteArray) {
        val text = String(bytes, Charsets.UTF_8)
        receiveBuffer.append(text)
        while (true) {
            val idx = receiveBuffer.indexOf('\n')
            if (idx < 0) break
            val line = receiveBuffer.substring(0, idx).trimEnd('\r')
            receiveBuffer.delete(0, idx + 1)
            if (line.isNotEmpty()) {
                mainHandler.post { onDataReceived?.invoke(line) }
            }
        }
    }
}
