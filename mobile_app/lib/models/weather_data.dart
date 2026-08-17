/// Data cuaca dari Open-Meteo (gratis, tanpa API key).
/// Bisa diserialisasi ke JSON untuk cache offline (Fase 1).
class CurrentWeather {
  final double temperature; // °C
  final int humidity; // %
  final double windSpeed; // km/h
  final int weatherCode; // WMO code

  CurrentWeather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) => CurrentWeather(
        temperature: (json['temperature'] as num).toDouble(),
        humidity: (json['humidity'] as num).toInt(),
        windSpeed: (json['wind_speed'] as num).toDouble(),
        weatherCode: (json['weather_code'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'humidity': humidity,
        'wind_speed': windSpeed,
        'weather_code': weatherCode,
      };
}

class DailyWeather {
  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final int precipProbability; // %
  final double precipitation; // mm

  DailyWeather({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.precipProbability,
    required this.precipitation,
  });

  factory DailyWeather.fromJson(Map<String, dynamic> json) => DailyWeather(
        date: DateTime.parse(json['date']),
        weatherCode: (json['weather_code'] as num).toInt(),
        tempMax: (json['temp_max'] as num).toDouble(),
        tempMin: (json['temp_min'] as num).toDouble(),
        precipProbability: (json['precip_probability'] as num).toInt(),
        precipitation: (json['precipitation'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weather_code': weatherCode,
        'temp_max': tempMax,
        'temp_min': tempMin,
        'precip_probability': precipProbability,
        'precipitation': precipitation,
      };
}

class WeatherData {
  final CurrentWeather current;
  final List<DailyWeather> daily;
  final String irrigationAdvice;
  final DateTime fetchedAt;

  WeatherData({
    required this.current,
    required this.daily,
    required this.irrigationAdvice,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        current: CurrentWeather.fromJson(
            Map<String, dynamic>.from(json['current'])),
        daily: (json['daily'] as List)
            .map((d) => DailyWeather.fromJson(Map<String, dynamic>.from(d)))
            .toList(),
        irrigationAdvice: json['irrigation_advice'] ?? '',
        fetchedAt: DateTime.parse(json['fetched_at']),
      );

  Map<String, dynamic> toJson() => {
        'current': current.toJson(),
        'daily': daily.map((d) => d.toJson()).toList(),
        'irrigation_advice': irrigationAdvice,
        'fetched_at': fetchedAt.toIso8601String(),
      };
}
