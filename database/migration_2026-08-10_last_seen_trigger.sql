-- ============================================================
-- MIGRASI (issue #22): perbarui devices.last_seen otomatis
-- Jalankan di Supabase Dashboard → SQL Editor.
-- Idempoten (CREATE OR REPLACE).
-- Mekanisme: 1) heartbeat() dari firmware (sudah ada), dan
--            2) trigger saat sensor_readings masuk (pengaman untuk
--               firmware lama / ESP32 yang belum kirim heartbeat).
-- ============================================================

-- 2) Trigger: setiap reading baru → sentuh last_seen device-nya.
CREATE OR REPLACE FUNCTION public.touch_device_last_seen()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE devices SET last_seen = NOW()
  WHERE device_id = NEW.device_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_touch_device_last_seen ON sensor_readings;
CREATE TRIGGER trg_touch_device_last_seen
AFTER INSERT ON sensor_readings
FOR EACH ROW EXECUTE FUNCTION public.touch_device_last_seen();

-- Verifikasi: trigger terdaftar
SELECT tgname, tgrelid::regclass, tgenabled
FROM pg_trigger
WHERE tgname = 'trg_touch_device_last_seen';
