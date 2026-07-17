#ifndef ANDROMEDA_SENSOR_H
#define ANDROMEDA_SENSOR_H

struct SensorReading {
  int raw;
  float percent;
};

SensorReading readSensor();

#endif
