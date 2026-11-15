// Shared formatting helpers for climate statistics.
//
// Used by OverviewCard (via import) and the P3.4 climate visualization widgets.
// No Flutter imports — pure Dart so it can be unit-tested without a widget
// environment.

/// Formats a Sen's slope value for display: signed, with a typographic minus
/// (U+2212) and precision scaled to magnitude so the value stays short.
///
/// Examples: `+0.034`, `−12.5`, `+120`
String formatSlope(double v) {
  final a = v.abs();
  final digits = a >= 100
      ? 0
      : a >= 10
      ? 1
      : a >= 1
      ? 2
      : 3;
  final s = a.toStringAsFixed(digits);
  if (double.parse(s) == 0) return s; // avoid "+0.000" / "−0.000"
  return '${v < 0 ? '−' : '+'}$s';
}

/// Formats a p-value with fixed precision, flooring very small values.
///
/// Example: `0.0082`, or `< 0.0001` for very small values.
String formatP(double p) => p < 0.0001 ? '< 0.0001' : p.toStringAsFixed(4);
