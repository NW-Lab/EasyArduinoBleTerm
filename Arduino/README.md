# Arduino BLE / Serial bridge

`M5StickS3_BLE_Serial_Bridge` forwards bytes between the M5StickS3 USB serial port and the app over BLE:

- App → BLE Nordic UART RX → USB serial (`Serial`)
- USB serial (`Serial`) → BLE Nordic UART TX notifications → App

The bridge uses the same Nordic UART Service UUIDs as the app:

| Characteristic | UUID | Direction |
| --- | --- | --- |
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | |
| RX (Write) | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | App → device |
| TX (Notify) | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | Device → app |

## Setup

1. Install the M5Stack board package in Arduino IDE and select **M5StickS3**. See the [official setup and upload guide](https://docs.m5stack.com/en/arduino/m5sticks3/program).
2. Open `M5StickS3_BLE_Serial_Bridge/M5StickS3_BLE_Serial_Bridge.ino` and upload it.
3. If the board menu provides **USB CDC On Boot**, enable it so `Serial` uses the USB connection.
4. Connect to **EasyArduinoBleTerm** from the app. Open the M5StickS3 USB serial port on the PC at **115200 baud**.

The sketch uses the BLE library included with the ESP32 Arduino core; it does not require the M5Unified or M5GFX libraries. Data is forwarded as raw bytes. USB serial data is split into 20-byte BLE notifications, and data received from the app is written directly to USB serial.
