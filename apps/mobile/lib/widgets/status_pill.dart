import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Compact status label. Always pairs colour with text (and optionally an
/// icon) so meaning never depends on colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.semanticsLabel,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? semanticsLabel;

  /// Direction pill. Colour is only applied to *significant* trends;
  /// non-significant trends are muted so they are not read as confirmed.
  /// Returns an empty widget for null / 'none' directions.
  factory StatusPill.direction({
    Key? key,
    required String? direction,
    required bool significant,
  }) {
    if (direction != 'increasing' && direction != 'decreasing') {
      return const StatusPill._empty();
    }
    final up = direction == 'increasing';
    final color = significant
        ? (up ? AppColors.cyan : AppColors.amber)
        : AppColors.textSecondary;
    return StatusPill(
      key: key,
      label: up ? 'Increasing' : 'Decreasing',
      color: color,
      icon: up ? Icons.trending_up : Icons.trending_down,
    );
  }

  /// Significance pill: filled-tone cyan when significant, muted otherwise.
  factory StatusPill.significance({Key? key, required bool significant}) {
    return StatusPill(
      key: key,
      label: significant ? 'Significant' : 'Not significant',
      color: significant ? AppColors.cyan : AppColors.textSecondary,
      icon: significant
          ? Icons.check_circle_outline
          : Icons.remove_circle_outline,
    );
  }

  const StatusPill._empty()
    : label = '',
      color = Colors.transparent,
      icon = null,
      semanticsLabel = null;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md - 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: AppRadii.pillAll,
          border: Border.fromBorderSide(AppBorders.tinted(color)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label,
                style: AppText.label.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
