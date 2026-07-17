import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/config.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/mini_chart.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  List<Reading> history = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final data = await SupabaseService.fetchReadingsForDevice(
      widget.device.deviceId,
      limit: 24,
    );
    setState(() {
      history = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reading = provider.latestReadings[widget.device.deviceId];
    final config = provider.configs[widget.device.deviceId];

    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.refresh();
          await loadHistory();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(reading, config),
            const SizedBox(height: 16),
            _buildControlButtons(config),
            const SizedBox(height: 16),
            _buildChart(),
            const SizedBox(height: 16),
            _buildSettings(config),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Reading? reading, DeviceConfig? config) {
    final moisture = reading?.moisturePercent ?? 0;
    final status = reading?.valveStatus ?? 'OFF';
    final updated = reading != null
        ? DateFormat('dd/MM HH:mm').format(reading.createdAt.toLocal())
        : '-';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '${moisture.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text('Kelembaban Tanah'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip('Valve', status, status == 'ON' ? Colors.green : Colors.grey),
                _infoChip('Mode', config?.mode ?? 'auto', Colors.blue),
                _infoChip('Update', updated, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Chip(
          label: Text(value, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
        ),
      ],
    );
  }

  Widget _buildControlButtons(DeviceConfig? config) {
    final duration = config?.valveDuration ?? 30;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.read<AppProvider>().sendCommand(
              widget.device.deviceId,
              'VALVE_ON',
              duration: duration,
            ),
            icon: const Icon(Icons.water_drop),
            label: Text('Buka Valve ($duration d)'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => context.read<AppProvider>().sendCommand(
              widget.device.deviceId,
              'VALVE_OFF',
            ),
            icon: const Icon(Icons.block),
            label: const Text('Tutup Valve'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (history.length < 2) {
      return const Card(child: ListTile(title: Text('Belum cukup data')));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Riwayat 24 jam terakhir',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 200, child: MiniChart(readings: history)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettings(DeviceConfig? config) {
    if (config == null) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengaturan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _buildModeSwitch(config),
            _buildSlider(
              'Threshold Kering',
              config.thresholdDry,
              0,
              50,
              (v) => context.read<AppProvider>().updateConfig(
                config.copyWith(thresholdDry: v.toInt()),
              ),
            ),
            _buildSlider(
              'Threshold Basah',
              config.thresholdWet,
              50,
              100,
              (v) => context.read<AppProvider>().updateConfig(
                config.copyWith(thresholdWet: v.toInt()),
              ),
            ),
            _buildSlider(
              'Durasi Valve (d)',
              config.valveDuration,
              5,
              120,
              (v) => context.read<AppProvider>().updateConfig(
                config.copyWith(valveDuration: v.toInt()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitch(DeviceConfig config) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Mode Otomatis'),
        Switch(
          value: config.mode == 'auto',
          onChanged: (value) => context.read<AppProvider>().updateConfig(
            config.copyWith(mode: value ? 'auto' : 'manual'),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    int value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
