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
// #define WIFI_SSID "HUAWEI-B535-932"
#define WIFI_SSID "WIFI_Premium"
#define WIFI_PASSWORD "senyumdulu"

// ============================================================
// KONFIGURASI SUPABASE
// Ganti dengan URL dan publishable key project Supabase lo
// ============================================================
#define SUPABASE_URL "https://hedsphbfzbhpmiwihrnk.supabase.co"
#define SUPABASE_ANON_KEY "sb_publishable_NUeHpWMeBE6R-lXNr6-jUQ_KWhaGTT5"

// ============================================================
// DEFAULT SISTEM
// Akan dioverride oleh system_config dari Supabase
// ============================================================
#define DEFAULT_THRESHOLD_DRY 30
#define DEFAULT_THRESHOLD_WET 70
#define DEFAULT_VALVE_DURATION_MS 30000
// ============================================================
// INTERVAL PENGIRIMAN DATA SENSOR KE SERVER (detik)
//   Default produksi: 1800 detik (30 menit).
//   Nilai system_config.read_interval di Supabase tetap bisa
//   meng-override nilai ini (dibatasi minimal MIN_READ_INTERVAL_SEC
//   agar nilai invalid di DB tidak memicu spam request).
// ============================================================
#define DEFAULT_READ_INTERVAL_SEC 1800
#define MIN_READ_INTERVAL_SEC 60

// ============================================================
// TIMING & SAFETY
// ============================================================
#define WIFI_TIMEOUT_MS 10000
#define VALVE_MAX_DURATION_MS 120000
// Poll perintah dari app. 10s = 6x lebih hemat request WiFi
// (sebelumnya 1s × 6 petak = 6 request/detik → beban WiFi tinggi
// yang memicu puncak arus & reset daya pada power yang rapuh).
#define COMMAND_POLL_INTERVAL_MS 10000
#define HEARTBEAT_INTERVAL_MS 60000UL
#define CONFIG_REFRESH_INTERVAL_MS 120000UL

#endif
