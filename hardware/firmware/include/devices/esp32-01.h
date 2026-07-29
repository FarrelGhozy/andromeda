#ifndef ANDROMEDA_ESP32_01_H
#define ANDROMEDA_ESP32_01_H

#define ESP32_ID "esp32-01"

static const char* PETAK_IDS[6] = {"petak-01", "petak-02", "petak-03", "petak-04", "petak-05", "petak-06"};
static const int SENSOR_PINS[6] = {32, 33, 34, 35, 36, 39};
static const int RELAY_PINS[6] = {26, 27, 14, 12, 13, 15};

// LED Built-in (biasanya GPIO 2 untuk ESP32 Dev)
#define LED_PIN 2

#endif
