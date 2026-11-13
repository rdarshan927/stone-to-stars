import 'package:flutter/material.dart';

/// Palette: deep navy foundation with blue, cyan and warm orange accents.
class AppColors {
  static const background = Color(0xFF0A1020);
  static const surface = Color(0xFF111A2E);
  static const surfaceHigh = Color(0xFF18243D);
  static const border = Color(0xFF243352);
  static const textPrimary = Color(0xFFE8EEF9);
  static const textSecondary = Color(0xFF93A1BD);
  static const blue = Color(0xFF4C8DFF);
  static const cyan = Color(0xFF22D3EE);
  static const orange = Color(0xFFFF9F43);
  static const danger = Color(0xFFFF6B6B);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.blue,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.surface,
        primary: AppColors.blue,
        secondary: AppColors.cyan,
        tertiary: AppColors.orange,
        error: AppColors.danger,
        onSurface: AppColors.textPrimary,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.surfaceHigh,
    ),
    dividerColor: AppColors.border,
  );
}
