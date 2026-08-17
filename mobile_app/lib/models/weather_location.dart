/// Lokasi lahan yang DITENTUKAN petani secara manual (bukan GPS HP).
/// Disimpan lokal di SharedPreferences via LocalStore.
class WeatherLocation {
  final String name;
  final String? admin1;
  final String country;
  final double lat;
  final double lon;
  final DateTime savedAt;

  WeatherLocation({
    required this.name,
    this.admin1,
    required this.country,
    required this.lat,
    required this.lon,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  /// Nama tampilan: "Banyuwangi, Jawa Timur, Indonesia".
  String get displayName => [
        name,
        admin1,
        country,
      ].where((s) => s != null && s.trim().isNotEmpty).join(', ');

  factory WeatherLocation.fromJson(Map<String, dynamic> json) =>
      WeatherLocation(
        name: json['name'] ?? '',
        admin1: json['admin1'] as String?,
        country: json['country'] ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        savedAt: json['saved_at'] != null
            ? DateTime.parse(json['saved_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'admin1': admin1,
        'country': country,
        'lat': lat,
        'lon': lon,
        'saved_at': savedAt.toIso8601String(),
      };
}
