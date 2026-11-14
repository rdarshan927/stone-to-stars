import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'stat_tile.dart';

/// Summary card shown at the top of the Overview section.
class OverviewCard extends StatelessWidget {
  const OverviewCard({super.key, required this.analysis});

  final ClimateAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final loc = analysis.location;
    final ds = analysis.dataset;
    final per = analysis.period;
    final tTrend = analysis.temperature.trend;
    final pTrend = analysis.precipitation.trend;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stone to Stars',
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Earth System Trend Detective',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _SourceBadge(sources: ds.sources),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Location info
          Text(
            'Location',
            style: tt.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          StatTile(
            label: 'Requested',
            value:
                '${loc.requestedLatitude.toStringAsFixed(4)}°, '
                '${loc.requestedLongitude.toStringAsFixed(4)}°',
          ),
          StatTile(
            label: 'Grid cell',
            value:
                '${loc.latitude.toStringAsFixed(4)}°, '
                '${loc.longitude.toStringAsFixed(4)}°',
          ),
          if (loc.elevationM != null)
            StatTile(
              label: 'Elevation',
              value: '${loc.elevationM!.toStringAsFixed(0)} m',
            ),
          StatTile(label: 'Period', value: '${per.startYear}–${per.endYear}'),

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Quick trend summary
          Text(
            'Trend Summary',
            style: tt.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _TrendSummaryRow(
            label: 'Temperature',
            trend: tTrend,
            color: AppColors.cyan,
          ),
          const SizedBox(height: 6),
          _TrendSummaryRow(
            label: 'Precipitation',
            trend: pTrend,
            color: AppColors.orange,
          ),

          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orange.withAlpha(80)),
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NASA POWER data is model-derived and grid-based '
                    '(~0.5° resolution, ≈55 km). It represents a grid '
                    'cell, not a station or exact point. '
                    'A non-significant trend does not mean climate is stable.',
                    style: tt.bodySmall?.copyWith(color: AppColors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendSummaryRow extends StatelessWidget {
  const _TrendSummaryRow({
    required this.label,
    required this.trend,
    required this.color,
  });

  final String label;
  final TrendResult trend;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (!trend.hasResult) {
      return Row(
        children: [
          _dot(AppColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label  Insufficient data',
              style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final dir = trend.direction ?? 'none';
    final sig = trend.significant ?? false;
    final slope = trend.senSlopePerDecade;
    final dirColor = dir == 'increasing'
        ? AppColors.cyan
        : dir == 'decreasing'
        ? AppColors.orange
        : AppColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _dot(color),
        const SizedBox(width: 8),
        // Label: intrinsic width capped at 100 px, shrinks on very narrow screens.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 100),
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        // Pills + slope in an Expanded Wrap so they never overflow the row.
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(dir[0].toUpperCase() + dir.substring(1), dirColor, tt),
              _pill(
                sig ? 'Significant' : 'Not sig.',
                sig ? AppColors.cyan : AppColors.textSecondary,
                tt,
              ),
              if (slope != null)
                Text(
                  '${slope >= 0 ? '+' : ''}${slope.toStringAsFixed(3)} '
                  '${trend.slopeUnitsPerDecade}',
                  style: tt.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _pill(String text, Color c, TextTheme tt) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: c.withAlpha(25),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: tt.labelSmall?.copyWith(color: c)),
  );
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.sources});

  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.blue.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blue.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'NASA POWER',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.blue, fontWeight: FontWeight.bold),
          ),
          if (sources.isNotEmpty)
            Text(
              sources.join(', '),
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
