package com.nwlab.easyarduinobleterm.ble

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID

private const val TAG = "BleService"

// Nordic UART Service UUIDs (ESP32_BleSerial)
val SERVICE_UUID: UUID = UUID.fromString("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
val TX_CHAR_UUID: UUID = UUID.fromString("6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // ESP32→App (Notify)
val RX_CHAR_UUID: UUID = UUID.fromString("6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // App→ESP32 (Write)
val CCCD_UUID: UUID    = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

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

    // Callback for received data lines (called on main thread)
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

        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "Scan failed: errorCode=$errorCode")
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
        Log.d(TAG, "Scan started")
        mainHandler.postDelayed({ stopScan() }, 15_000)
    }

    fun stopScan() {
        bleScanner?.stopScan(scanCallback)
        bleScanner = null
        if (_state.value is BleState.Scanning) {
            _state.value = BleState.Disconnected
        }
        Log.d(TAG, "Scan stopped")
    }

    // --- Connect ---

    fun connect(device: BleDevice) {
        stopScan()
        _state.value = BleState.Connecting
        Log.d(TAG, "Connecting to ${device.name} (${device.address})")
        gatt = device.device.connectGatt(
            context, false, gattCallback, BluetoothDevice.TRANSPORT_LE
        )
    }

    fun disconnect() {
        Log.d(TAG, "Disconnect requested")
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        txCharacteristic = null
        rxCharacteristic = null
        _state.value = BleState.Disconnected
    }

    // --- Send ---

    fun send(text: String) {
        val char = rxCharacteristic ?: run {
            Log.w(TAG, "send: rxCharacteristic is null")
            return
        }
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

    private val receiveBuffer = StringBuilder()

    private val gattCallback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            Log.d(TAG, "onConnectionStateChange: status=$status newState=$newState")
            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Connected! Requesting MTU 512...")
                    // MTU拡張を要求してから discoverServices する
                    // （ESP32 BleSerial は大きいパケットを送る場合がある）
                    gatt.requestMtu(512)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "Disconnected. status=$status")
                    mainHandler.post {
                        _state.value = if (status == BluetoothGatt.GATT_SUCCESS)
                            BleState.Disconnected
                        else
                            BleState.Error("切断されました (status=$status)")
                    }
                    this@BleService.gatt = null
                    txCharacteristic = null
                    rxCharacteristic = null
                }
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            Log.d(TAG, "onMtuChanged: mtu=$mtu status=$status")
            // MTU 交渉完了後にサービス検出
            gatt.discoverServices()
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            Log.d(TAG, "onServicesDiscovered: status=$status")
            if (status != BluetoothGatt.GATT_SUCCESS) {
                mainHandler.post { _state.value = BleState.Error("サービス検出失敗 status=$status") }
                return
            }

            // 全サービスをログ出力
            gatt.services.forEach { svc ->
                Log.d(TAG, "  Service: ${svc.uuid}")
                svc.characteristics.forEach { ch ->
                    Log.d(TAG, "    Char: ${ch.uuid} props=${ch.properties}")
                }
            }

            val service = gatt.getService(SERVICE_UUID)
            if (service == null) {
                Log.e(TAG, "Nordic UART Service not found!")
                mainHandler.post { _state.value = BleState.Error("Nordic UART Service が見つかりません") }
                return
            }

            val txChar = service.getCharacteristic(TX_CHAR_UUID)
            val rxChar = service.getCharacteristic(RX_CHAR_UUID)
            Log.d(TAG, "TX char: $txChar")
            Log.d(TAG, "RX char: $rxChar")

            if (txChar == null) {
                Log.e(TAG, "TX characteristic not found!")
                mainHandler.post { _state.value = BleState.Error("TX Characteristic が見つかりません") }
                return
            }

            txCharacteristic = txChar
            rxCharacteristic = rxChar

            // setCharacteristicNotification と writeDescriptor は
            // メインスレッドから呼ぶ（一部デバイスで必須）
            mainHandler.post {
                enableNotify(gatt, txChar)
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            Log.d(TAG, "onDescriptorWrite: uuid=${descriptor.uuid} status=$status")
            if (descriptor.uuid == CCCD_UUID) {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    Log.d(TAG, "Notify enabled successfully!")
                } else {
                    Log.w(TAG, "CCCD write status=$status (non-zero, but continuing)")
                }
                // 成否に関わらず接続完了とする
                mainHandler.post {
                    _state.value = BleState.Connected(gatt.device.name ?: gatt.device.address)
                }
            }
        }

        // Android 13 (API 33) 以降
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            Log.d(TAG, "onCharacteristicChanged (API33+): ${value.size} bytes")
            handleReceivedBytes(value)
        }

        // Android 12 以前
        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            val value = characteristic.value ?: return
            Log.d(TAG, "onCharacteristicChanged (legacy): ${value.size} bytes")
            handleReceivedBytes(value)
        }
    }

    // メインスレッドから呼ぶこと
    private fun enableNotify(gatt: BluetoothGatt, txChar: BluetoothGattCharacteristic) {
        val notifySet = gatt.setCharacteristicNotification(txChar, true)
        Log.d(TAG, "setCharacteristicNotification: $notifySet")

        val descriptor = txChar.getDescriptor(CCCD_UUID)
        if (descriptor == null) {
            Log.w(TAG, "CCCD descriptor not found! Marking as connected anyway.")
            _state.value = BleState.Connected(gatt.device.name ?: gatt.device.address)
            return
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            val result = gatt.writeDescriptor(descriptor, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
            Log.d(TAG, "writeDescriptor (API33+): result=$result")
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            @Suppress("DEPRECATION")
            val result = gatt.writeDescriptor(descriptor)
            Log.d(TAG, "writeDescriptor (legacy): result=$result")
        }
        // 完了は onDescriptorWrite で通知
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
                Log.v(TAG, "Received line: $line")
                mainHandler.post { onDataReceived?.invoke(line) }
            }
        }
    }
}
