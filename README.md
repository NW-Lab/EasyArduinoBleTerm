# EasyArduinoBleTerm

Arduino IDEのシリアルモニター・シリアルプロッターに相当する機能を、BLE（Bluetooth Low Energy）経由でiPhoneから利用するためのiOSアプリです。

## 概要

[ESP32_BleSerial](https://github.com/avinabmalla/ESP32_BleSerial) ライブラリを使用したArduino/ESP32デバイスと接続し、データの送受信・可視化を行います。

## 機能

### BLE接続
- 周辺のBLEデバイスをスキャンし、アドバタイズ名で接続先を選択できます。
- Nordic UART Service（NUS）プロファイルに対応しています。
- 接続・切断はナビゲーションバーのボタンから操作できます。

### ターミナル
- 受信したデータをテキストとして表示します。
- 各行の受信日時（`HH:mm:ss.SSS`形式）を記録します。
- 受信日時の表示をON/OFFで切り替えられます。
- 自動スクロール機能があります。
- テキスト入力フィールドからデバイスにデータを送信できます。

### プロッター
- カンマ区切り（CSV）で受信した数値データをリアルタイムグラフにプロットします。
- 最大5チャンネルのデータを同時に表示できます。
- チャンネルごとに表示/非表示を切り替えられます。
- **横軸（時間軸）:**
  - ピンチ操作でズームイン・ズームアウトができます。
  - 0.1秒 / 1秒 / 10秒 の3段階プリセットで切り替えられます。
  - 時間幅とグリッド間隔が画面右下に表示されます。
- **縦軸（値軸）:**
  - **自動モード:** 表示中のデータの中心に自動的に合わせます。
  - **固定モード:** 最小値・最大値を手動で設定できます。

## 対応環境

| 項目 | 内容 |
|------|------|
| プラットフォーム | iOS 17.0 以上 |
| 開発言語 | Swift 5.0 |
| 開発環境 | Xcode 15.4 以上 |
| 対応デバイス | iPhone / iPad |

## BLE サービス情報

ESP32_BleSerial ライブラリのデフォルト設定（Nordic UART Service）に対応しています。

| 名称 | UUID |
|------|------|
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |
| RX Characteristic (Write) | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` |
| TX Characteristic (Notify) | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` |

## セットアップ

### iOSアプリ

1. このリポジトリをクローンします。
   ```bash
   git clone https://github.com/NW-Lab/EasyArduinoBleTerm.git
   ```
2. `EasyArduinoBleTerm.xcodeproj` をXcodeで開きます。
3. Signing & Capabilities で開発チームを設定します。
4. iPhoneに実機ビルドします。

### Arduino / ESP32 側

[ESP32_BleSerial](https://github.com/avinabmalla/ESP32_BleSerial) ライブラリをArduino IDEにインストールし、以下のような基本的なスケッチで動作確認できます。

```cpp
#include <BleSerial.h>

BleSerial ble;

void setup() {
    Serial.begin(115200);
    // アドバタイズ名を設定（アプリのスキャン画面に表示されます）
    ble.begin("MyESP32Device");
}

void loop() {
    // カンマ区切りでデータを送信（プロッターで表示可能）
    float sensor1 = analogRead(34) * 3.3 / 4095.0;
    float sensor2 = analogRead(35) * 3.3 / 4095.0;
    ble.printf("%.3f,%.3f\n", sensor1, sensor2);

    // BLEからの受信データをシリアルに転送
    while (ble.available()) {
        Serial.write(ble.read());
    }

    delay(10); // 100Hz
}
```

## プロジェクト構成

```
EasyArduinoBleTerm/
├── EasyArduinoBleTerm.xcodeproj/
│   └── project.pbxproj
└── EasyArduinoBleTerm/
    ├── EasyArduinoBleTermApp.swift   # アプリエントリーポイント
    ├── Info.plist                    # Bluetooth権限設定
    ├── Models/
    │   └── PlotData.swift            # プロット用データモデル
    ├── ViewModels/
    │   ├── BLEManager.swift          # BLE通信管理（CoreBluetooth）
    │   └── PlotterViewModel.swift    # プロッターのロジック
    └── Views/
        ├── ContentView.swift         # メイン画面（タブ切り替え）
        ├── DeviceSelectionView.swift # デバイス選択画面
        ├── TerminalView.swift        # ターミナル画面
        └── PlotterView.swift         # プロッター画面
```

## ライセンス

MIT License

## 関連リンク

- [ESP32_BleSerial ライブラリ](https://github.com/avinabmalla/ESP32_BleSerial)
