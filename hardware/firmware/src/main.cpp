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

  initAllValves(RELAY_PINS);

  Serial.println("ANDROMEDA firmware starting (multi-petak)");
  Serial.print("ESP32 ID: ");
  Serial.println(ESP32_ID);
  Serial.print("Number of petaks: ");
  Serial.println(NUM_PETAK);

  // Koneksi WiFi
  if (!connectWiFi()) {
    Serial.println("WiFi failed, going to sleep");
    goToSleep(DEFAULT_READ_INTERVAL_SEC);
  }

  // Baca semua sensor
  AllReadings allReadings = readAllSensors(SENSOR_PINS);

  // Ambil read_interval dari petak pertama (sama untuk semua)
  SystemConfig firstConfig = getSystemConfig(PETAK_IDS[0]);
  int readIntervalSec = firstConfig.valid ? firstConfig.readIntervalSec : DEFAULT_READ_INTERVAL_SEC;

  bool anyValveOpened = false;
  bool valveStates[NUM_PETAK] = {false};

  // Loop: proses tiap petak
  for (int i = 0; i < NUM_PETAK; i++) {
    const char* deviceId = PETAK_IDS[i];
    int sensorVal = allReadings.readings[i].raw;
    float percent = allReadings.readings[i].percent;

    Serial.println("---");
    Serial.print("Processing ");
    Serial.println(deviceId);

    // Ambil config petak ini
    SystemConfig config = getSystemConfig(deviceId);
    if (!config.valid) {
      config = firstConfig;
    }

    // Cek perintah pending
    PendingCommand cmd = getPendingCommand(deviceId);

    if (cmd.valid) {
      Serial.print("Executing command: ");
      Serial.println(cmd.command);

      if (cmd.command.equals("VALVE_ON")) {
        int duration = cmd.duration > 0 ? cmd.duration * 1000 : config.valveDurationMs;
        openValve(RELAY_PINS[i], duration);
        valveStates[i] = true;
        anyValveOpened = true;
      } else if (cmd.command.equals("VALVE_OFF")) {
        closeSingleValve(RELAY_PINS[i]);
        valveStates[i] = false;
      }

      markCommandExecuted(cmd.id);
    } else if (config.mode == "auto") {
      // Mode otomatis
      if (percent < config.thresholdDry) {
        Serial.print("Soil dry (");
        Serial.print(percent);
        Serial.print("%), opening valve");
        openValve(RELAY_PINS[i], config.valveDurationMs);
        valveStates[i] = true;
        anyValveOpened = true;
      } else if (percent > config.thresholdWet) {
        Serial.print("Soil wet enough (");
        Serial.print(percent);
        Serial.println("%), valve stays closed");
        valveStates[i] = false;
      } else {
        Serial.print("Soil moisture normal (");
        Serial.print(percent);
        Serial.println("%), no action");
        valveStates[i] = false;
      }
    }
  }

  // Pastikan semua valve mati
  closeAllValves(RELAY_PINS);

  // Kirim status akhir (batch)
  AllReadings finalReadings = readAllSensors(SENSOR_PINS);
  postAllSensorReadings(finalReadings, valveStates, PETAK_IDS);

  // Disconnect WiFi untuk hemat daya
  disconnectWiFi();
  digitalWrite(LED_PIN, LOW);

  // Tidur
  goToSleep(readIntervalSec);
}

void loop() {
  // Tidak dipakai karena deep sleep
}
