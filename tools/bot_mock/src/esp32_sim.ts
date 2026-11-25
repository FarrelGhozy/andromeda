// ============================================================
// ANDROMEDA bot_mock — Runtime Virtual ESP32-01 (Non-Blocking)
// ------------------------------------------------------------
// Meniru arsitektur hardware/firmware/src/main.cpp:
//   1. Loop 1 dtk   : update timer valve + integrasi fisika air +
//                     immediate push feedback saat valve auto-close
//   2. Loop 5 dtk   : poll pending_commands + expiry check +
//                     eksekusi + PATCH executed + immediate push
//   3. Loop 60 dtk  : POST /rpc/heartbeat (devices.last_seen)
//   4. Loop 120 dtk : sync system_config (mode/threshold/interval)
//   5. Loop 30 mnt  : record sensor_readings terjadwal + auto-mode
// ============================================================

import {
  checkValveAutoClose,
  closeValveState,
  createInitialBattery,
  createInitialPetakStates,
  openValveState,
  PETAK_AGRONOMY,
  readSimulatedSensor,
  stepBatteryVoltage,
  stepSoilPhysics,
} from "./soil_physics";
import type { SupabaseApi } from "./supabase";
import {
  clamp,
  CONFIG_SYNC_EVERY_MS,
  createRng,
  DEFAULT_SYSTEM_CONFIG,
  ESP32_ID,
  HEARTBEAT_EVERY_MS,
  isValidRaw,
  log,
  MIN_SENSOR_INTERVAL_SEC,
  VALVE_CHANGE_DEBOUNCE_MS,
  type BatteryState,
  type CliOpts,
  type PetakId,
  type PetakSimState,
  type ReadingRow,
  type Rng,
  type SystemConfig,
  type WeatherSample,
} from "./types";
import type { WeatherEngine } from "./weather";

function formatWeatherBrief(w: WeatherSample): string {
  const rainTag = w.rainMmHr >= 0.35 ? ` hujan=${w.rainMmHr.toFixed(1)}mm/j` : "";
  return `T=${w.tempC.toFixed(1)}°C RH=${Math.round(w.rhPct)}% surya=${w.solarWm2}W/m²${rainTag}`;
}

export class Esp32Simulator {
  readonly petaks: readonly PetakId[];
  readonly opts: CliOpts;
  readonly supabase: SupabaseApi;
  readonly weather: WeatherEngine;
  readonly rng: Rng;

  readonly configs: Record<PetakId, SystemConfig>;
  readonly states: Record<PetakId, PetakSimState>;
  readonly battery: BatteryState;
  readonly prevValveStates: Record<PetakId, boolean>;

  private effectiveIntervalSec: number;
  private lastPhysicsMs = 0;
  private lastValvePushMs = 0;
  private cycleCount = 0;

  constructor(params: {
    opts: CliOpts;
    supabase: SupabaseApi;
    weather: WeatherEngine;
    nowMs?: number;
  }) {
    this.opts = params.opts;
    this.petaks = params.opts.only;
    this.supabase = params.supabase;
    this.weather = params.weather;
    this.rng = createRng(params.opts.seed);

    const startDate = new Date(params.nowMs ?? Date.now());
    this.states = createInitialPetakStates(this.petaks, this.rng);
    this.battery = createInitialBattery(startDate);
    this.configs = {} as Record<PetakId, SystemConfig>;
    this.prevValveStates = {} as Record<PetakId, boolean>;
    for (const id of this.petaks) {
      this.configs[id] = { ...DEFAULT_SYSTEM_CONFIG };
      this.prevValveStates[id] = false;
    }
    this.effectiveIntervalSec = params.opts.intervalSec;
    this.lastPhysicsMs = startDate.getTime();
  }

  get readIntervalSec(): number {
    return this.effectiveIntervalSec;
  }

  private openValveCount(): number {
    let n = 0;
    for (const id of this.petaks) {
      if (this.states[id].valve.open) n++;
    }
    return n;
  }

  private syncPrevValveStates(): void {
    for (const id of this.petaks) {
      this.prevValveStates[id] = this.states[id].valve.open;
    }
  }

  /**
   * Memajukan fisika tanah & baterai dari `lastPhysicsMs` sampai `nowMs`.
   */
  advancePhysicsTo(nowMs: number): WeatherSample {
    const at = new Date(nowMs);
    const w = this.weather.sampleAt(at);
    const dtSec = Math.max(0, (nowMs - this.lastPhysicsMs) / 1000);
    if (dtSec > 0) {
      for (const id of this.petaks) {
        stepSoilPhysics(id, this.states[id], w, at, dtSec, this.rng);
      }
      stepBatteryVoltage(
        this.battery,
        w,
        this.openValveCount(),
        dtSec,
        this.rng,
      );
      this.lastPhysicsMs = nowMs;
    }
    return w;
  }

  private buildReadingBatch(
    nowMs: number,
    w: WeatherSample,
    allowFaults: boolean,
  ): ReadingRow[] {
    const battV = stepBatteryVoltage(
      this.battery,
      w,
      this.openValveCount(),
      0,
      this.rng,
    );
    return this.petaks.map((id) => {
      const out = readSimulatedSensor(
        id,
        this.states[id],
        w,
        allowFaults,
        this.rng,
      );
      if (out.fault) {
        log(`  ${id}: injeksi SENSOR FAULT raw=${out.raw} (uji UI error)`);
      }
      return {
        device_id: id,
        moisture: out.raw,
        moisture_percent: out.pct,
        valve_status: this.states[id].valve.open ? "ON" : "OFF",
        battery_voltage: battV,
      };
    });
  }

  private async pushSnapshot(
    nowMs: number,
    reason: string,
    allowFaults: boolean,
  ): Promise<ReadingRow[]> {
    const w = this.advancePhysicsTo(nowMs);
    const rows = this.buildReadingBatch(nowMs, w, allowFaults);
    const summary = rows
      .map(
        (r) =>
          `${r.device_id.split("-")[1]}:${r.moisture_percent}%${r.valve_status === "ON" ? "↑" : ""}`,
      )
      .join(" ");

    if (this.opts.dryRun) {
      log(
        `  [dry-run] ${reason} | ${formatWeatherBrief(w)} | aki=${rows[0]?.battery_voltage ?? 0}V | ${summary}`,
      );
      return rows;
    }

    const ok = await this.supabase.postReadings(rows);
    log(
      `${reason} (${rows.length}/${this.petaks.length}) → ${ok ? "OK" : "GAGAL"} | ${formatWeatherBrief(w)} | aki=${rows[0]?.battery_voltage ?? 0}V | ${summary}`,
    );
    return rows;
  }

  /**
   * Sinkronisasi system_config seluruh petak dan perbarui interval record
   * jika CLI tidak mengunci `--interval` / `--fast`.
   */
  async syncConfigs(): Promise<void> {
    const fetched = await this.supabase.getAllSystemConfigs(this.petaks);
    let minDbInterval = 0;
    for (const id of this.petaks) {
      const cfg = fetched[id];
      if (cfg && cfg.valid) {
        this.configs[id] = cfg;
        if (cfg.readIntervalSec >= MIN_SENSOR_INTERVAL_SEC) {
          if (minDbInterval === 0 || cfg.readIntervalSec < minDbInterval) {
            minDbInterval = cfg.readIntervalSec;
          }
        }
      }
    }
    if (!this.opts.intervalPinned && minDbInterval >= MIN_SENSOR_INTERVAL_SEC) {
      if (minDbInterval !== this.effectiveIntervalSec) {
        log(
          `  config: read_interval berubah ${this.effectiveIntervalSec}s → ${minDbInterval}s (dari system_config)`,
        );
        this.effectiveIntervalSec = minDbInterval;
      }
    }
  }

  /**
   * Hidrasi kelembaban awal dari sensor_readings terakhir di Supabase agar
   * kurva grafik nyambung mulus tanpa lompatan setelah restart / backfill.
   */
  async hydrateFromSupabase(): Promise<void> {
    if (!this.opts.hydrate) return;
    const latest = await this.supabase.getLatestReadings(this.petaks);
    const hydrated: string[] = [];
    for (const id of this.petaks) {
      const r = latest[id];
      if (!r || !isValidRaw(r.moisture)) continue;
      this.states[id].rootPct = clamp(r.moisturePercent, 8, 92);
      hydrated.push(`${id.split("-")[1]}:${r.moisturePercent.toFixed(1)}%`);
    }
    if (hydrated.length > 0) {
      log(`  hidrasi state dari Supabase: ${hydrated.join(" ")}`);
    }
  }

  /**
   * Urutan boot selayaknya ESP32 setup():
   * init cuaca → sync config → hidrasi state → heartbeat awal → sensor push pertama.
   */
  async boot(nowMs = Date.now()): Promise<void> {
    this.lastPhysicsMs = nowMs;
    await this.weather.init(1);

    log(`ANDROMEDA virtual ESP32-01 mulai — ${ESP32_ID}`);
    log(`  petak      : ${this.petaks.join(", ")}`);
    log(`  cuaca      : ${this.weather.sourceLabel}`);
    log(
      `  jadwal     : sensor tiap ${this.effectiveIntervalSec}s (${(this.effectiveIntervalSec / 60).toFixed(1)} mnt${this.opts.intervalPinned ? ", pinned CLI" : ", ikut system_config"}), cmd poll ${this.opts.cmdPollSec}s, heartbeat 60s`,
    );
    log(
      `  opsi       : faults=${this.opts.faults ? "ON (petak-06)" : "OFF"}, hydrate=${this.opts.hydrate ? "ON" : "OFF"}${this.opts.dryRun ? ", DRY-RUN" : ""}`,
    );
    for (const id of this.petaks) {
      const a = PETAK_AGRONOMY[id];
      log(`    • ${id}: ${a.cropName} (${a.soilType})`);
    }

    await this.syncConfigs();
    await this.hydrateFromSupabase();
    await this.runHeartbeat();
    await this.pollAndExecuteCommands(nowMs);
    await this.runSensorPushCycle(nowMs);
  }

  /**
   * Tick 1 detik: update timer valve + integrasi fisika +
   * immediate push saat valve auto-close (selaras main.cpp step 1 & 1b).
   */
  async tickOneSecond(nowMs = Date.now()): Promise<boolean> {
    this.advancePhysicsTo(nowMs);

    const autoClosed: PetakId[] = [];
    for (const id of this.petaks) {
      if (checkValveAutoClose(this.states[id], nowMs)) {
        autoClosed.push(id);
      }
    }

    if (autoClosed.length > 0) {
      log(`  valve auto-close (durasi habis): ${autoClosed.join(", ")}`);
    }

    // Cek perubahan state valve dengan debounce 2 detik (sama dgn main.cpp step 1b)
    if (nowMs - this.lastValvePushMs >= VALVE_CHANGE_DEBOUNCE_MS) {
      let changed = false;
      for (const id of this.petaks) {
        if (this.states[id].valve.open !== this.prevValveStates[id]) {
          changed = true;
          break;
        }
      }
      if (changed) {
        this.lastValvePushMs = nowMs;
        this.syncPrevValveStates();
        await this.pushSnapshot(
          nowMs,
          "immediate push (valve state change)",
          false,
        );
        return true;
      }
    }
    return false;
  }

  /**
   * Poll pending_commands (selaras main.cpp step 3):
   * - tandai command basi (> 2× read_interval) sebagai expired
   * - segarkan system_config petak sebelum eksekusi
   * - jalankan VALVE_ON / VALVE_OFF
   * - kirim feedback #1: PATCH status=executed + executed_at
   * - kirim feedback #2: immediate POST sensor_readings
   */
  async pollAndExecuteCommands(nowMs = Date.now()): Promise<number> {
    const pending = await this.supabase.getPendingCommands(this.petaks);
    if (pending.length === 0) return 0;

    let executedCount = 0;

    for (const cmd of pending) {
      const id = cmd.deviceId;
      const cfg = this.configs[id] ?? DEFAULT_SYSTEM_CONFIG;
      const expiryWindowMs = 2 * cfg.readIntervalSec * 1000;

      // Guard command basi (selaras fix #20 di mobile_app)
      if (nowMs - cmd.createdAtMs > expiryWindowMs) {
        if (this.opts.dryRun) {
          log(
            `  ${id}: [dry-run] command #${cmd.id} (${cmd.command}) basi → tandai expired`,
          );
        } else {
          const ok = await this.supabase.markCommandExpired(cmd.id);
          log(
            `  ${id}: command #${cmd.id} (${cmd.command}) kedaluwarsa → expired (${ok ? "OK" : "GAGAL"})`,
          );
        }
        continue;
      }

      if (this.opts.dryRun) {
        log(
          `  ${id}: [dry-run] lewati perintah #${cmd.id} ${cmd.command} (${cmd.duration}s)`,
        );
        continue;
      }

      // Segarkan config petak sebelum eksekusi (agar mode manual/auto akurat)
      const freshCfg = await this.supabase.getSystemConfig(id);
      if (freshCfg.valid) {
        this.configs[id] = freshCfg;
      }
      const activeCfg = this.configs[id];

      this.advancePhysicsTo(nowMs);

      if (cmd.command === "VALVE_ON") {
        if (cmd.duration === 0 && activeCfg.mode === "manual") {
          openValveState(this.states[id], 0, nowMs, "manual");
          log(`  ${id}: eksekusi #${cmd.id} VALVE_ON (indefinite, mode manual) → TERBUKA`);
        } else if (cmd.duration > 0) {
          openValveState(this.states[id], cmd.duration, nowMs, "manual");
          log(
            `  ${id}: eksekusi #${cmd.id} VALVE_ON (${this.states[id].valve.durationSec}s) → TERBUKA`,
          );
        } else {
          openValveState(
            this.states[id],
            activeCfg.valveDurationSec,
            nowMs,
            "manual",
          );
          log(
            `  ${id}: eksekusi #${cmd.id} VALVE_ON (default ${this.states[id].valve.durationSec}s) → TERBUKA`,
          );
        }
      } else if (cmd.command === "VALVE_OFF") {
        closeValveState(this.states[id]);
        log(`  ${id}: eksekusi #${cmd.id} VALVE_OFF → TERTUTUP`);
      } else {
        log(`  ${id}: perintah tidak dikenal "${cmd.command}" (#${cmd.id}) diabaikan`);
        continue;
      }

      const marked = await this.supabase.markCommandExecuted(cmd.id);
      log(`  ${id}: feedback command #${cmd.id} executed → ${marked ? "OK" : "GAGAL"}`);

      this.syncPrevValveStates();
      this.lastValvePushMs = nowMs;
      await this.pushSnapshot(
        nowMs,
        `immediate push (after ${cmd.command} ${id})`,
        false,
      );
      executedCount++;
    }

    return executedCount;
  }

  /**
   * Siklus record sensor terjadwal (default tiap 30 menit / 1800 detik),
   * selaras main.cpp step 5 + evaluasi irigasi mode auto.
   */
  async runSensorPushCycle(nowMs = Date.now()): Promise<ReadingRow[]> {
    this.cycleCount++;
    await this.weather.refreshIfStale(nowMs);
    await this.syncConfigs();

    const w = this.advancePhysicsTo(nowMs);

    // Evaluasi mode auto pada semua petak (sama dgn main.cpp step 5)
    for (const id of this.petaks) {
      const cfg = this.configs[id];
      const st = this.states[id];
      if (
        cfg.mode === "auto" &&
        st.rootPct < cfg.thresholdDry &&
        !st.valve.open
      ) {
        openValveState(st, cfg.valveDurationSec, nowMs, "auto");
        log(
          `  ${id}: mode auto — tanah kering (${st.rootPct.toFixed(1)}% < ${cfg.thresholdDry}%, ${formatWeatherBrief(w)}) → buka valve ${st.valve.durationSec}s`,
        );
      }
    }

    this.syncPrevValveStates();
    this.lastValvePushMs = nowMs;
    return await this.pushSnapshot(
      nowMs,
      `cycle #${this.cycleCount} (sensor record)`,
      this.opts.faults,
    );
  }

  async runHeartbeat(): Promise<boolean> {
    if (this.opts.dryRun) return true;
    const ok = await this.supabase.sendHeartbeat(ESP32_ID);
    log(`  heartbeat ${ESP32_ID} → ${ok ? "OK" : "GAGAL"}`);
    return ok;
  }

  /**
   * Graceful shutdown: tutup semua valve terbuka (fail-safe solenoid NC)
   * dan kirim 1 snapshot OFF terakhir agar UI tidak tertahan di TERBUKA.
   */
  async shutdown(nowMs = Date.now()): Promise<void> {
    const openIds = this.petaks.filter((id) => this.states[id].valve.open);
    if (openIds.length > 0) {
      for (const id of openIds) closeValveState(this.states[id]);
      this.syncPrevValveStates();
      log(`shutdown: tutup valve fail-safe NC (${openIds.join(", ")})`);
      await this.pushSnapshot(nowMs, "shutdown push (NC fail-safe)", false);
    }
  }
}

// ---------- Mode: LIVE (Non-Blocking Multi-Timer Scheduler) ----------

export async function runLive(
  supabase: SupabaseApi,
  weather: WeatherEngine,
  opts: CliOpts,
): Promise<void> {
  const sim = new Esp32Simulator({ opts, supabase, weather });
  await sim.boot();
  if (opts.once) {
    log("bot_mock LIVE (--once) selesai.");
    return;
  }

  let stopping = false;
  const requestStop = (signal: string) => {
    if (stopping) return;
    stopping = true;
    log(`menerima ${signal} — menutup simulasi dengan aman...`);
  };
  process.on("SIGINT", () => requestStop("SIGINT"));
  process.on("SIGTERM", () => requestStop("SIGTERM"));

  const bootMs = Date.now();
  let lastCmdPollMs = bootMs;
  let lastHeartbeatMs = bootMs;
  let lastConfigSyncMs = bootMs;
  let lastSensorPushMs = bootMs;

  while (!stopping) {
    await Bun.sleep(1000);
    if (stopping) break;

    const nowMs = Date.now();
    try {
      // 1. Timer valve 1 dtk + integrasi fisika + auto-close immediate push
      await sim.tickOneSecond(nowMs);

      // 2. Poll perintah dari app (default tiap 5 dtk — independen dari 30 mnt)
      if (nowMs - lastCmdPollMs >= opts.cmdPollSec * 1000) {
        lastCmdPollMs = nowMs;
        await sim.pollAndExecuteCommands(nowMs);
      }

      // 3. Heartbeat tiap 60 dtk (devices.last_seen tetap segar → badge Online)
      if (nowMs - lastHeartbeatMs >= HEARTBEAT_EVERY_MS) {
        lastHeartbeatMs = nowMs;
        await sim.runHeartbeat();
      }

      // 4. Sync system_config tiap 120 dtk (mode/threshold/read_interval)
      if (nowMs - lastConfigSyncMs >= CONFIG_SYNC_EVERY_MS) {
        lastConfigSyncMs = nowMs;
        await sim.syncConfigs();
      }

      // 5. Siklus record sensor terjadwal (default 30 menit = 1800 detik)
      if (nowMs - lastSensorPushMs >= sim.readIntervalSec * 1000) {
        lastSensorPushMs = nowMs;
        lastConfigSyncMs = nowMs; // runSensorPushCycle sudah sync config
        await sim.runSensorPushCycle(nowMs);
      }
    } catch (e) {
      log(
        `loop error: ${e instanceof Error ? e.message : String(e)} (lanjut tick berikutnya)`,
      );
    }
  }

  await sim.shutdown();
  log("bot_mock LIVE berhenti dengan bersih.");
}

// ---------- Mode: BACKFILL (Histori realistis tiap 30 menit) ----------

export async function runBackfill(
  supabase: SupabaseApi,
  weather: WeatherEngine,
  opts: CliOpts,
): Promise<void> {
  const petaks = opts.only;
  const STEP_MIN = 30;
  const STEP_SEC = STEP_MIN * 60;
  const totalSteps = Math.floor((opts.days * 24 * 60) / STEP_MIN);

  await weather.init(opts.days + 1);
  const configs = await supabase.getAllSystemConfigs(petaks);

  log(
    `bot_mock BACKFILL mulai — ${opts.days} hari × ${petaks.length} petak (${totalSteps} titik/petak, tiap ${STEP_MIN} mnt)`,
  );
  log(`  cuaca: ${weather.sourceLabel}`);

  const rng = createRng(opts.seed);
  const startMs = Date.now() - opts.days * 24 * 3600 * 1000;
  const states = createInitialPetakStates(petaks, rng);
  const battery = createInitialBattery(new Date(startMs));
  const allRows: ReadingRow[] = [];

  let autoIrrigations = 0;
  let rainySteps = 0;

  for (let step = 0; step < totalSteps; step++) {
    const tMs = startMs + step * STEP_SEC * 1000;
    const at = new Date(tMs);
    const w = weather.sampleAt(at);
    if (w.rainMmHr >= 0.5) rainySteps++;

    // Cek auto-irrigation pada titik 30-menitan (simulasi durasi aktual, mis. 30 detik!)
    const triggered: Array<{ id: PetakId; durationSec: number }> = [];
    for (const id of petaks) {
      const cfg = configs[id] ?? DEFAULT_SYSTEM_CONFIG;
      if (cfg.mode === "auto" && states[id].rootPct < cfg.thresholdDry) {
        const dur = clamp(Math.round(cfg.valveDurationSec), 5, 120);
        openValveState(states[id], dur, tMs, "auto");
        triggered.push({ id, durationSec: dur });
        autoIrrigations++;
      }
    }

    // Catat titik terjadwal pada tMs
    const openCount = triggered.length;
    const battV = stepBatteryVoltage(battery, w, openCount, 0, rng);
    for (const id of petaks) {
      const s = readSimulatedSensor(id, states[id], w, false, rng);
      allRows.push({
        device_id: id,
        moisture: s.raw,
        moisture_percent: s.pct,
        valve_status: states[id].valve.open ? "ON" : "OFF",
        battery_voltage: battV,
        created_at: at.toISOString(),
      });
    }

    // Simulasikan fase valve terbuka (hanya beberapa puluh detik, BUKAN 30 menit!)
    // lalu lanjutkan sisa langkah 30 menit dalam kondisi valve tertutup.
    if (triggered.length > 0) {
      const maxDur = Math.max(...triggered.map((t) => t.durationSec));
      // Sub-step per 10 detik selama valve menyala agar durasi beda antar-petak akurat
      let elapsed = 0;
      while (elapsed < maxDur) {
        const chunk = Math.min(10, maxDur - elapsed);
        const midAt = new Date(tMs + elapsed * 1000);
        for (const id of petaks) {
          stepSoilPhysics(id, states[id], w, midAt, chunk, rng);
          checkValveAutoClose(states[id], tMs + (elapsed + chunk) * 1000);
        }
        stepBatteryVoltage(
          battery,
          w,
          petaks.filter((id) => states[id].valve.open).length,
          chunk,
          rng,
        );
        elapsed += chunk;
      }

      // Pastikan semua valve tertutup & catat titik immediate push pasca-siram
      const closeAt = new Date(tMs + maxDur * 1000);
      const closeBattV = stepBatteryVoltage(battery, w, 0, 0, rng);
      for (const t of triggered) {
        closeValveState(states[t.id]);
        const sAfter = readSimulatedSensor(t.id, states[t.id], w, false, rng);
        allRows.push({
          device_id: t.id,
          moisture: sAfter.raw,
          moisture_percent: sAfter.pct,
          valve_status: "OFF",
          battery_voltage: closeBattV,
          created_at: closeAt.toISOString(),
        });
      }

      // Sisa waktu menuju titik 30-menit berikutnya (valve OFF)
      const remSec = Math.max(0, STEP_SEC - maxDur);
      const midRestAt = new Date(tMs + (maxDur + remSec / 2) * 1000);
      const wMid = weather.sampleAt(midRestAt);
      for (const id of petaks) {
        stepSoilPhysics(id, states[id], wMid, midRestAt, remSec, rng);
      }
      stepBatteryVoltage(battery, wMid, 0, remSec, rng);
    } else {
      // Tidak ada irigasi: majukan fisika 30 menit penuh dengan cuaca di tengah interval
      const midAt = new Date(tMs + (STEP_SEC / 2) * 1000);
      const wMid = weather.sampleAt(midAt);
      for (const id of petaks) {
        stepSoilPhysics(id, states[id], wMid, midAt, STEP_SEC, rng);
      }
      stepBatteryVoltage(battery, wMid, 0, STEP_SEC, rng);
    }
  }

  // Sisipkan 1 titik "sekarang" per petak agar badge Online & gauge langsung segar
  const now = new Date();
  const wNow = weather.sampleAt(now);
  const battNow = stepBatteryVoltage(battery, wNow, 0, 0, rng);
  for (const id of petaks) {
    const s = readSimulatedSensor(id, states[id], wNow, false, rng);
    allRows.push({
      device_id: id,
      moisture: s.raw,
      moisture_percent: s.pct,
      valve_status: "OFF",
      battery_voltage: battNow,
      created_at: now.toISOString(),
    });
  }

  log(
    `  total ${allRows.length} baris siap (${autoIrrigations} event siram otomatis, ${rainySteps} slot hujan)`,
  );

  if (opts.dryRun) {
    for (const r of allRows.slice(0, 6)) {
      log(
        `  [dry-run] ${r.device_id} ${r.created_at} raw=${r.moisture} pct=${r.moisture_percent}% valve=${r.valve_status} batt=${r.battery_voltage}V`,
      );
    }
    log(`  [dry-run] ... +${Math.max(0, allRows.length - 6)} baris lagi (tidak dikirim)`);
    log("  [dry-run] sampel kondisi terakhir tiap petak:");
    for (const r of allRows.slice(-petaks.length)) {
      log(
        `    ${r.device_id}: ${r.moisture_percent}% (raw=${r.moisture}, batt=${r.battery_voltage}V)`,
      );
    }
    return;
  }

  const CHUNK = 100;
  let sent = 0;
  for (let i = 0; i < allRows.length; i += CHUNK) {
    const chunk = allRows.slice(i, i + CHUNK);
    const ok = await supabase.postReadings(chunk);
    if (!ok) {
      log(
        `  chunk ${i / CHUNK + 1} GAGAL — berhenti (cek koneksi/key). Terkirim ${sent}/${allRows.length}.`,
      );
      process.exit(1);
    }
    sent += chunk.length;
    log(
      `  chunk ${i / CHUNK + 1}/${Math.ceil(allRows.length / CHUNK)} OK (${sent}/${allRows.length})`,
    );
    await Bun.sleep(300);
  }
  await supabase.sendHeartbeat(ESP32_ID);
  log(
    "bot_mock BACKFILL selesai — buka app, grafik 1H/1M terisi pola realistis + badge Online.",
  );
}

// ---------- Mode: CLEANUP ----------

export async function runCleanup(
  supabase: SupabaseApi,
  opts: CliOpts,
): Promise<void> {
  if (!opts.yes) {
    console.error(
      "Mode cleanup butuh --yes (pengaman biar nggak kehapus nggak sengaja).",
    );
    console.error("Contoh: bun src/bot_mock.ts --mode cleanup --days 1 --yes");
    process.exit(1);
  }
  const cutoff = new Date(Date.now() - opts.days * 24 * 3600 * 1000).toISOString();
  log(
    `bot_mock CLEANUP: hapus sensor_readings ${opts.only.join(",")} yang created_at >= ${cutoff}`,
  );
  if (opts.dryRun) {
    log("  [dry-run] tidak ada yang dihapus.");
    return;
  }
  const res = await supabase.deleteReadingsSince(opts.only, cutoff);
  log(
    `  DELETE → HTTP ${res.status} ${res.ok ? "OK" : "GAGAL: " + res.detail}`,
  );
  if (!res.ok) process.exit(1);
}
