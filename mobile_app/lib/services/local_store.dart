import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper SharedPreferences — SEMUA penyimpanan lokal app lewat sini:
/// lokasi cuaca, jurnal petani, cache snapshot offline.
/// Key constants terpusat supaya tidak ada string ajaib tersebar.
class LocalStore {
  // --- Cache snapshot offline (Fase 0) ---
  static const String cacheDevicesKey = 'cache_devices';
  static const String cacheReadingsKey = 'cache_readings';
  static const String cacheSavedAtKey = 'cache_saved_at';

  // --- Cuaca (Fase 1) ---
  static const String weatherLocationKey = 'weather_location';
  static const String weatherCacheKey = 'weather_cache';
  static const String weatherCacheAtKey = 'weather_cache_at';

  // --- Jurnal (Fase 2) ---
  static const String journalEntriesKey = 'journal_entries';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> setJson(String key, dynamic value) async {
    final prefs = await _prefs;
    await prefs.setString(key, jsonEncode(value));
  }

  Future<dynamic> getJson(String key) async {
    final prefs = await _prefs;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _prefs;
    await prefs.remove(key);
  }
}
