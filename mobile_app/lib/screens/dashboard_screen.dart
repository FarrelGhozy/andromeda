import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../providers/devices_provider.dart';
import '../models/enums.dart';
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
            onPressed: () =>
                context.read<DashboardProvider>().loadDevice(widget.deviceId),
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
            // 1. Gauge Kelembaban
            _buildGaugeSection(provider),
            const SizedBox(height: 16),

            // 2. Status Valve
            _buildValveSection(provider),
            const SizedBox(height: 16),

            // 3. Kontrol Valve
            _buildValveControl(provider),
            const SizedBox(height: 16),

            // 4. Grafik Historis
            _buildChartSection(provider),
            const SizedBox(height: 16),

            // 5. Konfigurasi
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
    final fresh = reading != null &&
        DateTime.now().difference(reading.createdAt) <=
            DevicesProvider.onlineWindow;
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
            MoistureGauge(
              percent: percent,
              size: 200,
              showLabel: true,
              offline: !fresh,
              thresholdDry: provider.config?.thresholdDry ?? 30,
              thresholdWet: provider.config?.thresholdWet ?? 70,
            ),
            const SizedBox(height: 16),
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
                  color: Colors.grey[600],
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
    final (icon, label, color, subtitle) = switch (status) {
      ValveDisplayStatus.open => (
          Icons.water_drop,
          'TERBUKA',
          AppColors.danger,
          'Valve terbuka (data segar)',
        ),
      ValveDisplayStatus.closed => (
          Icons.water_drop_outlined,
          'TERTUTUP',
          AppColors.success,
          'Valve tertutup (data segar)',
        ),
      ValveDisplayStatus.unknown => (
          Icons.help_outline,
          'TIDAK DIKETAHUI',
          AppColors.offline,
          'Tidak ada data segar dari perangkat',
        ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Valve',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            StatusBadge(
              text: provider.config?.isAutoMode == true ? 'Otomatis' : 'Manual',
              color: provider.config?.isAutoMode == true
                  ? AppColors.primaryGreen
                  : AppColors.accentOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValveControl(DashboardProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontrol Valve',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ValveButton(
                    label: 'BUKA',
                    icon: Icons.play_arrow,
                    color: AppColors.danger,
                    onPressed: (!provider.isValveOpen && !provider.sendingCommand)
                        ? () => _sendValve(provider, 'VALVE_ON')
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValveButton(
                    label: 'TUTUP',
                    icon: Icons.stop,
                    color: AppColors.success,
                    // Fix #16: TUTUP selalu aktif (safety) — saat status
                    // tidak diketahui pun user boleh memaksa menutup.
                    onPressed: !provider.sendingCommand
                        ? () => _sendValve(provider, 'VALVE_OFF')
                        : null,
                  ),
                ),
              ],
            ),
            if (provider.sendingCommand) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 12),
            DurationPicker(
              onSelected: (duration) =>
                  _sendValve(provider, 'VALVE_ON', duration: duration),
            ),
          ],
        ),
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
                Row(
                  children: ChartRange.values.map((range) {
                    final selected = provider.selectedChartRange == range;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        label: Text(range.label),
                        selected: selected,
                        onSelected: (_) => provider.setChartRange(range),
                        selectedColor: AppColors.primaryGreen,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                          fontSize: 12,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }).toList(),
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
                        style: TextStyle(color: Colors.grey[500]),
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
              style: TextStyle(color: Colors.grey[500]),
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
      _saveWithFeedback(provider, updated);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konfigurasi',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),

            // Mode
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mode Operasi'),
                ToggleButtons(
                  isSelected: [config.isAutoMode, config.isManualMode],
                  onPressed: (index) async {
                    config.mode = index == 0 ? 'auto' : 'manual';
                    final ok = await provider.updateConfig(config);
                    if (!mounted) return;
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Mode ${index == 0 ? 'Otomatis' : 'Manual'} diterapkan ✓'
                              : (provider.errorMessage ?? 'Gagal menyimpan mode'),
                        ),
                        backgroundColor: ok
                            ? AppColors.success
                            : AppColors.danger,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: AppColors.primaryGreen,
                  constraints: const BoxConstraints(
                    minWidth: 100,
                    minHeight: 36,
                  ),
                  children: const [
                    Text('Otomatis'),
                    Text('Manual'),
                  ],
                ),
              ],
            ),
            const Divider(),

            // Threshold kering
            ConfigSlider(
              label: 'Threshold Kering',
              subtitle: 'Tanah dianggap kering jika < ${_dry.round()}%',
              value: _dry,
              min: 10,
              max: 60,
              divisions: 10,
              onChanged: (v) => setState(() => _dry = v),
              onChangeEnd: (_) => saveConfig(),
            ),
            const Divider(),

            // Threshold basah
            ConfigSlider(
              label: 'Threshold Basah',
              subtitle: 'Tanah dianggap basah jika > ${_wet.round()}%',
              value: _wet,
              min: 40,
              max: 90,
              divisions: 10,
              onChanged: (v) => setState(() => _wet = v),
              onChangeEnd: (_) => saveConfig(),
            ),
            const Divider(),

            // Durasi valve
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

            // Interval baca
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
}
