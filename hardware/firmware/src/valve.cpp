#include <Arduino.h>
#include "valve.h"
#include "config.h"

static bool valveOpen = false;

void initValve() {
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  valveOpen = false;
}

void openValve(int durationMs) {
  if (durationMs > VALVE_MAX_DURATION_MS) {
    durationMs = VALVE_MAX_DURATION_MS;
  }
  if (durationMs < 1000) {
    durationMs = 1000;
  }

  Serial.print("Opening valve for ");
  Serial.print(durationMs);
  Serial.println(" ms");

  digitalWrite(RELAY_PIN, HIGH);
  valveOpen = true;

  delay(durationMs);

  closeValve();
}

void closeValve() {
  digitalWrite(RELAY_PIN, LOW);
  valveOpen = false;
  Serial.println("Valve closed");
}

bool isValveOpen() {
  return valveOpen;
}
