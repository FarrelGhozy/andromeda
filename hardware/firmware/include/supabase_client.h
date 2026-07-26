#ifndef ANDROMEDA_SUPABASE_CLIENT_H
#define ANDROMEDA_SUPABASE_CLIENT_H

#include <Arduino.h>
#include "sensor.h"

#define NUM_PETAK 6

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

bool postAllSensorReadings(const AllReadings& allReadings, const bool* valveStates, const char* const* petakIds);
SystemConfig getSystemConfig(const char* deviceId);
PendingCommand getPendingCommand(const char* deviceId);
void markCommandExecuted(long commandId);

#endif
