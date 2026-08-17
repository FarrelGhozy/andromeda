import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../models/weather_location.dart';
import '../models/weather_data.dart';
import '../providers/weather_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/weather_service.dart';
import '../widgets/offline_banner.dart';

/// Fitur Cuaca (Fase 1):
/// Petani menentukan lokasi lahan MANUAL (disimpan lokal, bukan GPS HP),
/// lalu melihat prakiraan 7 hari + rekomendasi irigasi dari Open-Meteo.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _showSearch = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeatherProvider>();
    final offline = context.watch<ConnectivityProvider>().isOffline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuaca'),
        actions: [
          if (provider.hasLocation)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Muat ulang cuaca',
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.loadForecast();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Offline & data dari cache → beri tahu umur data (Fase 0).
          if (offline && provider.cacheAt != null)
            OfflineBanner(cachedAt: provider.cacheAt),
          Expanded(
            child: !provider.hasLocation || _showSearch
                ? _SearchView(
                    showBack: provider.hasLocation,
                    onBack: () => setState(() => _showSearch = false),
                  )
                : _ForecastView(
                    onGantiLokasi: () => setState(() => _showSearch = true),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pencarian lokasi (geocoding Open-Meteo).
class _SearchView extends StatefulWidget {
  final bool showBack;
  final VoidCallback onBack;

  const _SearchView({required this.showBack, required this.onBack});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _controller = TextEditingController();
  List<WeatherLocation>? _results;
  bool _searching = false;
  String? _searchError;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await context.read<WeatherProvider>().search(q);
      if (!mounted) return;
      setState(() => _results = results);
      if (results.isEmpty) {
        setState(() => _searchError =
            'Lokasi tidak ditemukan. Coba nama kota/kecamatan terdekat.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Gagal mencari lokasi. Periksa koneksi internet.';
        _results = null;
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.showBack) ...[
          Text(
            'Lokasi saat ini:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.read<WeatherProvider>().location?.displayName ?? '',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Cari lokasi lahan Anda',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Tentukan lokasi secara manual agar prakiraan cuaca akurat '
          'untuk lahan Anda (tidak mengikuti lokasi HP).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Contoh: Banyuwangi, Ponorogo...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_searchError != null) ...[
          const SizedBox(height: 12),
          Text(
            _searchError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_results != null && _results!.isNotEmpty) ...[
          Text(
            'Hasil pencarian — pilih lokasi:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          ..._results!.map((loc) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.place_outlined,
                      color: AppColors.accentBlue),
                  title: Text(loc.name),
                  subtitle: Text(
                    [loc.admin1, loc.country]
                        .where((s) => s != null && s.isNotEmpty)
                        .join(', '),
                  ),
                  trailing: const Icon(Icons.check_circle_outline),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await context.read<WeatherProvider>().saveLocation(loc);
                    if (mounted) widget.onBack();
                  },
                ),
              )),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Tampilan prakiraan: lokasi + kondisi hari ini + rekomendasi + 7 hari.
class _ForecastView extends StatelessWidget {
  final VoidCallback onGantiLokasi;

  const _ForecastView({required this.onGantiLokasi});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<WeatherProvider>();
    final data = provider.data;
    final location = provider.location!;

    return RefreshIndicator(
      onRefresh: provider.loadForecast,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Lokasi + ganti
          Card(
            child: ListTile(
              leading: const Icon(Icons.place, color: AppColors.primaryGreen),
              title: Text(location.displayName,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                provider.cacheAt != null && data != null
                    ? 'Diperbarui ${_formatDayTime(provider.cacheAt!)}'
                    : 'Prakiraan cuaca 7 hari',
              ),
              trailing: TextButton.icon(
                onPressed: onGantiLokasi,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Ganti'),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (provider.isLoading && data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data == null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 48, color: AppColors.offline),
                    const SizedBox(height: 12),
                    Text(
                      provider.error ?? 'Belum ada data cuaca.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: provider.loadForecast,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            _TodayCard(current: data.current),
            const SizedBox(height: 12),
            _AdviceCard(advice: data.irrigationAdvice),
            const SizedBox(height: 16),
            Text('Prakiraan 7 hari', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...data.daily.map((d) => _DailyTile(day: d)),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  static String _formatDayTime(DateTime t) {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${days[t.weekday - 1]}, ${t.day} ${months[t.month - 1]} $hh:$mm';
  }
}

class _TodayCard extends StatelessWidget {
  final CurrentWeather current;

  const _TodayCard({required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = WeatherService.describeWeatherCode(current.weatherCode);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 64, color: AppColors.accentOrange),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${current.temperature.toStringAsFixed(0)}°C',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _miniStat(context, Icons.water_drop_outlined,
                    '${current.humidity}%', 'Kelembaban'),
                const SizedBox(width: 24),
                _miniStat(context, Icons.air, '${current.windSpeed.toStringAsFixed(0)} km/j',
                    'Angin'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.accentBlue),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final String advice;

  const _AdviceCard({required this.advice});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryGreen.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tips_and_updates_outlined,
                color: AppColors.primaryGreen, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rekomendasi irigasi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(advice),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyTile extends StatelessWidget {
  final DailyWeather day;

  const _DailyTile({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = WeatherService.describeWeatherCode(day.weatherCode);
    final now = DateTime.now();
    final isToday = day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;

    String dayLabel;
    if (isToday) {
      dayLabel = 'Hari ini';
    } else {
      const days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      dayLabel = days[day.date.weekday - 1];
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(dayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(icon, color: AppColors.accentOrange, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (day.precipProbability > 0) ...[
              const Icon(Icons.water_drop, size: 14, color: AppColors.accentBlue),
              const SizedBox(width: 2),
              Text('${day.precipProbability}%',
                  style: theme.textTheme.bodySmall),
              const SizedBox(width: 12),
            ],
            Text(
              '${day.tempMin.toStringAsFixed(0)}° / '
              '${day.tempMax.toStringAsFixed(0)}°',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
