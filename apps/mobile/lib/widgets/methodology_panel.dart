import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'app_card.dart';
import 'stat_tile.dart';

/// Methodology and limitations panel.
class MethodologyPanel extends StatelessWidget {
  const MethodologyPanel({super.key, required this.methodology});

  final Methodology methodology;

  @override
  Widget build(BuildContext context) {
    final m = methodology;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ANALYSIS METHODS',
            style: AppText.overline.copyWith(color: AppColors.cyan),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Semantics(
            header: true,
            child: Text('Methodology', style: AppText.title),
          ),
          const SizedBox(height: AppSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              // Use available panel width, after shell and card padding.
              // Allow at least 320 px per group, plus the column gap.
              final twoColumns =
                  constraints.maxWidth >=
                  AppBreakpoints.medium + AppSpacing.xxl * 2;
              final width = twoColumns
                  ? (constraints.maxWidth - AppSpacing.xl) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.xl,
                children: [
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section('Statistical Parameters', [
                          StatTile(
                            label: 'Significance level (α)',
                            value: '${m.alpha}',
                          ),
                          StatTile(
                            label: 'Min. observations',
                            value: '${m.minObservations} years',
                          ),
                          StatTile(
                            label: 'Hamed-Rao lag',
                            value: 'lag ${m.hamedRaoLag}',
                          ),
                          StatTile(
                            label: 'Annual completeness',
                            value: m.annualCompleteness,
                          ),
                        ]),
                        const SizedBox(height: AppSpacing.xl),
                        _section('Significance & CI', [
                          Text(m.significanceBasis, style: AppText.bodySmall),
                          const SizedBox(height: AppSpacing.sm),
                          Text(m.confidenceInterval, style: AppText.bodySmall),
                        ]),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section('Seasonality', [
                          Text(m.seasonal, style: AppText.bodySmall),
                        ]),
                        const SizedBox(height: AppSpacing.xl),
                        _section('Month-wise Trends', [
                          Text(m.monthWise, style: AppText.bodySmall),
                        ]),
                        const SizedBox(height: AppSpacing.xl),
                        _section('Anomaly Baseline', [
                          Text(m.baseline, style: AppText.bodySmall),
                        ]),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (m.limitations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: AppSpacing.lg),
            _section('Limitations', [
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
                      Expanded(
                        child: Text(limitation, style: AppText.bodySmall),
                      ),
                    ],
                  ),
                ),
            ]),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppCard.callout(
            accent: AppColors.amber,
            child: _section('Interpreting results', [
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
            ]),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(header: true, child: Text(title, style: AppText.subtitle)),
      const SizedBox(height: AppSpacing.sm),
      ...children,
    ],
  );
}
