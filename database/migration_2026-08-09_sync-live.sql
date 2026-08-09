-- ============================================================
-- MIGRASI: Sinkronkan database live dengan schema.sql (issue #15)
-- Jalankan di Supabase Dashboard → SQL Editor, URUT dari atas.
-- Semua statement idempoten (aman dijalankan ulang).
-- ============================================================

-- 1) Aktifkan realtime untuk tabel devices (issue #3)
--    App membaca stream devices; tanpa publikasi, Home tidak pernah
--    menerima data realtime.
ALTER PUBLICATION supabase_realtime ADD TABLE devices;

-- 2) Tambahkan 6 petak baru (esp32-02) agar sesuai blueprint 6 petak
--    per lahan (12 petak total). Live DB baru punya 6 petak (esp32-01).
INSERT INTO devices (device_id, esp32_id, name, location, sensor_index, status)
SELECT * FROM (VALUES
  ('petak-07', 'esp32-02', 'Petak 7',  'Lahan B', 1, 'active'),
  ('petak-08', 'esp32-02', 'Petak 8',  'Lahan B', 2, 'active'),
  ('petak-09', 'esp32-02', 'Petak 9',  'Lahan B', 3, 'active'),
  ('petak-10', 'esp32-02', 'Petak 10', 'Lahan B', 4, 'active'),
  ('petak-11', 'esp32-02', 'Petak 11', 'Lahan B', 5, 'active'),
  ('petak-12', 'esp32-02', 'Petak 12', 'Lahan B', 6, 'active')
) AS v(device_id, esp32_id, name, location, sensor_index, status)
WHERE NOT EXISTS (SELECT 1 FROM devices d WHERE d.device_id = v.device_id);

-- 3) Config default untuk petak baru
INSERT INTO system_config (device_id, mode, threshold_dry, threshold_wet, valve_duration, read_interval, updated_by)
SELECT v.device_id, 'auto', 30, 70, 30, 1800, 'system'
FROM (VALUES
  ('petak-07'), ('petak-08'), ('petak-09'),
  ('petak-10'), ('petak-11'), ('petak-12')
) AS v(device_id)
WHERE NOT EXISTS (SELECT 1 FROM system_config c WHERE c.device_id = v.device_id);

-- 4) Verifikasi hasil
SELECT d.device_id, d.esp32_id, d.name, d.location,
       (SELECT count(*) FROM sensor_readings r WHERE r.device_id = d.device_id) AS total_reading
FROM devices d
ORDER BY d.id;
