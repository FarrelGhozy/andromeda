import 'package:flutter/material.dart';

// ============================================================
// TEMA ANDROMEDA — Design System
// Palet warna: Hijau alam, Biru air, Oranye matahari
// Font: PlusJakartaSans (Google Fonts)
// ============================================================

class AppColors {
  // === Warna Utama ===
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFFA5D6A7);
  static const Color accentBlue = Color(0xFF1565C0);
  static const Color accentOrange = Color(0xFFE65100);

  // === Warna Status ===
  static const Color success = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFC107);
  static const Color offline = Color(0xFF9E9E9E);

  // === Background Surface ===
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color cardLight = Colors.white;
  static const Color bgDark = Color(0xFF121212);
  static const Color cardDark = Color(0xFF1E1E1E);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets listPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryGreen,
          secondary: AppColors.accentBlue,
          tertiary: AppColors.accentOrange,
          surface: AppColors.bgLight,
          error: AppColors.danger,
        ),
        scaffoldBackgroundColor: AppColors.bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          color: AppColors.cardLight,
          surfaceTintColor: Colors.transparent,
          margin: AppSpacing.listPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black87),
          bodySmall: TextStyle(fontSize: 12, color: Colors.grey),
          labelLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: const DividerThemeData(
          space: 16,
          thickness: 1,
          color: Color(0xFFE0E0E0),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          secondary: AppColors.accentBlue,
          tertiary: AppColors.accentOrange,
          surface: AppColors.bgDark,
          error: AppColors.danger,
        ),
        scaffoldBackgroundColor: AppColors.bgDark,
        cardTheme: CardThemeData(
          elevation: 2,
          color: AppColors.cardDark,
          surfaceTintColor: Colors.transparent,
          margin: AppSpacing.listPadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}
