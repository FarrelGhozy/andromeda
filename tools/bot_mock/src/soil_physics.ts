// ============================================================
// ANDROMEDA bot_mock — Fisika Tanah (Water Balance) & Sensor
// ------------------------------------------------------------
// Menggantikan mean-reversion + kosinus template dengan model
// neraca air zona akar yang dipengaruhi:
//   - jam lokal, suhu udara (T), kelembaban udara (RH) → VPD
//   - radiasi surya + profil naungan unik tiap petak
//   - kecepatan angin + koefisien tanaman (Kc) + mulsa
//   - curah hujan + intersepsi kanopi + resapan bertahap (wetting buffer)
//   - penyiraman drip aktual (valve ON per detik) + drainase gravitasi
//   - karakteristik fisik Capacitive Soil Sensor v1.2 (drift termal + ADC noise)
//   - tegangan aki 12V + solar 300Wp + voltage sag saat solenoid ON
// ============================================================

import {
  clamp,
  MAX_VALID_RAW,
  MIN_VALID_RAW,
  percentToRaw,
  rawToPercent,
  VALVE_MAX_SEC,
  VALVE_MIN_SEC,
  type BatteryState,
  type PetakAgronomy,
  type PetakId,
  type PetakSimState,
  type Rng,
  type WeatherSample,
} from "./types";

// 6 profil agronomi realistis untuk 6 petak Lahan A (esp32-01)
export const PETAK_AGRONOMY: Record<PetakId, PetakAgronomy> = {
  "petak-01": {
    cropName: "Cabai Merah",
    soilType: "Lempung berpasir + mulsa",
    initialPctRange: [48, 64],
    fieldCapacity: 74,
    wiltingPoint: 15,
    cropKc: 0.96,
    mulchFactor: 0.72,
    rainCapture: 0.58,
    drainageRatePerHr: 0.28,
    emitterPctPer30s: 17.5,
    infiltrationTauMin: 18,
    morningShade: 0.05,
    afternoonShade: 0.05,
    sensorTempDriftPerC: 0.07,
    adcNoiseRaw: 7,
    adcBiasRaw: -6,
    faultCandidate: false,
  },
  "petak-02": {
    cropName: "Tomat",
    soilType: "Tanah berpasir / bedengan tinggi",
    initialPctRange: [29, 44],
    fieldCapacity: 68,
    wiltingPoint: 13,
    cropKc: 1.18,
    mulchFactor: 0.96,
    rainCapture: 0.88,
    drainageRatePerHr: 0.44,
    emitterPctPer30s: 21.0,
    infiltrationTauMin: 12,
    morningShade: 0.0,
    afternoonShade: 0.0,
    sensorTempDriftPerC: 0.09,
    adcNoiseRaw: 9,
    adcBiasRaw: 11,
    faultCandidate: false,
  },
  "petak-03": {
    cropName: "Sawi / Sayur Daun",
    soilType: "Lempung subur + naungan pagi",
    initialPctRange: [62, 78],
    fieldCapacity: 82,
    wiltingPoint: 18,
    cropKc: 0.82,
    mulchFactor: 0.78,
    rainCapture: 0.72,
    drainageRatePerHr: 0.19,
    emitterPctPer30s: 16.0,
    infiltrationTauMin: 26,
    morningShade: 0.36,
    afternoonShade: 0.14,
    sensorTempDriftPerC: -0.05,
    adcNoiseRaw: 6,
    adcBiasRaw: -9,
    faultCandidate: false,
  },
  "petak-04": {
    cropName: "Terong",
    soilType: "Liat berpasir tepi lahan",
    initialPctRange: [40, 58],
    fieldCapacity: 76,
    wiltingPoint: 16,
    cropKc: 1.08,
    mulchFactor: 0.92,
    rainCapture: 0.94,
    drainageRatePerHr: 0.25,
    emitterPctPer30s: 17.0,
    infiltrationTauMin: 21,
    morningShade: 0.08,
    afternoonShade: 0.0,
    sensorTempDriftPerC: 0.12,
    adcNoiseRaw: 10,
    adcBiasRaw: 14,
    faultCandidate: false,
  },
  "petak-05": {
    cropName: "Bawang Merah",
    soilType: "Lempung gembur datar",
    initialPctRange: [42, 56],
    fieldCapacity: 75,
    wiltingPoint: 15,
    cropKc: 0.92,
    mulchFactor: 0.86,
    rainCapture: 0.84,
    drainageRatePerHr: 0.24,
    emitterPctPer30s: 18.5,
    infiltrationTauMin: 17,
    morningShade: 0.1,
    afternoonShade: 0.12,
    sensorTempDriftPerC: -0.06,
    adcNoiseRaw: 7,
    adcBiasRaw: 3,
    faultCandidate: false,
  },
  "petak-06": {
    cropName: "Kacang Panjang",
    soilType: "Lempung liat ujung saluran",
    initialPctRange: [50, 68],
    fieldCapacity: 80,
    wiltingPoint: 17,
    cropKc: 0.88,
    mulchFactor: 0.82,
    rainCapture: 0.78,
    drainageRatePerHr: 0.16,
    emitterPctPer30s: 14.5, // tekanan air ujung pipa lebih rendah ~85%
    infiltrationTauMin: 30,
    morningShade: 0.12,
    afternoonShade: 0.26,
    sensorTempDriftPerC: 0.08,
    adcNoiseRaw: 12, // kabel sensor paling panjang
    adcBiasRaw: -13,
    faultCandidate: true,
  },
};

export function createInitialPetakStates(
  petaks: readonly PetakId[],
  rng: Rng,
): Record<PetakId, PetakSimState> {
  const out = {} as Record<PetakId, PetakSimState>;
  for (const id of petaks) {
    const [lo, hi] = PETAK_AGRONOMY[id].initialPctRange;
    out[id] = {
      rootPct: clamp(rng.range(lo, hi), 10, 90),
      wettingBuffer: 0,
      microDrift: clamp(1.0 + rng.gauss() * 0.07, 0.82, 1.18),
      valve: { open: false, openedAtMs: 0, durationSec: 0, source: "none" },
    };
  }
  return out;
}

export function createInitialBattery(at: Date): BatteryState {
  const h = at.getHours() + at.getMinutes() / 60;
  // Estimasi SoC wajar sesuai jam mulai (paling rendah menjelang fajar, penuh sore)
  const soc =
    h >= 6 && h <= 16
      ? clamp(0.68 + ((h - 6) / 10) * 0.27, 0.65, 0.96)
      : h > 16
        ? clamp(0.95 - ((h - 16) / 14) * 0.24, 0.68, 0.96)
        : clamp(0.78 - (h / 6) * 0.12, 0.62, 0.82);
  return { soc };
}

export function openValveState(
  st: PetakSimState,
  durationSec: number,
  nowMs: number,
  source: "auto" | "manual",
): void {
  const d =
    durationSec === 0 && source === "manual"
      ? 0
      : clamp(Math.round(durationSec), VALVE_MIN_SEC, VALVE_MAX_SEC);
  st.valve = { open: true, openedAtMs: nowMs, durationSec: d, source };
}

export function closeValveState(st: PetakSimState): void {
  st.valve = { open: false, openedAtMs: 0, durationSec: 0, source: "none" };
}

export function checkValveAutoClose(st: PetakSimState, nowMs: number): boolean {
  if (!st.valve.open || st.valve.durationSec <= 0) return false;
  if (nowMs - st.valve.openedAtMs >= st.valve.durationSec * 1000) {
    closeValveState(st);
    return true;
  }
  return false;
}

function vaporPressureDeficitKpa(tempC: number, rhPct: number): number {
  const es = 0.6108 * Math.exp((17.27 * tempC) / (tempC + 237.3));
  return Math.max(0.05, es * (1 - clamp(rhPct, 10, 100) / 100));
}

/**
 * Memajukan neraca air tanah untuk satu petak selama `dtSec` detik.
 * Tidak memodifikasi state valve (timer valve diatur terpisah).
 */
export function stepSoilPhysics(
  id: PetakId,
  st: PetakSimState,
  weather: WeatherSample,
  at: Date,
  dtSec: number,
  rng: Rng,
): void {
  if (dtSec <= 0) return;

  const agro = PETAK_AGRONOMY[id];
  const dtHr = dtSec / 3600;
  const dtMin = dtSec / 60;
  const hour = at.getHours() + at.getMinutes() / 60;

  // 1. Update mikro-drift biologis/lingkungan (Ornstein-Uhlenbeck, tau ≈ 18 jam)
  const decay = Math.exp(-dtHr / 18);
  const sigma = 0.065 * Math.sqrt(Math.max(0, 1 - decay * decay));
  st.microDrift = clamp(
    1.0 + (st.microDrift - 1.0) * decay + rng.gauss() * sigma,
    0.78,
    1.24,
  );

  // 2. Paparan surya lokal (mempertimbangkan naungan pagi/sore tiap petak)
  const shade =
    hour < 12 ? agro.morningShade : agro.afternoonShade;
  const localSolar = weather.solarWm2 * (1 - shade);

  // 3. Evapotranspirasi (ETc) berbasis VPD + radiasi + angin (+ ET0 Open-Meteo bila ada)
  const vpd = vaporPressureDeficitKpa(weather.tempC, weather.rhPct);
  const radComponent = (localSolar / 1000) * 1.95;
  const aeroComponent = vpd * (0.42 + 0.025 * weather.windKmh);
  let potEvapPctPerHr = radComponent + aeroComponent;

  if (weather.et0MmHr != null) {
    // 1 mm ET0 ≈ 3.6% kehilangan kelembaban zona akar dangkal (~30cm bedengan)
    const et0Scaled = weather.et0MmHr * 3.6;
    potEvapPctPerHr = potEvapPctPerHr * 0.45 + et0Scaled * 0.55;
  }

  // Kurangi penguapan saat sedang hujan aktif
  if (weather.rainMmHr > 0.3) {
    potEvapPctPerHr *= clamp(1 - weather.rainMmHr / 10, 0.12, 1);
  }

  // Faktor stres air Ks: tanah makin kering makin susah menguap (kurva asimtotis)
  const availFrac = clamp(
    (st.rootPct - agro.wiltingPoint) / (agro.fieldCapacity - agro.wiltingPoint),
    0,
    1.25,
  );
  const ks = Math.pow(clamp(availFrac, 0, 1.15), 0.72);

  // Malam hari: penguapan sangat kecil (stomata menutup, tanpa radiasi)
  const nightMultiplier = localSolar < 5 ? 0.38 : 1.0;
  const evapLoss =
    potEvapPctPerHr *
    agro.cropKc *
    agro.mulchFactor *
    ks *
    nightMultiplier *
    st.microDrift *
    dtHr;

  // 4. Embun & kenaikan kapiler mikro menjelang fajar (03:30..06:30, RH tinggi)
  // Sangat kecil (+0.15..0.40 %/jam), BUKAN gelombang kosinus palsu!
  let dawnDewGain = 0;
  if (
    weather.solarWm2 < 15 &&
    weather.rhPct >= 86 &&
    hour >= 3.2 &&
    hour <= 6.5 &&
    st.rootPct < agro.fieldCapacity
  ) {
    const rhExcess = (weather.rhPct - 85) / 15; // 0..1
    dawnDewGain = 0.28 * rhExcess * (0.5 + 0.5 * agro.mulchFactor) * dtHr;
  }

  // 5. Infiltrasi air dari irigasi tetes (valve ON)
  let directIrrigationGain = 0;
  if (st.valve.open) {
    const totalPulse = (agro.emitterPctPer30s / 30) * dtSec;
    // 55% langsung terdeteksi dekat probe (feedback responsif), 45% meresap bertahap
    directIrrigationGain = totalPulse * 0.55;
    st.wettingBuffer += totalPulse * 0.45;
  }

  // 6. Infiltrasi hujan (setelah intersepsi daun/kanopi 0.35 mm/jam)
  if (weather.rainMmHr > 0.35) {
    const effectiveRainMm = (weather.rainMmHr - 0.35) * dtHr;
    // 1 mm hujan efektif ≈ +1.45% kelembaban zona akar dangkal, dimodulasi mulsa/kanopi
    st.wettingBuffer += effectiveRainMm * agro.rainCapture * 1.45;
  }

  // 7. Perkolasi dari lapisan atas (wettingBuffer) → zona akar (rootPct)
  let percolationGain = 0;
  if (st.wettingBuffer > 0.001) {
    const frac = 1 - Math.exp(-dtMin / agro.infiltrationTauMin);
    percolationGain = st.wettingBuffer * frac;
    st.wettingBuffer = Math.max(0, st.wettingBuffer - percolationGain);
  }

  // Terapkan neraca air
  st.rootPct +=
    directIrrigationGain + percolationGain + dawnDewGain - evapLoss;

  // 8. Drainase gravitasi eksponensial bila di atas kapasitas lapang
  if (st.rootPct > agro.fieldCapacity) {
    const excess = st.rootPct - agro.fieldCapacity;
    const drain = excess * (1 - Math.exp(-agro.drainageRatePerHr * dtHr));
    st.rootPct -= drain;
  }

  st.rootPct = clamp(st.rootPct, 5, 95);
  // Batasi buffer permukaan agar tidak menumpuk tak terbatas saat hujan ekstrem
  st.wettingBuffer = clamp(st.wettingBuffer, 0, 28);
}

export interface SimulatedSensorOutput {
  raw: number;
  pct: number;
  fault: boolean;
}

/**
 * Menghasilkan pembacaan ADC 12-bit + moisture_percent selayaknya
 * ESP32 analogRead() pada Capacitive Soil Moisture Sensor v1.2.
 */
export function readSimulatedSensor(
  id: PetakId,
  st: PetakSimState,
  weather: WeatherSample,
  allowFaults: boolean,
  rng: Rng,
): SimulatedSensorOutput {
  const agro = PETAK_AGRONOMY[id];

  // Fault langka khusus kandidat (petak-06) bila --faults aktif;
  // tidak merusak state kelembaban tanah internal.
  if (allowFaults && agro.faultCandidate && rng.next() < 0.015) {
    const raw = rng.next() < 0.55 ? 4095 : Math.round(rng.range(4, 28));
    return {
      raw,
      pct: Math.round(rawToPercent(raw) * 10) / 10,
      fault: true,
    };
  }

  // Drift dielektrik tipis akibat suhu lingkungan/tanah terhadap 25°C
  const thermalShiftPct = (weather.tempC - 25) * agro.sensorTempDriftPerC;
  const apparentPct = clamp(st.rootPct + thermalShiftPct, 0, 100);

  // Konversi ke ADC + offset kalibrasi probe + noise Gaussian 12-bit
  const idealRaw = percentToRaw(apparentPct);
  const noisyRaw = Math.round(
    idealRaw + agro.adcBiasRaw + rng.gauss() * agro.adcNoiseRaw,
  );
  const raw = clamp(noisyRaw, MIN_VALID_RAW, MAX_VALID_RAW);
  const pct = Math.round(rawToPercent(raw) * 10) / 10;

  return { raw, pct, fault: false };
}

/**
 * Model tegangan Aki 12V 100Ah + Solar Panel 300Wp + SCC 20A
 * + penurunan tegangan instan saat solenoid valve 12V terbuka.
 */
export function stepBatteryVoltage(
  battery: BatteryState,
  weather: WeatherSample,
  openValveCount: number,
  dtSec: number,
  rng: Rng,
): number {
  const dtHr = Math.max(0, dtSec) / 3600;

  // Pengisian surya proporsional terhadap radiasi (300Wp ≈ max ~15A di 12V)
  const chargeAmps =
    weather.solarWm2 > 35 ? (weather.solarWm2 / 950) * 13.5 : 0;
  // Beban konstan: router Huawei B535 (~0.45A) + ESP32/sensor (~0.12A) + valve (0.5A/valve)
  const loadAmps = 0.57 + openValveCount * 0.5;
  const netAmps = chargeAmps - loadAmps;

  // Kapasitas aki 100Ah
  battery.soc = clamp(battery.soc + (netAmps * dtHr) / 100, 0.45, 1.0);

  // Open-circuit voltage (OCV) aki lead-acid 12V
  const ocv = 11.85 + 0.9 * battery.soc;

  // Boost tegangan saat solar charger (SCC) sedang mengisi
  let chargeBoost = 0;
  if (weather.solarWm2 > 40) {
    const sunFactor = clamp((weather.solarWm2 - 40) / 550, 0, 1);
    // Bulk/absorption (~14.0V) saat SoC < 96%, float (~13.5V) saat penuh
    const targetChargeV = battery.soc < 0.96 ? 14.05 : 13.55;
    chargeBoost = Math.max(0, targetChargeV - ocv) * sunFactor;
  }

  // Voltage sag instan saat solenoid valve 12V menarik arus
  const valveSag = openValveCount * 0.18;

  const v = ocv + chargeBoost - valveSag + rng.gauss() * 0.02;
  return Math.round(clamp(v, 11.7, 14.3) * 100) / 100;
}
