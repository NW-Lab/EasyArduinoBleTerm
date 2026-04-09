// Nordic UART Service (ESP32_BleSerial)
const NUS_SERVICE_UUID  = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const NUS_TX_CHAR_UUID  = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // ESP32 → Browser (Notify)
const NUS_RX_CHAR_UUID  = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // Browser → ESP32 (Write)

export type BleDataCallback = (line: string, timestamp: Date) => void;
export type BleStatusCallback = (connected: boolean, deviceName: string) => void;

class BleService {
  private device: BluetoothDevice | null = null;
  private rxCharacteristic: BluetoothRemoteGATTCharacteristic | null = null;
  private dataCallback: BleDataCallback | null = null;
  private statusCallback: BleStatusCallback | null = null;
  private receiveBuffer = '';

  /** Web Bluetooth API が利用可能かチェック */
  isSupported(): boolean {
    return typeof navigator !== 'undefined' && 'bluetooth' in navigator;
  }

  /** コールバック登録 */
  onData(cb: BleDataCallback) { this.dataCallback = cb; }
  onStatus(cb: BleStatusCallback) { this.statusCallback = cb; }

  /**
   * デバイス選択ダイアログを表示して接続する。
   * Web Bluetooth API はユーザージェスチャー（クリック等）から呼ぶ必要がある。
   */
  async connect(): Promise<string> {
    if (!this.isSupported()) {
      throw new Error('Web Bluetooth API はこのブラウザでサポートされていません。Chrome または Edge を使用してください。');
    }

    // デバイス選択ダイアログ（ブラウザ標準UI）
    this.device = await navigator.bluetooth.requestDevice({
      filters: [{ services: [NUS_SERVICE_UUID] }],
      optionalServices: [NUS_SERVICE_UUID],
    });

    this.device.addEventListener('gattserverdisconnected', () => {
      this.rxCharacteristic = null;
      this.statusCallback?.(false, '');
    });

    const server = await this.device.gatt!.connect();
    const service = await server.getPrimaryService(NUS_SERVICE_UUID);

    // TX: 受信通知（ESP32 → Browser）
    const txChar = await service.getCharacteristic(NUS_TX_CHAR_UUID);
    await txChar.startNotifications();
    txChar.addEventListener('characteristicvaluechanged', (event: Event) => {
      const value = (event.target as BluetoothRemoteGATTCharacteristic).value!;
      const text = new TextDecoder().decode(value);
      const now = new Date();
      this.receiveBuffer += text;
      const lines = this.receiveBuffer.split('\n');
      this.receiveBuffer = lines.pop() ?? '';
      for (const line of lines) {
        if (line.trim()) this.dataCallback?.(line.trim(), now);
      }
    });

    // RX: 送信用（Browser → ESP32）
    this.rxCharacteristic = await service.getCharacteristic(NUS_RX_CHAR_UUID);

    const name = this.device.name ?? '(unknown)';
    this.statusCallback?.(true, name);
    return name;
  }

  /** 切断 */
  disconnect() {
    this.device?.gatt?.disconnect();
    this.device = null;
    this.rxCharacteristic = null;
    this.receiveBuffer = '';
  }

  /** データ送信 */
  async send(text: string): Promise<void> {
    if (!this.rxCharacteristic) throw new Error('未接続です');
    const encoded = new TextEncoder().encode(text + '\n');
    // BLE MTU は通常 20 バイト。長い場合は分割送信
    const CHUNK = 20;
    for (let i = 0; i < encoded.length; i += CHUNK) {
      await this.rxCharacteristic.writeValue(encoded.slice(i, i + CHUNK));
    }
  }

  get connected(): boolean {
    return this.device?.gatt?.connected ?? false;
  }

  get deviceName(): string {
    return this.device?.name ?? '';
  }
}

// シングルトン
export const bleService = new BleService();
