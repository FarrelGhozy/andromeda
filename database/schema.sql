-- ANDROMEDA - Database Schema for Supabase
-- Android Routine Monitoring Electronic Drip Automation
-- Multi-device MVP (no auth) - 6 petak

-- 1. Devices / Petak
CREATE TABLE devices (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  location TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Log data sensor dari ESP32
CREATE TABLE sensor_readings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(device_id),
  moisture INTEGER NOT NULL,
  moisture_percent REAL NOT NULL,
  valve_status TEXT NOT NULL DEFAULT 'OFF',
  battery_voltage REAL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Antrian perintah dari Android
CREATE TABLE pending_commands (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(device_id),
  command TEXT NOT NULL,
  duration INTEGER DEFAULT 30,
  status TEXT NOT NULL DEFAULT 'pending',
  source TEXT NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  executed_at TIMESTAMPTZ
);

-- 4. Konfigurasi sistem per device
CREATE TABLE system_config (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE REFERENCES devices(device_id),
  mode TEXT NOT NULL DEFAULT 'auto',
  threshold_dry INTEGER NOT NULL DEFAULT 30,
  threshold_wet INTEGER NOT NULL DEFAULT 70,
  valve_duration INTEGER NOT NULL DEFAULT 30,
  read_interval INTEGER NOT NULL DEFAULT 1800,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT
);

-- 5. Trigger updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_system_config_updated_at
  BEFORE UPDATE ON system_config
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6. Indexes
CREATE INDEX idx_sensor_readings_device_created_at ON sensor_readings(device_id, created_at DESC);
CREATE INDEX idx_pending_commands_status ON pending_commands(status);
CREATE INDEX idx_pending_commands_device_status ON pending_commands(device_id, status);

-- 7. Seed devices (6 petak)
INSERT INTO devices (device_id, name, location) VALUES
  ('petak-01', 'Petak 1', 'Lahan A'),
  ('petak-02', 'Petak 2', 'Lahan A'),
  ('petak-03', 'Petak 3', 'Lahan A'),
  ('petak-04', 'Petak 4', 'Lahan B'),
  ('petak-05', 'Petak 5', 'Lahan B'),
  ('petak-06', 'Petak 6', 'Lahan B');

-- 8. Seed default config
INSERT INTO system_config (device_id, mode, threshold_dry, threshold_wet, valve_duration, read_interval)
SELECT device_id, 'auto', 30, 70, 30, 1800
FROM devices
ON CONFLICT (device_id) DO NOTHING;

-- 9. RLS: no auth → public access for anon
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_devices" ON devices FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "public_sensor_readings" ON sensor_readings FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "public_pending_commands" ON pending_commands FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "public_system_config" ON system_config FOR ALL TO anon USING (true) WITH CHECK (true);

-- 10. Realtime publication
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END
$$;

ALTER PUBLICATION supabase_realtime ADD TABLE sensor_readings;
ALTER PUBLICATION supabase_realtime ADD TABLE system_config;
ALTER PUBLICATION supabase_realtime ADD TABLE pending_commands;

-- 11. Function: mark command as executed
CREATE OR REPLACE FUNCTION execute_command(cmd_id BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE pending_commands
  SET status = 'executed', executed_at = NOW()
  WHERE id = cmd_id;
END;
$$ LANGUAGE plpgsql;
