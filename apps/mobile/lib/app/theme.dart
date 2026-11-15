import 'package:flutter/material.dart';

import 'tokens.dart';

// Design tokens live in tokens.dart; re-exported so existing
// `import '../app/theme.dart'` statements keep resolving AppColors.
export 'tokens.dart';

/// Text theme mapped onto the Observatory type scale (Roboto).
TextTheme _textTheme(TextTheme base) {
  return base
      .apply(
        fontFamily: 'Roboto',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      )
      .copyWith(
        displayLarge: AppText.display,
        displayMedium: AppText.display,
        displaySmall: AppText.headline,
        headlineLarge: AppText.headline,
        headlineMedium: AppText.headline,
        headlineSmall: AppText.headline,
        titleLarge: AppText.title,
        titleMedium: AppText.title,
        titleSmall: AppText.subtitle,
        bodyLarge: AppText.body,
        bodyMedium: AppText.body,
        bodySmall: AppText.bodySmall,
        labelLarge: AppText.body.copyWith(fontWeight: FontWeight.w600),
        labelMedium: AppText.label,
        labelSmall: AppText.label,
      );
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.cyan,
        brightness: Brightness.dark,
      ).copyWith(
        surface: AppColors.surface,
        primary: AppColors.cyan,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.amber,
        onSecondary: AppColors.onAccent,
        tertiary: AppColors.blue,
        error: AppColors.danger,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.borderStrong,
        outlineVariant: AppColors.border,
      );

  final base = ThemeData(
    fontFamily: 'Roboto',
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
  );

  OutlineInputBorder inputBorder(Color c, {double w = AppBorders.width}) =>
      OutlineInputBorder(
        borderRadius: AppRadii.mdAll,
        borderSide: BorderSide(color: c, width: w),
      );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: _textTheme(base.textTheme),
    dividerColor: AppColors.border,
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: AppBorders.width,
      space: AppBorders.width,
    ),
    focusColor: AppColors.cyan.withAlpha(60),

    // ── Cards ────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgAll,
        side: AppBorders.subtle,
      ),
    ),

    // ── Inputs ───────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      labelStyle: AppText.label,
      floatingLabelStyle: AppText.label.copyWith(color: AppColors.cyan),
      hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
      errorStyle: AppText.label.copyWith(color: AppColors.danger),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.cyan, w: 1.5),
      errorBorder: inputBorder(AppColors.danger),
      focusedErrorBorder: inputBorder(AppColors.danger, w: 1.5),
      disabledBorder: inputBorder(AppColors.border),
    ),

    // ── Buttons ──────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: AppColors.surfaceHigh,
        disabledForegroundColor: AppColors.textSecondary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.onAccent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.cyan,
        side: const BorderSide(color: AppColors.borderStrong),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.cyan,
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
      ),
    ),

    // ── Navigation ───────────────────────────────────────────────────────
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.cyan.withAlpha(36),
      selectedIconTheme: const IconThemeData(color: AppColors.cyan),
      unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
      selectedLabelTextStyle: AppText.label.copyWith(color: AppColors.cyan),
      unselectedLabelTextStyle: AppText.label,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.cyan.withAlpha(36),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.cyan
              : AppColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => AppText.label.copyWith(
          color: states.contains(WidgetState.selected)
              ? AppColors.cyan
              : AppColors.textSecondary,
        ),
      ),
    ),

    // ── Misc ─────────────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.cyan,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadii.smAll,
        border: Border.fromBorderSide(AppBorders.subtle),
      ),
      textStyle: AppText.label.copyWith(color: AppColors.textPrimary),
    ),
  );
}
