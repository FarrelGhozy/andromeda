// ============================================================
// ANDROMEDA bot_mock — Mesin Cuaca Hibrida (Non-Template)
// ------------------------------------------------------------
// 1. Open-Meteo (gratis, tanpa API key — API sama dgn mobile_app):
//    suhu, kelembaban udara, radiasi surya, awan, hujan, angin, ET0
//    untuk mode live maupun backfill (past_days 1..30).
// 2. Fallback / Synthetic: generator iklim tropis Indonesia berbasis
//    rantai Markov rezim cuaca, kurva suhu asimetris Parton-Logan,
//    awan/angin Ornstein-Uhlenbeck, dan sel hujan konvektif stokastik.
//    Tidak ada pola sinus statis berulang antar-hari.
// ============================================================

import https from "node:https";
import {
  clamp,
  createRng,
  log,
  type Rng,
  type WeatherMode,
  type WeatherRegime,
  type WeatherSample,
} from "./types";

function getJsonIpv4(url: string, timeoutMs = 10_000): Promise<unknown> {
  return new Promise((resolve, reject) => {
    const req = https.get(
      url,
      { family: 4, timeout: timeoutMs },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (chunk: Buffer | string) => {
          chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
        });
        res.on("end", () => {
          const code = res.statusCode ?? 0;
          if (code < 200 || code >= 300) {
            reject(new Error(`HTTP ${code}`));
            return;
          }
          try {
            const body = Buffer.concat(chunks).toString("utf8");
            resolve(JSON.parse(body));
          } catch (e) {
            reject(e);
          }
        });
      },
    );
    req.on("timeout", () => {
      req.destroy(new Error("timeout"));
    });
    req.on("error", reject);
  });
}

interface RainCell {
  startHour: number;
  durationHr: number;
  peakMmHr: number;
}

interface SyntheticDayPlan {
  dayIndex: number;
  regime: WeatherRegime;
  tMin: number;
  tMax: number;
  tMinHour: number;
  tMaxHour: number;
  dewOffsetC: number;
  baseCloudPct: number;
  baseWindKmh: number;
  rainCells: RainCell[];
  hourlyCloudJitter: number[]; // 25 titik (jam 0..24)
  hourlyWindJitter: number[]; // 25 titik (jam 0..24)
}

const REGIME_TRANSITIONS: Record<WeatherRegime, Array<[WeatherRegime, number]>> = {
  cerah_panas: [
    ["cerah_panas", 0.42],
    ["cerah_berawan", 0.34],
    ["berawan_lembab", 0.14],
    ["hujan_sore_tropis", 0.08],
    ["hujan_deras", 0.02],
  ],
  cerah_berawan: [
    ["cerah_panas", 0.25],
    ["cerah_berawan", 0.35],
    ["berawan_lembab", 0.2],
    ["hujan_sore_tropis", 0.16],
    ["hujan_deras", 0.04],
  ],
  berawan_lembab: [
    ["cerah_panas", 0.12],
    ["cerah_berawan", 0.24],
    ["berawan_lembab", 0.28],
    ["hujan_sore_tropis", 0.24],
    ["hujan_deras", 0.12],
  ],
  hujan_sore_tropis: [
    ["cerah_panas", 0.12],
    ["cerah_berawan", 0.28],
    ["berawan_lembab", 0.24],
    ["hujan_sore_tropis", 0.24],
    ["hujan_deras", 0.12],
  ],
  hujan_deras: [
    ["cerah_panas", 0.06],
    ["cerah_berawan", 0.18],
    ["berawan_lembab", 0.34],
    ["hujan_sore_tropis", 0.26],
    ["hujan_deras", 0.16],
  ],
};

function satVaporPressureKpa(tempC: number): number {
  return 0.6108 * Math.exp((17.27 * tempC) / (tempC + 237.3));
}

function hashDaySeed(baseSeed: number, dayIndex: number): number {
  let x = (baseSeed ^ Math.imul(dayIndex + 0x9e3779b9, 0x85ebca6b)) >>> 0;
  x = Math.imul(x ^ (x >>> 13), 0xc2b2ae35) >>> 0;
  return (x ^ (x >>> 16)) >>> 0;
}

function pickWeightedRegime(
  prev: WeatherRegime,
  rng: Rng,
): WeatherRegime {
  const table = REGIME_TRANSITIONS[prev];
  const roll = rng.next();
  let acc = 0;
  for (const [regime, weight] of table) {
    acc += weight;
    if (roll <= acc) return regime;
  }
  return table[table.length - 1][0];
}

function localDayIndex(at: Date): number {
  // Indeks hari lokal (WIB / timezone mesin) supaya siklus siang-malam pas.
  const localMidnight = new Date(
    at.getFullYear(),
    at.getMonth(),
    at.getDate(),
  ).getTime();
  return Math.floor(localMidnight / 86_400_000);
}

function localHourFloat(at: Date): number {
  return (
    at.getHours() +
    at.getMinutes() / 60 +
    at.getSeconds() / 3600
  );
}

export class SyntheticWeatherModel {
  private readonly baseSeed: number;
  private readonly days = new Map<number, SyntheticDayPlan>();

  constructor(seed?: number) {
    this.baseSeed =
      (seed ?? ((Date.now() ^ Math.floor(Math.random() * 0xffffffff)) >>> 0)) >>>
      0;
  }

  private getOrCreateDay(dayIndex: number): SyntheticDayPlan {
    const existing = this.days.get(dayIndex);
    if (existing) return existing;

    // Pastikan rantai Markov mengalir mulus dari hari sebelumnya bila dekat.
    let prevDay = this.days.get(dayIndex - 1);
    if (!prevDay && this.days.size > 0) {
      const minKnown = Math.min(...this.days.keys());
      const maxKnown = Math.max(...this.days.keys());
      if (dayIndex > maxKnown && dayIndex - maxKnown <= 35) {
        for (let d = maxKnown + 1; d < dayIndex; d++) {
          this.getOrCreateDay(d);
        }
        prevDay = this.days.get(dayIndex - 1);
      } else if (dayIndex < minKnown && minKnown - dayIndex <= 35) {
        // Bangun hari mundur independen
        prevDay = undefined;
      }
    }

    const rng = createRng(hashDaySeed(this.baseSeed, dayIndex));
    const startRegimes: WeatherRegime[] = [
      "cerah_panas",
      "cerah_berawan",
      "berawan_lembab",
      "hujan_sore_tropis",
      "hujan_deras",
    ];
    const regime: WeatherRegime = prevDay
      ? pickWeightedRegime(prevDay.regime, rng)
      : startRegimes[Math.floor(rng.next() * startRegimes.length)];

    // Profil suhu, awan, angin, dan sel hujan khas iklim tropis Indonesia.
    let tMinTarget: number;
    let tMaxTarget: number;
    let baseCloudPct: number;
    let baseWindKmh: number;
    const rainCells: RainCell[] = [];

    switch (regime) {
      case "cerah_panas":
        tMinTarget = rng.range(22.2, 24.4);
        tMaxTarget = rng.range(32.5, 35.4);
        baseCloudPct = rng.range(10, 28);
        baseWindKmh = rng.range(6.5, 13.0);
        break;
      case "cerah_berawan":
        tMinTarget = rng.range(21.8, 23.8);
        tMaxTarget = rng.range(30.4, 33.2);
        baseCloudPct = rng.range(30, 56);
        baseWindKmh = rng.range(5.5, 11.5);
        if (rng.next() < 0.18) {
          rainCells.push({
            startHour: rng.range(15.0, 18.5),
            durationHr: rng.range(0.4, 1.0),
            peakMmHr: rng.range(1.2, 4.0),
          });
        }
        break;
      case "berawan_lembab":
        tMinTarget = rng.range(21.4, 23.4);
        tMaxTarget = rng.range(28.2, 30.8);
        baseCloudPct = rng.range(62, 86);
        baseWindKmh = rng.range(4.0, 9.5);
        if (rng.next() < 0.45) {
          rainCells.push({
            startHour: rng.range(13.5, 20.5),
            durationHr: rng.range(0.7, 2.0),
            peakMmHr: rng.range(1.5, 5.5),
          });
        }
        break;
      case "hujan_sore_tropis":
        // Pagi-siang cukup hangat lalu konveksi membentuk hujan sore khas tropis.
        tMinTarget = rng.range(21.5, 23.6);
        tMaxTarget = rng.range(29.8, 32.8);
        baseCloudPct = rng.range(48, 76);
        baseWindKmh = rng.range(6.0, 14.0);
        rainCells.push({
          startHour: rng.range(13.5, 17.8),
          durationHr: rng.range(1.0, 2.8),
          peakMmHr: rng.range(6.5, 18.5),
        });
        if (rng.next() < 0.3) {
          rainCells.push({
            startHour: rng.range(19.0, 22.0),
            durationHr: rng.range(0.6, 1.5),
            peakMmHr: rng.range(1.8, 5.5),
          });
        }
        break;
      case "hujan_deras":
        tMinTarget = rng.range(20.8, 22.8);
        tMaxTarget = rng.range(26.8, 29.6);
        baseCloudPct = rng.range(78, 96);
        baseWindKmh = rng.range(9.0, 19.0);
        rainCells.push({
          startHour: rng.range(11.5, 16.0),
          durationHr: rng.range(1.8, 4.0),
          peakMmHr: rng.range(12.0, 28.0),
        });
        if (rng.next() < 0.55) {
          rainCells.push({
            startHour: rng.range(1.0, 6.0),
            durationHr: rng.range(1.0, 2.5),
            peakMmHr: rng.range(3.0, 11.0),
          });
        }
        break;
    }

    // Inersia termal ringan dari hari sebelumnya (tidak melompat liar)
    const tMin = prevDay ? prevDay.tMin * 0.3 + tMinTarget * 0.7 : tMinTarget;
    const tMax = prevDay ? prevDay.tMax * 0.25 + tMaxTarget * 0.75 : tMaxTarget;

    // Proses Ornstein-Uhlenbeck per jam untuk awan & angin (kontinu, non-periodik)
    const hourlyCloudJitter: number[] = [];
    const hourlyWindJitter: number[] = [];
    let cState = rng.gauss() * 10;
    let wState = rng.gauss() * 2;
    for (let h = 0; h <= 24; h++) {
      cState = cState * 0.72 + rng.gauss() * 11;
      wState = wState * 0.68 + rng.gauss() * 2.2;
      hourlyCloudJitter.push(clamp(cState, -28, 28));
      hourlyWindJitter.push(clamp(wState, -5, 8));
    }

    const plan: SyntheticDayPlan = {
      dayIndex,
      regime,
      tMin,
      tMax: Math.max(tMin + 4.2, tMax),
      tMinHour: rng.range(5.2, 5.9),
      tMaxHour: rng.range(13.2, 14.5),
      dewOffsetC: rng.range(-0.9, 0.7),
      baseCloudPct,
      baseWindKmh,
      rainCells,
      hourlyCloudJitter,
      hourlyWindJitter,
    };

    this.days.set(dayIndex, plan);
    return plan;
  }

  sampleAt(at: Date): WeatherSample {
    const dIdx = localDayIndex(at);
    const day = this.getOrCreateDay(dIdx);
    const prevDay = this.getOrCreateDay(dIdx - 1);
    const nextDay = this.getOrCreateDay(dIdx + 1);
    const h = localHourFloat(at);

    // Interpolasi halus jitter awan & angin per jam
    const hLo = Math.min(23, Math.floor(h));
    const frac = h - hLo;
    const cloudNoise =
      day.hourlyCloudJitter[hLo] * (1 - frac) +
      day.hourlyCloudJitter[hLo + 1] * frac;
    const windNoise =
      day.hourlyWindJitter[hLo] * (1 - frac) +
      day.hourlyWindJitter[hLo + 1] * frac;

    // Evaluasi intensitas sel hujan (amplop lonceng asimetris)
    let rainMmHr = 0;
    for (const cell of day.rainCells) {
      if (h >= cell.startHour && h <= cell.startHour + cell.durationHr) {
        const u = (h - cell.startHour) / cell.durationHr; // 0..1
        // Puncak hujan agak cepat (u ≈ 0.35), reda lebih pelan
        const env = Math.sin(Math.PI * Math.pow(u, 0.72));
        rainMmHr += cell.peakMmHr * Math.max(0, env);
      }
    }

    // Tutupan awan meningkat saat hujan atau menjelang sel hujan sore
    let rainCloudBoost = 0;
    for (const cell of day.rainCells) {
      const dist = Math.min(
        Math.abs(h - cell.startHour),
        Math.abs(h - (cell.startHour + cell.durationHr)),
      );
      if (h >= cell.startHour && h <= cell.startHour + cell.durationHr) {
        rainCloudBoost = Math.max(rainCloudBoost, 38);
      } else if (dist < 2.0) {
        rainCloudBoost = Math.max(rainCloudBoost, 24 * (1 - dist / 2.0));
      }
    }
    const cloudPct = clamp(day.baseCloudPct + cloudNoise + rainCloudBoost, 4, 100);

    // Kurva suhu diurnal asimetris (Parton-Logan simplified), kontinu melintasi 00:00
    const sunsetHour = 18.1;
    let tempC: number;
    if (h >= day.tMinHour && h <= sunsetHour) {
      // Siang: kurva sinus miring (puncak di tMaxHour ~13:45)
      const spanToPeak = day.tMaxHour - day.tMinHour;
      const spanAfterPeak = sunsetHour - day.tMaxHour;
      if (h <= day.tMaxHour) {
        const phase = ((h - day.tMinHour) / spanToPeak) * (Math.PI / 2);
        tempC = day.tMin + (day.tMax - day.tMin) * Math.sin(phase);
      } else {
        const u = (h - day.tMaxHour) / spanAfterPeak;
        // Turun sekitar 48% rentang dari puncak sampai senja
        tempC = day.tMax - (day.tMax - day.tMin) * 0.48 * Math.pow(u, 1.35);
      }
    } else if (h > sunsetHour) {
      // Malam (senja hari ini → fajar besok)
      const tSunset = day.tMax - (day.tMax - day.tMin) * 0.48;
      const nightLen = 24 - sunsetHour + nextDay.tMinHour;
      const elapsedNight = h - sunsetHour;
      const decay = 1 - Math.exp((-2.6 * elapsedNight) / nightLen);
      const normDecay = decay / (1 - Math.exp(-2.6));
      tempC = tSunset - (tSunset - nextDay.tMin) * normDecay;
    } else {
      // Dini hari (00:00 → fajar hari ini): lanjutkan kurva senja kemarin secara kontinu
      const tSunsetPrev = prevDay.tMax - (prevDay.tMax - prevDay.tMin) * 0.48;
      const nightLen = 24 - sunsetHour + day.tMinHour;
      const elapsedNight = h + (24 - sunsetHour);
      const decay = 1 - Math.exp((-2.6 * elapsedNight) / nightLen);
      const normDecay = decay / (1 - Math.exp(-2.6));
      tempC = tSunsetPrev - (tSunsetPrev - day.tMin) * normDecay;
    }

    // Pendinginan evaporatif saat hujan turun + variasi awan siang
    if (rainMmHr > 0.1) {
      tempC -= Math.min(5.2, 1.35 * Math.sqrt(rainMmHr));
    }
    if (h > 9 && h < 17) {
      tempC -= ((cloudPct - day.baseCloudPct) / 100) * 2.2;
    }

    // Kelembaban udara (RH) terikat secara fisika ke titik embun + lonjakan hujan
    const tDew = day.tMin + day.dewOffsetC;
    const baseRh =
      (satVaporPressureKpa(tDew) / satVaporPressureKpa(tempC)) * 100;
    const rainRhBoost = rainMmHr > 0.1 ? Math.min(28, 12 + rainMmHr * 1.4) : 0;
    const cloudRhBoost = ((cloudPct - 45) / 100) * 6;
    const rhPct = clamp(baseRh + rainRhBoost + cloudRhBoost, 36, 99);

    // Radiasi surya (W/m²): aktif 05:55..18:05 dengan atenuasi awan Kasten-Czeplak
    let solarWm2 = 0;
    if (h > 5.9 && h < 18.1) {
      const sunAngle = Math.sin(((h - 5.9) / (18.1 - 5.9)) * Math.PI);
      const clearSky = 960 * Math.pow(Math.max(0, sunAngle), 1.15);
      const cloudAtten = 1 - 0.72 * Math.pow(cloudPct / 100, 2.1);
      const rainAtten = rainMmHr > 0.5 ? clamp(1 - rainMmHr / 45, 0.35, 1) : 1;
      solarWm2 = Math.max(0, clearSky * cloudAtten * rainAtten);
    }

    // Angin sedikit lebih kencang siang hari dan saat hujan konvektif
    const diurnalWind =
      h >= 9 && h <= 17
        ? 2.2 * Math.sin(((h - 9) / 8) * Math.PI)
        : -1.2;
    const gustWind = rainMmHr > 2 ? Math.min(12, Math.sqrt(rainMmHr) * 2.1) : 0;
    const windKmh = clamp(
      day.baseWindKmh + diurnalWind + windNoise + gustWind,
      1.2,
      36,
    );

    return {
      tempC: Math.round(tempC * 10) / 10,
      rhPct: Math.round(rhPct * 10) / 10,
      cloudPct: Math.round(cloudPct),
      solarWm2: Math.round(solarWm2),
      rainMmHr: Math.round(rainMmHr * 100) / 100,
      windKmh: Math.round(windKmh * 10) / 10,
      source: "synthetic",
      regime: day.regime,
    };
  }
}

interface HourlyPoint {
  tsMs: number;
  tempC: number;
  rhPct: number;
  cloudPct: number;
  solarWm2: number;
  rainMmHr: number;
  windKmh: number;
  et0MmHr?: number;
}

export class WeatherEngine {
  private readonly mode: WeatherMode;
  private readonly lat: number;
  private readonly lon: number;
  private readonly synthetic: SyntheticWeatherModel;
  private hourly: HourlyPoint[] = [];
  private lastFetchMs = 0;
  private readonly refreshEveryMs = 30 * 60_000;
  private activeSource: "open-meteo" | "synthetic" = "synthetic";

  constructor(opts: {
    mode: WeatherMode;
    lat: number;
    lon: number;
    seed?: number;
  }) {
    this.mode = opts.mode;
    this.lat = opts.lat;
    this.lon = opts.lon;
    this.synthetic = new SyntheticWeatherModel(opts.seed);
  }

  get sourceLabel(): string {
    if (this.activeSource === "open-meteo") {
      return `Open-Meteo (${this.lat.toFixed(3)}, ${this.lon.toFixed(3)})`;
    }
    return "Synthetic Tropical Model (prosedural non-template)";
  }

  async init(pastDays = 0): Promise<void> {
    if (this.mode === "synthetic") {
      this.activeSource = "synthetic";
      return;
    }
    const ok = await this.fetchOpenMeteo(pastDays);
    if (!ok) {
      if (this.mode === "open-meteo") {
        log(
          "  cuaca: Open-Meteo gagal diambil → fallback sementara ke generator tropis prosedural",
        );
      } else {
        log(
          "  cuaca: Open-Meteo tidak terjangkau (offline) → memakai generator tropis prosedural",
        );
      }
      this.activeSource = "synthetic";
    }
  }

  async refreshIfStale(nowMs: number): Promise<void> {
    if (this.mode === "synthetic") return;
    if (nowMs - this.lastFetchMs < this.refreshEveryMs) return;
    await this.fetchOpenMeteo(1);
  }

  private async fetchOpenMeteo(pastDays: number): Promise<boolean> {
    const clampedPast = clamp(Math.round(pastDays), 0, 31);
    const params = new URLSearchParams({
      latitude: String(this.lat),
      longitude: String(this.lon),
      hourly: [
        "temperature_2m",
        "relative_humidity_2m",
        "cloud_cover",
        "shortwave_radiation",
        "rain",
        "wind_speed_10m",
        "et0_fao_evapotranspiration",
      ].join(","),
      timezone: "auto",
      forecast_days: "2",
    });
    if (clampedPast > 0) params.set("past_days", String(clampedPast));

    const url = `https://api.open-meteo.com/v1/forecast?${params.toString()}`;
    try {
      let rawData: unknown;
      try {
        // Prioritaskan IPv4: banyak ISP/jaringan di Indonesia memutus IPv6 ke Open-Meteo (ECONNRESET)
        rawData = await getJsonIpv4(url, 10_000);
      } catch {
        // Fallback ke fetch standar (untuk jaringan IPv6-only atau proxy HTTP)
        const res = await fetch(url, { signal: AbortSignal.timeout(10_000) });
        if (!res.ok) return false;
        rawData = await res.json();
      }
      const data = rawData as {
        utc_offset_seconds?: number;
        hourly?: Record<string, unknown[]>;
      };
      const h = data.hourly;
      if (!h || !Array.isArray(h["time"])) return false;

      const times = h["time"] as string[];
      const temps = (h["temperature_2m"] ?? []) as Array<number | null>;
      const rhs = (h["relative_humidity_2m"] ?? []) as Array<number | null>;
      const clouds = (h["cloud_cover"] ?? []) as Array<number | null>;
      const solars = (h["shortwave_radiation"] ?? []) as Array<number | null>;
      const rains = (h["rain"] ?? []) as Array<number | null>;
      const winds = (h["wind_speed_10m"] ?? []) as Array<number | null>;
      const et0s = (h["et0_fao_evapotranspiration"] ?? []) as Array<
        number | null
      >;
      const offsetSec = Number(data.utc_offset_seconds ?? 0);

      const parsed: HourlyPoint[] = [];
      for (let i = 0; i < times.length; i++) {
        // Open-Meteo mengembalikan "YYYY-MM-DDTHH:MM" pada timezone lokal lokasi.
        // Konversi deterministik ke epoch UTC memakai utc_offset_seconds.
        const isoUtc = `${times[i]}:00Z`;
        const wallMs = Date.parse(isoUtc);
        if (!Number.isFinite(wallMs)) continue;
        const tsMs = wallMs - offsetSec * 1000;

        const t = temps[i];
        const rh = rhs[i];
        if (t == null || rh == null) continue;

        parsed.push({
          tsMs,
          tempC: Number(t),
          rhPct: clamp(Number(rh), 20, 100),
          cloudPct: clamp(Number(clouds[i] ?? 40), 0, 100),
          solarWm2: Math.max(0, Number(solars[i] ?? 0)),
          rainMmHr: Math.max(0, Number(rains[i] ?? 0)),
          windKmh: Math.max(0, Number(winds[i] ?? 6)),
          et0MmHr: et0s[i] != null ? Math.max(0, Number(et0s[i])) : undefined,
        });
      }

      if (parsed.length < 4) return false;
      parsed.sort((a, b) => a.tsMs - b.tsMs);
      this.hourly = parsed;
      this.lastFetchMs = Date.now();
      this.activeSource = "open-meteo";
      return true;
    } catch {
      return false;
    }
  }

  sampleAt(at: Date): WeatherSample {
    if (this.activeSource === "open-meteo" && this.hourly.length >= 2) {
      const target = at.getTime();
      const first = this.hourly[0];
      const last = this.hourly[this.hourly.length - 1];
      if (target >= first.tsMs - 3_600_000 && target <= last.tsMs + 3_600_000) {
        return this.interpolateHourly(target);
      }
    }
    return this.synthetic.sampleAt(at);
  }

  private interpolateHourly(targetMs: number): WeatherSample {
    const arr = this.hourly;
    if (targetMs <= arr[0].tsMs) return this.pointToSample(arr[0]);
    if (targetMs >= arr[arr.length - 1].tsMs) {
      return this.pointToSample(arr[arr.length - 1]);
    }

    // Binary search titik kiri
    let lo = 0;
    let hi = arr.length - 1;
    while (lo + 1 < hi) {
      const mid = (lo + hi) >> 1;
      if (arr[mid].tsMs <= targetMs) lo = mid;
      else hi = mid;
    }
    const a = arr[lo];
    const b = arr[hi];
    const span = Math.max(1, b.tsMs - a.tsMs);
    const f = clamp((targetMs - a.tsMs) / span, 0, 1);
    const lerp = (x: number, y: number) => x + (y - x) * f;

    return {
      tempC: Math.round(lerp(a.tempC, b.tempC) * 10) / 10,
      rhPct: Math.round(lerp(a.rhPct, b.rhPct) * 10) / 10,
      cloudPct: Math.round(lerp(a.cloudPct, b.cloudPct)),
      solarWm2: Math.round(lerp(a.solarWm2, b.solarWm2)),
      rainMmHr: Math.round(lerp(a.rainMmHr, b.rainMmHr) * 100) / 100,
      windKmh: Math.round(lerp(a.windKmh, b.windKmh) * 10) / 10,
      et0MmHr:
        a.et0MmHr != null && b.et0MmHr != null
          ? Math.round(lerp(a.et0MmHr, b.et0MmHr) * 1000) / 1000
          : undefined,
      source: "open-meteo",
    };
  }

  private pointToSample(p: HourlyPoint): WeatherSample {
    return {
      tempC: Math.round(p.tempC * 10) / 10,
      rhPct: Math.round(p.rhPct * 10) / 10,
      cloudPct: Math.round(p.cloudPct),
      solarWm2: Math.round(p.solarWm2),
      rainMmHr: Math.round(p.rainMmHr * 100) / 100,
      windKmh: Math.round(p.windKmh * 10) / 10,
      et0MmHr: p.et0MmHr,
      source: "open-meteo",
    };
  }
}
