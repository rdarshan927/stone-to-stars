import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/climate_analysis.dart';
import 'annual_chart.dart';
import 'climate_trend_card.dart';
import 'excluded_years_panel.dart';
import 'observatory_layout.dart';
import 'observatory_artwork.dart';
import 'seasonal_trend_card.dart';
import 'temperature_anomaly_explorer.dart';

/// Temperature presentation; request and editor state stay in the dashboard.
class TemperatureExplorer extends StatelessWidget {
  const TemperatureExplorer({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObservatoryHero(
          imagery: ObservatoryArtworkKind.temperatureHorizon,
          eyebrow: 'Temperature exploration',
          title: 'How is temperature changing?',
          description: 'Explore annual observations and seasonal evidence.',
          compact: MediaQuery.sizeOf(context).width < AppBreakpoints.expanded,
          actions: explorer,
        ),
        ?status,
        if (data != null) ...[
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) => AnnualChart(
              series: data.temperature.series,
              seriesUnits: data.temperature.seriesUnits,
              seriesColor: AppColors.cyan,
              title: 'Annual Mean Temperature',
              trend: data.temperature.trend,
              framed: false,
              plotHeight: constraints.maxWidth >= 800 ? 360 : 260,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(data.temperature.method, style: AppText.label),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final wide = constraints.maxWidth >= 800 * scale;
              final width = wide
                  ? (constraints.maxWidth - AppSpacing.xxl) / 2
                  : constraints.maxWidth;
              // Stable children retain expanded details across width changes.
              return Wrap(
                key: const ValueKey('temperature_findings'),
                spacing: AppSpacing.xxl,
                runSpacing: AppSpacing.xl,
                children: [
                  SizedBox(
                    width: width,
                    child: ClimateTrendCard(
                      title: 'Annual Temperature Trend',
                      trend: data.temperature.trend,
                      accentColor: AppColors.cyan,
                      framed: false,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: SeasonalTrendCard(
                      title: 'Seasonal Temperature Trend',
                      trend: data.temperature.seasonal,
                      accentColor: AppColors.cyan,
                      framed: false,
                    ),
                  ),
                ],
              );
            },
          ),
          if (data.temperature.excludedYears.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            ExcludedYearsPanel(excludedYears: data.temperature.excludedYears),
          ],
          const SizedBox(height: AppSpacing.xl),
          TemperatureAnomalyExplorer(result: data.temperature.anomalies),
          const SizedBox(height: AppSpacing.xl),
          ObservatorySection(
            title: 'Reading the evidence',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  data.methodology.annualCompleteness,
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
