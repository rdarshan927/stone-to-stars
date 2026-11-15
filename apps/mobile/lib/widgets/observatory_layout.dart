import 'package:flutter/material.dart';

import '../app/tokens.dart';
import 'observatory_artwork.dart';

/// Open editorial hero. Content stays in reading order when the optional
/// supporting visual moves beside it; no fixed heights or text clipping.
class ObservatoryHero extends StatelessWidget {
  const ObservatoryHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.supporting,
    this.actions,
    this.compact = false,
    this.accent = AppColors.cyan,
    this.imagery,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? supporting;
  final Widget? actions;
  final bool compact;
  final Color accent;
  final ObservatoryArtworkKind? imagery;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final wide = constraints.maxWidth >= 900 * scale;
      final atmospheric =
          imagery != null && imagery != ObservatoryArtworkKind.globe;
      final intro = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppText.overline.copyWith(color: accent, letterSpacing: 2),
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              title,
              style: compact
                  ? AppText.editorialCompact.copyWith(fontSize: 28)
                  : wide
                  ? AppText.editorial
                  : AppText.editorialCompact,
            ),
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.lg),
          Text(
            description,
            style: compact
                ? atmospheric
                      ? AppText.bodySmall.copyWith(color: AppColors.textPrimary)
                      : AppText.bodySmall
                : AppText.body.copyWith(fontSize: 17, height: 1.5),
          ),
        ],
      );
      final globe = imagery == ObservatoryArtworkKind.globe;
      Widget introduction = intro;
      if (globe && !wide) {
        final artSize = constraints.maxWidth < 450 ? 76.0 : 112.0;
        introduction = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: intro),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: artSize,
              height: artSize,
              child: ObservatoryArtwork(kind: imagery!),
            ),
          ],
        );
      } else if (imagery != null && !globe) {
        // Decoration is limited to the introduction, never the editor, chart,
        // statistics, or supporting scientific findings.
        introduction = Stack(
          children: [
            Positioned.fill(child: ObservatoryArtwork(kind: imagery!)),
            intro,
          ],
        );
      }
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          introduction,
          if (actions != null) ...[
            const SizedBox(height: AppSpacing.lg),
            actions!,
          ],
        ],
      );
      final side = globe && wide
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 260,
                  child: ObservatoryArtwork(kind: imagery!),
                ),
                if (supporting != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  supporting!,
                ],
              ],
            )
          : supporting;
      return Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? AppSpacing.md : AppSpacing.xxl,
        ),
        child: wide && side != null
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: copy),
                  const SizedBox(width: AppSpacing.xxxl),
                  Expanded(flex: 4, child: side),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  if (supporting != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    supporting!,
                  ],
                ],
              ),
      );
    },
  );
}

/// A reading section rather than another enclosing dashboard card.
class ObservatorySection extends StatelessWidget {
  const ObservatorySection({
    super.key,
    required this.title,
    required this.child,
    this.description,
  });

  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpacing.xl),
      Semantics(header: true, child: Text(title, style: AppText.sectionTitle)),
      if (description != null) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(description!, style: AppText.bodySmall),
      ],
      const SizedBox(height: AppSpacing.lg),
      child,
    ],
  );
}
