#ifndef ANDROMEDA_SENSOR_H
#define ANDROMEDA_SENSOR_H

#define NUM_PETAK 6

struct SensorReading {
  int raw;
  float percent;
};

struct AllReadings {
  SensorReading readings[NUM_PETAK];
};

AllReadings readAllSensors(const int* sensorPins);

#endif
