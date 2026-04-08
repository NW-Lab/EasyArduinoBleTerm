import Foundation
import CoreBluetooth
import Combine
#if canImport(UIKit)
import UIKit
#endif

// Nordic UART Service UUIDs (ESP32_BleSerial default)
let NORDIC_SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
let NORDIC_RX_UUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Write (phone -> device)
let NORDIC_TX_UUID      = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Notify (device -> phone)

struct DiscoveredPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    var rssi: Int

    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id
    }
}

struct ReceivedMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let text: String
}

class BLEManager: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isScanning: Bool = false
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var connectionState: ConnectionState = .disconnected
    @Published var receivedMessages: [ReceivedMessage] = []

    // MARK: - Internal
    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var receiveBuffer: String = ""

    // ターミナル表示の上限行数
    private let maxMessages = 2000

    // 受信メッセージのバッチ蓄積バッファ（UI更新を間引くため）
    private var pendingMessages: [ReceivedMessage] = []

    // UIへの反映タイマー: 最大20fps に制限
    private var uiFlushTimer: Timer?
    private let uiFlushInterval: TimeInterval = 1.0 / 20.0

    // 受信アクティビティ監視（一定時間受信が止まったらスリープ抑止を解除）
    private var receiveActivityTimer: Timer?
    private let receiveInactivityTimeout: TimeInterval = 10.0

    // Callbacks for ViewModels
    var onDataReceived: ((String, Date) -> Void)?

    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    // MARK: - Init / Deinit

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        startUIFlushTimer()
    }

    deinit {
        uiFlushTimer?.invalidate()
        receiveActivityTimer?.invalidate()
        setScreenSleepDisabled(false)
    }

    // MARK: - UI Flush Timer

    private func startUIFlushTimer() {
        uiFlushTimer = Timer.scheduledTimer(withTimeInterval: uiFlushInterval, repeats: true) { [weak self] _ in
            self?.flushPendingMessages()
        }
        RunLoop.main.add(uiFlushTimer!, forMode: .common)
    }

    /// pendingMessages を receivedMessages に一括反映する
    private func flushPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        receivedMessages.append(contentsOf: pendingMessages)
        pendingMessages.removeAll()
        // 上限を超えた古いメッセージを削除
        if receivedMessages.count > maxMessages {
            receivedMessages.removeFirst(receivedMessages.count - maxMessages)
        }
    }

    // MARK: - Public API

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        discoveredPeripherals.removeAll()
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: [NORDIC_SERVICE_UUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        centralManager.stopScan()
        isScanning = false
    }

    func connect(to discovered: DiscoveredPeripheral) {
        stopScanning()
        activePeripheral = discovered.peripheral
        connectionState = .connecting
        centralManager.connect(discovered.peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = activePeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    func send(_ text: String) {
        guard let peripheral = activePeripheral,
              let rxChar = rxCharacteristic,
              let data = text.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: rxChar, type: .withResponse)
    }

    private func setScreenSleepDisabled(_ disabled: Bool) {
        #if canImport(UIKit)
        if Thread.isMainThread {
            UIApplication.shared.isIdleTimerDisabled = disabled
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.isIdleTimerDisabled = disabled
            }
        }
        #endif
    }

    private func refreshReceiveActivity() {
        setScreenSleepDisabled(true)
        receiveActivityTimer?.invalidate()
        receiveActivityTimer = Timer.scheduledTimer(withTimeInterval: receiveInactivityTimeout, repeats: false) { [weak self] _ in
            self?.setScreenSleepDisabled(false)
        }
        RunLoop.main.add(receiveActivityTimer!, forMode: .common)
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            isScanning = false
            connectionState = .disconnected
            receiveActivityTimer?.invalidate()
            setScreenSleepDisabled(false)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unknown"
        let discovered = DiscoveredPeripheral(
            id: peripheral.identifier,
            peripheral: peripheral,
            name: name,
            rssi: RSSI.intValue
        )
        if let idx = discoveredPeripherals.firstIndex(where: { $0.id == discovered.id }) {
            discoveredPeripherals[idx] = discovered
        } else {
            discoveredPeripherals.append(discovered)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        activePeripheral = peripheral
        connectedPeripheral = peripheral
        connectionState = .connected
        peripheral.delegate = self
        peripheral.discoverServices([NORDIC_SERVICE_UUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .failed(error?.localizedDescription ?? "Connection failed")
        activePeripheral = nil
        connectedPeripheral = nil
        receiveActivityTimer?.invalidate()
        setScreenSleepDisabled(false)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        connectionState = .disconnected
        activePeripheral = nil
        connectedPeripheral = nil
        txCharacteristic = nil
        rxCharacteristic = nil
        receiveActivityTimer?.invalidate()
        setScreenSleepDisabled(false)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == NORDIC_SERVICE_UUID {
            peripheral.discoverCharacteristics([NORDIC_RX_UUID, NORDIC_TX_UUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == NORDIC_TX_UUID {
                txCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            } else if char.uuid == NORDIC_RX_UUID {
                rxCharacteristic = char
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic.uuid == NORDIC_TX_UUID,
              let data = characteristic.value,
              let str = String(data: data, encoding: .utf8) else { return }

          refreshReceiveActivity()

        let now = Date()
        receiveBuffer += str

        // 改行で分割し、末尾の未完了チャンクはバッファに残す
        var lines = receiveBuffer.components(separatedBy: "\n")
        receiveBuffer = lines.removeLast()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // ターミナル表示用にバッチ蓄積（タイマーで一括反映）
            pendingMessages.append(ReceivedMessage(timestamp: now, text: trimmed))

            // プロッターへはリアルタイムで通知
            onDataReceived?(trimmed, now)
        }
    }
}
