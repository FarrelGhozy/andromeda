import { describe, expect, test } from "bun:test";
import {
  closeValveState,
  createInitialBattery,
  createInitialPetakStates,
  openValveState,
  PETAK_AGRONOMY,
  readSimulatedSensor,
  stepBatteryVoltage,
  stepSoilPhysics,
} from "../src/soil_physics";
import {
  createRng,
  DRY_REF,
  MAX_VALID_RAW,
  MIN_VALID_RAW,
  percentToRaw,
  PETAK_IDS,
  rawToPercent,
  WET_REF,
  type WeatherSample,
} from "../src/types";
import { SyntheticWeatherModel } from "../src/weather";

describe("ADC & kalibrasi sensor (selaras hardware/firmware/src/sensor.cpp)", () => {
  test("konversi raw <-> percent akurat di titik referensi", () => {
    expect(rawToPercent(WET_REF)).toBe(100);
    expect(rawToPercent(DRY_REF)).toBe(0);
    expect(rawToPercent(2100)).toBe(50);
    expect(rawToPercent(4095)).toBe(0);
    expect(rawToPercent(0)).toBe(100);

    expect(percentToRaw(100)).toBe(WET_REF);
    expect(percentToRaw(0)).toBe(DRY_REF);
    expect(percentToRaw(50)).toBe(2100);
  });

  test("readSimulatedSensor selalu dalam rentang valid saat faults=false", () => {
    const rng = createRng(42);
    const states = createInitialPetakStates(PETAK_IDS, rng);
    const w: WeatherSample = {
      tempC: 31,
      rhPct: 60,
      cloudPct: 30,
      solarWm2: 720,
      rainMmHr: 0,
      windKmh: 8,
      source: "synthetic",
    };

    for (let i = 0; i < 200; i++) {
      for (const id of PETAK_IDS) {
        const out = readSimulatedSensor(id, states[id], w, false, rng);
        expect(out.fault).toBe(false);
        expect(out.raw).toBeGreaterThanOrEqual(MIN_VALID_RAW);
        expect(out.raw).toBeLessThanOrEqual(MAX_VALID_RAW);
        expect(out.pct).toBeGreaterThanOrEqual(0);
        expect(out.pct).toBeLessThanOrEqual(100);
      }
    }
  });

  test("injeksi fault hanya terjadi di petak-06 dan tidak merusak rootPct", () => {
    const rng = createRng(12345);
    const states = createInitialPetakStates(PETAK_IDS, rng);
    const beforePct = states["petak-06"].rootPct;
    const w: WeatherSample = {
      tempC: 28,
      rhPct: 70,
      cloudPct: 40,
      solarWm2: 400,
      rainMmHr: 0,
      windKmh: 6,
      source: "synthetic",
    };

    let faultCount06 = 0;
    let faultOther = 0;
    for (let i = 0; i < 600; i++) {
      for (const id of PETAK_IDS) {
        const out = readSimulatedSensor(id, states[id], w, true, rng);
        if (out.fault) {
          if (id === "petak-06") faultCount06++;
          else faultOther++;
        }
      }
    }

    expect(faultOther).toBe(0);
    expect(faultCount06).toBeGreaterThan(0);
    expect(states["petak-06"].rootPct).toBe(beforePct);
  });
});

describe("Fisika neraca air tanah (non-template)", () => {
  test("siang panas terik mengering jauh lebih cepat daripada malam hari", () => {
    const rng1 = createRng(7);
    const rng2 = createRng(7);
    const sDay = createInitialPetakStates(["petak-02"], rng1)["petak-02"];
    const sNight = createInitialPetakStates(["petak-02"], rng2)["petak-02"];
    sDay.rootPct = 60;
    sNight.rootPct = 60;

    const hotMidday: WeatherSample = {
      tempC: 34.2,
      rhPct: 48,
      cloudPct: 15,
      solarWm2: 880,
      rainMmHr: 0,
      windKmh: 12,
      source: "synthetic",
    };
    const coolNight: WeatherSample = {
      tempC: 22.5,
      rhPct: 84,
      cloudPct: 30,
      solarWm2: 0,
      rainMmHr: 0,
      windKmh: 3,
      source: "synthetic",
    };

    const middayDate = new Date(2026, 7, 15, 13, 30, 0);
    const nightDate = new Date(2026, 7, 15, 22, 30, 0);

    // Simulasi 3 jam (6 × 30 menit)
    for (let i = 0; i < 6; i++) {
      stepSoilPhysics("petak-02", sDay, hotMidday, middayDate, 1800, rng1);
      stepSoilPhysics("petak-02", sNight, coolNight, nightDate, 1800, rng2);
    }

    const dayDrop = 60 - sDay.rootPct;
    const nightDrop = 60 - sNight.rootPct;

    expect(dayDrop).toBeGreaterThan(4.0); // siang panas turun nyata (> 4% per 3 jam)
    expect(nightDrop).toBeGreaterThanOrEqual(0); // malam TIDAK melompat naik artifisial
    expect(nightDrop).toBeLessThan(1.2); // malam hampir landai
    expect(dayDrop).toBeGreaterThan(nightDrop * 5);
  });

  test("penyiraman drip 30 detik menaikkan kelembaban + meresap bertahap lewat wettingBuffer", () => {
    const rng = createRng(99);
    const st = createInitialPetakStates(["petak-05"], rng)["petak-05"];
    st.rootPct = 28;
    const at = new Date(2026, 7, 15, 10, 0, 0);
    const mild: WeatherSample = {
      tempC: 28,
      rhPct: 70,
      cloudPct: 45,
      solarWm2: 500,
      rainMmHr: 0,
      windKmh: 6,
      source: "synthetic",
    };

    openValveState(st, 30, at.getTime(), "manual");
    for (let s = 0; s < 30; s++) {
      stepSoilPhysics("petak-05", st, mild, at, 1, rng);
    }
    closeValveState(st);

    const rightAfterWatering = st.rootPct;
    expect(rightAfterWatering).toBeGreaterThan(36); // kenaikan langsung ~10%
    expect(rightAfterWatering).toBeLessThan(50); // tidak langsung mentok 95%!
    expect(st.wettingBuffer).toBeGreaterThan(4); // sisa air masih meresap

    // 20 menit kemudian, wettingBuffer meresap → kelembaban naik halus (wetting front)
    stepSoilPhysics("petak-05", st, mild, at, 20 * 60, rng);
    expect(st.rootPct).toBeGreaterThan(rightAfterWatering);
    expect(st.wettingBuffer).toBeLessThan(4);
  });

  test("hujan menaikkan kelembaban secara diferensial (mulsa petak-01 < terbuka petak-04)", () => {
    const rng = createRng(321);
    const states = createInitialPetakStates(["petak-01", "petak-04"], rng);
    states["petak-01"].rootPct = 42;
    states["petak-04"].rootPct = 42;

    const storm: WeatherSample = {
      tempC: 24.5,
      rhPct: 95,
      cloudPct: 95,
      solarWm2: 90,
      rainMmHr: 14,
      windKmh: 15,
      source: "synthetic",
    };
    const at = new Date(2026, 7, 15, 15, 30, 0);

    // 1 jam hujan + 30 menit perkolasi
    stepSoilPhysics("petak-01", states["petak-01"], storm, at, 3600, rng);
    stepSoilPhysics("petak-04", states["petak-04"], storm, at, 3600, rng);
    const afterRain: WeatherSample = { ...storm, rainMmHr: 0 };
    stepSoilPhysics("petak-01", states["petak-01"], afterRain, at, 1800, rng);
    stepSoilPhysics("petak-04", states["petak-04"], afterRain, at, 1800, rng);

    expect(states["petak-01"].rootPct).toBeGreaterThan(48);
    expect(states["petak-04"].rootPct).toBeGreaterThan(states["petak-01"].rootPct + 2);
  });

  test("drainase gravitasi menurunkan kelembaban di atas kapasitas lapang", () => {
    const rng = createRng(55);
    const st = createInitialPetakStates(["petak-02"], rng)["petak-02"];
    const fc = PETAK_AGRONOMY["petak-02"].fieldCapacity;
    st.rootPct = 90; // jauh di atas fieldCapacity (68%)

    const humidNight: WeatherSample = {
      tempC: 23,
      rhPct: 90,
      cloudPct: 60,
      solarWm2: 0,
      rainMmHr: 0,
      windKmh: 3,
      source: "synthetic",
    };
    const at = new Date(2026, 7, 15, 23, 0, 0);

    stepSoilPhysics("petak-02", st, humidNight, at, 2 * 3600, rng);
    expect(st.rootPct).toBeLessThan(80);
    expect(st.rootPct).toBeGreaterThan(fc - 2);
  });
});

describe("Cuaca prosedural non-template & model aki 12V", () => {
  test("cuaca sintetis tidak berulang antar-hari dan kontinu melintasi tengah malam", () => {
    const modelA = new SyntheticWeatherModel(202601);
    const modelB = new SyntheticWeatherModel(999999);

    const noonTempsA: number[] = [];
    const noonTempsB: number[] = [];
    for (let d = 1; d <= 7; d++) {
      const t = new Date(2026, 7, d, 13, 30, 0);
      noonTempsA.push(modelA.sampleAt(t).tempC);
      noonTempsB.push(modelB.sampleAt(t).tempC);
    }

    // Tidak konstan / template (harus ada variasi suhu siang antar-hari)
    const uniqueA = new Set(noonTempsA);
    expect(uniqueA.size).toBeGreaterThanOrEqual(4);
    expect(noonTempsA).not.toEqual(noonTempsB);

    // Kontinuitas melewati tengah malam (23:55 -> 00:05 tidak boleh lompat > 1.0°C)
    const beforeMid = modelA.sampleAt(new Date(2026, 7, 4, 23, 55, 0));
    const afterMid = modelA.sampleAt(new Date(2026, 7, 5, 0, 5, 0));
    expect(Math.abs(afterMid.tempC - beforeMid.tempC)).toBeLessThan(1.0);
  });

  test("tegangan aki lebih tinggi saat cerah dibanding mendung/malam & sag saat valve ON", () => {
    const rng = createRng(101);
    const sunny: WeatherSample = {
      tempC: 32,
      rhPct: 55,
      cloudPct: 12,
      solarWm2: 850,
      rainMmHr: 0,
      windKmh: 8,
      source: "synthetic",
    };
    const night: WeatherSample = {
      tempC: 23,
      rhPct: 88,
      cloudPct: 40,
      solarWm2: 0,
      rainMmHr: 0,
      windKmh: 4,
      source: "synthetic",
    };

    const battSunny = createInitialBattery(new Date(2026, 7, 15, 11, 0, 0));
    const vSunnyOff = stepBatteryVoltage(battSunny, sunny, 0, 60, rng);
    const vSunnyOn = stepBatteryVoltage({ soc: battSunny.soc }, sunny, 1, 0, rng);
    const vNightOff = stepBatteryVoltage({ soc: battSunny.soc }, night, 0, 0, rng);

    expect(vSunnyOff).toBeGreaterThan(vNightOff + 0.6);
    expect(vSunnyOff - vSunnyOn).toBeGreaterThan(0.1); // voltage sag solenoid ~0.18V
  });
});
