/// Design tokens for the "Observatory" visual language.
///
/// Single source of truth for colour, spacing, radii, borders and type.
/// Widgets should reference these instead of hard-coding values.
library;

import 'package:flutter/material.dart';

/// Colour palette: deep navy foundation, cyan / ice-blue scientific accent,
/// amber secondary accent.
///
/// Contrast (WCAG) against [surface]: textPrimary ≈ 14:1,
/// textSecondary ≈ 6.5:1, cyan ≈ 9:1, amber ≈ 9:1, danger ≈ 6:1.
class AppColors {
  AppColors._();

  // Surfaces
  static const background = Color(0xFF050D18);
  static const atmosphere = Color(0xFF10374A);
  static const horizon = Color(0xFF092639);
  static const navigation = Color(0xFF071321);
  static const surface = Color(0xFF111A2E);
  static const surfaceHigh = Color(0xFF18243D);
  static const border = Color(0xFF243352);
  static const borderStrong = Color(0xFF34466B);

  // Text
  static const textPrimary = Color(0xFFE8EEF9);
  static const textSecondary = Color(0xFF93A1BD);

  // Accents
  /// Ice-blue: primary brand and scientific accent.
  static const cyan = Color(0xFF22D3EE);

  /// Secondary accent (amber). Name kept for backwards compatibility.
  static const orange = Color(0xFFFFB04D);

  /// Alias for readability in new code.
  static const amber = orange;

  /// Legacy accent still used by existing screens (form button, badges).
  static const blue = Color(0xFF4C8DFF);

  // Semantic
  static const danger = Color(0xFFFF6B6B);

  /// Text/icon colour to place on a solid cyan or amber fill.
  static const onAccent = Color(0xFF06101F);
}

/// Static atmospheric treatments: no blur, animation, or image downloads.
class AppGradients {
  AppGradients._();

  static const space = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.navigation, AppColors.background],
  );
  static const atmosphere = RadialGradient(
    center: Alignment.topRight,
    radius: 1.3,
    colors: [AppColors.atmosphere, Color(0x0010374A)],
    stops: [0, 0.85],
  );
}

/// 4-pt spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Default padding inside cards.
  static const double cardPadding = lg;
}

/// Responsive breakpoints (logical px) and content sizing.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this width: phone layout (bottom navigation bar).
  static const double medium = 600;

  /// From this width: desktop layout (extended navigation rail).
  static const double expanded = 1000;

  /// Maximum width of the page content column.
  static const double contentMaxWidth = 1200;
}

/// Corner radii.
class AppRadii {
  AppRadii._();

  static const double sm = 8; // chips, banners, small controls
  static const double md = 12; // inputs, buttons
  static const double lg = 14; // cards (matches existing screens)
  static const double pill = 999;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Border conventions.
class AppBorders {
  AppBorders._();

  static const double width = 1;

  static const BorderSide subtle = BorderSide(
    color: AppColors.border,
    width: width,
  );
  static const BorderSide strong = BorderSide(
    color: AppColors.borderStrong,
    width: width,
  );

  /// Tinted border for accent-coloured surfaces (pills, callouts).
  static BorderSide tinted(Color c) =>
      BorderSide(color: c.withAlpha(120), width: width);
}

/// Typography scale (Roboto). Sizes are logical px; line heights are ratios.
class AppText {
  AppText._();

  static const _tabular = [FontFeature.tabularFigures()];

  /// Editorial styles are opt-in so existing scientific content keeps its scale.
  static const editorial = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 52,
    height: 1.08,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    color: AppColors.textPrimary,
  );

  static const editorialCompact = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const display = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 32,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );
  static const headline = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 24,
    height: 1.25,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const title = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const subtitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const bodySmall = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const label = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );

  /// Overline / section eyebrow: small caps-style label.
  static const overline = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.textSecondary,
  );

  /// Tabular (fixed-width digit) numeric styles for statistics.
  static const numeric = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 1.4,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );
  static const numericLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
    color: AppColors.textPrimary,
  );
}
