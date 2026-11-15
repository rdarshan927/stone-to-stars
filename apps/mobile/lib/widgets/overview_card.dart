import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import '../utils/climate_format.dart';
import 'observatory_layout.dart';
import 'observatory_artwork.dart';
import 'sparkline_chart.dart';
import 'status_pill.dart';

export '../utils/climate_format.dart' show formatSlope, formatP;

/// Compact highlights can share a row when each has adequate reading width.
const double kOverviewTwoColumnWidth = 720;

String _coord(double v, String pos, String neg) =>
    '${v.abs().toStringAsFixed(2)}°${v >= 0 ? pos : neg}';

/// Earth Observatory introduction, location explorer, qualified findings,
/// compact climate highlights, and provenance. Query state stays in Dashboard.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.analysis,
    this.explorer,
    this.status,
    this.onTemperature,
    this.onPrecipitation,
  });

  final ClimateAnalysis? analysis;
  final Widget? explorer;
  final Widget? status;
  final VoidCallback? onTemperature;
  final VoidCallback? onPrecipitation;

  @override
  Widget build(BuildContext context) {
    final data = analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObservatoryHero(
          imagery: ObservatoryArtworkKind.globe,
          compact: MediaQuery.sizeOf(context).width < AppBreakpoints.medium,
          eyebrow: 'Earth Observatory',
          title: 'How is the climate changing here?',
          description:
              'Explore temperature and precipitation with NASA POWER data.',
          actions: explorer,
          supporting: data == null ? status : _ClimateInsight(analysis: data),
        ),
        if (data != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final width =
                  constraints.maxWidth >= kOverviewTwoColumnWidth * scale
                  ? (constraints.maxWidth - AppSpacing.lg) / 2
                  : constraints.maxWidth;
              return Wrap(
                key: const ValueKey('overview_findings'),
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.lg,
                children: [
                  SizedBox(
                    width: width,
                    child: _ClimateHighlight(
                      title: 'Annual temperature',
                      variable: data.temperature,
                      accent: AppColors.cyan,
                      icon: Icons.thermostat,
                      action: 'Explore temperature',
                      onOpen: onTemperature,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ClimateHighlight(
                      title: 'Annual precipitation',
                      variable: data.precipitation,
                      accent: AppColors.amber,
                      icon: Icons.water_drop,
                      action: 'Explore precipitation',
                      onOpen: onPrecipitation,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          ObservatorySection(
            title: 'Data & provenance',
            child: _Provenance(analysis: data),
          ),
        ],
      ],
    );
  }
}

/// Each statement refers to one variable. No combined warming/wetting headline
/// can accidentally turn an uncertain estimate into an established finding.
class _ClimateInsight extends StatelessWidget {
  const _ClimateInsight({required this.analysis});
  final ClimateAnalysis analysis;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: AppSpacing.lg),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: AppColors.cyan, width: 2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLIMATE INSIGHT',
          style: AppText.overline.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: AppSpacing.md),
        _finding(
          'Temperature',
          analysis.temperature.trend,
          'mean temperature',
          AppColors.cyan,
        ),
        const SizedBox(height: AppSpacing.md),
        _finding(
          'Precipitation',
          analysis.precipitation.trend,
          'total precipitation',
          AppColors.amber,
        ),
      ],
    ),
  );

  Widget _finding(String title, TrendResult trend, String noun, Color accent) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppText.label.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(_narrative(trend, noun), style: AppText.bodySmall),
        ],
      );
}

String _narrative(TrendResult trend, String noun) {
  if (!trend.hasResult) {
    return 'Insufficient data for a trend: ${trend.nObservations} of '
        '${trend.minObservationsRequired} years with complete data required '
        'for annual $noun.';
  }
  if (trend.significant == null) {
    return 'Statistical significance is unavailable for annual $noun; this result '
        'does not establish a confirmed annual trend.';
  }
  final known =
      trend.direction == 'increasing' || trend.direction == 'decreasing';
  final up = trend.direction == 'increasing';
  final p = trend.pValueHamedRao == null
      ? null
      : formatP(trend.pValueHamedRao!);
  final stat = [
    if (p != null) 'p ${p.startsWith('<') ? '' : '= '}$p',
    'α = ${trend.alpha}',
  ].join(', ');
  if (trend.significant == true) {
    return known
        ? 'A statistically significant ${up ? 'increase' : 'decrease'} in annual $noun ($stat).'
        : 'A statistically significant trend in annual $noun ($stat).';
  }
  return known
      ? 'The estimated $noun slope points ${up ? 'upward' : 'downward'}, but it is '
            'not statistically significant ($stat). This is inconclusive, not evidence of stability.'
      : 'No clear trend direction was detected for annual $noun ($stat). '
            'This is inconclusive, not evidence of stability.';
}

class _ClimateHighlight extends StatelessWidget {
  const _ClimateHighlight({
    required this.title,
    required this.variable,
    required this.accent,
    required this.icon,
    required this.action,
    this.onOpen,
  });
  final String title;
  final VariableAnalysis variable;
  final Color accent;
  final IconData icon;
  final String action;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final trend = variable.trend;
    final known =
        trend.direction == 'increasing' || trend.direction == 'decreasing';
    final confirmed = trend.hasResult && trend.significant == true && known;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withAlpha(20), AppColors.navigation],
        ),
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: accent.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: AppText.subtitle),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (!trend.hasResult)
            const StatusPill(
              label: 'Insufficient data',
              color: AppColors.textSecondary,
              icon: Icons.info_outline,
            )
          else ...[
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  trend.senSlopePerDecade == null
                      ? '—'
                      : formatSlope(trend.senSlopePerDecade!),
                  style: AppText.numericLarge.copyWith(
                    color: confirmed ? accent : AppColors.textSecondary,
                  ),
                ),
                Text(trend.slopeUnitsPerDecade, style: AppText.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusPill(
                  label: known
                      ? (trend.direction == 'increasing'
                            ? 'Increasing'
                            : 'Decreasing')
                      : 'No clear direction',
                  color: confirmed ? accent : AppColors.textSecondary,
                  icon: known
                      ? (trend.direction == 'increasing'
                            ? Icons.trending_up
                            : Icons.trending_down)
                      : Icons.horizontal_rule,
                ),
                if (trend.significant == null)
                  const StatusPill(
                    label: 'Significance unavailable',
                    color: AppColors.textSecondary,
                    icon: Icons.info_outline,
                  )
                else
                  StatusPill.significance(significant: trend.significant!),
              ],
            ),
          ],
          if (variable.series.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SparklineChart(
              series: variable.series,
              seriesUnits: variable.seriesUnits,
              accentColor: accent,
              trend: trend,
              compact: true,
              chartHeight: 64,
              semanticLabel: '$title historical series',
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            Text('No annual observations available.', style: AppText.bodySmall),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (trend.hasResult)
            _Metadata(label: 'Years analysed', value: '${trend.nObservations}'),
          if (variable.excludedYears.isNotEmpty)
            _Metadata(
              label: 'Years excluded (incomplete)',
              value: '${variable.excludedYears.length}',
            ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              minimumSize: const Size(
                kMinInteractiveDimension,
                kMinInteractiveDimension,
              ),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    children: [
      Text(label, style: AppText.label),
      Text(value, style: AppText.numeric.copyWith(fontSize: 13)),
    ],
  );
}

class _Provenance extends StatelessWidget {
  const _Provenance({required this.analysis});
  final ClimateAnalysis analysis;
  @override
  Widget build(BuildContext context) {
    final location = analysis.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATASET PROVENANCE', style: AppText.overline),
        const SizedBox(height: AppSpacing.sm),
        Text(
          analysis.dataset.provider,
          style: AppText.body.copyWith(fontWeight: FontWeight.w600),
        ),
        if (analysis.dataset.sources.isNotEmpty)
          Text(analysis.dataset.sources.join(', '), style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.md),
        _Metadata(
          label: 'NASA POWER grid cell',
          value:
              '${_coord(location.latitude, 'N', 'S')}, ${_coord(location.longitude, 'E', 'W')}',
        ),
        _Metadata(
          label: 'Requested',
          value:
              '${location.requestedLatitude.toStringAsFixed(4)}°, ${location.requestedLongitude.toStringAsFixed(4)}°',
        ),
        _Metadata(
          label: 'Analysis period',
          value: '${analysis.period.startYear}–${analysis.period.endYear}',
        ),
        if (location.elevationM != null)
          _Metadata(
            label: 'Elevation',
            value: '${location.elevationM!.toStringAsFixed(0)} m',
          ),
        const SizedBox(height: AppSpacing.md),
        Text(analysis.methodology.significanceBasis, style: AppText.bodySmall),
        Text(analysis.methodology.annualCompleteness, style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Text(
          'NASA POWER provides model/reanalysis-derived gridded data '
          '(0.5° latitude × 0.625° longitude). It is not weather-station data. '
          'A non-significant trend does not mean climate is stable.',
          style: AppText.bodySmall,
        ),
      ],
    );
  }
}
