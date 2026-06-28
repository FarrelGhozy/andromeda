-- ANDROMEDA - Database Schema for Supabase
-- Android Routine Monitoring Electronic Drip Automation
-- PDB Desa Merayan

-- 1. Log data sensor dari ESP32
CREATE TABLE sensor_readings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  moisture INTEGER NOT NULL,
  moisture_percent REAL NOT NULL,
  valve_status TEXT NOT NULL DEFAULT 'OFF',
  device_id TEXT NOT NULL DEFAULT 'andromeda-01',
  battery_voltage REAL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Antrian perintah dari Android
CREATE TABLE pending_commands (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  command TEXT NOT NULL,
  duration INTEGER DEFAULT 30,
  status TEXT NOT NULL DEFAULT 'pending',
  source TEXT NOT NULL DEFAULT 'android',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  executed_at TIMESTAMPTZ
);

-- 3. Konfigurasi sistem
CREATE TABLE system_config (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  mode TEXT NOT NULL DEFAULT 'auto',
  threshold_dry INTEGER NOT NULL DEFAULT 70,
  threshold_wet INTEGER NOT NULL DEFAULT 85,
  valve_duration INTEGER NOT NULL DEFAULT 30,
  read_interval INTEGER NOT NULL DEFAULT 1800,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT
);

-- 4. Trigger updated_at
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

-- Indexes
CREATE INDEX idx_sensor_readings_created_at ON sensor_readings(created_at DESC);
CREATE INDEX idx_pending_commands_status ON pending_commands(status);
