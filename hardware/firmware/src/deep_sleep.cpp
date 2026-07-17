#include <Arduino.h>
#include "deep_sleep.h"
#include "config.h"
#include <esp_sleep.h>

void goToSleep(uint64_t sleepSeconds) {
  Serial.print("Going to sleep for ");
  Serial.print(sleepSeconds);
  Serial.println(" seconds");
  Serial.flush();

  uint64_t sleepUs = sleepSeconds * 1000000ULL;
  esp_sleep_enable_timer_wakeup(sleepUs);
  esp_deep_sleep_start();
}
