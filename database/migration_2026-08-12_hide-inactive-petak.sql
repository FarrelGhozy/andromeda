-- ============================================================
-- MIGRASI: sembunyikan petak tanpa sensor (issue: app vs Supabase)
-- Masalah:
--   - Firmware hanya punya 2 sensor fisik (pin 32 & 33), tapi
--     devices men-seed 6 petak semua 'active'.
--   - heartbeat() meng-update last_seen SEMUA petak esp32-01 →
--     petak-03..06 tampak "Online" di app padahal tidak ada data.
-- Perbaikan:
--   1. petak-03..06 → status='inactive' (belum ada hardware).
--   2. heartbeat() hanya menyentuh petak yang status='active'.
-- Jalankan di Supabase Dashboard → SQL Editor. Idempoten.
-- ============================================================

-- 1) Nonaktifkan petak yang belum punya sensor fisik.
UPDATE devices
SET status = 'inactive'
WHERE device_id IN ('petak-03', 'petak-04', 'petak-05', 'petak-06')
  AND status = 'active';

-- 2) Heartbeat hanya untuk petak aktif (punya sensor).
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
