#!/usr/bin/env bun
// ============================================================
// ANDROMEDA bot_mock — CLI Entrypoint Virtual ESP32-01
// ------------------------------------------------------------
// Menjalankan simulasi ESP32-01 non-blocking:
//   - Record sensor_readings tiap 30 menit (1800 dtk, selaras hardware)
//   - Poll pending_commands tiap 5 dtk + immediate push feedback
//   - Valve timer 1 dtk + immediate push saat auto-close
//   - Heartbeat tiap 60 dtk (devices.last_seen → badge Online)
//   - Pola kelembaban & aki realistis non-template berbasis jam,
//     suhu, RH, radiasi surya, hujan, angin (Open-Meteo + fallback)
// ============================================================

import { runBackfill, runCleanup, runLive } from "./esp32_sim";
import { HttpSupabaseApi } from "./supabase";
import {
  clamp,
  DEFAULT_CMD_POLL_SEC,
  DEFAULT_LAT,
  DEFAULT_LON,
  DEFAULT_SENSOR_INTERVAL_SEC,
  log,
  PETAK_IDS,
  type CliOpts,
  type PetakId,
  type WeatherMode,
} from "./types";
import { WeatherEngine } from "./weather";

// ---------- Env (prioritas: export > ./ .env > root .env > mobile .env) ----------

async function loadEnvFile(path: string): Promise<Record<string, string>> {
  try {
    const f = Bun.file(path);
    if (!(await f.exists())) return {};
    const out: Record<string, string> = {};
    for (const line of (await f.text()).split("\n")) {
      const t = line.trim();
      if (!t || t.startsWith("#") || !t.includes("=")) continue;
      const i = t.indexOf("=");
      const k = t.slice(0, i).trim();
      let v = t.slice(i + 1).trim();
      if (
        (v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))
      ) {
        v = v.slice(1, -1);
      }
      out[k] = v;
    }
    return out;
  } catch {
    return {};
  }
}

export async function resolveEnv(): Promise<{
  url: string;
  key: string;
  lat: number;
  lon: number;
}> {
  const here = import.meta.dir; // .../tools/bot_mock/src
  const candidates = [
    `${here}/../.env`, // tools/bot_mock/.env (opsional)
    `${here}/../../../.env`, // root .env (SUMBER UTAMA)
    `${here}/../../../mobile_app/.env`, // sync mobile
  ];
  const merged: Record<string, string> = {};
  for (const p of [...candidates].reverse()) {
    Object.assign(merged, await loadEnvFile(p));
  }
  const url = (Bun.env.SUPABASE_URL ?? merged.SUPABASE_URL ?? "").trim();
  const key = (Bun.env.SUPABASE_ANON_KEY ?? merged.SUPABASE_ANON_KEY ?? "").trim();
  const rawLat = Number(Bun.env.BOT_LAT ?? merged.BOT_LAT);
  const rawLon = Number(Bun.env.BOT_LON ?? merged.BOT_LON);
  const lat = Number.isFinite(rawLat) && rawLat >= -90 && rawLat <= 90 ? rawLat : DEFAULT_LAT;
  const lon = Number.isFinite(rawLon) && rawLon >= -180 && rawLon <= 180 ? rawLon : DEFAULT_LON;
  return { url, key, lat, lon };
}

// ---------- CLI Parser ----------

export function parseArgs(
  argv: string[],
  defaults: { lat?: number; lon?: number } = {},
): CliOpts {
  const o: CliOpts = {
    mode: "live",
    days: 7,
    intervalSec: DEFAULT_SENSOR_INTERVAL_SEC, // 1800 detik = 30 menit
    intervalPinned: false,
    cmdPollSec: DEFAULT_CMD_POLL_SEC, // 5 detik
    weatherMode: "auto",
    lat: defaults.lat ?? DEFAULT_LAT,
    lon: defaults.lon ?? DEFAULT_LON,
    seed: undefined,
    hydrate: true,
    faults: false,
    dryRun: false,
    only: [...PETAK_IDS],
    once: false,
    yes: false,
  };

  let fast = false;
  let explicitCmdPoll = false;

  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = argv[i + 1];
    const val = (flag: string): string | undefined => {
      if (a.startsWith(flag + "=")) return a.slice(flag.length + 1);
      if (a === flag && next && !next.startsWith("--")) {
        i++;
        return next;
      }
      return undefined;
    };

    let v: string | undefined;
    if ((v = val("--mode")) !== undefined) {
      if (v === "live" || v === "backfill" || v === "cleanup") o.mode = v;
      else throw new Error(`--mode harus live|backfill|cleanup (dapat "${v}")`);
    } else if ((v = val("--days")) !== undefined) {
      o.days = clamp(parseInt(v, 10) || 7, 1, 30);
    } else if ((v = val("--interval")) !== undefined) {
      const parsed = parseInt(v, 10);
      if (!Number.isFinite(parsed)) {
        throw new Error(`--interval harus angka detik (dapat "${v}")`);
      }
      o.intervalSec = clamp(parsed, 10, 7200);
      o.intervalPinned = true;
    } else if ((v = val("--cmd-poll")) !== undefined) {
      const parsed = parseInt(v, 10);
      if (!Number.isFinite(parsed)) {
        throw new Error(`--cmd-poll harus angka detik (dapat "${v}")`);
      }
      o.cmdPollSec = clamp(parsed, 2, 60);
      explicitCmdPoll = true;
    } else if ((v = val("--weather")) !== undefined) {
      if (v === "auto" || v === "open-meteo" || v === "synthetic") {
        o.weatherMode = v as WeatherMode;
      } else {
        throw new Error(
          `--weather harus auto|open-meteo|synthetic (dapat "${v}")`,
        );
      }
    } else if ((v = val("--lat")) !== undefined) {
      const n = Number(v);
      if (!Number.isFinite(n) || n < -90 || n > 90) {
        throw new Error(`--lat tidak valid: "${v}"`);
      }
      o.lat = n;
    } else if ((v = val("--lon")) !== undefined) {
      const n = Number(v);
      if (!Number.isFinite(n) || n < -180 || n > 180) {
        throw new Error(`--lon tidak valid: "${v}"`);
      }
      o.lon = n;
    } else if ((v = val("--seed")) !== undefined) {
      const n = parseInt(v, 10);
      if (!Number.isFinite(n)) {
        throw new Error(`--seed harus angka bulat (dapat "${v}")`);
      }
      o.seed = n >>> 0;
    } else if (a === "--fast") {
      fast = true;
    } else if (a === "--dry-run") {
      o.dryRun = true;
    } else if (a === "--faults") {
      o.faults = true;
    } else if (a === "--no-faults") {
      o.faults = false;
    } else if (a === "--no-hydrate") {
      o.hydrate = false;
    } else if ((v = val("--only")) !== undefined) {
      const list = v
        .split(",")
        .map((s) => s.trim())
        .filter((s) => (PETAK_IDS as readonly string[]).includes(s)) as PetakId[];
      if (list.length > 0) o.only = list;
      else {
        throw new Error(
          `--only tidak cocok: "${v}" (contoh: petak-01,petak-02)`,
        );
      }
    } else if (a === "--once") {
      o.once = true;
    } else if (a === "--yes") {
      o.yes = true;
    } else if (a === "--help" || a === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Argumen tidak dikenal: "${a}" (lihat --help)`);
    }
  }

  if (fast) {
    o.intervalSec = 30;
    o.intervalPinned = true;
    if (!explicitCmdPoll) o.cmdPollSec = 3;
  }

  return o;
}

export function printHelp(): void {
  console.log(`
ANDROMEDA bot_mock — Virtual ESP32-01 (Bun + TypeScript)

  bun src/bot_mock.ts --mode live                     # produksi: record 30 mnt, cmd poll 5 dtk
  bun src/bot_mock.ts --mode live --fast              # demo cepat: record 30 dtk, cmd poll 3 dtk
  bun src/bot_mock.ts --mode live --once [--dry-run]  # sekali siklus lalu keluar
  bun src/bot_mock.ts --mode backfill --days 7        # isi histori 7 hari (tiap 30 mnt)
  bun src/bot_mock.ts --mode cleanup --days 1 --yes   # hapus data simulasi N hari terakhir

Opsi:
  --mode live|backfill|cleanup   default live
  --interval N       detik antar record sensor (10-7200; default 1800 = 30 mnt,
                     ikut system_config.read_interval jika tidak diisi)
  --cmd-poll N       detik antar cek pending_commands (2-60, default 5)
  --fast             shortcut demo (--interval 30 --cmd-poll 3)
  --weather MODE     auto|open-meteo|synthetic (default auto: Open-Meteo + fallback lokal)
  --lat N --lon N    koordinat cuaca Open-Meteo (default BOT_LAT/BOT_LON atau ${DEFAULT_LAT}, ${DEFAULT_LON})
  --days N           backfill/cleanup: rentang hari (1-30, default 7)
  --only A,B         batasi petak (default semua 6 petak)
  --seed N           seed PRNG opsional (untuk uji deterministik)
  --no-hydrate       jangan baca kelembaban terakhir dari Supabase saat boot
  --faults           aktifkan injeksi SENSOR ERROR langka di petak-06 (default mati)
  --no-faults        matikan injeksi SENSOR ERROR (default)
  --once             live sekali siklus lalu keluar
  --dry-run          cetak payload tanpa menulis ke Supabase
  --yes              konfirmasi cleanup (wajib untuk mode cleanup)
`);
}

// ---------- Main ----------

async function main(): Promise<void> {
  const env = await resolveEnv();

  let opts: CliOpts;
  try {
    opts = parseArgs(Bun.argv.slice(2), { lat: env.lat, lon: env.lon });
  } catch (e) {
    console.error(e instanceof Error ? e.message : String(e));
    printHelp();
    process.exit(1);
  }

  if (!env.url || !env.key) {
    console.error("SUPABASE_URL / SUPABASE_ANON_KEY kosong.");
    console.error(
      "Isi root .env (disarankan) atau tools/bot_mock/.env — contoh di .env.example.",
    );
    process.exit(1);
  }

  log(`Supabase: ${env.url} — mode ${opts.mode}`);

  const supabase = new HttpSupabaseApi(env.url, env.key);
  const weather = new WeatherEngine({
    mode: opts.weatherMode,
    lat: opts.lat,
    lon: opts.lon,
    seed: opts.seed,
  });

  if (opts.mode === "live") {
    await runLive(supabase, weather, opts);
  } else if (opts.mode === "backfill") {
    await runBackfill(supabase, weather, opts);
  } else {
    await runCleanup(supabase, opts);
  }
}

if (import.meta.main) {
  await main();
}
