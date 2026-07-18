import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../config/theme_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Koneksi
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
                        connected
                            ? Icons.check_circle
                            : Icons.error,
                        color: connected
                            ? AppColors.success
                            : AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        connected ? 'Terhubung' : 'Terputus',
                        style: TextStyle(
                          color: connected
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Notifikasi
          _buildCard(
            title: 'Notifikasi',
            children: [
              SwitchListTile(
                title: const Text('Alert Kelembaban Kritis'),
                subtitle: const Text('Dapatkan notifikasi saat tanah terlalu kering/basah'),
                value: false,
                onChanged: (v) {},
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Data
          _buildCard(
            title: 'Data',
            children: [
              ListTile(
                leading: const Icon(Icons.download, color: AppColors.primaryGreen),
                title: const Text('Ekspor Data CSV'),
                subtitle: const Text('Download riwayat sensor ke penyimpanan'),
                trailing: const Icon(Icons.chevron_right),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur ekspor akan segera hadir')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Info
          _buildCard(
            title: 'Tentang',
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.primaryGreen),
                title: const Text('ANDROMEDA'),
                subtitle: const Text('v1.0.0 (build 1)\nIrigasi Tetes Otomatis Berbasis IoT'),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.code, color: AppColors.accentBlue),
                title: const Text('Open Source'),
                subtitle: const Text('github.com/FarrelGhozy/andromeda'),
                contentPadding: EdgeInsets.zero,
                onTap: () => _openUrl('https://github.com/FarrelGhozy/andromeda'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.groups, color: AppColors.accentOrange),
                title: const Text('Program PDB'),
                subtitle: const Text('Desa Meraya — Kec. Menthobi Raya'),
                contentPadding: EdgeInsets.zero,
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
}
