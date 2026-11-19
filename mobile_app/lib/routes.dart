import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/esp32_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/journal_edit_screen.dart';
import 'screens/journal_article_screen.dart';
import 'models/journal_article.dart';
import 'models/journal_entry.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String esp32Detail = '/esp32';
  static const String settings = '/settings';
  static const String weather = '/weather';
  static const String journal = '/journal';
  static const String journalEdit = '/journal-edit';
  static const String journalArticle = '/journal-article';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
      case AppRoutes.dashboard:
        final deviceId = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => DashboardScreen(deviceId: deviceId),
        );
      case AppRoutes.esp32Detail:
        final esp32Id = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => Esp32Screen(esp32Id: esp32Id),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.weather:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const WeatherScreen(),
        );
      case AppRoutes.journal:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const JournalScreen(),
        );
      case AppRoutes.journalEdit:
        final entry = settings.arguments as JournalEntry?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => JournalEditScreen(entry: entry),
        );
      case AppRoutes.journalArticle:
        final article = settings.arguments as JournalArticle;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => JournalArticleScreen(article: article),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const SplashScreen(),
        );
    }
  }
}
