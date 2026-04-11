# EasyArduinoBleTerm

Arduino IDE の **シリアルモニター** と **シリアルプロッター** に相当する機能を、BLE（Bluetooth Low Energy）経由で利用するクロスプラットフォームアプリです。
**iOS 版**（Swift / SwiftUI）、**Android 版**（Kotlin / Jetpack Compose）、**Windows 版**（WinUI 3 / C#）、および **Web 版**（React / TypeScript）の4プラットフォームに対応しています。

[ESP32_BleSerial](https://github.com/avinabmalla/ESP32_BleSerial) ライブラリ（Nordic UART Service）を使用した Arduino / ESP32 デバイスに対応しています。100Hz 以上の高速データ受信にも対応できるよう、全プラットフォームで UI スロットリング（30fps 表示更新）を実装しています。

---

## Web 版（ブラウザですぐに使えます）

**URL:** [https://nw-lab.github.io/EasyArduinoBleTerm/](https://nw-lab.github.io/EasyArduinoBleTerm/)

| 項目 | 内容 |
|---|---|
| ブラウザ | Google Chrome または Microsoft Edge |
| OS | Windows 10/11・macOS・Android（iOS / Safari は非対応） |
| 備考 | Web Bluetooth API を使用しているため、対応ブラウザが必要です。 |

---

## リポジトリ構成

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

## iOS 版のセットアップ

### 必要環境
| 項目 | 内容 |
|---|---|
| OS | macOS 13 以降 |
| IDE | Xcode 15 以降 |
| 実行環境 | iPhone / iPad（iOS 16 以降）実機 ※ BLE はシミュレーター不可 |

### ビルド手順
```bash
git clone https://github.com/NW-Lab/EasyArduinoBleTerm.git
cd EasyArduinoBleTerm/iOS
open EasyArduinoBleTerm.xcodeproj
```
Xcode の **Signing & Capabilities** タブで開発チームを設定し、実機にビルドしてください。

---

## Android 版のセットアップ

### 必要環境
| 項目 | 内容 |
|---|---|
| IDE | Android Studio Ladybug（2024.2.1）以降 |
| 対応 Android | Android 8.0（API 26）以降 |
| 実行環境 | BLE 対応 Android 実機 ※ エミュレーターでは BLE 不可 |

### ビルド手順
```bash
git clone https://github.com/NW-Lab/EasyArduinoBleTerm.git
```
Android Studio で `Android/` フォルダーを **Open an existing project** で開き、Gradle Sync 後に実機にビルドしてください。

### 配布方法（APK）
1. Android Studio メニュー → **Build → Build Bundle(s) / APK(s) → Build APK(s)**
2. `app/build/outputs/apk/debug/app-debug.apk` が生成される
3. APK ファイルをそのまま共有（メール・Google Drive など）
4. 受け取った側は「提供元不明のアプリ」を許可してインストール

---

## Windows 版のセットアップ

### 必要環境
| 項目 | 内容 |
|---|---|
| OS | Windows 10 (1903) 以降 または Windows 11 |
| IDE | Visual Studio 2022（17.8 以降） |
| ワークロード | .NET デスクトップ開発 + Windows アプリ開発 |
| その他 | Windows App SDK 拡張機能、BLE 対応 Bluetooth アダプター |

### ビルド手順
```bash
git clone https://github.com/NW-Lab/EasyArduinoBleTerm.git
```
Visual Studio で `Windows/EasyArduinoBleTerm/EasyArduinoBleTerm.csproj` を開き、ビルドしてください。

---

## Web 版のローカル開発

Web 版は GitHub Pages で公開済みですが、ローカルで開発・実行することも可能です。

### 必要環境
- Node.js 20 以降
- pnpm

### ビルド手順
```bash
git clone https://github.com/NW-Lab/EasyArduinoBleTerm.git
cd EasyArduinoBleTerm/Web/EasyArduinoBleTerm
pnpm install
pnpm dev
```
`http://localhost:5173` を Chrome / Edge で開いてください。

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
