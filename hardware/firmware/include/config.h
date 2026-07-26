#ifndef ANDROMEDA_CONFIG_H
#define ANDROMEDA_CONFIG_H

// ============================================================
// PILIH ESP32
// Ganti include dibawah sesuai ESP32 yang akan di-flash
// ============================================================
#include "devices/esp32-01.h"

// ============================================================
// KONFIGURASI JARINGAN
// ============================================================
#define WIFI_SSID "HUAWEI-B535-932"
#define WIFI_PASSWORD "ganti-password-wifi"

// ============================================================
// KONFIGURASI SUPABASE
// Ganti dengan URL dan publishable key project Supabase lo
// ============================================================
#define SUPABASE_URL "https://your-project.supabase.co"
#define SUPABASE_ANON_KEY "your-anon-key"

// ============================================================
// DEFAULT SISTEM
// Akan dioverride oleh system_config dari Supabase
// ============================================================
#define DEFAULT_THRESHOLD_DRY 30
#define DEFAULT_THRESHOLD_WET 70
#define DEFAULT_VALVE_DURATION_MS 30000
#define DEFAULT_READ_INTERVAL_SEC 1800

// ============================================================
// TIMING & SAFETY
// ============================================================
#define WIFI_TIMEOUT_MS 10000
#define VALVE_MAX_DURATION_MS 120000

#endif
