import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/supabase_service.dart';
import '../providers/theme_provider.dart';
import '../config/theme_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notifPrefKey = 'notif_enabled';

  bool _notifEnabled = false;
  bool _exporting = false;
  String _version = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadVersion();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _notifEnabled = prefs.getBool(_notifPrefKey) ?? false);
    } catch (_) {}
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = 'v${info.version} (build ${info.buildNumber})');
    } catch (_) {}
  }

  Future<void> _toggleNotif(bool value) async {
    setState(() => _notifEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notifPrefKey, value);
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? 'Preferensi notifikasi disimpan (push menyusul di versi berikutnya)'
            : 'Notifikasi dinonaktifkan'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Menyiapkan ekspor data…')),
    );
    try {
      final client = SupabaseService().client;
      final devices = await client.from('devices').select(
            'device_id, name, location',
          ).order('id');
      final readings = await client.rpc('get_latest_readings');

      final rows = <List<String>>[
        ['device_id', 'name', 'location', 'moisture', 'moisture_percent', 'valve_status', 'created_at'],
      ];
      final readingList = (readings as List).cast<Map<String, dynamic>>();
      for (final d in devices) {
        final rid = d['device_id'] ?? '';
        final r = readingList
            .where((e) => e['device_id'] == rid)
            .toList()
            .isEmpty
            ? <String, dynamic>{}
            : readingList.firstWhere((e) => e['device_id'] == rid);
        rows.add([
          rid,
          '${d['name'] ?? ''}',
          '${d['location'] ?? ''}',
          '${r['moisture'] ?? ''}',
          '${r['moisture_percent'] ?? ''}',
          '${r['valve_status'] ?? ''}',
          '${r['created_at'] ?? ''}',
        ]);
      }

      final csv = rows
          .map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
          .join('\n');

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/andromeda_data_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Data ANDROMEDA',
        text: 'Ekspor data sensor ANDROMEDA (${rows.length - 1} perangkat)',
      );
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal ekspor data: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            title: 'Status Koneksi',
            children: [
              FutureBuilder<bool>(
                future: SupabaseService().checkConnection(),
                builder: (context, snapshot) {
                  final connected = snapshot.data ?? false;
                  return Row(
                    children: [
                      Icon(
                        connected ? Icons.check_circle : Icons.error,
                        color: connected
                            ? AppColors.success
                            : AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        connected ? 'Terhubung' : 'Terputus',
                        style: TextStyle(
                          color: connected ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tampilan
          _buildCard(
            title: 'Tampilan',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Mode Gelap'),
                subtitle: const Text('Tampilan gelap untuk kondisi minim cahaya'),
                value: context.watch<ThemeProvider>().isDark,
                onChanged: (v) => context.read<ThemeProvider>().setDark(v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Notifikasi
          _buildCard(
            title: 'Tampilan',
            children: [
              SwitchListTile(
                title: const Text('Alert Kelembaban Kritis'),
                subtitle: const Text(
                  'Dapatkan notifikasi saat tanah terlalu kering/basah.\nPush notification aktif di versi berikutnya — preferensi ini disimpan.',
                ),
                value: _notifEnabled,
                onChanged: _toggleNotif,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCard(
            title: 'Data',
            children: [
              ListTile(
                leading: Icon(Icons.download, color: theme.colorScheme.primary),
                title: const Text('Ekspor Data CSV'),
                subtitle: Text(
                  _exporting
                      ? 'Menyiapkan file…'
                      : 'Bagikan data sensor terbaru semua perangkat',
                ),
                trailing: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                contentPadding: EdgeInsets.zero,
                onTap: _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCard(
            title: 'Tentang',
            children: [
              ListTile(
                leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                title: const Text('ANDROMEDA'),
                subtitle: Text('$_version\nIrigasi Tetes Otomatis Berbasis IoT'),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.code, color: AppColors.accentBlue),
                title: const Text('Open Source'),
                subtitle: const Text('github.com/FarrelGhozy/andromeda'),
                contentPadding: EdgeInsets.zero,
                onTap: () => _openUrl('https://github.com/FarrelGhozy/andromeda'),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.share, color: AppColors.accentOrange),
                title: const Text('Bagikan Aplikasi'),
                subtitle: const Text('Sebarkan ke sesama petani'),
                contentPadding: EdgeInsets.zero,
                onTap: () => _shareApp(),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'ANDROMEDA - Irigasi Tetes Otomatis Berbasis IoT untuk Petani Indonesia\n\n'
      'https://github.com/FarrelGhozy/andromeda',
    );
  }
}
