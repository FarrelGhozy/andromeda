import 'dart:async';

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
          if (offline) OfflineBanner(cachedAt: provider.cacheAt),
          Expanded(
            child:
                !provider.hasLocation || _showSearch
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
  static const _debounceDuration = Duration(milliseconds: 400);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<WeatherLocation> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;
  bool _selectingLocation = false;
  String? _searchError;
  int _requestSerial = 0;

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _requestSerial++;
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _hasSearched = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _hasSearched = false;
      _searchError = null;
      _results = const [];
    });
    _debounce = Timer(_debounceDuration, () => _search(query));
  }

  Future<void> _search([String? submittedQuery]) async {
    _debounce?.cancel();
    final query = (submittedQuery ?? _controller.text).trim();
    if (query.length < 2) return;

    final requestId = ++_requestSerial;
    if (!_searching) {
      setState(() {
        _searching = true;
        _searchError = null;
      });
    }
    try {
      final results = await context.read<WeatherProvider>().search(query);
      if (!mounted || requestId != _requestSerial) return;
      setState(() {
        _results = results;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted || requestId != _requestSerial) return;
      setState(() {
        _searchError =
            'Rekomendasi lokasi belum dapat dimuat. Periksa koneksi lalu coba lagi.';
        _results = const [];
        _hasSearched = true;
      });
    } finally {
      if (mounted && requestId == _requestSerial) {
        setState(() => _searching = false);
      }
    }
  }

  void _clearQuery() {
    _debounce?.cancel();
    _requestSerial++;
    _controller.clear();
    setState(() {
      _results = const [];
      _searching = false;
      _hasSearched = false;
      _searchError = null;
    });
    _focusNode.requestFocus();
  }

  Future<void> _selectLocation(WeatherLocation location) async {
    if (_selectingLocation) return;
    _selectingLocation = true;
    _debounce?.cancel();
    _requestSerial++;
    _focusNode.unfocus();
    HapticFeedback.selectionClick();

    final save = context.read<WeatherProvider>().saveLocation(location);
    // Lokasi di provider berubah sinkron, jadi pindah ke prakiraan tanpa
    // menunggu permintaan jaringan selesai.
    widget.onBack();
    try {
      await save;
    } catch (_) {
      // Kegagalan prakiraan sudah ditangani WeatherProvider.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final query = _controller.text.trim();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.tertiary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.cloud_outlined,
                  color: colors.onTertiary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temukan lokasi lahan',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Pilih lokasi yang paling dekat agar prakiraan cuaca '
                      'dan saran penyiraman lebih akurat.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (widget.showBack) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lokasi aktif',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.read<WeatherProvider>().location?.displayName ??
                            '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: widget.onBack,
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text('Cari lokasi', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          'Ketik minimal 2 huruf. Rekomendasi akan muncul otomatis.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          keyboardType: TextInputType.streetAddress,
          autocorrect: false,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: 'Desa, kecamatan, atau kota',
            prefixIcon: const Icon(Icons.search),
            suffixIcon:
                _searching
                    ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : query.isNotEmpty
                    ? IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clearQuery,
                    )
                    : null,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _buildSearchState(theme, query),
        ),
      ],
    );
  }

  Widget _buildSearchState(ThemeData theme, String query) {
    final colors = theme.colorScheme;

    if (query.isEmpty) {
      return const _SearchTips(key: ValueKey('tips'));
    }
    if (query.length < 2) {
      return Padding(
        key: const ValueKey('minimum-query'),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Ketik satu huruf lagi untuk mulai mencari.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (_searching) {
      return Container(
        key: const ValueKey('loading'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mencari lokasi yang cocok...',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    if (_searchError != null) {
      return Container(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wifi_off_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _searchError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onErrorContainer,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Coba lagi',
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              color: colors.onErrorContainer,
            ),
          ],
        ),
      );
    }
    if (_results.isNotEmpty) {
      return Column(
        key: const ValueKey('results'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Row(
              children: [
                Text('Rekomendasi lokasi', style: theme.textTheme.labelLarge),
                const Spacer(),
                Text(
                  '${_results.length} hasil',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < _results.length; index++) ...[
                  _LocationSuggestionTile(
                    location: _results[index],
                    onTap: () => _selectLocation(_results[index]),
                  ),
                  if (index != _results.length - 1)
                    Divider(
                      height: 1,
                      indent: 64,
                      color: colors.outlineVariant,
                    ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    if (_hasSearched) {
      return Container(
        key: const ValueKey('empty'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.location_off_outlined,
              color: colors.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text('Lokasi belum ditemukan', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Coba nama kecamatan atau kota terdekat, misalnya '
              '“Ponorogo, Jawa Timur”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _SearchTips extends StatelessWidget {
  const _SearchTips({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agar hasil lebih tepat', style: theme.textTheme.labelLarge),
          const SizedBox(height: 12),
          const _SearchTip(
            icon: Icons.signpost_outlined,
            text: 'Gunakan nama desa, kecamatan, atau kota terdekat.',
          ),
          const SizedBox(height: 10),
          const _SearchTip(
            icon: Icons.map_outlined,
            text: 'Tambahkan provinsi bila ada beberapa lokasi bernama sama.',
          ),
        ],
      ),
    );
  }
}

class _SearchTip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SearchTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationSuggestionTile extends StatelessWidget {
  final WeatherLocation location;
  final VoidCallback onTap;

  const _LocationSuggestionTile({required this.location, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = location.searchSubtitle;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_outlined,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
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
              title: Text(
                location.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: AppColors.offline,
                    ),
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
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
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
    final (label, icon) = WeatherService.describeWeatherCode(
      current.weatherCode,
    );

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
                _miniStat(
                  context,
                  Icons.water_drop_outlined,
                  '${current.humidity}%',
                  'Kelembaban',
                ),
                const SizedBox(width: 24),
                _miniStat(
                  context,
                  Icons.air,
                  '${current.windSpeed.toStringAsFixed(0)} km/j',
                  'Angin',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.accentBlue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
            const Icon(
              Icons.tips_and_updates_outlined,
              color: AppColors.primaryGreen,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rekomendasi irigasi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
    final isToday =
        day.date.year == now.year &&
        day.date.month == now.month &&
        day.date.day == now.day;

    String dayLabel;
    if (isToday) {
      dayLabel = 'Hari ini';
    } else {
      const days = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
        'Minggu',
      ];
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
              child: Text(
                dayLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(icon, color: AppColors.accentOrange, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (day.precipProbability > 0) ...[
              const Icon(
                Icons.water_drop,
                size: 14,
                color: AppColors.accentBlue,
              ),
              const SizedBox(width: 2),
              Text(
                '${day.precipProbability}%',
                style: theme.textTheme.bodySmall,
              ),
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
