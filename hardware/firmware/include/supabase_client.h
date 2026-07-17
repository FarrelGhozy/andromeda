#ifndef ANDROMEDA_SUPABASE_CLIENT_H
#define ANDROMEDA_SUPABASE_CLIENT_H

#include <Arduino.h>
#include "sensor.h"

struct SystemConfig {
  String mode;
  int thresholdDry;
  int thresholdWet;
  int valveDurationMs;
  int readIntervalSec;
  bool valid;
};

struct PendingCommand {
  long id;
  String command;
  int duration;
  bool valid;
};

bool postSensorReading(const char* deviceId, const SensorReading& reading, const char* valveStatus);
SystemConfig getSystemConfig(const char* deviceId);
PendingCommand getPendingCommand(const char* deviceId);
void markCommandExecuted(long commandId);

#endif
