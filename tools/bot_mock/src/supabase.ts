// ============================================================
// ANDROMEDA bot_mock — Klien Supabase REST (mirip supabase_client.cpp)
// ------------------------------------------------------------
// - Batch query system_config & pending_commands (hemat request)
// - Retry otomatis utk gangguan jaringan sementara / HTTP 5xx
// - Hidrasi reading terakhir saat startup agar grafik nyambung mulus
// - Interface SupabaseApi dapat di-mock penuh pada unit test
// ============================================================

import {
  DEFAULT_SYSTEM_CONFIG,
  MIN_SENSOR_INTERVAL_SEC,
  PETAK_IDS,
  type LatestReading,
  type PendingCommand,
  type PetakId,
  type ReadingRow,
  type SystemConfig,
} from "./types";

export interface SupabaseApi {
  getAllSystemConfigs(
    petaks: readonly PetakId[],
  ): Promise<Record<PetakId, SystemConfig>>;
  getSystemConfig(deviceId: PetakId): Promise<SystemConfig>;
  getPendingCommands(petaks: readonly PetakId[]): Promise<PendingCommand[]>;
  markCommandExecuted(id: number): Promise<boolean>;
  markCommandExpired(id: number): Promise<boolean>;
  getLatestReadings(
    petaks: readonly PetakId[],
  ): Promise<Partial<Record<PetakId, LatestReading>>>;
  postReadings(rows: ReadingRow[]): Promise<boolean>;
  sendHeartbeat(esp32Id: string): Promise<boolean>;
  deleteReadingsSince(
    petaks: readonly PetakId[],
    cutoffIso: string,
  ): Promise<{ ok: boolean; status: number; detail: string }>;
}

function isPetakId(v: unknown): v is PetakId {
  return typeof v === "string" && (PETAK_IDS as readonly string[]).includes(v);
}

function parseConfigRow(c: Record<string, unknown>): SystemConfig {
  const rawInterval = Number(c["read_interval"]);
  const readIntervalSec =
    Number.isFinite(rawInterval) && rawInterval >= MIN_SENSOR_INTERVAL_SEC
      ? Math.round(rawInterval)
      : DEFAULT_SYSTEM_CONFIG.readIntervalSec;

  return {
    mode: c["mode"] === "manual" ? "manual" : "auto",
    thresholdDry: Number(c["threshold_dry"] ?? DEFAULT_SYSTEM_CONFIG.thresholdDry),
    thresholdWet: Number(c["threshold_wet"] ?? DEFAULT_SYSTEM_CONFIG.thresholdWet),
    valveDurationSec: Number(
      c["valve_duration"] ?? DEFAULT_SYSTEM_CONFIG.valveDurationSec,
    ),
    readIntervalSec,
    valid: true,
  };
}

export class HttpSupabaseApi implements SupabaseApi {
  private readonly baseUrl: string;
  private readonly apiKey: string;

  constructor(supabaseUrl: string, apiKey: string) {
    this.baseUrl = supabaseUrl.replace(/\/$/, "") + "/rest/v1";
    this.apiKey = apiKey;
  }

  private headers(preferMinimal = false): Record<string, string> {
    const h: Record<string, string> = {
      apikey: this.apiKey,
      Authorization: `Bearer ${this.apiKey}`,
      "Content-Type": "application/json",
    };
    if (preferMinimal) h["Prefer"] = "return=minimal";
    return h;
  }

  private async req(
    method: string,
    path: string,
    body?: unknown,
    preferMinimal = false,
    maxRetries = 1,
  ): Promise<{ status: number; text: string }> {
    let lastErr: unknown;
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        const res = await fetch(`${this.baseUrl}${path}`, {
          method,
          headers: this.headers(preferMinimal),
          body: body === undefined ? undefined : JSON.stringify(body),
          signal: AbortSignal.timeout(10_000),
        });
        const text = await res.text();
        if (res.status >= 500 && attempt < maxRetries) {
          await Bun.sleep(400 * (attempt + 1));
          continue;
        }
        return { status: res.status, text };
      } catch (e) {
        lastErr = e;
        if (attempt < maxRetries) {
          await Bun.sleep(400 * (attempt + 1));
          continue;
        }
      }
    }
    throw lastErr instanceof Error ? lastErr : new Error(String(lastErr));
  }

  async getAllSystemConfigs(
    petaks: readonly PetakId[],
  ): Promise<Record<PetakId, SystemConfig>> {
    const result = {} as Record<PetakId, SystemConfig>;
    for (const id of petaks) {
      result[id] = { ...DEFAULT_SYSTEM_CONFIG };
    }
    try {
      const ids = petaks.join(",");
      const r = await this.req(
        "GET",
        `/system_config?device_id=in.(${ids})&select=*`,
        undefined,
        false,
        1,
      );
      if (r.status !== 200) return result;
      const arr = JSON.parse(r.text) as Record<string, unknown>[];
      if (!Array.isArray(arr)) return result;
      for (const row of arr) {
        const id = row["device_id"];
        if (isPetakId(id)) {
          result[id] = parseConfigRow(row);
        }
      }
    } catch {
      // Fallback ke DEFAULT_SYSTEM_CONFIG (seperti firmware saat jaringan gagal)
    }
    return result;
  }

  async getSystemConfig(deviceId: PetakId): Promise<SystemConfig> {
    try {
      const r = await this.req(
        "GET",
        `/system_config?device_id=eq.${deviceId}&select=*&limit=1`,
        undefined,
        false,
        1,
      );
      if (r.status !== 200) return { ...DEFAULT_SYSTEM_CONFIG };
      const arr = JSON.parse(r.text) as Record<string, unknown>[];
      if (!Array.isArray(arr) || arr.length === 0) {
        return { ...DEFAULT_SYSTEM_CONFIG };
      }
      return parseConfigRow(arr[0]);
    } catch {
      return { ...DEFAULT_SYSTEM_CONFIG };
    }
  }

  async getPendingCommands(
    petaks: readonly PetakId[],
  ): Promise<PendingCommand[]> {
    try {
      const ids = petaks.join(",");
      const r = await this.req(
        "GET",
        `/pending_commands?device_id=in.(${ids})&status=eq.pending&select=*&order=created_at.asc`,
        undefined,
        false,
        0,
      );
      if (r.status !== 200) return [];
      const arr = JSON.parse(r.text) as Record<string, unknown>[];
      if (!Array.isArray(arr)) return [];

      const out: PendingCommand[] = [];
      for (const row of arr) {
        const id = row["device_id"];
        if (!isPetakId(id)) continue;
        const createdMs = Date.parse(String(row["created_at"] ?? ""));
        out.push({
          id: Number(row["id"]),
          deviceId: id,
          command: String(row["command"] ?? ""),
          duration: Number(row["duration"] ?? 30),
          createdAtMs: Number.isFinite(createdMs) ? createdMs : Date.now(),
          valid: true,
        });
      }
      return out;
    } catch {
      return [];
    }
  }

  async markCommandExecuted(id: number): Promise<boolean> {
    try {
      const r = await this.req(
        "PATCH",
        `/pending_commands?id=eq.${id}`,
        { status: "executed", executed_at: new Date().toISOString() },
        true,
        2,
      );
      return r.status >= 200 && r.status < 300;
    } catch {
      return false;
    }
  }

  async markCommandExpired(id: number): Promise<boolean> {
    try {
      const r = await this.req(
        "PATCH",
        `/pending_commands?id=eq.${id}`,
        { status: "expired" },
        true,
        1,
      );
      return r.status >= 200 && r.status < 300;
    } catch {
      return false;
    }
  }

  async getLatestReadings(
    petaks: readonly PetakId[],
  ): Promise<Partial<Record<PetakId, LatestReading>>> {
    const out: Partial<Record<PetakId, LatestReading>> = {};
    const wanted = new Set<string>(petaks);

    // Jalur cepat: RPC get_latest_readings (1 request untuk semua petak)
    try {
      const r = await this.req("POST", "/rpc/get_latest_readings", {}, false, 1);
      if (r.status === 200) {
        const arr = JSON.parse(r.text) as Record<string, unknown>[];
        if (Array.isArray(arr)) {
          for (const row of arr) {
            const id = row["device_id"];
            if (!isPetakId(id) || !wanted.has(id)) continue;
            const createdMs = Date.parse(String(row["created_at"] ?? ""));
            out[id] = {
              deviceId: id,
              moisture: Number(row["moisture"] ?? 0),
              moisturePercent: Number(row["moisture_percent"] ?? 0),
              valveStatus: row["valve_status"] === "ON" ? "ON" : "OFF",
              createdAtMs: Number.isFinite(createdMs) ? createdMs : Date.now(),
            };
          }
          return out;
        }
      }
    } catch {
      // Lanjut fallback query langsung
    }

    // Fallback: GET 1 baris terakhir per petak secara paralel
    await Promise.all(
      petaks.map(async (id) => {
        try {
          const r = await this.req(
            "GET",
            `/sensor_readings?device_id=eq.${id}&select=device_id,moisture,moisture_percent,valve_status,created_at&order=created_at.desc&limit=1`,
            undefined,
            false,
            0,
          );
          if (r.status !== 200) return;
          const arr = JSON.parse(r.text) as Record<string, unknown>[];
          if (!Array.isArray(arr) || arr.length === 0) return;
          const row = arr[0];
          const createdMs = Date.parse(String(row["created_at"] ?? ""));
          out[id] = {
            deviceId: id,
            moisture: Number(row["moisture"] ?? 0),
            moisturePercent: Number(row["moisture_percent"] ?? 0),
            valveStatus: row["valve_status"] === "ON" ? "ON" : "OFF",
            createdAtMs: Number.isFinite(createdMs) ? createdMs : Date.now(),
          };
        } catch {
          // Abaikan jika gagal
        }
      }),
    );
    return out;
  }

  async postReadings(rows: ReadingRow[]): Promise<boolean> {
    if (rows.length === 0) return true;
    try {
      const r = await this.req("POST", "/sensor_readings", rows, true, 2);
      return r.status >= 200 && r.status < 300;
    } catch {
      return false;
    }
  }

  async sendHeartbeat(esp32Id: string): Promise<boolean> {
    try {
      const r = await this.req(
        "POST",
        "/rpc/heartbeat",
        { _esp32_id: esp32Id },
        false,
        1,
      );
      return r.status >= 200 && r.status < 300;
    } catch {
      return false;
    }
  }

  async deleteReadingsSince(
    petaks: readonly PetakId[],
    cutoffIso: string,
  ): Promise<{ ok: boolean; status: number; detail: string }> {
    const ids = petaks.join(",");
    const r = await this.req(
      "DELETE",
      `/sensor_readings?created_at=gte.${encodeURIComponent(cutoffIso)}&device_id=in.(${ids})`,
      undefined,
      true,
      0,
    );
    return {
      ok: r.status >= 200 && r.status < 300,
      status: r.status,
      detail: r.text.slice(0, 200),
    };
  }
}
