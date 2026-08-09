import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../providers/devices_provider.dart';
import '../routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusText = 'Menghubungkan...';

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final connected = await SupabaseService().checkConnection();
    if (!mounted) return;

    if (connected) {
      setState(() => _statusText = 'Memuat data...');
      _waitForData();
    } else {
      setState(() => _statusText = 'Tidak terhubung ke server');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Tidak terhubung ke server.\nPeriksa koneksi internet Anda.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      });
    }
  }

  Future<void> _waitForData() async {
    final provider = context.read<DevicesProvider>();
    while (!provider.isReady) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
    }
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'ANDROMEDA',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Irigasi Tetes Otomatis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Berbasis IoT',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),

              const Spacer(flex: 1),

              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _statusText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
              ),

              const Spacer(flex: 2),

              Text(
                'Teknologi Tepat Guna\nuntuk Petani Indonesia',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'v1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
