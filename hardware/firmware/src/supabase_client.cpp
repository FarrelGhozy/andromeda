#include "supabase_client.h"
#include "config.h"
#include <HTTPClient.h>
#include <ArduinoJson.h>

static String baseUrl = String(SUPABASE_URL) + "/rest/v1";
static String apiKey = SUPABASE_ANON_KEY;

static void addHeaders(HTTPClient& http) {
  http.addHeader("apikey", apiKey);
  http.addHeader("Authorization", "Bearer " + apiKey);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");
}

bool postAllSensorReadings(const AllReadings& allReadings, const bool* valveStates, const char* const* petakIds) {
  HTTPClient http;
  String url = baseUrl + "/sensor_readings";
  http.begin(url);
  addHeaders(http);

  StaticJsonDocument<1024> doc;
  JsonArray array = doc.to<JsonArray>();

  int validCount = 0;
  for (int i = 0; i < NUM_PETAK; i++) {
    if (!isSensorValid(allReadings.readings[i])) continue;

    JsonObject item = array.createNestedObject();
    item["device_id"] = petakIds[i];
    item["moisture"] = allReadings.readings[i].raw;
    item["moisture_percent"] = allReadings.readings[i].percent;
    item["valve_status"] = valveStates[i] ? "ON" : "OFF";
    validCount++;
  }

  if (validCount == 0) {
    Serial.println("No valid sensor readings to post");
    http.end();
    return true;
  }

  String payload;
  serializeJson(doc, payload);

  Serial.print("POST sensor_readings (");
  Serial.print(validCount);
  Serial.print("/");
  Serial.print(NUM_PETAK);
  Serial.print(" valid): ");
  Serial.println(payload);

  int code = http.POST(payload);
  Serial.print("Response code: ");
  Serial.println(code);

  http.end();
  return code >= 200 && code < 300;
}

SystemConfig getSystemConfig(const char* deviceId) {
  HTTPClient http;
  String url = baseUrl + "/system_config?device_id=eq." + String(deviceId) + "&select=*&limit=1";
  http.begin(url);
  addHeaders(http);

  int code = http.GET();
  SystemConfig cfg = { "auto", DEFAULT_THRESHOLD_DRY, DEFAULT_THRESHOLD_WET, DEFAULT_VALVE_DURATION_MS, DEFAULT_READ_INTERVAL_SEC, false };

  if (code == 200) {
    String response = http.getString();
    Serial.print("GET system_config for ");
    Serial.print(deviceId);
    Serial.print(": ");
    Serial.println(response);

    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, response);
    if (!err && doc.is<JsonArray>() && doc.size() > 0) {
      JsonObject obj = doc[0];
      cfg.mode = obj["mode"] | "auto";
      cfg.thresholdDry = obj["threshold_dry"] | DEFAULT_THRESHOLD_DRY;
      cfg.thresholdWet = obj["threshold_wet"] | DEFAULT_THRESHOLD_WET;
      cfg.valveDurationMs = (obj["valve_duration"] | 30) * 1000;
      cfg.readIntervalSec = obj["read_interval"] | DEFAULT_READ_INTERVAL_SEC;
      cfg.valid = true;
    }
  }

  http.end();
  return cfg;
}

PendingCommand getPendingCommand(const char* deviceId) {
  HTTPClient http;
  String url = baseUrl + "/pending_commands?device_id=eq." + String(deviceId)
             + "&status=eq.pending&select=*&order=created_at.asc&limit=1";
  http.begin(url);
  addHeaders(http);

  int code = http.GET();
  PendingCommand cmd = { 0, "", 0, false };

  if (code == 200) {
    String response = http.getString();
    Serial.print("GET pending_commands for ");
    Serial.print(deviceId);
    Serial.print(": ");
    Serial.println(response);

    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, response);
    if (!err && doc.is<JsonArray>() && doc.size() > 0) {
      JsonObject obj = doc[0];
      cmd.id = obj["id"];
      cmd.command = obj["command"] | "";
      cmd.duration = obj["duration"] | 30;
      cmd.valid = true;
    }
  }

  http.end();
  return cmd;
}

void markCommandExecuted(long commandId) {
  HTTPClient http;
  String url = baseUrl + "/pending_commands?id=eq." + String(commandId);
  http.begin(url);
  addHeaders(http);
  http.addHeader("Prefer", "return=minimal");

  StaticJsonDocument<128> doc;
  doc["status"] = "executed";

  String payload;
  serializeJson(doc, payload);

  int code = http.PATCH(payload);
  Serial.print("PATCH command status: ");
  Serial.println(code);

  http.end();
}

bool sendHeartbeat(const char* esp32Id) {
  HTTPClient http;
  String url = baseUrl + "/rpc/heartbeat";
  http.begin(url);
  addHeaders(http);

  StaticJsonDocument<128> doc;
  doc["_esp32_id"] = esp32Id;

  String payload;
  serializeJson(doc, payload);

  int code = http.POST(payload);
  Serial.print("Heartbeat (");
  Serial.print(esp32Id);
  Serial.print("): ");
  Serial.println(code);

  http.end();
  return code >= 200 && code < 300;
}
