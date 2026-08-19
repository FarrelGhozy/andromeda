/// Lokasi lahan yang DITENTUKAN petani secara manual (bukan GPS HP).
/// Disimpan lokal di SharedPreferences via LocalStore.
class WeatherLocation {
  final String name;
  final String? admin1;
  final String? admin2;
  final String country;
  final double lat;
  final double lon;
  final DateTime savedAt;

  WeatherLocation({
    required this.name,
    this.admin1,
    this.admin2,
    required this.country,
    required this.lat,
    required this.lon,
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  /// Nama lengkap yang tetap jelas saat ada beberapa daerah bernama sama.
  String get displayName =>
      _uniqueParts([name, admin2, admin1, country]).join(', ');

  /// Keterangan ringkas untuk daftar rekomendasi autocomplete.
  String get searchSubtitle =>
      _uniqueParts([admin2, admin1, country], excluding: name).join(', ');

  factory WeatherLocation.fromJson(Map<String, dynamic> json) =>
      WeatherLocation(
        name: json['name'] ?? '',
        admin1: json['admin1'] as String?,
        admin2: json['admin2'] as String?,
        country: json['country'] ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        savedAt:
            json['saved_at'] != null
                ? DateTime.parse(json['saved_at'])
                : DateTime.now(),
      );

  /// Memetakan respons Open-Meteo tanpa mencampur format penyimpanan lokal.
  factory WeatherLocation.fromGeocodingJson(Map<String, dynamic> json) =>
      WeatherLocation(
        name: json['name'] as String? ?? '',
        admin1: json['admin1'] as String?,
        admin2: json['admin2'] as String?,
        country: json['country'] as String? ?? '',
        lat: (json['latitude'] as num).toDouble(),
        lon: (json['longitude'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'admin1': admin1,
    'admin2': admin2,
    'country': country,
    'lat': lat,
    'lon': lon,
    'saved_at': savedAt.toIso8601String(),
  };
}

List<String> _uniqueParts(Iterable<String?> values, {String? excluding}) {
  final result = <String>[];
  final seen = <String>{};
  if (excluding != null) seen.add(excluding.trim().toLowerCase());

  for (final value in values) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty || !seen.add(clean.toLowerCase())) continue;
    result.add(clean);
  }
  return result;
}
