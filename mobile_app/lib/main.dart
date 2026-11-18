import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/supabase_config.dart';
import 'config/theme_config.dart';
import 'services/supabase_service.dart';
import 'services/device_repository.dart';
import 'services/sensor_repository.dart';
import 'services/config_repository.dart';
import 'services/local_store.dart';
import 'services/cache_repository.dart';
import 'services/weather_service.dart';
import 'services/mock/mock_config_repository.dart';
import 'services/mock/mock_database.dart';
import 'services/mock/mock_device_repository.dart';
import 'services/mock/mock_sensor_repository.dart';
import 'providers/devices_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/journal_provider.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final DeviceRepository deviceRepo;
  final SensorRepository sensorRepo;
  final ConfigRepository configRepo;

  if (AppConfig.isMockMode) {
    // Mode mock: tanpa Supabase, tanpa internet. Satu database
    // in-memory dipakai bareng ketiga repository mock.
    final mockDb = MockDatabase.seed();
    deviceRepo = MockDeviceRepository(mockDb);
    sensorRepo = MockSensorRepository(mockDb);
    configRepo = MockConfigRepository(mockDb);
  } else {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase belum dikonfigurasi. Copy .env.example menjadi .env di root '
        'projek, isi SUPABASE_URL dan SUPABASE_ANON_KEY, lalu sync dengan '
        '`cp .env mobile_app/.env`.',
      );
    }
    final supabase = SupabaseService();
    await supabase.init();

    final client = supabase.client;
    deviceRepo = SupabaseDeviceRepository(client);
    sensorRepo = SupabaseSensorRepository(client);
    configRepo = SupabaseConfigRepository(client);
  }

  final localStore = LocalStore();
  final cacheRepo = CacheRepository(localStore);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final p = ConnectivityProvider();
            p.init();
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = WeatherProvider(WeatherService(), localStore);
            p.init();
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = JournalProvider(localStore);
            p.init();
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = DevicesProvider(deviceRepo, cacheRepo: cacheRepo);
            p.init();
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            sensorRepo,
            configRepo,
            context.read<DevicesProvider>(),
          ),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => MaterialApp(
        title: 'ANDROMEDA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeProvider.mode,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
