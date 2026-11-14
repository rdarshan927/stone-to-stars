import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Section heading: optional overline eyebrow, title, optional subtitle and
/// optional trailing widget (e.g. a badge or action).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Semantics(
                  excludeSemantics: true,
                  label: eyebrow,
                  child: Text(eyebrow!.toUpperCase(), style: AppText.overline),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              Semantics(header: true, child: Text(title, style: AppText.title)),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(subtitle!, style: AppText.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}
