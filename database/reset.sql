-- ============================================================
-- RESET DATABASE ANDROMEDA (⚠️ MENGHAPUS SEMUA DATA)
--
-- CARA PAKAI (Supabase Dashboard → SQL Editor):
--   1. Jalankan file ini (drop semua tabel & fungsi).
--   2. Lalu jalankan schema.sql (buat ulang + seed dengan fix).
--
-- ⚠️ PERINGATAN: semua riwayat sensor_readings, pending_commands,
--    system_config, dan devices AKAN TERHAPUS. Pastikan data lama
--    tidak dibutuhkan lagi (ESP32 akan mengisi ulang setiap 5 dtk).
-- ============================================================

DROP TRIGGER IF EXISTS trg_touch_device_last_seen ON sensor_readings;
DROP TRIGGER IF EXISTS trigger_system_config_updated_at ON system_config;

DROP FUNCTION IF EXISTS public.touch_device_last_seen() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS public.execute_command(BIGINT) CASCADE;
DROP FUNCTION IF EXISTS public.get_latest_readings() CASCADE;
DROP FUNCTION IF EXISTS public.heartbeat(TEXT) CASCADE;

DROP TABLE IF EXISTS public.sensor_readings CASCADE;
DROP TABLE IF EXISTS public.pending_commands CASCADE;
DROP TABLE IF EXISTS public.system_config CASCADE;
DROP TABLE IF EXISTS public.devices CASCADE;
