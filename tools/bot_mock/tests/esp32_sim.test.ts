import { describe, expect, test } from "bun:test";
import { parseArgs } from "../src/bot_mock";
import { Esp32Simulator, runBackfill } from "../src/esp32_sim";
import type { SupabaseApi } from "../src/supabase";
import {
  DEFAULT_CMD_POLL_SEC,
  DEFAULT_SENSOR_INTERVAL_SEC,
  DEFAULT_SYSTEM_CONFIG,
  PETAK_IDS,
  type CliOpts,
  type LatestReading,
  type PendingCommand,
  type PetakId,
  type ReadingRow,
  type SystemConfig,
} from "../src/types";
import { WeatherEngine } from "../src/weather";

class FakeSupabase implements SupabaseApi {
  configs: Record<PetakId, SystemConfig>;
  pendingCommands: PendingCommand[] = [];
  executedIds: number[] = [];
  expiredIds: number[] = [];
  postedBatches: ReadingRow[][] = [];
  heartbeats: string[] = [];
  latestReadings: Partial<Record<PetakId, LatestReading>> = {};

  constructor() {
    this.configs = {} as Record<PetakId, SystemConfig>;
    for (const id of PETAK_IDS) {
      this.configs[id] = { ...DEFAULT_SYSTEM_CONFIG, valid: true };
    }
  }

  async getAllSystemConfigs(
    petaks: readonly PetakId[],
  ): Promise<Record<PetakId, SystemConfig>> {
    const out = {} as Record<PetakId, SystemConfig>;
    for (const id of petaks) {
      out[id] = { ...this.configs[id] };
    }
    return out;
  }

  async getSystemConfig(deviceId: PetakId): Promise<SystemConfig> {
    return { ...this.configs[deviceId] };
  }

  async getPendingCommands(
    petaks: readonly PetakId[],
  ): Promise<PendingCommand[]> {
    const set = new Set<PetakId>(petaks);
    return this.pendingCommands.filter((c) => set.has(c.deviceId));
  }

  async markCommandExecuted(id: number): Promise<boolean> {
    this.executedIds.push(id);
    this.pendingCommands = this.pendingCommands.filter((c) => c.id !== id);
    return true;
  }

  async markCommandExpired(id: number): Promise<boolean> {
    this.expiredIds.push(id);
    this.pendingCommands = this.pendingCommands.filter((c) => c.id !== id);
    return true;
  }

  async getLatestReadings(
    petaks: readonly PetakId[],
  ): Promise<Partial<Record<PetakId, LatestReading>>> {
    const out: Partial<Record<PetakId, LatestReading>> = {};
    for (const id of petaks) {
      if (this.latestReadings[id]) out[id] = this.latestReadings[id];
    }
    return out;
  }

  async postReadings(rows: ReadingRow[]): Promise<boolean> {
    this.postedBatches.push(rows);
    return true;
  }

  async sendHeartbeat(esp32Id: string): Promise<boolean> {
    this.heartbeats.push(esp32Id);
    return true;
  }

  async deleteReadingsSince() {
    return { ok: true, status: 204, detail: "" };
  }
}

function makeOpts(overrides: Partial<CliOpts> = {}): CliOpts {
  return {
    mode: "live",
    days: 2,
    intervalSec: DEFAULT_SENSOR_INTERVAL_SEC,
    intervalPinned: false,
    cmdPollSec: DEFAULT_CMD_POLL_SEC,
    weatherMode: "synthetic",
    lat: -7.7956,
    lon: 110.3695,
    seed: 2026,
    hydrate: true,
    faults: false,
    dryRun: false,
    only: [...PETAK_IDS],
    once: false,
    yes: false,
    ...overrides,
  };
}

describe("CLI parseArgs", () => {
  test("default interval = 1800s (30 menit), cmd-poll = 5s, faults = false", () => {
    const opts = parseArgs([]);
    expect(opts.mode).toBe("live");
    expect(opts.intervalSec).toBe(1800);
    expect(opts.intervalPinned).toBe(false);
    expect(opts.cmdPollSec).toBe(5);
    expect(opts.weatherMode).toBe("auto");
    expect(opts.faults).toBe(false);
    expect(opts.hydrate).toBe(true);
  });

  test("--interval mengunci interval, --fast shortcut 30s/3s, --faults aktifkan fault", () => {
    const pinned = parseArgs(["--interval", "600", "--cmd-poll=8", "--faults"]);
    expect(pinned.intervalSec).toBe(600);
    expect(pinned.intervalPinned).toBe(true);
    expect(pinned.cmdPollSec).toBe(8);
    expect(pinned.faults).toBe(true);

    const fast = parseArgs(["--fast", "--weather", "synthetic", "--no-hydrate"]);
    expect(fast.intervalSec).toBe(30);
    expect(fast.intervalPinned).toBe(true);
    expect(fast.cmdPollSec).toBe(3);
    expect(fast.weatherMode).toBe("synthetic");
    expect(fast.hydrate).toBe(false);
  });
});

describe("Esp32Simulator — perilaku virtual ESP32-01 & feedback instan", () => {
  test("boot melakukan hidrasi valid (abaikan fault ADC), heartbeat awal, dan push awal", async () => {
    const supa = new FakeSupabase();
    supa.latestReadings["petak-01"] = {
      deviceId: "petak-01",
      moisture: 2040,
      moisturePercent: 55.0,
      valveStatus: "OFF",
      createdAtMs: Date.now() - 60_000,
    };
    supa.latestReadings["petak-06"] = {
      deviceId: "petak-06",
      moisture: 4095, // fault ADC → wajib diabaikan saat hidrasi
      moisturePercent: 0,
      valveStatus: "OFF",
      createdAtMs: Date.now() - 60_000,
    };

    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 42,
    });
    const sim = new Esp32Simulator({
      opts: makeOpts(),
      supabase: supa,
      weather,
      nowMs: new Date(2026, 7, 15, 9, 0, 0).getTime(),
    });

    await sim.boot(new Date(2026, 7, 15, 9, 0, 0).getTime());

    expect(sim.states["petak-01"].rootPct).toBeCloseTo(55.0, 0);
    expect(sim.states["petak-06"].rootPct).toBeGreaterThan(40); // tidak jadi 0%
    expect(supa.heartbeats).toEqual(["esp32-01"]);
    expect(supa.postedBatches.length).toBe(1);
    expect(supa.postedBatches[0].length).toBe(6);
  });

  test("VALVE_ON dieksekusi → PATCH executed + immediate push ON → auto-close 30s push OFF + moisture naik", async () => {
    const supa = new FakeSupabase();
    const startMs = new Date(2026, 7, 15, 11, 0, 0).getTime();
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 77,
    });
    const sim = new Esp32Simulator({
      opts: makeOpts({ hydrate: false }),
      supabase: supa,
      weather,
      nowMs: startMs,
    });

    await sim.boot(startMs);
    sim.states["petak-05"].rootPct = 40;
    const beforePct = sim.states["petak-05"].rootPct;
    const batchesAfterBoot = supa.postedBatches.length;

    // App mengirim perintah VALVE_ON 30 detik pada t+5s
    const cmdTime = startMs + 5_000;
    supa.pendingCommands.push({
      id: 101,
      deviceId: "petak-05",
      command: "VALVE_ON",
      duration: 30,
      createdAtMs: cmdTime - 1000,
      valid: true,
    });

    const executed = await sim.pollAndExecuteCommands(cmdTime);
    expect(executed).toBe(1);
    expect(supa.executedIds).toEqual([101]);
    expect(sim.states["petak-05"].valve.open).toBe(true);

    // Immediate push feedback #1: valve_status === "ON"
    expect(supa.postedBatches.length).toBe(batchesAfterBoot + 1);
    const onBatch = supa.postedBatches[supa.postedBatches.length - 1];
    const rowOn = onBatch.find((r) => r.device_id === "petak-05")!;
    expect(rowOn.valve_status).toBe("ON");

    // Simulasikan 30 detik berjalan (1 tick per detik)
    let pushedOnAutoClose = false;
    for (let s = 1; s <= 30; s++) {
      const pushed = await sim.tickOneSecond(cmdTime + s * 1000);
      if (pushed) pushedOnAutoClose = true;
    }

    expect(pushedOnAutoClose).toBe(true);
    expect(sim.states["petak-05"].valve.open).toBe(false);

    // Immediate push feedback #2 saat auto-close: valve_status === "OFF" & moisture naik!
    const offBatch = supa.postedBatches[supa.postedBatches.length - 1];
    const rowOff = offBatch.find((r) => r.device_id === "petak-05")!;
    expect(rowOff.valve_status).toBe("OFF");
    expect(rowOff.moisture_percent).toBeGreaterThan(beforePct + 6);
    // Tegangan aki pulih setelah solenoid tutup
    expect(rowOff.battery_voltage).toBeGreaterThan(rowOn.battery_voltage);
  });

  test("VALVE_ON duration=0 mode manual terbuka indefinite sampai VALVE_OFF", async () => {
    const supa = new FakeSupabase();
    supa.configs["petak-05"].mode = "manual";
    const startMs = new Date(2026, 7, 15, 10, 0, 0).getTime();
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 11,
    });
    const sim = new Esp32Simulator({
      opts: makeOpts({ hydrate: false }),
      supabase: supa,
      weather,
      nowMs: startMs,
    });
    await sim.boot(startMs);

    supa.pendingCommands.push({
      id: 201,
      deviceId: "petak-05",
      command: "VALVE_ON",
      duration: 0,
      createdAtMs: startMs + 1000,
      valid: true,
    });
    await sim.pollAndExecuteCommands(startMs + 2000);
    expect(sim.states["petak-05"].valve.open).toBe(true);
    expect(sim.states["petak-05"].valve.durationSec).toBe(0);

    // Setelah 150 detik tetap terbuka (indefinite)
    await sim.tickOneSecond(startMs + 152_000);
    expect(sim.states["petak-05"].valve.open).toBe(true);

    // Kirim VALVE_OFF → langsung tutup & immediate push OFF
    supa.pendingCommands.push({
      id: 202,
      deviceId: "petak-05",
      command: "VALVE_OFF",
      duration: 5,
      createdAtMs: startMs + 153_000,
      valid: true,
    });
    await sim.pollAndExecuteCommands(startMs + 154_000);
    expect(sim.states["petak-05"].valve.open).toBe(false);
    expect(supa.executedIds).toEqual([201, 202]);
    const lastRow = supa.postedBatches[supa.postedBatches.length - 1].find(
      (r) => r.device_id === "petak-05",
    )!;
    expect(lastRow.valve_status).toBe("OFF");
  });

  test("command basi (> 2× read_interval) ditandai expired & tidak membuka valve", async () => {
    const supa = new FakeSupabase();
    const nowMs = new Date(2026, 7, 15, 14, 0, 0).getTime();
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 19,
    });
    const sim = new Esp32Simulator({
      opts: makeOpts({ hydrate: false }),
      supabase: supa,
      weather,
      nowMs,
    });
    await sim.boot(nowMs);

    // Umur 3 jam (> 2 × 30 menit = 1 jam)
    supa.pendingCommands.push({
      id: 301,
      deviceId: "petak-01",
      command: "VALVE_ON",
      duration: 30,
      createdAtMs: nowMs - 3 * 3600_000,
      valid: true,
    });

    const executed = await sim.pollAndExecuteCommands(nowMs + 5000);
    expect(executed).toBe(0);
    expect(supa.expiredIds).toEqual([301]);
    expect(supa.executedIds).toEqual([]);
    expect(sim.states["petak-01"].valve.open).toBe(false);
  });

  test("siklus sensor 30 menit memicu irigasi otomatis saat petak kering (< threshold_dry)", async () => {
    const supa = new FakeSupabase();
    const startMs = new Date(2026, 7, 15, 13, 0, 0).getTime();
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 51,
    });
    const sim = new Esp32Simulator({
      opts: makeOpts({ hydrate: false }),
      supabase: supa,
      weather,
      nowMs: startMs,
    });

    sim.states["petak-02"].rootPct = 24.5; // di bawah threshold_dry 30%
    await sim.runSensorPushCycle(startMs);

    expect(sim.states["petak-02"].valve.open).toBe(true);
    expect(sim.states["petak-02"].valve.source).toBe("auto");
    const lastBatch = supa.postedBatches[supa.postedBatches.length - 1];
    expect(lastBatch.find((r) => r.device_id === "petak-02")?.valve_status).toBe(
      "ON",
    );
  });

  test("shutdown menutup valve terbuka (NC fail-safe) & mengirim snapshot OFF", async () => {
    const supa = new FakeSupabase();
    const startMs = new Date(2026, 7, 15, 12, 0, 0).getTime();
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 88,
    });
    const sim = new Esp32Simulator({
      opts: makeOpts({ hydrate: false }),
      supabase: supa,
      weather,
      nowMs: startMs,
    });
    await sim.boot(startMs);

    supa.pendingCommands.push({
      id: 401,
      deviceId: "petak-04",
      command: "VALVE_ON",
      duration: 60,
      createdAtMs: startMs + 1000,
      valid: true,
    });
    await sim.pollAndExecuteCommands(startMs + 2000);
    expect(sim.states["petak-04"].valve.open).toBe(true);

    await sim.shutdown(startMs + 10_000);
    expect(sim.states["petak-04"].valve.open).toBe(false);
    const finalBatch = supa.postedBatches[supa.postedBatches.length - 1];
    expect(
      finalBatch.find((r) => r.device_id === "petak-04")?.valve_status,
    ).toBe("OFF");
  });

  test("syncConfigs mengikuti system_config.read_interval jika tidak di-pin CLI", async () => {
    const supa = new FakeSupabase();
    supa.configs["petak-01"].readIntervalSec = 900; // 15 menit dari app
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 12,
    });

    const unpinned = new Esp32Simulator({
      opts: makeOpts({ intervalPinned: false }),
      supabase: supa,
      weather,
    });
    await unpinned.syncConfigs();
    expect(unpinned.readIntervalSec).toBe(900);

    const pinned = new Esp32Simulator({
      opts: makeOpts({ intervalSec: 1800, intervalPinned: true }),
      supabase: supa,
      weather,
    });
    await pinned.syncConfigs();
    expect(pinned.readIntervalSec).toBe(1800);
  });

  test("backfill menghasilkan histori 30-menit yang realistis & menyertakan heartbeat", async () => {
    const supa = new FakeSupabase();
    const weather = new WeatherEngine({
      mode: "synthetic",
      lat: -7.7956,
      lon: 110.3695,
      seed: 333,
    });

    await runBackfill(
      supa,
      weather,
      makeOpts({ mode: "backfill", days: 2, only: ["petak-01", "petak-02"] }),
    );

    const allRows = supa.postedBatches.flat();
    // 2 hari × 48 slot/hari × 2 petak = 192 + 2 titik now (+ opsional titik pasca-siram)
    expect(allRows.length).toBeGreaterThanOrEqual(194);
    expect(supa.heartbeats).toEqual(["esp32-01"]);

    // Pastikan tidak ada yang mentok artifisial 95% secara masif seperti bug lama
    const pct02 = allRows
      .filter((r) => r.device_id === "petak-02")
      .map((r) => r.moisture_percent);
    const maxPct02 = Math.max(...pct02);
    const minPct02 = Math.min(...pct02);
    expect(maxPct02).toBeLessThan(85);
    expect(minPct02).toBeGreaterThan(15);
    expect(maxPct02 - minPct02).toBeGreaterThan(8); // ada dinamika pengeringan/siram nyata
  });
});
