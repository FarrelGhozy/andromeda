#include <Arduino.h>
#include "config.h"
#include "wifi_manager.h"
#include "sensor.h"
#include "valve.h"
#include "supabase_client.h"

unsigned long lastSensorPush = 0;
unsigned long lastCommandCheck = 0;
unsigned long lastWiFiCheck = 0;
unsigned long lastValvePush = 0;
int currentReadIntervalSec = DEFAULT_READ_INTERVAL_SEC;
SystemConfig cachedConfigs[NUM_PETAK];
bool prevValveStates[NUM_PETAK] = {false};

static void refreshAllConfigs() {
  for (int i = 0; i < NUM_PETAK; i++) {
    SystemConfig cfg = getSystemConfig(PETAK_IDS[i]);
    if (cfg.valid) {
      cachedConfigs[i] = cfg;
      if (cfg.readIntervalSec > 0) {
        currentReadIntervalSec = cfg.readIntervalSec;
      }
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(500);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  initAllValves(RELAY_PINS);

  Serial.println("ANDROMEDA firmware v2 (non-blocking)");
  Serial.print("ESP32 ID: ");
  Serial.println(ESP32_ID);
  Serial.print("Number of petaks: ");
  Serial.println(NUM_PETAK);

  if (!connectWiFi()) {
    Serial.println("WiFi failed, restarting...");
    ESP.restart();
  }

  refreshAllConfigs();

  lastSensorPush = millis();
}

void loop() {
  unsigned long now = millis();

  // 1. Update valve timers (non-blocking)
  updateValves();

  // 1b. Push valve state change to Supabase immediately
  if (now - lastValvePush >= 2000) {
    bool valveChanged = false;
    for (int i = 0; i < NUM_PETAK; i++) {
      bool current = getValveState(i);
      if (current != prevValveStates[i]) {
        valveChanged = true;
        prevValveStates[i] = current;
      }
    }
    if (valveChanged) {
      lastValvePush = now;
      AllReadings readings = readAllSensors(SENSOR_PINS);
      bool states[NUM_PETAK];
      for (int i = 0; i < NUM_PETAK; i++) states[i] = getValveState(i);
      postAllSensorReadings(readings, states, PETAK_IDS);
      Serial.println("Immediate push after valve state change");
    }
  }

  // 2. WiFi check & reconnect every 30s
  if (now - lastWiFiCheck >= 30000) {
    lastWiFiCheck = now;
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi disconnected, reconnecting...");
      if (connectWiFi()) {
        refreshAllConfigs();
      }
    }
  }

  // 3. Check pending commands every 1s
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
          if (cmd.duration == 0 && cachedConfigs[i].mode == "manual") {
            openValveIndefinitely(RELAY_PINS[i]);
          } else if (cmd.duration > 0) {
            openValve(RELAY_PINS[i], cmd.duration * 1000);
          } else {
            openValve(RELAY_PINS[i], cachedConfigs[i].valveDurationMs);
          }
        } else if (cmd.command.equals("VALVE_OFF")) {
          closeSingleValve(RELAY_PINS[i]);
        }

        markCommandExecuted(cmd.id);

        // Immediate push so app sees valve state in real-time
        AllReadings cmdReadings = readAllSensors(SENSOR_PINS);
        bool cmdValveStates[NUM_PETAK];
        for (int j = 0; j < NUM_PETAK; j++) {
          cmdValveStates[j] = getValveState(j);
        }
        postAllSensorReadings(cmdReadings, cmdValveStates, PETAK_IDS);
        Serial.println("Immediate push after command");
      }
    }
  }

  // 4. Sensor push cycle
  if (now - lastSensorPush >= (unsigned long)currentReadIntervalSec * 1000) {
    lastSensorPush = now;
    Serial.println("=== Sensor push cycle ===");

    AllReadings readings = readAllSensors(SENSOR_PINS);

    for (int i = 0; i < NUM_PETAK; i++) {
      SystemConfig cfg = getSystemConfig(PETAK_IDS[i]);
      if (cfg.valid) {
        cachedConfigs[i] = cfg;
        if (cfg.readIntervalSec > 0) {
          currentReadIntervalSec = cfg.readIntervalSec;
        }

        if (isSensorValid(readings.readings[i])
            && cfg.mode == "auto"
            && readings.readings[i].percent < cfg.thresholdDry
            && !getValveState(i)) {
          Serial.print("Petak ");
          Serial.print(i);
          Serial.print(" dry (");
          Serial.print(readings.readings[i].percent);
          Serial.print("%), opening valve for ");
          Serial.print(cfg.valveDurationMs);
          Serial.println(" ms");
          openValve(RELAY_PINS[i], cfg.valveDurationMs);
        }
      }
    }

    bool actualValveStates[NUM_PETAK];
    for (int i = 0; i < NUM_PETAK; i++) {
      actualValveStates[i] = getValveState(i);
    }

    postAllSensorReadings(readings, actualValveStates, PETAK_IDS);

    Serial.println("=== Sensor push complete ===");
  }

  delay(10);
}
