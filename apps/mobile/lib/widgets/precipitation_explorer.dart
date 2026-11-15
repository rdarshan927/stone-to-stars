import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/climate_analysis.dart';
import 'annual_chart.dart';
import 'climate_trend_card.dart';
import 'excluded_years_panel.dart';
import 'observatory_layout.dart';
import 'observatory_artwork.dart';
import 'seasonal_trend_card.dart';

/// Rainfall evidence and units, with request and editor state in the dashboard.
class PrecipitationExplorer extends StatelessWidget {
  const PrecipitationExplorer({
    super.key,
    required this.analysis,
    required this.explorer,
    this.status,
  });

  final ClimateAnalysis? analysis;
  final Widget explorer;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final data = analysis;
    final rain = data?.precipitation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObservatoryHero(
          imagery: ObservatoryArtworkKind.precipitationHorizon,
          eyebrow: 'Precipitation exploration',
          title: 'How is rainfall changing?',
          description: 'Explore year-to-year rainfall variability and long-term evidence.',
          accent: AppColors.amber,
          compact: MediaQuery.sizeOf(context).width < AppBreakpoints.expanded,
          actions: explorer,
        ),
        ?status,
        if (data != null && rain != null) ...[
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) => AnnualChart(
              series: rain.series,
              seriesUnits: rain.seriesUnits,
              seriesColor: AppColors.amber,
              title: 'Annual Precipitation Total',
              trend: rain.trend,
              framed: false,
              fitYAxisLabels: true,
              plotHeight: constraints.maxWidth >= 800 ? 360 : 260,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.only(left: AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.amber, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANNUAL TOTAL · ${rain.seriesUnits}',
                  style: AppText.overline.copyWith(color: AppColors.amber),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Read annual totals separately from estimated change per decade.',
                  style: AppText.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ObservatorySection(
            title: 'Rainfall evidence',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                final wide = constraints.maxWidth >= 800 * scale;
                final available = constraints.maxWidth - AppSpacing.xxl;
                // The annual interpretation leads; seasonal evidence follows.
                // Stable children preserve expanded statistics on resize.
                return Wrap(
                  key: const ValueKey('precipitation_findings'),
                  spacing: AppSpacing.xxl,
                  runSpacing: AppSpacing.xl,
                  children: [
                    SizedBox(
                      width: wide ? available * .55 : constraints.maxWidth,
                      child: ClimateTrendCard(
                        title: 'Annual Precipitation Trend',
                        trend: rain.trend,
                        accentColor: AppColors.amber,
                        framed: false,
                      ),
                    ),
                    SizedBox(
                      width: wide ? available * .45 : constraints.maxWidth,
                      child: SeasonalTrendCard(
                        title: 'Seasonal Precipitation Trend',
                        trend: rain.seasonal,
                        accentColor: AppColors.amber,
                        framed: false,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (rain.excludedYears.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            ExcludedYearsPanel(excludedYears: rain.excludedYears),
          ],
          const SizedBox(height: AppSpacing.xl),
          ObservatorySection(
            title: 'Understanding precipitation',
            description:
                'Annual totals, estimated change and scientific limitations.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Annual series: ${rain.seriesUnits}. Annual change: ${rain.trend.slopeUnitsPerDecade}. Seasonal change: ${rain.seasonal.slopeUnitsPerDecade}.',
                  style: AppText.body.copyWith(color: AppColors.amber),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(rain.method, style: AppText.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  data.methodology.annualCompleteness,
                  style: AppText.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(data.methodology.seasonal, style: AppText.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  data.methodology.significanceBasis,
                  style: AppText.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  data.methodology.confidenceInterval,
                  style: AppText.bodySmall,
                ),
                for (final limitation in data.methodology.limitations) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(limitation, style: AppText.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
