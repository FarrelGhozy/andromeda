#!/usr/bin/env bun
// ============================================================
// ANDROMEDA bot_mock — simulasi ESP32-01 hidup (Bun + TypeScript)
// ------------------------------------------------------------
// Peran: pengganti hardware/firmware/src/main.cpp saat ESP32
// asli belum ada / lagi mati. Bikin app kelihatan "hidup":
// gauge gerak, badge Online, grafik keisi, tombol valve responsif.
//
// Yang dilakukan tiap tick (mirip firmware asli):
//   1. GET system_config per petak (mode/threshold/durasi)
//   2. GET pending_commands pending per petak → eksekusi → PATCH executed
//   3. Random-walk kelembaban + efek siang/malam + efek valve ON
//   4. POST batch sensor_readings (6 petak sekaligus)
//   5. POST /rpc/heartbeat tiap 60 dtk (devices.last_seen)
//
// Aturan fisika yang dipatuhi (dari firmware & app):
//   - percent = 100 - ((raw-1500)/1200*100), raw = 2700 - pct/100*1200
//   - ADC valid 100..4000, di luar itu = SENSOR ERROR (app membuangnya)
//   - valve max 120 detik (VALVE_MAX_DURATION_MS)
//   - Online = last_seen/reading fresh ≤ 60 menit (DevicesProvider.onlineWindow)
//   - command basi > 2×read_interval jadi expired → bot eksekusi cepat
//
// Cara pakai singkat (detail di README.md sebelah file ini):
//   bun src/bot_mock.ts --mode live              # jalan terus, tick 30 dtk
//   bun src/bot_mock.ts --mode live --fast       # demo cepat, tick 10 dtk
//   bun src/bot_mock.ts --mode live --once       # sekali kirim lalu keluar
//   bun src/bot_mock.ts --mode backfill --days 7 # isi grafik 7 hari ke belakang
//   bun src/bot_mock.ts --mode cleanup --days 1 --yes
// ============================================================

// ---------- Konstanta (disalin dari firmware & schema) ----------
const ESP32_ID = "esp32-01";
const PETAK_IDS = [
  "petak-01",
  "petak-02",
  "petak-03",
  "petak-04",
  "petak-05",
  "petak-06",
] as const;
type PetakId = (typeof PETAK_IDS)[number];

const WET_REF = 1500; // ADC tanah basah (sensor.cpp)
const DRY_REF = 2700; // ADC tanah kering (sensor.cpp)
const MIN_VALID_RAW = 100; // schema.sql + sensor_reading.dart
const MAX_VALID_RAW = 4000;
const VALVE_MAX_SEC = 120; // config.h VALVE_MAX_DURATION_MS
const HEARTBEAT_EVERY_MS = 60_000;

// ---------- Profil tiap petak (biar nggak kelihatan bot) ----------
// base = kelembaban rata-rata, amp = ayunan harian, noise = liar harian.
interface PetakProfile {
  base: number;
  amp: number;
  noise: number;
  note: string;
}
const PROFILES: Record<PetakId, PetakProfile> = {
  "petak-01": { base: 55, amp: 6, noise: 1.5, note: "normal lembab" },
  "petak-02": { base: 25, amp: 5, noise: 2.0, note: "kering → sering trigger auto" },
  "petak-03": { base: 80, amp: 4, noise: 1.2, note: "basah habis disiram" },
  "petak-04": { base: 50, amp: 12, noise: 2.5, note: "fluktuatif siang/malam" },
  "petak-05": { base: 45, amp: 6, noise: 2.0, note: "buat demo tombol manual" },
  "petak-06": { base: 60, amp: 8, noise: 2.0, note: "kadang fault (uji SENSOR ERROR)" },
};

// ---------- Tipe ----------
interface SystemConfig {
  mode: "auto" | "manual";
  thresholdDry: number;
  thresholdWet: number;
  valveDurationSec: number;
  readIntervalSec: number;
  valid: boolean;
}
interface PendingCommand {
  id: number;
  command: string;
  duration: number;
  valid: boolean;
}
interface ValveState {
  open: boolean;
  openedAt: number; // epoch ms
  durationSec: number; // 0 = indefinite (manual VALVE_ON duration 0)
}
interface SimState {
  pct: number;
  valve: ValveState;
}
interface CliOpts {
  mode: "live" | "backfill" | "cleanup";
  days: number;
  intervalSec: number;
  dryRun: boolean;
  noFaults: boolean;
  only: PetakId[];
  once: boolean;
  yes: boolean;
}

// ---------- Util ----------
function log(msg: string) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}
function clamp(v: number, lo: number, hi: number) {
  return Math.min(hi, Math.max(lo, v));
}
function gauss() {
  // Box-Muller: noise mirip sensor asli
  let u = 0;
  let v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(2.0 * Math.PI * v);
}
function rawToPercent(raw: number): number {
  const p = 100 - ((raw - WET_REF) / (DRY_REF - WET_REF)) * 100;
  return clamp(p, 0, 100);
}
function percentToRaw(pct: number): number {
  return Math.round(DRY_REF - (clamp(pct, 0, 100) / 100) * (DRY_REF - WET_REF));
}
function diurnalOffset(date: Date): number {
  // Kering maksimal jam 14:00 (-7%), basah maksimal jam 02:00 (+7%).
  const h = date.getHours() + date.getMinutes() / 60;
  return -7 * Math.cos(((h - 14) / 24) * 2 * Math.PI);
}
function batteryVoltage(date: Date): number {
  // Aki + solar: puncak cas jam 13:00, drop malam hari.
  const h = date.getHours() + date.getMinutes() / 60;
  const v = 12.6 + 0.7 * Math.cos(((h - 13) / 24) * 2 * Math.PI) + gauss() * 0.05;
  return Math.round(clamp(v, 11.8, 14.2) * 100) / 100;
}

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
async function resolveEnv() {
  const here = import.meta.dir; // .../tools/bot_mock/src
  const candidates = [
    `${here}/../.env`, // tools/bot_mock/.env (opsional)
    `${here}/../../../.env`, // root .env (SUMBER UTAMA)
    `${here}/../../../mobile_app/.env`, // sync mobile
  ];
  const merged: Record<string, string> = {};
  // Urutan prioritas terbalik: yang terakhir menang, tapi Bun.env/export menang mutlak.
  for (const p of [...candidates].reverse()) {
    Object.assign(merged, await loadEnvFile(p));
  }
  const url = Bun.env.SUPABASE_URL ?? merged.SUPABASE_URL ?? "";
  const key = Bun.env.SUPABASE_ANON_KEY ?? merged.SUPABASE_ANON_KEY ?? "";
  return { url: url.trim(), key: key.trim() };
}

// ---------- CLI ----------
function parseArgs(argv: string[]): CliOpts {
  const o: CliOpts = {
    mode: "live",
    days: 7,
    intervalSec: 30,
    dryRun: false,
    noFaults: false,
    only: [...PETAK_IDS],
    once: false,
    yes: false,
  };
  let fast = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = argv[i + 1];
    const val = (flag: string) => {
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
      o.days = Math.max(1, Math.min(30, parseInt(v, 10) || 7));
    } else if ((v = val("--interval")) !== undefined) {
      o.intervalSec = clamp(parseInt(v, 10) || 30, 5, 3600);
    } else if (a === "--fast") {
      fast = true;
    } else if (a === "--dry-run") {
      o.dryRun = true;
    } else if (a === "--no-faults") {
      o.noFaults = true;
    } else if ((v = val("--only")) !== undefined) {
      const list = v
        .split(",")
        .map((s) => s.trim())
        .filter((s) => (PETAK_IDS as readonly string[]).includes(s)) as PetakId[];
      if (list.length > 0) o.only = list;
      else throw new Error(`--only tidak cocok: "${v}" (contoh: petak-01,petak-02)`);
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
  if (fast) o.intervalSec = 10;
  return o;
}
function printHelp() {
  console.log(`
ANDROMEDA bot_mock — simulasi ESP32-01 (Bun + TS)

  bun src/bot_mock.ts --mode live [--fast] [--interval 30]
  bun src/bot_mock.ts --mode live --once [--dry-run]
  bun src/bot_mock.ts --mode backfill --days 7 [--only petak-01,petak-02]
  bun src/bot_mock.ts --mode cleanup --days 1 --yes

Opsi:
  --mode live|backfill|cleanup   default live
  --days N        backfill/cleanup: rentang hari (1-30, default 7)
  --interval N    detik antar tick live (5-3600, default 30)
  --fast          shortcut --interval 10 (demo biar gauge cepat gerak)
  --only A,B      batasi petak (default semua 6)
  --once          live sekali tick lalu keluar (buat cron/tes)
  --dry-run       cetak payload, JANGAN tulis ke Supabase
  --no-faults     matikan injeksi SENSOR ERROR (demo bersih ke petani)
  --yes           konfirmasi cleanup tanpa tanya (wajib buat cleanup)
`);
}

// ---------- Supabase REST (fetch mentah, mirip HTTPClient firmware) ----------
let BASE = "";
let APIKEY = "";
function headers(preferMinimal = false): Record<string, string> {
  const h: Record<string, string> = {
    apikey: APIKEY,
    Authorization: `Bearer ${APIKEY}`,
    "Content-Type": "application/json",
  };
  if (preferMinimal) h["Prefer"] = "return=minimal";
  return h;
}
async function req(
  method: string,
  path: string,
  body?: unknown,
  preferMinimal = false,
): Promise<{ status: number; text: string }> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: headers(preferMinimal),
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(10_000),
  });
  const text = await res.text();
  return { status: res.status, text };
}
const DEFAULT_CFG: SystemConfig = {
  mode: "auto",
  thresholdDry: 30,
  thresholdWet: 70,
  valveDurationSec: 30,
  readIntervalSec: 1800,
  valid: false,
};
async function getSystemConfig(deviceId: string): Promise<SystemConfig> {
  try {
    const r = await req(
      "GET",
      `/system_config?device_id=eq.${deviceId}&select=*&limit=1`,
    );
    if (r.status !== 200) return { ...DEFAULT_CFG };
    const arr = JSON.parse(r.text) as Record<string, unknown>[];
    if (!Array.isArray(arr) || arr.length === 0) return { ...DEFAULT_CFG };
    const c = arr[0];
    return {
      mode: c["mode"] === "manual" ? "manual" : "auto",
      thresholdDry: Number(c["threshold_dry"] ?? 30),
      thresholdWet: Number(c["threshold_wet"] ?? 70),
      valveDurationSec: Number(c["valve_duration"] ?? 30),
      readIntervalSec: Number(c["read_interval"] ?? 1800),
      valid: true,
    };
  } catch {
    return { ...DEFAULT_CFG }; // fallback kayak firmware: WiFi gagal → default
  }
}
async function getPendingCommand(deviceId: string): Promise<PendingCommand> {
  try {
    const r = await req(
      "GET",
      `/pending_commands?device_id=eq.${deviceId}&status=eq.pending&select=*&order=created_at.asc&limit=1`,
    );
    if (r.status !== 200) return { id: 0, command: "", duration: 30, valid: false };
    const arr = JSON.parse(r.text) as Record<string, unknown>[];
    if (!Array.isArray(arr) || arr.length === 0) {
      return { id: 0, command: "", duration: 30, valid: false };
    }
    const c = arr[0];
    return {
      id: Number(c["id"]),
      command: String(c["command"] ?? ""),
      duration: Number(c["duration"] ?? 30),
      valid: true,
    };
  } catch {
    return { id: 0, command: "", duration: 30, valid: false };
  }
}
async function markCommandExecuted(id: number): Promise<boolean> {
  try {
    const r = await req(
      "PATCH",
      `/pending_commands?id=eq.${id}`,
      { status: "executed", executed_at: new Date().toISOString() },
      true,
    );
    return r.status >= 200 && r.status < 300;
  } catch {
    return false;
  }
}
interface ReadingRow {
  device_id: string;
  moisture: number;
  moisture_percent: number;
  valve_status: "ON" | "OFF";
  battery_voltage: number;
  created_at?: string;
}
async function postReadings(rows: ReadingRow[]): Promise<boolean> {
  const r = await req("POST", "/sensor_readings", rows, true);
  return r.status >= 200 && r.status < 300;
}
async function sendHeartbeat(): Promise<boolean> {
  try {
    const r = await req("POST", "/rpc/heartbeat", { _esp32_id: ESP32_ID });
    return r.status >= 200 && r.status < 300;
  } catch {
    return false;
  }
}

// ---------- Simulasi ----------
function initSim(petaks: PetakId[]): Record<string, SimState> {
  const s: Record<string, SimState> = {};
  for (const id of petaks) {
    s[id] = {
      pct: clamp(PROFILES[id].base + gauss() * 2, 5, 95),
      valve: { open: false, openedAt: 0, durationSec: 0 },
    };
  }
  return s;
}
function openValve(st: SimState, durationSec: number) {
  const d = clamp(Math.round(durationSec), 0, VALVE_MAX_SEC);
  // duration 0 = indefinite (firmware openValveIndefinitely, mode manual)
  st.valve = { open: true, openedAt: Date.now(), durationSec: d };
}
function closeValve(st: SimState) {
  st.valve = { open: false, openedAt: 0, durationSec: 0 };
}
function valveAutoClose(st: SimState, now: number): boolean {
  // Return true jika barusan auto-close.
  if (!st.valve.open || st.valve.durationSec <= 0) return false;
  if ((now - st.valve.openedAt) / 1000 >= st.valve.durationSec) {
    closeValve(st);
    return true;
  }
  return false;
}
function stepMoisture(
  id: PetakId,
  st: SimState,
  at: Date,
  intervalSec: number,
  noFaults: boolean,
): { raw: number; pct: number; fault: boolean } {
  const prof = PROFILES[id];
  // Target: base + ayunan harian + offset siang/malam, lalu kejar pelan-pelan.
  const target =
    prof.base + Math.sin(Date.now() / 3_600_000) * 1.5 + diurnalOffset(at);
  st.pct += (target - st.pct) * 0.15 + gauss() * prof.noise * 0.5;
  if (st.valve.open) {
    // Siram: naik sebanding durasi tick (≈ +3.5% per 30 dtk, mirip tetesan nyata).
    st.pct += 3.5 * (intervalSec / 30);
  } else {
    // Penguapan alami pelan.
    st.pct -= 0.15 * (intervalSec / 30);
  }
  st.pct = clamp(st.pct, 5, 95);
  // Injeksi fault langka: kabel putus/open circuit → ADC 4095 / ~0.
  if (!noFaults && Math.random() < 0.015) {
    const raw = Math.random() < 0.5 ? 4095 : 12;
    return { raw, pct: rawToPercent(raw), fault: true };
  }
  const raw = clamp(percentToRaw(st.pct), MIN_VALID_RAW, MAX_VALID_RAW);
  return { raw, pct: Math.round(rawToPercent(raw) * 10) / 10, fault: false };
}

// ---------- Mode: LIVE ----------
async function runLive(o: CliOpts) {
  const petaks = o.only;
  const sim = initSim(petaks);
  log(
    `bot_mock LIVE mulai — ESP32 ${ESP32_ID}, petak: ${petaks.join(", ")}, tick ${o.intervalSec}s${o.dryRun ? " (DRY-RUN)" : ""}`,
  );
  let tick = 0;
  let lastHeartbeat = 0;

  for (;;) {
    tick++;
    const now = new Date();
    try {
      // 1. Ambil config + perintah paralel (6 petak).
      const cfgs = await Promise.all(petaks.map((id) => getSystemConfig(id)));
      const cmds = await Promise.all(petaks.map((id) => getPendingCommand(id)));

      // 2. Eksekusi perintah dari app (VALVE_ON / VALVE_OFF).
      for (let i = 0; i < petaks.length; i++) {
        const id = petaks[i];
        const cmd = cmds[i];
        const cfg = cfgs[i];
        if (!cmd.valid) continue;
        if (o.dryRun) {
          log(`  ${id}: [dry-run] lewati perintah ${cmd.command} (${cmd.duration}s)`);
          continue;
        }
        if (cmd.command === "VALVE_ON") {
          if (cmd.duration === 0 && cfg.mode === "manual") openValve(sim[id], 0);
          else if (cmd.duration > 0) openValve(sim[id], cmd.duration);
          else openValve(sim[id], cfg.valveDurationSec);
          log(`  ${id}: eksekusi VALVE_ON (${cmd.duration}s) → valve TERBUKA`);
        } else if (cmd.command === "VALVE_OFF") {
          closeValve(sim[id]);
          log(`  ${id}: eksekusi VALVE_OFF → valve TERTUTUP`);
        } else {
          log(`  ${id}: perintah asing "${cmd.command}" diabaikan`);
          continue;
        }
        const ok = await markCommandExecuted(cmd.id);
        log(`  ${id}: tandai executed #${cmd.id} → ${ok ? "OK" : "GAGAL"}`);
      }

      // 3. Auto-close valve yang durasinya habis + logika auto firmware.
      for (let i = 0; i < petaks.length; i++) {
        const id = petaks[i];
        if (valveAutoClose(sim[id], Date.now())) {
          log(`  ${id}: valve auto-close (durasi habis)`);
        }
        const cfg = cfgs[i];
        const st = sim[id];
        if (
          cfg.mode === "auto" &&
          st.pct < cfg.thresholdDry &&
          !st.valve.open
        ) {
          openValve(st, cfg.valveDurationSec);
          log(
            `  ${id}: tanah kering (${st.pct.toFixed(1)}% < ${cfg.thresholdDry}%) → siram ${cfg.valveDurationSec}s`,
          );
        }
      }

      // 4. Generate + kirim readings batch.
      const rows: ReadingRow[] = petaks.map((id) => {
        const s = stepMoisture(id, sim[id], now, o.intervalSec, o.noFaults);
        if (s.fault) log(`  ${id}: injeksi SENSOR FAULT raw=${s.raw} (uji UI error)`);
        return {
          device_id: id,
          moisture: s.raw,
          moisture_percent: s.pct,
          valve_status: sim[id].valve.open ? "ON" : "OFF",
          battery_voltage: batteryVoltage(now),
        };
      });
      if (o.dryRun) {
        for (const r of rows) {
          log(
            `  [dry-run] ${r.device_id} raw=${r.moisture} pct=${r.moisture_percent}% valve=${r.valve_status} batt=${r.battery_voltage}V`,
          );
        }
      } else {
        const ok = await postReadings(rows);
        const summary = rows
          .map((r) => `${r.device_id.split("-")[1]}:${r.moisture_percent}%${r.valve_status === "ON" ? "↑" : ""}`)
          .join(" ");
        log(`tick #${tick}: POST sensor_readings (${rows.length}/${petaks.length}) → ${ok ? "OK" : "GAGAL"} | ${summary}`);
      }

      // 5. Heartbeat tiap 60 dtk (devices.last_seen → badge Online).
      if (!o.dryRun && Date.now() - lastHeartbeat >= HEARTBEAT_EVERY_MS) {
        lastHeartbeat = Date.now();
        const ok = await sendHeartbeat();
        log(`  heartbeat ${ESP32_ID} → ${ok ? "OK" : "GAGAL"}`);
      }
    } catch (e) {
      log(`tick #${tick} error: ${e instanceof Error ? e.message : String(e)} (lanjut tick berikutnya)`);
    }
    if (o.once) break;
    await Bun.sleep(o.intervalSec * 1000);
  }
  log("bot_mock LIVE selesai.");
}

// ---------- Mode: BACKFILL (isi grafik N hari ke belakang) ----------
async function runBackfill(o: CliOpts) {
  const petaks = o.only;
  const STEP_MIN = 30;
  const totalSteps = Math.floor((o.days * 24 * 60) / STEP_MIN);
  log(`bot_mock BACKFILL mulai — ${o.days} hari × ${petaks.length} petak (${totalSteps} titik/petak, tiap ${STEP_MIN} mnt)`);
  const sim = initSim(petaks);
  const start = Date.now() - o.days * 24 * 3600 * 1000;
  const allRows: ReadingRow[] = [];

  for (let step = 0; step < totalSteps; step++) {
    const at = new Date(start + step * STEP_MIN * 60 * 1000);
    for (const id of petaks) {
      const st = sim[id];
      // Auto-close berdasar waktu simulasi (bukan wall-clock).
      if (st.valve.open && st.valve.durationSec > 0) {
        const elapsed =
          (at.getTime() - (st as unknown as { _openedSim?: number })._openedSim!) / 1000;
        if (elapsed >= st.valve.durationSec) closeValve(st);
      }
      // Tiru threshold default (30/70) biar ada event siram di histori.
      if (!st.valve.open && st.pct < 30) {
        openValve(st, 30);
        (st as unknown as { _openedSim?: number })._openedSim = at.getTime();
      }
      const s = stepMoisture(id, st, at, STEP_MIN * 60, true); // backfill tanpa fault
      allRows.push({
        device_id: id,
        moisture: s.raw,
        moisture_percent: s.pct,
        valve_status: st.valve.open ? "ON" : "OFF",
        battery_voltage: batteryVoltage(at),
        created_at: at.toISOString(),
      });
    }
  }
  // Sisipkan 1 titik "sekarang" per petak biar badge Online + gauge fresh.
  const now = new Date();
  for (const id of petaks) {
    const s = stepMoisture(id, sim[id], now, 30, true);
    allRows.push({
      device_id: id,
      moisture: s.raw,
      moisture_percent: s.pct,
      valve_status: sim[id].valve.open ? "ON" : "OFF",
      battery_voltage: batteryVoltage(now),
      created_at: now.toISOString(),
    });
  }
  log(`  total ${allRows.length} baris akan dikirim (${petaks.length} petak × ${totalSteps + 1} titik)`);
  if (o.dryRun) {
    for (const r of allRows.slice(0, 5)) {
      log(`  [dry-run] ${r.device_id} ${r.created_at} raw=${r.moisture} pct=${r.moisture_percent}% valve=${r.valve_status}`);
    }
    log(`  [dry-run] ... +${allRows.length - 5} baris lagi (tidak dikirim)`);
    return;
  }
  const CHUNK = 100;
  let sent = 0;
  for (let i = 0; i < allRows.length; i += CHUNK) {
    const chunk = allRows.slice(i, i + CHUNK);
    const ok = await postReadings(chunk);
    if (!ok) {
      log(`  chunk ${i / CHUNK + 1} GAGAL — berhenti (cek koneksi/key). Terkirim ${sent}/${allRows.length}.`);
      process.exit(1);
    }
    sent += chunk.length;
    log(`  chunk ${i / CHUNK + 1}/${Math.ceil(allRows.length / CHUNK)} OK (${sent}/${allRows.length})`);
    await Bun.sleep(300); // jeda sopan buat Supabase free tier
  }
  await sendHeartbeat();
  log("bot_mock BACKFILL selesai — buka app, grafik 1H/1M harusnya penuh + badge Online.");
}

// ---------- Mode: CLEANUP (hapus data simulasi, hati-hati!) ----------
async function runCleanup(o: CliOpts) {
  if (!o.yes) {
    console.error("Mode cleanup butuh --yes (pengaman biar nggak kehapus nggak sengaja).");
    console.error("Contoh: bun src/bot_mock.ts --mode cleanup --days 1 --yes");
    process.exit(1);
  }
  const cutoff = new Date(Date.now() - o.days * 24 * 3600 * 1000).toISOString();
  const ids = o.only.join(",");
  log(`bot_mock CLEANUP: hapus sensor_readings ${ids} yang created_at >= ${cutoff}`);
  if (o.dryRun) {
    log("  [dry-run] tidak ada yang dihapus.");
    return;
  }
  try {
    const r = await req(
      "DELETE",
      `/sensor_readings?created_at=gte.${encodeURIComponent(cutoff)}&device_id=in.(${ids})`,
      undefined,
      true,
    );
    log(`  DELETE → HTTP ${r.status} ${r.status >= 200 && r.status < 300 ? "OK" : "GAGAL: " + r.text.slice(0, 200)}`);
  } catch (e) {
    log(`  cleanup error: ${e instanceof Error ? e.message : String(e)}`);
    process.exit(1);
  }
}

// ---------- Main ----------
async function main() {
  let opts: CliOpts;
  try {
    opts = parseArgs(Bun.argv.slice(2));
  } catch (e) {
    console.error(e instanceof Error ? e.message : String(e));
    printHelp();
    process.exit(1);
  }
  const { url, key } = await resolveEnv();
  if (!url || !key) {
    console.error("SUPABASE_URL / SUPABASE_ANON_KEY kosong.");
    console.error("Isi root .env (disarankan) atau tools/bot_mock/.env — contoh di .env.example.");
    process.exit(1);
  }
  BASE = url.replace(/\/$/, "") + "/rest/v1";
  APIKEY = key;
  log(`Supabase: ${url} — mode ${opts.mode}`);

  if (opts.mode === "live") await runLive(opts);
  else if (opts.mode === "backfill") await runBackfill(opts);
  else await runCleanup(opts);
}

await main();
