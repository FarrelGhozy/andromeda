-- ============================================================
-- ANDROMEDA — Database Schema for Supabase
-- Irigasi Tetes Otomatis Berbasis IoT (Android + ESP32)
--
-- ARSITEKTUR FINAL (keputusan project, issue #21):
--   1 lahan, 6 petak, dikelola 1 ESP32 (esp32-01).
--   BUKAN 2 lahan 12 petak. Jangan menambah petak-07..12.
--
-- CARA PAKAI:
--   A. Project BARU (disarankan):
--      Jalankan seluruh file ini di Supabase Dashboard → SQL Editor.
--      Sudah idempoten → aman dijalankan ulang.
--   B. Project SUDAH ADA:
--      JANGAN jalankan file ini (tabel sudah ada). Gunakan file
--      migration di folder yang sama (lihat database/migration_*.sql).
--
-- STATUS COMMAND (pending_commands.status, issue #18/#20):
--   'pending'   → belum dieksekusi ESP32
--   'executed'  → sudah dieksekusi ESP32 (execute_command)
--   'expired'   → basi, tidak dieksekusi (app/trigger menandai)
--   'cancelled' → dibatalkan user (app)
--
-- RENTANG ADC SENSOR (issue #17):
--   Valid 100–4000 (firmware: 2700 = kering 0%, 1500 = basah 100%).
--   Di luar rentang = sensor putus/kabel lepas → app tampil
--   "SENSOR ERROR" (bukan "100% BASAH" palsu).
-- ============================================================

-- ============================================================
-- 1. TABEL: devices / petak
-- ============================================================
CREATE TABLE IF NOT EXISTS devices (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE,          -- 'petak-01' .. 'petak-06'
  esp32_id TEXT NOT NULL DEFAULT '',       -- 'esp32-01'
  name TEXT NOT NULL,                      -- 'Petak 1'
  location TEXT,                           -- 'Lahan A'
  sensor_index INTEGER NOT NULL DEFAULT 0, -- urutan sensor di ESP32
  status TEXT NOT NULL DEFAULT 'active',   -- 'active' | 'inactive'
  last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- di-update heartbeat/trigger
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devices_esp32 ON devices(esp32_id);

-- ============================================================
-- 2. TABEL: log data sensor dari ESP32
-- ============================================================
CREATE TABLE IF NOT EXISTS sensor_readings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(device_id),
  moisture INTEGER NOT NULL,               -- ADC mentah (valid 100-4000)
  moisture_percent REAL NOT NULL,          -- 0-100
  valve_status TEXT NOT NULL DEFAULT 'OFF',-- 'ON' | 'OFF'
  battery_voltage REAL,                    -- opsional
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. TABEL: antrian perintah dari Android → ESP32
-- ============================================================
CREATE TABLE IF NOT EXISTS pending_commands (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(device_id),
  command TEXT NOT NULL,                   -- 'VALVE_ON' | 'VALVE_OFF'
  duration INTEGER DEFAULT 30,             -- detik valve terbuka
  status TEXT NOT NULL DEFAULT 'pending',  -- lihat STATUS COMMAND di atas
  source TEXT NOT NULL DEFAULT 'android',  -- 'android' | 'android_auto' | 'system'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  executed_at TIMESTAMPTZ
);

-- ============================================================
-- 4. TABEL: konfigurasi sistem per device
-- ============================================================
CREATE TABLE IF NOT EXISTS system_config (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE REFERENCES devices(device_id),
  mode TEXT NOT NULL DEFAULT 'auto',       -- 'auto' | 'manual'
  threshold_dry INTEGER NOT NULL DEFAULT 30,  -- % tanah dianggap kering
  threshold_wet INTEGER NOT NULL DEFAULT 70,  -- % tanah dianggap basah
  valve_duration INTEGER NOT NULL DEFAULT 30, -- detik default buka valve
  read_interval INTEGER NOT NULL DEFAULT 1800,-- detik antar pembacaan
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT
);

-- ============================================================
-- 5. TRIGGER: auto-update updated_at (system_config)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_system_config_updated_at ON system_config;
CREATE TRIGGER trigger_system_config_updated_at
  BEFORE UPDATE ON system_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 6. INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_sensor_readings_device_created_at
  ON sensor_readings(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pending_commands_status
  ON pending_commands(status);
CREATE INDEX IF NOT EXISTS idx_pending_commands_device_status
  ON pending_commands(device_id, status);

-- ============================================================
-- 7. SEED: 6 petak (1 ESP32 = esp32-01) + config default
--    Idempoten: ON CONFLICT → tidak dobel saat dijalankan ulang.
--    STATUS: hanya petak dengan sensor fisik terpasang yang
--    'active'. Petak-03..06 'inactive' (belum ada hardware) →
--    tidak tampil di app & tidak disentuh heartbeat(). Ubah ke
--    'active' setelah sensor dipasang.
-- ============================================================
INSERT INTO devices (device_id, esp32_id, name, location, sensor_index, status) VALUES
  ('petak-01', 'esp32-01', 'Petak 1', 'Lahan A', 0, 'active'),
  ('petak-02', 'esp32-01', 'Petak 2', 'Lahan A', 1, 'active'),
  ('petak-03', 'esp32-01', 'Petak 3', 'Lahan A', 2, 'inactive'),
  ('petak-04', 'esp32-01', 'Petak 4', 'Lahan A', 3, 'inactive'),
  ('petak-05', 'esp32-01', 'Petak 5', 'Lahan A', 4, 'inactive'),
  ('petak-06', 'esp32-01', 'Petak 6', 'Lahan A', 5, 'inactive')
ON CONFLICT (device_id) DO NOTHING;

INSERT INTO system_config (device_id, mode, threshold_dry, threshold_wet, valve_duration, read_interval)
SELECT device_id, 'auto', 30, 70, 30, 1800
FROM devices
ON CONFLICT (device_id) DO NOTHING;

-- ============================================================
-- 8. RLS: akses publik anon (app pakai anon key, tanpa login)
--    Idempoten: DROP POLICY IF EXISTS + CREATE.
-- ============================================================
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_devices" ON devices;
CREATE POLICY "public_devices" ON devices FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "public_sensor_readings" ON sensor_readings;
CREATE POLICY "public_sensor_readings" ON sensor_readings FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "public_pending_commands" ON pending_commands;
CREATE POLICY "public_pending_commands" ON pending_commands FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "public_system_config" ON system_config;
CREATE POLICY "public_system_config" ON system_config FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- 9. REALTIME PUBLICATION (wajib: app stream devices/readings/config/commands)
--    Idempoten: hanya menambah tabel yang belum ter-publish.
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['devices','sensor_readings','system_config','pending_commands']
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE %I', t);
    END IF;
  END LOOP;
END
$$;

-- ============================================================
-- 10. FUNGSI: execute_command — dipanggil ESP32 setelah eksekusi
-- ============================================================
CREATE OR REPLACE FUNCTION execute_command(cmd_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE pending_commands
  SET status = 'executed', executed_at = NOW()
  WHERE id = cmd_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 11. FUNGSI: get_latest_readings — reading terbaru tiap device
--     (dipakai app untuk ekspor CSV)
-- ============================================================
CREATE OR REPLACE FUNCTION get_latest_readings()
RETURNS TABLE (
  device_id TEXT,
  moisture INTEGER,
  moisture_percent REAL,
  valve_status TEXT,
  created_at TIMESTAMPTZ
) LANGUAGE sql AS $$
  SELECT DISTINCT ON (sr.device_id)
    sr.device_id,
    sr.moisture,
    sr.moisture_percent,
    sr.valve_status,
    sr.created_at
  FROM sensor_readings sr
  ORDER BY sr.device_id, sr.created_at DESC;
$$;

-- ============================================================
-- 12. HEARTBEAT: ESP32 meng-update last_seen semua petaknya
--     Dipanggil firmware berkala → status online akurat (3 mnt).
--     Hanya petak status='active' yang disentuh — petak tanpa
--     sensor (inactive) tidak boleh tampak "Online" di app.
-- ============================================================
CREATE OR REPLACE FUNCTION heartbeat(_esp32_id TEXT)
RETURNS VOID LANGUAGE sql AS $$
  UPDATE devices
  SET last_seen = NOW()
  WHERE esp32_id = _esp32_id
    AND status = 'active';
$$;

-- ============================================================
-- 13. TRIGGER PENGAMAN (issue #22): setiap reading baru menyentuh
--     last_seen device-nya — untuk firmware lama yang belum kirim
--     heartbeat.
-- ============================================================
CREATE OR REPLACE FUNCTION touch_device_last_seen()
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
FOR EACH ROW EXECUTE FUNCTION touch_device_last_seen();
