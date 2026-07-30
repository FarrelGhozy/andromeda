import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../models/enums.dart';
import '../widgets/moisture_gauge.dart';
import '../widgets/valve_button.dart';
import '../widgets/moisture_chart.dart';
import '../widgets/config_slider.dart';
import '../widgets/status_badge.dart';
import '../widgets/duration_picker.dart';
import '../widgets/error_banner.dart';
import '../config/theme_config.dart';

class DashboardScreen extends StatefulWidget {
  final String deviceId;
  const DashboardScreen({super.key, required this.deviceId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Memuat data...'),
                  ],
                ),
              );
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
                );
              },
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
              ],
            ),
            if (reading?.rssi != null) ...[
              const SizedBox(height: 8),
              Text(
                'WiFi: ${reading!.rssi} dBm',
                style: Theme.of(context).textTheme.bodySmall,
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

  Widget _buildValveSection(DashboardProvider provider) {
    final isOpen = provider.isValveOpen;
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
                  text: provider.config?.isAutoMode == true ? 'Otomatis' : 'Manual',
                  color: provider.config?.isAutoMode == true
                      ? AppColors.primaryGreen
                      : AppColors.accentOrange,
                  fontSize: 11,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isOpen ? Icons.water_drop : Icons.water_drop_outlined,
                  color: isOpen ? AppColors.success : AppColors.offline,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isOpen ? 'TERBUKA' : 'TERTUTUP',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isOpen ? AppColors.success : AppColors.offline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ValveButton(
                    label: 'BUKA',
                    icon: Icons.play_arrow,
                    color: AppColors.success,
                    onPressed: !isOpen
                        ? () => provider.sendValveCommand('VALVE_ON')
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValveButton(
                    label: 'TUTUP',
                    icon: Icons.stop,
                    color: AppColors.offline,
                    onPressed: isOpen
                        ? () => provider.sendValveCommand('VALVE_OFF')
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DurationPicker(
              onSelected: (duration) =>
                  provider.sendValveCommand('VALVE_ON', duration: duration),
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
                  onPressed: () => provider.updateConfig(config),
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
              subtitle: 'Tanah dianggap kering jika < ${config.thresholdDry}%',
              value: config.thresholdDry.toDouble(),
              min: 10,
              max: 60,
              divisions: 10,
              onChanged: null,
              onChangeEnd: (v) {
                config.thresholdDry = v.round();
                provider.updateConfig(config);
              },
            ),
            const Divider(),
            ConfigSlider(
              label: 'Threshold Basah',
              subtitle: 'Tanah dianggap basah jika > ${config.thresholdWet}%',
              value: config.thresholdWet.toDouble(),
              min: 40,
              max: 90,
              divisions: 10,
              onChanged: null,
              onChangeEnd: (v) {
                config.thresholdWet = v.round();
                provider.updateConfig(config);
              },
            ),
            const Divider(),
            ConfigSlider(
              label: 'Durasi Valve',
              subtitle: '${config.valveDuration} detik',
              value: config.valveDuration.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: null,
              onChangeEnd: (v) {
                config.valveDuration = v.round();
                provider.updateConfig(config);
              },
            ),
            const Divider(),
            ConfigSlider(
              label: 'Interval Baca',
              subtitle: 'Setiap ${config.readIntervalMinutes} menit',
              value: config.readIntervalMinutes.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: null,
              onChangeEnd: (v) {
                config.readInterval = (v * 60).round();
                provider.updateConfig(config);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle(DashboardProvider provider, dynamic config) {
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
          onSelectionChanged: (selected) {
            config.mode = selected.first;
            provider.updateConfig(config);
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
