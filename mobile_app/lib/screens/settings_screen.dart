import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import '../config/theme_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
                        color: connected ? AppColors.success : AppColors.danger,
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
          _buildCard(
            title: 'Tampilan',
            children: [
              SwitchListTile(
                title: const Text('Mode Gelap'),
                subtitle: const Text('Gunakan tema gelap untuk kenyamanan mata'),
                value: AndromedaApp.of(context)?.isDarkMode ?? false,
                onChanged: (v) => AndromedaApp.of(context)?.toggleTheme(v),
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  (AndromedaApp.of(context)?.isDarkMode ?? false)
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  color: theme.colorScheme.primary,
                ),
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
                subtitle: const Text('Download riwayat sensor ke penyimpanan'),
                trailing: Chip(
                  label: Text(
                    'Segera Hadir',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  backgroundColor: Colors.grey[200],
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                contentPadding: EdgeInsets.zero,
                enabled: false,
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
                subtitle: const Text('v1.0.0 (build 1)\nIrigasi Tetes Otomatis Berbasis IoT'),
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
