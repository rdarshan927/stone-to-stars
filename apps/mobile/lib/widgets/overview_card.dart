import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'app_card.dart';
import 'status_pill.dart';

/// Width from which the two variable panels sit side by side.
const double kOverviewTwoColumnWidth = 720;

/// Formats a Sen's slope for display: signed, typographic minus, with
/// precision scaled to magnitude so the value stays short.
String formatSlope(double v) {
  final a = v.abs();
  final digits = a >= 100
      ? 0
      : a >= 10
      ? 1
      : a >= 1
      ? 2
      : 3;
  final s = a.toStringAsFixed(digits);
  if (double.parse(s) == 0) return s; // avoid "+0.000" / "−0.000"
  return '${v < 0 ? '−' : '+'}$s';
}

/// Formats a p-value with fixed precision, flooring very small values.
String formatP(double p) => p < 0.0001 ? '< 0.0001' : p.toStringAsFixed(4);

String _coord(double v, String pos, String neg) =>
    '${v.abs().toStringAsFixed(2)}°${v >= 0 ? pos : neg}';

/// Overview screen content: hero, one trend panel per climate variable, and
/// the NASA POWER data note. Purely presentational; all values come from
/// [analysis].
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
          trend: temp.trend,
          excludedYears: temp.excludedYears.length,
        );
        final precipPanel = _TrendPanel(
          title: 'Annual precipitation',
          noun: 'total precipitation',
          icon: Icons.water_drop,
          trend: precip.trend,
          excludedYears: precip.excludedYears.length,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(analysis: analysis, wide: wide),
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.lg),
            const _DataNote(),
          ],
        );
      },
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.analysis, required this.wide});

  final ClimateAnalysis analysis;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final loc = analysis.location;
    final per = analysis.period;
    final title =
        '${_coord(loc.latitude, 'N', 'S')}, ${_coord(loc.longitude, 'E', 'W')}';
    final period = '${per.startYear}–${per.endYear}';

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STONE TO STARS · EARTH SYSTEM TREND DETECTIVE',
          style: AppText.overline.copyWith(color: AppColors.cyan),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.headline,
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

    final badge = _SourceBadge(dataset: analysis.dataset);

    return AppCard(
      padding: EdgeInsets.all(wide ? AppSpacing.xl : AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                const SizedBox(width: AppSpacing.lg),
                badge,
              ],
            )
          else ...[
            heading,
            const SizedBox(height: AppSpacing.md),
            badge,
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _FactChip(
                icon: Icons.date_range_outlined,
                label: 'Period',
                value: period,
              ),
              _FactChip(
                icon: Icons.my_location_outlined,
                label: 'Requested',
                value:
                    '${loc.requestedLatitude.toStringAsFixed(4)}°, '
                    '${loc.requestedLongitude.toStringAsFixed(4)}°',
              ),
              if (loc.elevationM != null)
                _FactChip(
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

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadii.smAll,
        border: const Border.fromBorderSide(AppBorders.subtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
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
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.dataset});

  final Dataset dataset;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cyan.withAlpha(20),
        borderRadius: AppRadii.smAll,
        border: Border.fromBorderSide(AppBorders.tinted(AppColors.cyan)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dataset.provider,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(
              color: AppColors.cyan,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dataset.sources.isNotEmpty)
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

// ── Trend panel ─────────────────────────────────────────────────────────────

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.title,
    required this.noun,
    required this.icon,
    required this.trend,
    required this.excludedYears,
  });

  final String title;
  final String noun;
  final IconData icon;
  final TrendResult trend;
  final int excludedYears;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.cyan),
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
          if (trend.hasResult) ..._result(context) else _insufficient(),
        ],
      ),
    );
  }

  Widget _insufficient() {
    return Row(
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
    );
  }

  List<Widget> _result(BuildContext context) {
    final dir = trend.direction;
    final known = dir == 'increasing' || dir == 'decreasing';
    final up = dir == 'increasing';
    final sig = trend.significant ?? false;
    final slope = trend.senSlopePerDecade;

    // Colour only confirms *significant* trends; everything else is muted.
    final valueColor = !sig || !known
        ? AppColors.textSecondary
        : (up ? AppColors.cyan : AppColors.amber);

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
            StatusPill.direction(direction: dir, significant: sig)
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
      Text(sentence, style: AppText.bodySmall),
      const SizedBox(height: AppSpacing.md),
      const Divider(),
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

// ── Data note ───────────────────────────────────────────────────────────────

class _DataNote extends StatelessWidget {
  const _DataNote();

  @override
  Widget build(BuildContext context) {
    return AppCard.callout(
      accent: AppColors.amber,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.amber),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'NASA POWER provides model/reanalysis-derived gridded data '
              '(0.5° latitude × 0.625° longitude). '
              'It is not weather-station data. '
              'A non-significant trend does not mean climate is stable.',
              style: AppText.bodySmall.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
