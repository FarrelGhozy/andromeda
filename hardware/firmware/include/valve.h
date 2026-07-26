#ifndef ANDROMEDA_VALVE_H
#define ANDROMEDA_VALVE_H

#define NUM_PETAK 6

void initAllValves(const int* relayPins);
void openValve(int relayPin, int durationMs);
void closeSingleValve(int relayPin);
void closeAllValves(const int* relayPins);
bool getValveState(int index);

#endif
