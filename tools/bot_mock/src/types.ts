// ============================================================
// ANDROMEDA bot_mock — Konstanta hardware & tipe bersama
// Disinkronkan dengan hardware/firmware dan database/schema.sql
// ============================================================

export const ESP32_ID = "esp32-01";

export const PETAK_IDS = [
  "petak-01",
  "petak-02",
  "petak-03",
  "petak-04",
  "petak-05",
  "petak-06",
] as const;

export type PetakId = (typeof PETAK_IDS)[number];

// Kalibrasi ADC Capacitive Soil Sensor v1.2 (hardware/firmware/src/sensor.cpp)
export const WET_REF = 1500;
export const DRY_REF = 2700;
export const MIN_VALID_RAW = 100; // database/schema.sql & sensor_reading.dart
export const MAX_VALID_RAW = 4000;

// Safety & timing default (selaras hardware/firmware/include/config.h)
export const VALVE_MIN_SEC = 1;
export const VALVE_MAX_SEC = 120; // VALVE_MAX_DURATION_MS = 120000
export const DEFAULT_SENSOR_INTERVAL_SEC = 1800; // 30 menit
export const MIN_SENSOR_INTERVAL_SEC = 60;
export const DEFAULT_CMD_POLL_SEC = 5;
export const HEARTBEAT_EVERY_MS = 60_000;
export const CONFIG_SYNC_EVERY_MS = 120_000;
export const VALVE_CHANGE_DEBOUNCE_MS = 2_000;

// Koordinat default wilayah tropis Indonesia (WIB); dapat di-override via .env / CLI
export const DEFAULT_LAT = -7.7956;
export const DEFAULT_LON = 110.3695;

export type WeatherMode = "auto" | "open-meteo" | "synthetic";
export type WeatherRegime =
  | "cerah_panas"
  | "cerah_berawan"
  | "berawan_lembab"
  | "hujan_sore_tropis"
  | "hujan_deras";

export interface SystemConfig {
  mode: "auto" | "manual";
  thresholdDry: number;
  thresholdWet: number;
  valveDurationSec: number;
  readIntervalSec: number;
  valid: boolean;
}

export const DEFAULT_SYSTEM_CONFIG: SystemConfig = {
  mode: "auto",
  thresholdDry: 30,
  thresholdWet: 70,
  valveDurationSec: 30,
  readIntervalSec: DEFAULT_SENSOR_INTERVAL_SEC,
  valid: false,
};

export interface PendingCommand {
  id: number;
  deviceId: PetakId;
  command: string;
  duration: number;
  createdAtMs: number;
  valid: boolean;
}

export interface ReadingRow {
  device_id: PetakId;
  moisture: number;
  moisture_percent: number;
  valve_status: "ON" | "OFF";
  battery_voltage: number;
  created_at?: string;
}

export interface LatestReading {
  deviceId: PetakId;
  moisture: number;
  moisturePercent: number;
  valveStatus: "ON" | "OFF";
  createdAtMs: number;
}

export interface WeatherSample {
  tempC: number;
  rhPct: number;
  cloudPct: number;
  solarWm2: number;
  rainMmHr: number;
  windKmh: number;
  et0MmHr?: number;
  source: "open-meteo" | "synthetic";
  regime?: WeatherRegime;
}

export interface ValveState {
  open: boolean;
  openedAtMs: number;
  durationSec: number; // 0 = indefinite (manual VALVE_ON duration 0)
  source: "auto" | "manual" | "none";
}

export interface PetakAgronomy {
  cropName: string;
  soilType: string;
  initialPctRange: [number, number];
  fieldCapacity: number; // % batas kapasitas lapang (di atas ini drainase gravitasi)
  wiltingPoint: number; // % titik layu (evaporasi melambat asimtotis)
  cropKc: number; // koefisien tanaman ETc
  mulchFactor: number; // 0.55-1.0 (mulsa plastik menahan evaporasi tanah)
  rainCapture: number; // fraksi hujan yang masuk ke sekitar probe
  drainageRatePerHr: number; // laju drainase gravitasi per jam di atas kapasitas lapang
  emitterPctPer30s: number; // tambahan kelembaban efektif untuk 30 detik tetes drip
  infiltrationTauMin: number; // konstanta waktu resapan lapisan atas → zona akar (menit)
  morningShade: number; // 0 = matahari penuh pagi, 0.4 = agak teduh pagi
  afternoonShade: number; // 0 = matahari penuh siang-sore, 0.35 = teduh sore
  sensorTempDriftPerC: number; // drift dielektrik sensor kapasitif (%/°C terhadap 25°C)
  adcNoiseRaw: number; // std dev noise ADC 12-bit
  adcBiasRaw: number; // offset kalibrasi kecil per probe
  faultCandidate: boolean; // hanya petak-06 (kabel terpanjang)
}

export interface PetakSimState {
  rootPct: number; // kelembaban aktual zona akar (0-100%)
  wettingBuffer: number; // air di lapisan permukaan yang sedang meresap ke probe (%)
  microDrift: number; // faktor AR(1) harian unik per petak (±15% di sekitar 1.0)
  valve: ValveState;
}

export interface BatteryState {
  soc: number; // State of Charge aki 12V 100Ah (0.45..1.0)
}

export interface CliOpts {
  mode: "live" | "backfill" | "cleanup";
  days: number;
  intervalSec: number;
  intervalPinned: boolean;
  cmdPollSec: number;
  weatherMode: WeatherMode;
  lat: number;
  lon: number;
  seed?: number;
  hydrate: boolean;
  faults: boolean;
  dryRun: boolean;
  only: PetakId[];
  once: boolean;
  yes: boolean;
}

export interface Rng {
  next(): number; // [0, 1)
  range(min: number, max: number): number;
  gauss(): number; // N(0, 1)
}

// ---------- Util murni ----------

export function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

export function rawToPercent(raw: number): number {
  const p = 100 - ((raw - WET_REF) / (DRY_REF - WET_REF)) * 100;
  return clamp(p, 0, 100);
}

export function percentToRaw(pct: number): number {
  return Math.round(DRY_REF - (clamp(pct, 0, 100) / 100) * (DRY_REF - WET_REF));
}

export function isValidRaw(raw: number): boolean {
  return raw >= MIN_VALID_RAW && raw <= MAX_VALID_RAW;
}

export function createRng(seed?: number): Rng {
  let state = (seed ?? ((Date.now() ^ (Math.random() * 0xffffffff)) >>> 0)) >>> 0;
  if (state === 0) state = 0x9e3779b9;

  // Mulberry32: cepat, distribusi baik, deterministik bila seed diberikan.
  const next = (): number => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };

  const range = (min: number, max: number): number => min + next() * (max - min);

  const gauss = (): number => {
    let u = 0;
    let v = 0;
    while (u === 0) u = next();
    while (v === 0) v = next();
    return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
  };

  return { next, range, gauss };
}

export function log(msg: string): void {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}
