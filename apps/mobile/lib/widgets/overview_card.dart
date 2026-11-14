import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import '../utils/climate_format.dart';
import 'sparkline_chart.dart';
import 'status_pill.dart';

// formatSlope and formatP are provided by climate_format.dart.
// Re-export so code that previously imported them from this file keeps working.
// export must appear before any declarations.
export '../utils/climate_format.dart' show formatSlope, formatP;

/// Width from which the two variable panels sit side by side.
const double kOverviewTwoColumnWidth = 720;

String _coord(double v, String pos, String neg) =>
    '${v.abs().toStringAsFixed(2)}°${v >= 0 ? pos : neg}';

/// Observatory Overview screen content:
/// 1. Editorial location & dataset header (unboxed typographic hierarchy).
/// 2. Prominent Temperature (cyan) and Precipitation (amber) trend sections
///    with embedded [SparklineChart]s, latest value, period mean, Sen's slope,
///    significance, and 95% confidence intervals.
/// 3. Visually quiet NASA POWER gridded data disclaimer.
class OverviewCard extends StatelessWidget {
  const OverviewCard({super.key, required this.analysis});

  final ClimateAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final temp = analysis.temperature;
    final precip = analysis.precipitation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kOverviewTwoColumnWidth;

        final tempPanel = _TrendPanel(
          title: 'Annual temperature',
          noun: 'mean temperature',
          icon: Icons.thermostat,
          accentColor: AppColors.cyan,
          variable: temp,
        );
        final precipPanel = _TrendPanel(
          title: 'Annual precipitation',
          noun: 'total precipitation',
          icon: Icons.water_drop,
          accentColor: AppColors.amber,
          variable: precip,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditorialHeader(analysis: analysis, wide: wide),
            const SizedBox(height: AppSpacing.xl),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tempPanel),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: precipPanel),
                ],
              )
            else ...[
              tempPanel,
              const SizedBox(height: AppSpacing.lg),
              precipPanel,
            ],
            const SizedBox(height: AppSpacing.xl),
            const _DataNote(),
          ],
        );
      },
    );
  }
}

// ── Editorial Observatory Header ────────────────────────────────────────────

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader({required this.analysis, required this.wide});

  final ClimateAnalysis analysis;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final loc = analysis.location;
    final per = analysis.period;
    final title =
        '${_coord(loc.latitude, 'N', 'S')}, ${_coord(loc.longitude, 'E', 'W')}';
    final period = '${per.startYear}–${per.endYear}';

    final eyebrow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.cyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'STONE TO STARS · EARTH SYSTEM TREND DETECTIVE',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.overline.copyWith(color: AppColors.cyan),
          ),
        ),
      ],
    );

    final headingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        eyebrow,
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: (wide ? AppText.display : AppText.headline).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Annual temperature and precipitation trends for $period at the '
          'NASA POWER cell nearest your requested point.',
          style: AppText.bodySmall,
        ),
      ],
    );

    final datasetReadout = _DatasetReadout(dataset: analysis.dataset);

    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: const BoxDecoration(
        border: Border(bottom: AppBorders.subtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: headingBlock),
                const SizedBox(width: AppSpacing.lg),
                datasetReadout,
              ],
            )
          else ...[
            headingBlock,
            const SizedBox(height: AppSpacing.md),
            datasetReadout,
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _TelemetryMetaItem(
                icon: Icons.date_range_outlined,
                label: 'Period',
                value: period,
              ),
              _TelemetryMetaItem(
                icon: Icons.my_location_outlined,
                label: 'Requested',
                value:
                    '${loc.requestedLatitude.toStringAsFixed(4)}°, '
                    '${loc.requestedLongitude.toStringAsFixed(4)}°',
              ),
              if (loc.elevationM != null)
                _TelemetryMetaItem(
                  icon: Icons.terrain_outlined,
                  label: 'Elevation',
                  value: '${loc.elevationM!.toStringAsFixed(0)} m',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TelemetryMetaItem extends StatelessWidget {
  const _TelemetryMetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$label  ', style: AppText.label),
                TextSpan(
                  text: value,
                  style: AppText.numeric.copyWith(fontSize: 13),
                ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DatasetReadout extends StatelessWidget {
  const _DatasetReadout({required this.dataset});

  final Dataset dataset;

  @override
  Widget build(BuildContext context) {
    final hasSources = dataset.sources.isNotEmpty;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DATASET PROVENANCE',
            style: AppText.overline.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            dataset.provider,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(
              color: AppColors.cyan,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasSources)
            Text(
              dataset.sources.join(', '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.label,
            ),
        ],
      ),
    );
  }
}

// ── Variable Trend Section ──────────────────────────────────────────────────

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.title,
    required this.noun,
    required this.icon,
    required this.accentColor,
    required this.variable,
  });

  final String title;
  final String noun;
  final IconData icon;
  final Color accentColor;
  final VariableAnalysis variable;

  TrendResult get trend => variable.trend;
  int get excludedYears => variable.excludedYears.length;

  @override
  Widget build(BuildContext context) {
    final isSig = trend.hasResult && (trend.significant ?? false);
    final topBarColor = isSig ? accentColor : accentColor.withAlpha(110);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgAll,
        border: const Border.fromBorderSide(AppBorders.subtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 3, color: topBarColor),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: accentColor),
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
                if (trend.hasResult)
                  ..._buildResultContent(context)
                else
                  ..._buildInsufficientContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInsufficientContent() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Insufficient data for a trend: ${trend.nObservations} of '
              '${trend.minObservationsRequired} years with complete data '
              'required.',
              style: AppText.bodySmall,
            ),
          ),
        ],
      ),
      if (variable.series.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        SparklineChart(
          series: variable.series,
          seriesUnits: variable.seriesUnits,
          accentColor: accentColor,
          trend: trend,
          semanticLabel: '$title historical series',
        ),
      ],
    ];
  }

  List<Widget> _buildResultContent(BuildContext context) {
    final dir = trend.direction;
    final known = dir == 'increasing' || dir == 'decreasing';
    final up = dir == 'increasing';
    final sig = trend.significant ?? false;
    final slope = trend.senSlopePerDecade;

    // Colour only confirms *significant* trends; everything else is muted.
    // Temperature uses cyan and precipitation uses amber when significant.
    final valueColor = !sig || !known ? AppColors.textSecondary : accentColor;

    final stat = [
      if (trend.pValueHamedRao != null) 'p = ${formatP(trend.pValueHamedRao!)}',
      'α = ${trend.alpha}',
    ].join(', ');

    final String sentence;
    if (sig) {
      sentence = known
          ? 'A statistically significant ${up ? 'increase' : 'decrease'} in '
                'annual $noun ($stat).'
          : 'A statistically significant trend in annual $noun ($stat).';
    } else {
      sentence = known
          ? 'The slope points ${up ? 'upward' : 'downward'}, but it is not '
                'statistically significant ($stat). This is inconclusive, '
                'not evidence of stability.'
          : 'No clear trend direction was detected ($stat).';
    }

    return [
      Text("SEN'S SLOPE", style: AppText.overline.copyWith(fontSize: 10)),
      const SizedBox(height: AppSpacing.xxs),
      Wrap(
        spacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Text(
            slope == null ? '—' : formatSlope(slope),
            style: AppText.numericLarge.copyWith(color: valueColor),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(trend.slopeUnitsPerDecade, style: AppText.bodySmall),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          if (known)
            StatusPill(
              label: up ? 'Increasing' : 'Decreasing',
              color: sig ? accentColor : AppColors.textSecondary,
              icon: up ? Icons.trending_up : Icons.trending_down,
            )
          else
            const StatusPill(
              label: 'No clear direction',
              color: AppColors.textSecondary,
              icon: Icons.horizontal_rule,
            ),
          StatusPill.significance(significant: sig),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      SparklineChart(
        series: variable.series,
        seriesUnits: variable.seriesUnits,
        accentColor: accentColor,
        trend: trend,
        semanticLabel: '$title historical series',
      ),
      const SizedBox(height: AppSpacing.md),
      Text(sentence, style: AppText.bodySmall),
      const SizedBox(height: AppSpacing.md),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpacing.sm),
      if (trend.ci95LowPerDecade != null && trend.ci95HighPerDecade != null)
        _Metric(
          label: '95% confidence range',
          value:
              '${formatSlope(trend.ci95LowPerDecade!)} to '
              '${formatSlope(trend.ci95HighPerDecade!)} '
              '${trend.slopeUnitsPerDecade}',
        ),
      _Metric(label: 'Years analysed', value: '${trend.nObservations}'),
      if (excludedYears > 0)
        _Metric(label: 'Years excluded (incomplete)', value: '$excludedYears'),
    ];
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: AppText.bodySmall)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppText.numeric.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quiet Data Disclaimer ───────────────────────────────────────────────────

class _DataNote extends StatelessWidget {
  const _DataNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      decoration: const BoxDecoration(border: Border(top: AppBorders.subtle)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'NASA POWER provides model/reanalysis-derived gridded data '
              '(0.5° latitude × 0.625° longitude). '
              'It is not weather-station data. '
              'A non-significant trend does not mean climate is stable.',
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
