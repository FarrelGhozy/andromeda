import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Ganti dengan URL dan anon key Supabase project lo
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    publishableKey: 'your-anon-key',
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
