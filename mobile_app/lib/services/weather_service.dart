import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/weather_location.dart';
import '../models/weather_data.dart';

/// Klien Open-Meteo — gratis, tanpa API key, tanpa registrasi.
/// Endpoint:
/// - Geocoding: https://geocoding-api.open-meteo.com/v1/search
/// - Forecast:  https://api.open-meteo.com/v1/forecast
class WeatherService {
  static const String _geocodingBase =
      'https://geocoding-api.open-meteo.com/v1/search';
  static const String _forecastBase = 'https://api.open-meteo.com/v1/forecast';

  /// Cari lokasi berdasarkan nama (geocoding GeoNames, bahasa Indonesia).
  Future<List<WeatherLocation>> searchLocation(String query) async {
    final uri = Uri.parse(_geocodingBase).replace(
      queryParameters: {
        'name': query,
        'count': '8',
        'language': 'id',
        'format': 'json',
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Gagal mencari lokasi (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];
    return results
        .map(
          (result) => WeatherLocation.fromGeocodingJson(
            Map<String, dynamic>.from(result as Map),
          ),
        )
        .where((location) => location.name.isNotEmpty)
        .toList();
  }

  /// Prakiraan cuaca 7 hari + kondisi saat ini.
  /// WAJIB `timezone=auto` — tanpa itu jam/tanggal bergeser dari WIB.
  Future<WeatherData> getForecast(double lat, double lon) async {
    final uri = Uri.parse(_forecastBase).replace(
      queryParameters: {
        'latitude': lat.toString(),
        'longitude': lon.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_probability_max,precipitation_sum',
        'timezone': 'auto',
        'forecast_days': '7',
      },
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Gagal mengambil cuaca (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>;

    final times = (daily['time'] as List).cast<String>();
    final codes = (daily['weather_code'] as List).cast<num>();
    final tMax = (daily['temperature_2m_max'] as List).cast<num>();
    final tMin = (daily['temperature_2m_min'] as List).cast<num>();
    final precipProb =
        (daily['precipitation_probability_max'] as List).cast<num>();
    final precip = (daily['precipitation_sum'] as List).cast<num>();

    final dailyList = <DailyWeather>[];
    for (var i = 0; i < times.length; i++) {
      dailyList.add(
        DailyWeather(
          date: DateTime.parse(times[i]),
          weatherCode: codes[i].toInt(),
          tempMax: tMax[i].toDouble(),
          tempMin: tMin[i].toDouble(),
          precipProbability: precipProb[i].toInt(),
          precipitation: precip[i].toDouble(),
        ),
      );
    }

    return WeatherData(
      current: CurrentWeather(
        temperature: (current['temperature_2m'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
      ),
      daily: dailyList,
      irrigationAdvice: _irrigationAdvice(dailyList),
    );
  }

  /// Rekomendasi irigasi sederhana berdasarkan prakiraan BESOK (indeks 1).
  String _irrigationAdvice(List<DailyWeather> daily) {
    if (daily.length < 2) {
      return 'Kondisi normal — pantau kelembaban tanah di aplikasi.';
    }
    final tomorrow = daily[1];
    if (tomorrow.precipProbability >= 60) {
      return 'Hujan diperkirakan besok (${tomorrow.precipProbability}%) — '
          'pertimbangkan TUNDA penyiraman agar air tidak mubazir.';
    }
    if (tomorrow.tempMax >= 33 && tomorrow.precipProbability < 20) {
      return 'Panas & kering besok (${tomorrow.tempMax.toStringAsFixed(0)}°C) — '
          'kelembaban tanah cepat turun, siapkan jadwal siram.';
    }
    return 'Kondisi normal — pantau kelembaban tanah di aplikasi.';
  }

  /// Map kode cuaca WMO → (label bahasa Indonesia, ikon).
  /// Dipakai untuk menampilkan cuaca yang mudah dipahami petani.
  static (String, IconData) describeWeatherCode(int code) {
    switch (code) {
      case 0:
        return ('Cerah', Icons.wb_sunny);
      case 1:
        return ('Sebagian cerah', Icons.wb_sunny);
      case 2:
        return ('Berawan', Icons.wb_cloudy);
      case 3:
        return ('Mendung', Icons.cloud);
      case 45:
      case 48:
        return ('Kabut', Icons.blur_on);
      case 51:
      case 53:
      case 55:
        return ('Gerimis', Icons.grain);
      case 56:
      case 57:
        return ('Gerimis beku', Icons.ac_unit);
      case 61:
      case 63:
      case 65:
        return ('Hujan', Icons.water_drop);
      case 66:
      case 67:
        return ('Hujan beku', Icons.ac_unit);
      case 71:
      case 73:
      case 75:
        return ('Salju', Icons.ac_unit);
      case 77:
        return ('Butiran salju', Icons.ac_unit);
      case 80:
      case 81:
      case 82:
        return ('Hujan deras', Icons.water_drop);
      case 85:
      case 86:
        return ('Hujan salju', Icons.ac_unit);
      case 95:
        return ('Badai petir', Icons.thunderstorm);
      case 96:
      case 99:
        return ('Badai petir & hujan es', Icons.thunderstorm);
      default:
        return ('Cuaca', Icons.cloud_outlined);
    }
  }
}
