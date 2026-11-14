import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/climate_analysis.dart';
import '../utils/climate_format.dart';
import 'app_card.dart';
import 'stat_tile.dart';
import 'status_pill.dart';

/// Monthly seasonal Mann-Kendall result, separate from the annual trend.
class SeasonalTrendCard extends StatelessWidget {
  const SeasonalTrendCard({
    super.key,
    required this.title,
    required this.trend,
    required this.accentColor,
  });

  final String title;
  final SeasonalTrend trend;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final significant = trend.significant == true;
    final knownDirection =
        trend.direction == 'increasing' || trend.direction == 'decreasing';
    final valueColor = significant && knownDirection
        ? accentColor
        : AppColors.textSecondary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEASONAL TREND',
            style: AppText.overline.copyWith(color: accentColor),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Semantics(header: true, child: Text(title, style: AppText.subtitle)),
          const SizedBox(height: AppSpacing.md),
          if (!trend.hasResult)
            Text(
              'Insufficient data for seasonal trend analysis.',
              style: AppText.bodySmall,
            )
          else ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (knownDirection)
                  StatusPill(
                    label: trend.direction == 'increasing'
                        ? 'Increasing'
                        : 'Decreasing',
                    color: valueColor,
                    icon: trend.direction == 'increasing'
                        ? Icons.trending_up
                        : Icons.trending_down,
                  ),
                if (trend.significant != null)
                  StatusPill.significance(significant: significant)
                else
                  const StatusPill(
                    label: 'Significance unavailable',
                    color: AppColors.textSecondary,
                    icon: Icons.info_outline,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (trend.senSlopePerDecade != null)
              StatTile(
                label: "Sen's slope",
                value:
                    '${formatSlope(trend.senSlopePerDecade!)} '
                    '${trend.slopeUnitsPerDecade}',
                valueColor: valueColor,
              ),
            if (trend.pValue != null)
              StatTile(label: 'p-value', value: formatP(trend.pValue!)),
            if (!significant) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                trend.significant == false
                    ? 'A non-significant result is inconclusive and does not '
                          'imply no change or a stable climate.'
                    : 'Statistical significance is unavailable; this result '
                          'does not establish a confirmed seasonal trend.',
                style: AppText.bodySmall,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
