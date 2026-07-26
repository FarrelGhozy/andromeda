#include <Arduino.h>
#include "valve.h"
#include "config.h"

static bool valveStates[NUM_PETAK] = {false};

void initAllValves(const int* relayPins) {
  for (int i = 0; i < NUM_PETAK; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], LOW);
    valveStates[i] = false;
  }
  Serial.println("All valves initialized");
}

void openValve(int relayPin, int durationMs) {
  if (durationMs > VALVE_MAX_DURATION_MS) {
    durationMs = VALVE_MAX_DURATION_MS;
  }
  if (durationMs < 1000) {
    durationMs = 1000;
  }

  Serial.print("Opening valve on pin ");
  Serial.print(relayPin);
  Serial.print(" for ");
  Serial.print(durationMs);
  Serial.println(" ms");

  digitalWrite(relayPin, HIGH);
  for (int i = 0; i < NUM_PETAK; i++) {
    if (relayPin == RELAY_PINS[i]) {
      valveStates[i] = true;
      break;
    }
  }

  delay(durationMs);

  digitalWrite(relayPin, LOW);
  for (int i = 0; i < NUM_PETAK; i++) {
    if (relayPin == RELAY_PINS[i]) {
      valveStates[i] = false;
      break;
    }
  }

  Serial.println("Valve closed after duration");
}

void closeSingleValve(int relayPin) {
  digitalWrite(relayPin, LOW);
  for (int i = 0; i < NUM_PETAK; i++) {
    if (relayPin == RELAY_PINS[i]) {
      valveStates[i] = false;
      break;
    }
  }
}

void closeAllValves(const int* relayPins) {
  for (int i = 0; i < NUM_PETAK; i++) {
    digitalWrite(relayPins[i], LOW);
    valveStates[i] = false;
  }
  Serial.println("All valves closed");
}

bool getValveState(int index) {
  if (index >= 0 && index < NUM_PETAK) {
    return valveStates[index];
  }
  return false;
}
