#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

namespace {
constexpr char kDeviceName[] = "EasyArduinoBleTerm";
constexpr char kServiceUuid[] = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
constexpr char kRxUuid[] = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
constexpr char kTxUuid[] = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";
constexpr size_t kBlePayloadSize = 20;

BLECharacteristic* txCharacteristic = nullptr;
volatile bool bleClientConnected = false;

class ServerCallbacks final : public BLEServerCallbacks {
  void onConnect(BLEServer*) override {
    bleClientConnected = true;
  }

  void onDisconnect(BLEServer* server) override {
    bleClientConnected = false;
    server->startAdvertising();
  }
};

class RxCallbacks final : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    uint8_t* data = characteristic->getData();
    const size_t length = characteristic->getLength();
    if (data != nullptr && length > 0) {
      Serial.write(data, length);
    }
  }
};

void startBleUart() {
  BLEDevice::init(kDeviceName);

  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService* service = server->createService(kServiceUuid);

  txCharacteristic = service->createCharacteristic(
      kTxUuid, BLECharacteristic::PROPERTY_NOTIFY);
  txCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic* rxCharacteristic = service->createCharacteristic(
      kRxUuid,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  rxCharacteristic->setCallbacks(new RxCallbacks());

  service->start();

  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(kServiceUuid);
  advertising->setScanResponse(true);
  advertising->start();
}
}  // namespace

void setup() {
  Serial.begin(115200);
  startBleUart();
}

void loop() {
  if (!bleClientConnected) {
    while (Serial.available() > 0) {
      Serial.read();
    }
    delay(1);
    return;
  }

  while (Serial.available() > 0) {
    uint8_t data[kBlePayloadSize];
    size_t length = 0;
    while (length < sizeof(data) && Serial.available() > 0) {
      data[length++] = static_cast<uint8_t>(Serial.read());
    }

    txCharacteristic->setValue(data, length);
    txCharacteristic->notify();
    delay(5);
  }
}
