import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Standard surface container: surface fill, 1 px subtle border, card radius.
///
/// Use instead of hand-rolled `Container` + `BoxDecoration`.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.color = AppColors.surface,
    this.borderSide = AppBorders.subtle,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BorderSide borderSide;
  final BorderRadius? radius;

  /// Tinted callout variant (e.g. data notes) using an accent colour.
  factory AppCard.callout({
    Key? key,
    required Color accent,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.md),
  }) {
    return AppCard(
      key: key,
      color: accent.withAlpha(20),
      borderSide: AppBorders.tinted(accent),
      radius: AppRadii.smAll,
      padding: padding,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius ?? AppRadii.lgAll,
        border: Border.fromBorderSide(borderSide),
      ),
      child: child,
    );
  }
}
