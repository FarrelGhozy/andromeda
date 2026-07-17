#include <Arduino.h>
#include "sensor.h"
#include "config.h"

// ADC 12-bit: 0-4095
// Capacitive sensor: kering ~2700 (0%), basah ~1500 (100%)
// Kalibrasi linier sederhana
SensorReading readSensor() {
  int raw = analogRead(SENSOR_PIN);

  // Map: raw 2700 -> 0%, raw 1500 -> 100%
  float percent = 100.0f - ((raw - 1500.0f) / (2700.0f - 1500.0f)) * 100.0f;
  if (percent < 0.0f) percent = 0.0f;
  if (percent > 100.0f) percent = 100.0f;

  Serial.print("Sensor raw: ");
  Serial.print(raw);
  Serial.print(" -> percent: ");
  Serial.println(percent);

  return { raw, percent };
}
