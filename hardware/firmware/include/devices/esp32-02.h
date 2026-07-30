#ifndef ANDROMEDA_ESP32_02_H
#define ANDROMEDA_ESP32_02_H

#define ESP32_ID "esp32-02"

static const char* PETAK_IDS[6] = {"petak-07", "petak-08", "petak-09", "petak-10", "petak-11", "petak-12"};
static const int SENSOR_PINS[6] = {32, 33, 34, 35, 36, 39};
static const int RELAY_PINS[6] = {26, 27, 14, 12, 13, 15};
static const bool SENSOR_CONNECTED[6] = {true, true, true, true, true, true};

#define LED_PIN 2

#endif
