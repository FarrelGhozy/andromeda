-- ============================================================
-- MIGRASI: Sinkronkan database live dengan schema.sql (issue #15)
-- REVISI: arsitektur final = 1 LAHAN, 6 PETA K (issue #21)
-- Jalankan di Supabase Dashboard → SQL Editor, URUT dari atas.
-- Semua statement idempoten (aman dijalankan ulang).
-- ⚠️ JANGAN jalankan versi lama file ini (menambah petak-07..12
--    Lahan B / esp32-02) — keputusan user: 1 lahan 6 petak saja.
-- ============================================================

-- 1) Aktifkan realtime untuk tabel devices (issue #3)
--    App membaca stream devices; tanpa publikasi, Home tidak pernah
--    menerima data realtime.
ALTER PUBLICATION supabase_realtime ADD TABLE devices;

-- 2) Seed 6 petak (semua esp32_id = 'esp32-01' → 1 ESP32 mengelola
--    6 petak). Idempoten: hanya mengisi yang belum ada.
INSERT INTO devices (device_id, esp32_id, name, location, sensor_index, status)
SELECT * FROM (VALUES
  ('petak-01', 'esp32-01', 'Petak 1',  'Lahan A', 0, 'active'),
  ('petak-02', 'esp32-01', 'Petak 2',  'Lahan A', 1, 'active'),
  ('petak-03', 'esp32-01', 'Petak 3',  'Lahan A', 2, 'active'),
  ('petak-04', 'esp32-01', 'Petak 4',  'Lahan A', 3, 'active'),
  ('petak-05', 'esp32-01', 'Petak 5',  'Lahan A', 4, 'active'),
  ('petak-06', 'esp32-01', 'Petak 6',  'Lahan A', 5, 'active')
) AS v(device_id, esp32_id, name, location, sensor_index, status)
WHERE NOT EXISTS (SELECT 1 FROM devices d WHERE d.device_id = v.device_id);

-- 3) Perbaiki esp32_id yang salah (bila pernah ter-seed esp32-02 dst.)
UPDATE devices SET esp32_id = 'esp32-01'
WHERE device_id LIKE 'petak-%' AND esp32_id IS DISTINCT FROM 'esp32-01';

-- 4) Config default untuk petak yang belum punya
INSERT INTO system_config (device_id, mode, threshold_dry, threshold_wet, valve_duration, read_interval, updated_by)
SELECT v.device_id, 'auto', 30, 70, 30, 1800, 'system'
FROM (VALUES
  ('petak-01'), ('petak-02'), ('petak-03'),
  ('petak-04'), ('petak-05'), ('petak-06')
) AS v(device_id)
WHERE NOT EXISTS (SELECT 1 FROM system_config c WHERE c.device_id = v.device_id);

-- 5) Verifikasi hasil
SELECT d.device_id, d.esp32_id, d.name, d.location,
       (SELECT count(*) FROM sensor_readings r WHERE r.device_id = d.device_id) AS total_reading
FROM devices d
ORDER BY d.id;
