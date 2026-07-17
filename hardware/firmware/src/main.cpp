#include <Arduino.h>
#include "config.h"
#include "wifi_manager.h"
#include "sensor.h"
#include "valve.h"
#include "supabase_client.h"
#include "deep_sleep.h"

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  initValve();

  Serial.println("ANDROMEDA firmware starting");
  Serial.print("Device ID: ");
  Serial.println(DEVICE_ID);

  // Koneksi WiFi
  if (!connectWiFi()) {
    Serial.println("WiFi failed, going to sleep");
    goToSleep(DEFAULT_READ_INTERVAL_SEC);
  }

  // Baca sensor
  SensorReading reading = readSensor();

  // Ambil config dari Supabase
  SystemConfig config = getSystemConfig(DEVICE_ID);
  if (!config.valid) {
    Serial.println("Using default config");
  }

  // Cek perintah pending
  PendingCommand cmd = getPendingCommand(DEVICE_ID);
  bool valveActivated = false;
  int valveDuration = config.valveDurationMs;

  if (cmd.valid) {
    Serial.print("Executing command: ");
    Serial.println(cmd.command);

    if (cmd.command.equals("VALVE_ON")) {
      if (cmd.duration > 0) {
        valveDuration = cmd.duration * 1000;
      }
      openValve(valveDuration);
      valveActivated = true;
    } else if (cmd.command.equals("VALVE_OFF")) {
      closeValve();
    }

    markCommandExecuted(cmd.id);
  } else if (config.mode == "auto") {
    // Mode otomatis
    if (reading.percent < config.thresholdDry) {
      Serial.println("Soil dry, opening valve");
      openValve(config.valveDurationMs);
      valveActivated = true;
    } else if (reading.percent > config.thresholdWet) {
      Serial.println("Soil wet enough, valve stays closed");
    }
  }

  // Pastikan valve mati sebelum tidur
  closeValve();

  // Kirim status akhir
  SensorReading finalReading = readSensor();
  postSensorReading(DEVICE_ID, finalReading, valveActivated ? "ON" : "OFF");

  // Disconnect WiFi untuk hemat daya
  disconnectWiFi();
  digitalWrite(LED_PIN, LOW);

  // Tidur
  goToSleep(config.readIntervalSec);
}

void loop() {
  // Tidak dipakai karena deep sleep
}
