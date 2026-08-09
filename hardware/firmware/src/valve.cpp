#include <Arduino.h>
#include "valve.h"
#include "config.h"

static bool valveStates[NUM_PETAK] = {false};
static bool valveTimersActive[NUM_PETAK] = {false};
static unsigned long valveOpenTime[NUM_PETAK] = {0};
static unsigned long valveDurationMs[NUM_PETAK] = {0};

static int findIndexByPin(int relayPin) {
  for (int i = 0; i < NUM_PETAK; i++) {
    if (relayPin == RELAY_PINS[i]) return i;
  }
  return -1;
}

void initAllValves(const int* relayPins) {
  for (int i = 0; i < NUM_PETAK; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], LOW);
    valveStates[i] = false;
    valveTimersActive[i] = false;
  }
  Serial.println("All valves initialized");
}

void openValve(int relayPin, int durationMs) {
  int idx = findIndexByPin(relayPin);
  if (idx < 0) return;

  if (durationMs > VALVE_MAX_DURATION_MS) durationMs = VALVE_MAX_DURATION_MS;
  if (durationMs < 1000) durationMs = 1000;

  digitalWrite(relayPin, HIGH);
  valveStates[idx] = true;
  valveTimersActive[idx] = true;
  valveOpenTime[idx] = millis();
  valveDurationMs[idx] = durationMs;

  Serial.print("Valve ");
  Serial.print(idx);
  Serial.print(" open for ");
  Serial.print(durationMs);
  Serial.println(" ms");
}

void openValveIndefinitely(int relayPin) {
  int idx = findIndexByPin(relayPin);
  if (idx < 0) return;

  digitalWrite(relayPin, HIGH);
  valveStates[idx] = true;
  valveTimersActive[idx] = false;

  Serial.print("Valve ");
  Serial.print(idx);
  Serial.println(" open indefinitely");
}

void closeSingleValve(int relayPin) {
  int idx = findIndexByPin(relayPin);
  if (idx < 0) return;

  digitalWrite(relayPin, LOW);
  valveStates[idx] = false;
  valveTimersActive[idx] = false;

  Serial.print("Valve ");
  Serial.print(idx);
  Serial.println(" closed");
}

void closeAllValves(const int* relayPins) {
  for (int i = 0; i < NUM_PETAK; i++) {
    digitalWrite(relayPins[i], LOW);
    valveStates[i] = false;
    valveTimersActive[i] = false;
  }
  Serial.println("All valves closed");
}

void updateValves() {
  unsigned long now = millis();
  for (int i = 0; i < NUM_PETAK; i++) {
    if (valveTimersActive[i] && (now - valveOpenTime[i] >= valveDurationMs[i])) {
      digitalWrite(RELAY_PINS[i], LOW);
      valveStates[i] = false;
      valveTimersActive[i] = false;
      Serial.print("Valve ");
      Serial.print(i);
      Serial.println(" auto-closed by timer");
    }
  }
}

bool getValveState(int index) {
  if (index >= 0 && index < NUM_PETAK) return valveStates[index];
  return false;
}
