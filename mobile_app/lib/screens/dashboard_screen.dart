import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../models/enums.dart';
import '../models/sensor_reading.dart';
import '../models/system_config.dart';
import '../widgets/moisture_gauge.dart';
import '../widgets/valve_button.dart';
import '../widgets/moisture_chart.dart';
import '../widgets/config_slider.dart';
import '../widgets/status_badge.dart';
import '../widgets/duration_picker.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';
import '../config/theme_config.dart';

class DashboardScreen extends StatefulWidget {
  final String deviceId;
  const DashboardScreen({super.key, required this.deviceId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Nilai slider lokal (agar drag tidak spam update ke server).
  // Disinkronkan dari config saat berubah (lihat _syncConfigLocals).
  double _dry = 30;
  double _wet = 70;
  double _duration = 30;
  double _intervalMin = 30;
  DateTime? _configVersion;

  // Durasi valve untuk tombol BUKA (dipilih via DurationPicker).
  int _selectedValveDuration = 0;

  void _syncConfigLocals(SystemConfig? config) {
    if (config == null) return;
    if (_configVersion != config.updatedAt) {
      _configVersion = config.updatedAt;
      _dry = config.thresholdDry.toDouble();
      _wet = config.thresholdWet.toDouble();
      _duration = config.valveDuration.toDouble();
      _intervalMin = config.readIntervalMinutes.toDouble();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDevice(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceId.toUpperCase().replaceAll('-', ' ')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<DashboardProvider>().loadDevice(widget.deviceId);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, _) {
          switch (provider.state) {
            case DashboardState.loading:
              return const ShimmerDashboard();
            case DashboardState.error:
              return ErrorBanner(
                message: provider.errorMessage ?? 'Terjadi kesalahan',
                onRetry: () => provider.loadDevice(widget.deviceId),
              );
            case DashboardState.ready:
              return _buildDashboard(context, provider);
          }
        },
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.loadDevice(widget.deviceId),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildGaugeSection(provider),
            const SizedBox(height: 16),
            _buildValveSection(provider),
            const SizedBox(height: 16),
            _buildChartSection(provider),
            const SizedBox(height: 16),
            _buildConfigSection(provider),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugeSection(DashboardProvider provider) {
    final reading = provider.latestReading;
    final percent = reading?.moisturePercent ?? 0;
    final fresh = provider.isFresh;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Kelembaban Tanah',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final gaugeSize = constraints.maxWidth < 300
                    ? constraints.maxWidth * 0.6
                    : 200.0;
                return MoistureGauge(
                  percent: percent,
                  size: gaugeSize,
                  showLabel: true,
                  greyedOut: !fresh,
                  fault: fresh && reading?.isSensorFault == true,
                  thresholdDry: provider.config?.thresholdDry ?? 30,
                  thresholdWet: provider.config?.thresholdWet ?? 70,
                );
              },
            ),
            const SizedBox(height: 16),
            if (fresh && reading?.isSensorFault == true) ...[
              Text(
                '⚠ Sensor bermasalah — periksa kabel sensor '
                '(ADC ${reading?.moisture ?? 0} di luar rentang valid '
                '${SensorReading.minValidRaw}–${SensorReading.maxValidRaw})',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoChip(Icons.sensors, 'ADC: ${reading?.moisture ?? 0}'),
                const SizedBox(width: 16),
                _infoChip(
                  Icons.access_time,
                  reading?.createdAt != null
                      ? DateFormat('HH:mm').format(reading!.createdAt)
                      : '—',
                ),
                if (reading?.batteryVoltage != null) ...[
                  const SizedBox(width: 16),
                  _infoChip(
                    Icons.battery_std,
                    '${reading!.batteryVoltage!.toStringAsFixed(1)}V',
                  ),
                ],
              ],
            ),
            if (!fresh) ...[
              const SizedBox(height: 8),
              Text(
                'Menunggu data terbaru dari perangkat…',
                style: TextStyle(
                  fontSize: 12,
                  // Fix #27: warna adaptif terhadap tema.
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Kirim perintah valve dengan feedback SnackBar (sukses/gagal).
  Future<void> _sendValve(
      DashboardProvider provider, String command, {int? duration}) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await provider.sendValveCommand(command,
        duration: duration ?? 30);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (command == 'VALVE_ON'
                  ? 'Perintah BUKA valve terkirim ✓'
                  : 'Perintah TUTUP valve terkirim ✓')
              : (provider.errorMessage ?? 'Gagal mengirim perintah'),
        ),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildValveSection(DashboardProvider provider) {
    final status = provider.valveDisplayStatus;
    // Fix #25: konvensi — hijau = aktif/terbuka, netral = tertutup,
    // abu-abu offline = tidak diketahui. Merah khusus bahaya (tombol TUTUP).
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    final (icon, label, color) = switch (status) {
      ValveDisplayStatus.open => (
          Icons.water_drop,
          'TERBUKA',
          AppColors.success,
        ),
      ValveDisplayStatus.closed => (
          Icons.water_drop_outlined,
          'TERTUTUP',
          neutral,
        ),
      ValveDisplayStatus.unknown => (
          Icons.help_outline,
          'TIDAK DIKETAHUI',
          AppColors.offline,
        ),
    };
    final isAuto = provider.config?.isAutoMode == true;
    final valveDuration = _selectedValveDuration > 0 ? _selectedValveDuration : 30;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Valve',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                StatusBadge(
                  text: isAuto ? 'Otomatis' : 'Manual',
                  color: isAuto ? AppColors.primaryGreen : AppColors.accentOrange,
                  fontSize: 11,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            if (status == ValveDisplayStatus.unknown) ...[
              const SizedBox(height: 2),
              Text(
                'Tidak ada data segar dari perangkat — status valve tidak diketahui',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ValveButton(
                    label: 'BUKA',
                    icon: Icons.play_arrow,
                    color: AppColors.success,
                    onPressed: (!provider.isValveOpen && !provider.sendingCommand)
                        ? () {
                            HapticFeedback.lightImpact();
                            _sendValve(provider, 'VALVE_ON',
                                duration: valveDuration);
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValveButton(
                    label: 'TUTUP',
                    icon: Icons.stop,
                    color: AppColors.danger,
                    // Fix #16: TUTUP selalu aktif (safety) — saat status
                    // tidak diketahui pun user boleh memaksa menutup.
                    onPressed: !provider.sendingCommand
                        ? () {
                            HapticFeedback.lightImpact();
                            _sendValve(provider, 'VALVE_OFF');
                          }
                        : null,
                  ),
                ),
              ],
            ),
            if (provider.sendingCommand) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            // Fix #18/#20: status perintah valve terbaru + countdown auto-OFF.
            if (provider.commandState != CommandState.idle) ...[
              const SizedBox(height: 12),
              _buildCommandStatus(provider),
            ],
            const SizedBox(height: 12),
            DurationPicker(
              selectedDuration: _selectedValveDuration,
              onSelected: (d) => setState(() => _selectedValveDuration = d),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandStatus(DashboardProvider provider) {
    final state = provider.commandState;
    final cmd = provider.latestCommand;
    final theme = Theme.of(context);

    final (label, color, icon) = switch (state) {
      CommandState.sending => (
          'Mengirim perintah…',
          AppColors.accentOrange,
          Icons.sync,
        ),
      CommandState.pending => (
          'Menunggu ESP32 mengeksekusi…',
          AppColors.accentOrange,
          Icons.hourglass_top,
        ),
      CommandState.executed => (
          cmd?.executedAt != null
              ? 'Dieksekusi ${DateFormat('HH:mm').format(cmd!.executedAt!)}'
              : 'Dieksekusi ESP32 ✓',
          AppColors.success,
          Icons.check_circle,
        ),
      CommandState.expired => (
          'Kedaluwarsa — ESP32 tidak merespons',
          AppColors.offline,
          Icons.timer_off,
        ),
      CommandState.cancelled => (
          'Dibatalkan',
          AppColors.offline,
          Icons.cancel,
        ),
      CommandState.idle => ('', AppColors.offline, Icons.circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ),
          // Fix #19: countdown auto-OFF fallback.
          if (state == CommandState.pending &&
              provider.autoOffRemaining > Duration.zero) ...[
            Text(
              'Auto-OFF ${provider.autoOffRemaining.inSeconds}s',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Fix #20: tombol batal untuk command pending.
          if (state == CommandState.pending)
            TextButton(
              onPressed: () async {
                final ok = await provider.cancelPendingCommand();
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'Perintah dibatalkan ✓'
                        : (provider.errorMessage ?? 'Gagal membatalkan')),
                    backgroundColor:
                        ok ? AppColors.success : AppColors.danger,
                    duration: const Duration(seconds: 3),
                  ));
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text('Batal', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }

  Widget _buildChartSection(DashboardProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Riwayat Kelembaban',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ChartRange.values.map((range) {
                      final selected = provider.selectedChartRange == range;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: ChoiceChip(
                          label: Text(range.label),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (_) => provider.setChartRange(range),
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : null,
                            fontSize: 12,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: provider.history.isNotEmpty
                  ? MoistureChart(
                      data: provider.history,
                      thresholdDry: provider.config?.thresholdDry ?? 30,
                      thresholdWet: provider.config?.thresholdWet ?? 70,
                    )
                  : Center(
                      child: Text(
                        'Belum ada data',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(DashboardProvider provider) {
    final config = provider.config;
    if (config == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'Konfigurasi belum tersedia',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    _syncConfigLocals(config);

    Future<void> _saveWithFeedback(
        DashboardProvider provider, SystemConfig updated) async {
      final messenger = ScaffoldMessenger.of(context);
      final ok = await provider.updateConfig(updated);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Konfigurasi tersimpan ✓' : (provider.errorMessage ?? 'Gagal menyimpan konfigurasi'),
          ),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    void saveConfig() {
      final updated = config.copyWith(
        thresholdDry: _dry.round(),
        thresholdWet: _wet.round(),
        valveDuration: _duration.round(),
        readInterval: (_intervalMin * 60).round(),
      );
      // Fix #28: tolak konfigurasi invalid (kering ≥ basah).
      if (!updated.isValid) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Threshold kering harus lebih kecil dari threshold basah'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 3),
        ));
        return;
      }
      _saveWithFeedback(provider, updated);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Konfigurasi',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton.icon(
                  onPressed: saveConfig,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Simpan'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildModeToggle(provider, config),
            const Divider(),
            ConfigSlider(
              label: 'Threshold Kering',
              subtitle: 'Tanah dianggap kering jika < ${_dry.round()}%',
              value: _dry,
              min: 10,
              max: 60,
              divisions: 10,
              // Fix #28: kunci slider agar selalu dry < wet (margin 5).
              onChanged: (v) => setState(
                  () => _dry = v >= _wet ? _wet - 5 : v),
              onChangeEnd: (_) => saveConfig(),
            ),
            const Divider(),
            ConfigSlider(
              label: 'Threshold Basah',
              subtitle: 'Tanah dianggap basah jika > ${_wet.round()}%',
              value: _wet,
              min: 40,
              max: 90,
              divisions: 10,
              // Fix #28: kunci slider agar selalu wet > dry (margin 5).
              onChanged: (v) => setState(
                  () => _wet = v <= _dry ? _dry + 5 : v),
              onChangeEnd: (_) => saveConfig(),
            ),
            const Divider(),
            ConfigSlider(
              label: 'Durasi Valve',
              subtitle: '${_duration.round()} detik',
              value: _duration,
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: (v) => setState(() => _duration = v),
              onChangeEnd: (_) => saveConfig(),
            ),
            const Divider(),
            ConfigSlider(
              label: 'Interval Baca',
              subtitle: 'Setiap ${_intervalMin.round()} menit',
              value: _intervalMin,
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: (v) => setState(() => _intervalMin = v),
              onChangeEnd: (_) => saveConfig(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(DashboardProvider provider, SystemConfig config) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Mode Operasi', style: Theme.of(context).textTheme.bodyMedium),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'auto', label: Text('Otomatis'), icon: Icon(Icons.auto_awesome, size: 16)),
            ButtonSegment(value: 'manual', label: Text('Manual'), icon: Icon(Icons.touch_app, size: 16)),
          ],
          selected: {config.isAutoMode ? 'auto' : 'manual'},
          onSelectionChanged: (selected) async {
            final previous = config.mode;
            config.mode = selected.first;
            final ok = await provider.updateConfig(config);
            if (!ok && mounted) {
              setState(() => config.mode = previous);
            }
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}
