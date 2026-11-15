import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'app_card.dart';

/// Open scientific field guide. Backend descriptions are displayed verbatim.
class MethodologyPanel extends StatelessWidget {
  const MethodologyPanel({
    super.key,
    required this.methodology,
    this.dataset,
    this.temperature,
    this.precipitation,
  });

  final Methodology methodology;
  final Dataset? dataset;
  final VariableAnalysis? temperature;
  final VariableAnalysis? precipitation;

  @override
  Widget build(BuildContext context) {
    final m = methodology;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('REFERENCE', 'Statistical Parameters', [
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = constraints.maxWidth >= 540 * scale
                  ? 3
                  : constraints.maxWidth >= 272 * scale
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - AppSpacing.lg * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: [
                  _parameter('Significance level (α)', '${m.alpha}', width),
                  _parameter(
                    'Min. observations',
                    '${m.minObservations} years',
                    width,
                  ),
                  _parameter('Hamed-Rao lag', 'lag ${m.hamedRaoLag}', width),
                ],
              );
            },
          ),
        ]),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            final width = constraints.maxWidth >= 900 * scale
                ? (constraints.maxWidth - AppSpacing.xxl) / 2
                : constraints.maxWidth;
            return Wrap(
              key: const ValueKey('methodology_sections'),
              spacing: AppSpacing.xxl,
              runSpacing: AppSpacing.xl,
              children: [
                SizedBox(
                  width: width,
                  child: _section('01', 'Data & completeness', [
                    Text(
                      dataset?.provider ?? 'NASA POWER',
                      style: AppText.body,
                    ),
                    if (dataset != null && dataset!.sources.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(dataset!.sources.join(' · '), style: AppText.label),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(m.annualCompleteness, style: AppText.bodySmall),
                    if (temperature != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Temperature · ${temperature!.seriesUnits}',
                        style: AppText.label.copyWith(color: AppColors.cyan),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(temperature!.method, style: AppText.bodySmall),
                    ],
                    if (precipitation != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Precipitation · ${precipitation!.seriesUnits}',
                        style: AppText.label.copyWith(color: AppColors.amber),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(precipitation!.method, style: AppText.bodySmall),
                    ],
                  ]),
                ),
                SizedBox(
                  width: width,
                  child: _section('02', "Sen's slope", [
                    Text(
                      'The median of pairwise slopes estimates the direction and magnitude of a monotonic trend using the actual observation years.',
                      style: AppText.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Slopes are reported per decade in the units shown with each result. A positive slope estimates an increase; a negative slope estimates a decrease. The sign alone does not establish statistical significance.',
                      style: AppText.bodySmall,
                    ),
                  ]),
                ),
                SizedBox(
                  width: width,
                  child: _section('03', 'Mann-Kendall & Hamed-Rao', [
                    Text(
                      'Mann-Kendall tests for monotonic trends. The Hamed-Rao correction adjusts the test variance for serial correlation; it does not change the observations or the estimated slope.',
                      style: AppText.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(m.significanceBasis, style: AppText.bodySmall),
                  ]),
                ),
                SizedBox(
                  width: width,
                  child: _section('04', 'Confidence intervals', [
                    Text(m.confidenceInterval, style: AppText.bodySmall),
                  ]),
                ),
                SizedBox(
                  width: width,
                  child: _section('05', 'Seasonality', [
                    Text(m.seasonal, style: AppText.bodySmall),
                  ]),
                ),
                SizedBox(
                  width: width,
                  child: _section('06', 'Month-wise Trends', [
                    Text(m.monthWise, style: AppText.bodySmall),
                  ]),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _section('07', 'Anomaly Baseline', [
          Text(m.baseline, style: AppText.bodySmall),
        ]),
        const SizedBox(height: AppSpacing.xl),
        AppCard.callout(
          accent: AppColors.amber,
          child: _section('08', 'Interpreting results', [
            Text(
              'Insufficient observations means the trend analysis lacks the '
              'required observations. Statistical significance unavailable '
              'means no significance result is supplied; it is not a '
              'non-significant result.',
              style: AppText.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'NASA POWER is model/reanalysis-derived and grid-based. '
              'It is not station-observed data. '
              'A non-significant result is inconclusive and does not imply '
              'no change or a stable climate.',
              style: AppText.bodySmall,
            ),
          ], accent: AppColors.amber),
        ),
        if (m.limitations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          _section('CAUTIONS', 'Limitations', [
            for (final limitation in m.limitations)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(limitation, style: AppText.bodySmall)),
                  ],
                ),
              ),
          ], accent: AppColors.amber),
        ],
      ],
    );
  }

  Widget _parameter(String label, String value, double width) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: AppText.numeric),
      ],
    ),
  );

  Widget _section(
    String step,
    String title,
    List<Widget> children, {
    Color accent = AppColors.cyan,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: AppSpacing.md),
      ExcludeSemantics(
        child: Text(step, style: AppText.overline.copyWith(color: accent)),
      ),
      const SizedBox(height: AppSpacing.xs),
      Semantics(header: true, child: Text(title, style: AppText.sectionTitle)),
      const SizedBox(height: AppSpacing.md),
      ...children,
    ],
  );
}
