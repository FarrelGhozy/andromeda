import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme_config.dart';
import 'services/supabase_service.dart';
import 'services/device_repository.dart';
import 'services/sensor_repository.dart';
import 'services/config_repository.dart';
import 'providers/devices_provider.dart';
import 'providers/dashboard_provider.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabase = SupabaseService();
  await supabase.init();

  final client = supabase.client;
  final deviceRepo = DeviceRepository(client);
  final sensorRepo = SensorRepository(client);
  final configRepo = ConfigRepository(client);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final p = DevicesProvider(deviceRepo);
            p.init();
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(sensorRepo, configRepo),
        ),
      ],
      child: const AndromedaApp(),
    ),
  );
}

class AndromedaApp extends StatefulWidget {
  const AndromedaApp({super.key});

  static _AndromedaAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AndromedaAppState>();
  }

  @override
  State<AndromedaApp> createState() => _AndromedaAppState();
}

class _AndromedaAppState extends State<AndromedaApp> {
  bool _isDarkMode = false;

  void toggleTheme(bool isDark) {
    setState(() => _isDarkMode = isDark);
  }

  bool get isDarkMode => _isDarkMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANDROMEDA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
