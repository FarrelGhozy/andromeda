#include <Arduino.h>
#include "sensor.h"
#include "config.h"

static SensorReading readOneSensor(int pin) {
  int raw = analogRead(pin);

  float percent = 100.0f - ((raw - 1500.0f) / (2700.0f - 1500.0f)) * 100.0f;
  if (percent < 0.0f) percent = 0.0f;
  if (percent > 100.0f) percent = 100.0f;

  return { raw, percent };
}

AllReadings readAllSensors(const int* sensorPins) {
  AllReadings result;
  for (int i = 0; i < NUM_PETAK; i++) {
    if (SENSOR_CONNECTED[i]) {
      result.readings[i] = readOneSensor(sensorPins[i]);
      Serial.print("Sensor ");
      Serial.print(i);
      Serial.print(" (pin ");
      Serial.print(sensorPins[i]);
      Serial.print("): raw=");
      Serial.print(result.readings[i].raw);
      Serial.print(" percent=");
      Serial.println(result.readings[i].percent);
    } else {
      result.readings[i] = { -1, -1.0f };
      Serial.print("Sensor ");
      Serial.print(i);
      Serial.println(": disabled (no hardware)");
    }
    delay(10);
  }
  return result;
}

bool isSensorValid(const SensorReading& reading) {
  return reading.raw >= 0 && reading.percent >= 0.0f;
}
