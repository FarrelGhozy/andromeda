#include <Arduino.h>
#include "config.h"
#include "wifi_manager.h"
#include "sensor.h"
#include "valve.h"
#include "supabase_client.h"

unsigned long lastSensorPush = 0;
unsigned long lastCommandCheck = 0;
int currentReadIntervalSec = DEFAULT_READ_INTERVAL_SEC;

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  initAllValves(RELAY_PINS);

  Serial.println("ANDROMEDA firmware starting (always-on mode)");
  Serial.print("ESP32 ID: ");
  Serial.println(ESP32_ID);
  Serial.print("Number of petaks: ");
  Serial.println(NUM_PETAK);

  if (!connectWiFi()) {
    Serial.println("WiFi failed, restarting...");
    ESP.restart();
  }

  SystemConfig firstConfig = getSystemConfig(PETAK_IDS[0]);
  if (firstConfig.valid) {
    currentReadIntervalSec = firstConfig.readIntervalSec;
  }

  lastSensorPush = millis();
}

void loop() {
  unsigned long now = millis();

  // ========== CEK PENDING COMMANDS (prioritas) ==========
  if (now - lastCommandCheck >= COMMAND_POLL_INTERVAL_MS) {
    lastCommandCheck = now;

    for (int i = 0; i < NUM_PETAK; i++) {
      PendingCommand cmd = getPendingCommand(PETAK_IDS[i]);

      if (cmd.valid) {
        Serial.print("Executing command for petak ");
        Serial.print(i);
        Serial.print(": ");
        Serial.println(cmd.command);

        if (cmd.command.equals("VALVE_ON")) {
          int duration = cmd.duration > 0 ? cmd.duration * 1000 : DEFAULT_VALVE_DURATION_MS;
          openValve(RELAY_PINS[i], duration);
        } else if (cmd.command.equals("VALVE_OFF")) {
          closeSingleValve(RELAY_PINS[i]);
        }

        markCommandExecuted(cmd.id);
      }
    }
  }

  // ========== PUSH SENSOR DATA SESUAI INTERVAL ==========
  if (now - lastSensorPush >= (unsigned long)currentReadIntervalSec * 1000) {
    Serial.println("=== Sensor push cycle ===");

    AllReadings beforeReadings = readAllSensors(SENSOR_PINS);

    // Auto mode: buka valve jika tanah kering
    for (int i = 0; i < NUM_PETAK; i++) {
      SystemConfig config = getSystemConfig(PETAK_IDS[i]);
      if (!config.valid) {
        config.mode = "auto";
        config.thresholdDry = DEFAULT_THRESHOLD_DRY;
        config.thresholdWet = DEFAULT_THRESHOLD_WET;
        config.valveDurationMs = DEFAULT_VALVE_DURATION_MS;
      }
      if (config.readIntervalSec > 0) {
        currentReadIntervalSec = config.readIntervalSec;
      }

      if (config.mode == "auto" && beforeReadings.readings[i].percent < config.thresholdDry) {
        Serial.print("Petak ");
        Serial.print(i);
        Serial.print(" dry (");
        Serial.print(beforeReadings.readings[i].percent);
        Serial.print("%), opening valve for ");
        Serial.print(config.valveDurationMs);
        Serial.println(" ms");
        openValve(RELAY_PINS[i], config.valveDurationMs);
      }
    }

    closeAllValves(RELAY_PINS);

    AllReadings afterReadings = readAllSensors(SENSOR_PINS);
    bool valveStates[NUM_PETAK] = {false};

    postAllSensorReadings(afterReadings, valveStates, PETAK_IDS);

    lastSensorPush = millis();
    Serial.println("=== Sensor push complete ===");
  }

  delay(100);
}
