-- ============================================================
-- MIGRASI: aktifkan kembali 6 petak (keputusan user terbaru)
-- Sebelumnya petak-03..06 dibuat 'inactive' karena belum ada
-- data sensor. Sekarang user ingin SEMUA 6 petak aktif, terekam
-- ESP32, dan tampil di app — apk & firmware harus sinkron.
-- Jalankan di Supabase Dashboard → SQL Editor. Idempoten.
-- ============================================================

-- 1) Aktifkan semua petak (6 sensor dikelola esp32-01).
UPDATE devices
SET status = 'active'
WHERE device_id IN ('petak-01', 'petak-02', 'petak-03', 'petak-04', 'petak-05', 'petak-06')
  AND status = 'inactive';

-- 2) Heartbeat menyentuh semua petak aktif (benar: ESP32 mengelola 6).
CREATE OR REPLACE FUNCTION public.heartbeat(_esp32_id TEXT)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE devices
  SET last_seen = NOW()
  WHERE esp32_id = _esp32_id
    AND status = 'active';
$$;

-- 3) Verifikasi hasil
SELECT device_id, status, last_seen
FROM devices
ORDER BY id;
