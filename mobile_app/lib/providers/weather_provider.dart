import 'package:flutter/material.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/local_store.dart';

/// State fitur cuaca: lokasi lahan (persisten lokal) + data prakiraan.
/// Cache forecast terakhir di SharedPreferences agar tetap bisa dibaca
/// saat offline (Fase 0/1 — offline mode).
class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;
  final LocalStore _store;

  WeatherLocation? _location;
  WeatherData? _data;
  DateTime? _cacheAt;
  bool _loading = false;
  String? _error;

  bool get hasLocation => _location != null;
  WeatherLocation? get location => _location;
  WeatherData? get data => _data;
  DateTime? get cacheAt => _cacheAt;
  bool get isLoading => _loading;
  String? get error => _error;

  WeatherProvider(this._service, this._store);

  /// Muat lokasi tersimpan + cache forecast dari SharedPreferences.
  Future<void> init() async {
    final rawLoc = await _store.getJson(LocalStore.weatherLocationKey);
    if (rawLoc is Map) {
      _location =
          WeatherLocation.fromJson(Map<String, dynamic>.from(rawLoc));
    }
    final rawCache = await _store.getJson(LocalStore.weatherCacheKey);
    final rawCacheAt = await _store.getJson(LocalStore.weatherCacheAtKey);
    if (rawCache is Map) {
      _data = WeatherData.fromJson(Map<String, dynamic>.from(rawCache));
      _cacheAt = DateTime.tryParse(rawCacheAt as String? ?? '');
    }
    notifyListeners();
  }

  Future<List<WeatherLocation>> search(String query) =>
      _service.searchLocation(query);

  /// Simpan lokasi pilihan petani + langsung ambil prakiraannya.
  Future<void> saveLocation(WeatherLocation location) async {
    _location = location;
    await _store.setJson(LocalStore.weatherLocationKey, location.toJson());
    notifyListeners();
    await loadForecast();
  }

  /// Ambil prakiraan dari Open-Meteo; gagal (offline) → pakai cache.
  Future<void> loadForecast() async {
    final loc = _location;
    if (loc == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _service.getForecast(loc.lat, loc.lon);
      _cacheAt = _data!.fetchedAt;
      await _store.setJson(
          LocalStore.weatherCacheKey, _data!.toJson());
      await _store.setJson(LocalStore.weatherCacheAtKey,
          _data!.fetchedAt.toIso8601String());
    } catch (_) {
      // Offline / gagal → pertahankan _data dari cache (jika ada).
      _error = _data != null
          ? 'Gagal memuat cuaca — menampilkan data tersimpan.'
          : 'Gagal memuat cuaca. Periksa koneksi internet.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
