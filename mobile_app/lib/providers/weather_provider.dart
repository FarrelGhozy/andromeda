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
  int _forecastRequestId = 0;

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
      _location = WeatherLocation.fromJson(Map<String, dynamic>.from(rawLoc));
    }
    final rawCache = await _store.getJson(LocalStore.weatherCacheKey);
    final rawCacheAt = await _store.getJson(LocalStore.weatherCacheAtKey);
    final rawCacheLocation = await _store.getJson(
      LocalStore.weatherCacheLocationKey,
    );
    final cacheMatchesLocation =
        rawCacheLocation == null ||
        _cacheBelongsToLocation(rawCacheLocation, _location);
    if (rawCache is Map && cacheMatchesLocation) {
      _data = WeatherData.fromJson(Map<String, dynamic>.from(rawCache));
      _cacheAt = DateTime.tryParse(rawCacheAt as String? ?? '');
    }
    notifyListeners();
    if (_location != null) await loadForecast();
  }

  Future<List<WeatherLocation>> search(String query) =>
      _service.searchLocation(query);

  /// Simpan lokasi pilihan petani + langsung ambil prakiraannya.
  Future<void> saveLocation(WeatherLocation location) async {
    final locationChanged =
        _location == null ||
        _location!.lat != location.lat ||
        _location!.lon != location.lon;
    _location = location;
    if (locationChanged) {
      // Jangan pernah menampilkan prakiraan lokasi lama di bawah nama baru.
      _forecastRequestId++;
      _data = null;
      _cacheAt = null;
      _loading = false;
      _error = null;
    }
    notifyListeners();
    await _store.setJson(LocalStore.weatherLocationKey, location.toJson());
    if (locationChanged) {
      await _store.remove(LocalStore.weatherCacheKey);
      await _store.remove(LocalStore.weatherCacheAtKey);
      await _store.remove(LocalStore.weatherCacheLocationKey);
    }
    if (_location?.lat != location.lat || _location?.lon != location.lon) {
      return;
    }
    await loadForecast();
  }

  /// Ambil prakiraan dari Open-Meteo; gagal (offline) → pakai cache.
  Future<void> loadForecast() async {
    final loc = _location;
    if (loc == null) return;
    final requestId = ++_forecastRequestId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final forecast = await _service.getForecast(loc.lat, loc.lon);
      if (requestId != _forecastRequestId) return;
      _data = forecast;
      _cacheAt = _data!.fetchedAt;
      await _store.setJson(LocalStore.weatherCacheKey, _data!.toJson());
      await _store.setJson(
        LocalStore.weatherCacheAtKey,
        _data!.fetchedAt.toIso8601String(),
      );
      await _store.setJson(LocalStore.weatherCacheLocationKey, {
        'lat': loc.lat,
        'lon': loc.lon,
      });
    } catch (_) {
      if (requestId != _forecastRequestId) return;
      // Offline / gagal → pertahankan _data dari cache (jika ada).
      _error =
          _data != null
              ? 'Gagal memuat cuaca — menampilkan data tersimpan.'
              : 'Gagal memuat cuaca. Periksa koneksi internet.';
    } finally {
      if (requestId == _forecastRequestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  bool _cacheBelongsToLocation(dynamic raw, WeatherLocation? location) {
    if (raw is! Map || location == null) return false;
    final map = Map<String, dynamic>.from(raw);
    final lat = map['lat'];
    final lon = map['lon'];
    if (lat is! num || lon is! num) return false;
    return (lat.toDouble() - location.lat).abs() < 0.000001 &&
        (lon.toDouble() - location.lon).abs() < 0.000001;
  }
}
