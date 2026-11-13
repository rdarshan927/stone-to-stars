import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'stat_tile.dart';

/// Methodology and limitations panel.
class MethodologyPanel extends StatelessWidget {
  const MethodologyPanel({super.key, required this.methodology});

  final Methodology methodology;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final m = methodology;

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
          Text(
            'Methodology',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _section('Statistical Parameters', [
            StatTile(label: 'Significance level (α)', value: '${m.alpha}'),
            StatTile(
              label: 'Min. observations',
              value: '${m.minObservations} years',
            ),
            StatTile(label: 'Hamed-Rao lag', value: 'lag ${m.hamedRaoLag}'),
            StatTile(label: 'Annual completeness', value: m.annualCompleteness),
          ]),
          const SizedBox(height: 14),
          _section('Significance & CI', [
            _textBlock(tt, m.significanceBasis),
            const SizedBox(height: 6),
            _textBlock(tt, m.confidenceInterval),
          ]),
          const SizedBox(height: 14),
          _section('Seasonality', [_textBlock(tt, m.seasonal)]),
          const SizedBox(height: 14),
          _section('Month-wise Trends', [_textBlock(tt, m.monthWise)]),
          const SizedBox(height: 14),
          _section('Anomaly Baseline', [_textBlock(tt, m.baseline)]),
          const SizedBox(height: 20),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          Text(
            'Limitations',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 10),
          ...m.limitations.map(
            (lim) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.circle, size: 6, color: AppColors.danger),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lim,
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.orange.withAlpha(80)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NASA POWER is model/reanalysis-derived and grid-based. '
                    'It is not station-observed data. '
                    'A non-significant result does NOT mean climate is stable — '
                    'it means the data are insufficient to detect a trend at the '
                    'chosen significance level.',
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

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }

  Widget _textBlock(TextTheme tt, String text) =>
      Text(text, style: tt.bodySmall?.copyWith(color: AppColors.textSecondary));
}
