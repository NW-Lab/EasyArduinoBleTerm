# EasyArduinoBleTerm

Arduino IDE の **シリアルモニター** と **シリアルプロッター** に相当する機能を、BLE（Bluetooth Low Energy）経由で利用するクロスプラットフォームアプリです。
**iOS 版**（Swift / SwiftUI）、**Android 版**（Kotlin / Jetpack Compose）、**Windows 版**（WinUI 3 / C#）、および **Web 版**（React / TypeScript）の4プラットフォームに対応しています。

[ESP32_BleSerial](https://github.com/avinabmalla/ESP32_BleSerial) ライブラリ（Nordic UART Service）を使用した Arduino / ESP32 デバイスに対応しています。100Hz 以上の高速データ受信にも対応できるよう、全プラットフォームで UI スロットリング（30fps 表示更新）を実装しています。

---

## インストール・利用方法（ビルド不要）

各プラットフォームですぐに利用できる形式を用意しています。

| プラットフォーム | インストール・利用方法 |
|---|---|
| **Web 版** | ブラウザで **[https://nw-lab.github.io/EasyArduinoBleTerm/](https://nw-lab.github.io/EasyArduinoBleTerm/)** を開く<br>※ Chrome または Edge が必要です。 |
| **iOS / iPadOS 版** | **[App Store からインストール](https://apps.apple.com/jp/app/easyarduinobleterm/id6759859872)** |
| **Android 版** | **[リリースページ](https://github.com/NW-Lab/EasyArduinoBleTerm/releases/latest)** から `EasyArduinoBleTermForAndroid.apk` をダウンロードしてインストール |
| **Windows 版** | **[リリースページ](https://github.com/NW-Lab/EasyArduinoBleTerm/releases/latest)** から `EasyArduinoBleTermForWindows.zip` をダウンロードし、展開して実行 |

---

## リポジトリ構成

ソースコードからビルド・改造したい場合は以下のディレクトリを参照してください。

```
EasyArduinoBleTerm/
├── Web/                              # Web 版 (React / TypeScript / Vite)
│   └── EasyArduinoBleTerm/
├── iOS/                              # iOS 版 (Swift / SwiftUI / Xcode)
│   └── EasyArduinoBleTerm/
├── Android/                          # Android 版 (Kotlin / Jetpack Compose)
│   └── app/src/main/java/...
└── Windows/                          # Windows 版 (WinUI 3 / C#)
    └── EasyArduinoBleTerm/
```

---

## 機能一覧

| 機能 | iOS 版 | Android 版 | Windows 版 | Web 版 |
|---|---|---|---|---|
| BLE デバイスのスキャン・選択 | ✅ | ✅ | ✅ | ✅ |
| アドバタイズ名・RSSI 表示 | ✅ | ✅ | ✅ | ✅ (※) |
| ターミナル（受信表示・送信） | ✅ | ✅ | ✅ | ✅ |
| 受信日時の表示 ON/OFF | ✅ | ✅ | ✅ | ✅ |
| 2000 行バッファー（古い行を自動削除） | ✅ | ✅ | ✅ | ✅ |
| プロッター（CSV 自動解析） | ✅ | ✅ | ✅ | ✅ |
| 最大 5 チャンネル・色分け表示 | ✅ | ✅ | ✅ | ✅ |
| チャンネル表示/非表示切り替え | ✅ | ✅ | ✅ | ✅ |
| 横軸プリセット（0.1s / 1s / 10s） | ✅ | ✅ | ✅ | ✅ |
| 縦軸 自動追従 ⇔ 固定 ワンタップ/クリック | ✅ | ✅ | ✅ | ✅ |

※ Web 版の RSSI 取得は一部環境・ブラウザに依存します。

### プロッターの操作方法

| 操作 | iOS / Android (タッチ) | Windows / Web (マウス) |
|---|---|---|
| **横軸（時間幅）ズーム** | ピンチ（水平） | ホイール回転 |
| **縦軸（値の幅）ズーム** | ピンチ（垂直） | Ctrl + ホイール |
| **縦軸オフセット移動** | 2本指ドラッグ | 右ドラッグ / Shift + ホイール |

---

## BLE プロトコル（ESP32_BleSerial / Nordic UART Service）

| 名称 | UUID |
|---|---|
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |
| TX Characteristic（ESP32 → アプリ、Notify） | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` |
| RX Characteristic（アプリ → ESP32、Write） | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` |

---

## 開発者向けビルド手順

### iOS 版
- **環境:** macOS 13 以降、Xcode 15 以降
- **手順:** `iOS/EasyArduinoBleTerm.xcodeproj` を開き、Signing を設定して実機にビルド（シミュレーター不可）。

### Android 版
- **環境:** Android Studio Ladybug 以降
- **手順:** `Android/` フォルダを開き、Gradle Sync 後に実機にビルド（エミュレーター不可）。

### Windows 版
- **環境:** Windows 10/11、Visual Studio 2022（.NET デスクトップ開発 + Windows アプリ開発）
- **手順:** `Windows/EasyArduinoBleTerm/EasyArduinoBleTerm.csproj` を開きビルド。

### Web 版
- **環境:** Node.js 20 以降、pnpm
- **手順:**
  ```bash
  cd Web/EasyArduinoBleTerm
  pnpm install
  pnpm dev
  ```

---

## Arduino / ESP32 サンプルコード

```cpp
#include <BleSerial.h>

BleSerial ble;

void setup() {
    // アドバタイズ名を設定（アプリのスキャン画面に表示されます）
    ble.begin("MyESP32Device");
}

void loop() {
    // カンマ区切りでデータを送信（プロッターで複数チャンネル表示可能）
    float v1 = sin(millis() / 1000.0);
    float v2 = cos(millis() / 1000.0);
    ble.printf("%.3f,%.3f\n", v1, v2);

    // アプリからの受信データを処理
    while (ble.available()) {
        char c = ble.read();
        // 必要に応じて処理
    }

    delay(10); // 100 Hz
}
```

---

## ライセンス

MIT License

## 関連リンク

- [ESP32_BleSerial ライブラリ](https://github.com/avinabmalla/ESP32_BleSerial)
