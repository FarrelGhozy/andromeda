import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../services/supabase_service.dart';
import '../services/device_repository.dart';
import '../services/sensor_repository.dart';
import '../services/config_repository.dart';
import '../providers/devices_provider.dart';
import '../providers/dashboard_provider.dart';
import '../routes.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Supabase
  final supabase = SupabaseService();
  await supabase.init();

  // Repos
  final client = supabase.client;
  final deviceRepo = DeviceRepository(client);
  final sensorRepo = SensorRepository(client);
  final configRepo = ConfigRepository(client);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final p = DevicesProvider(deviceRepo, sensorRepo);
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

class AndromedaApp extends StatelessWidget {
  const AndromedaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANDROMEDA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
