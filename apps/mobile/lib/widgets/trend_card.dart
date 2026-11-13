import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'stat_tile.dart';

/// Displays a [TrendResult] for one climate variable.
class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.title, required this.trend});

  final String title;
  final TrendResult trend;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    if (!trend.hasResult) {
      return _shell(
        context,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleRow(tt),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Insufficient data for trend analysis '
                      '(${trend.nObservations} / ${trend.minObservationsRequired} '
                      'observations required).',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final dir = trend.direction;
    final sig = trend.significant ?? false;

    return _shell(
      context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titleRow(tt),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [_directionChip(dir), _significanceChip(sig)],
            ),
            const SizedBox(height: 14),
            if (trend.senSlopePerDecade != null)
              StatTile(
                label: 'Sen\'s slope',
                value:
                    '${trend.senSlopePerDecade!.toStringAsFixed(4)} ${trend.slopeUnitsPerDecade}',
                valueColor: _dirColor(dir),
              ),
            if (trend.ci95LowPerDecade != null &&
                trend.ci95HighPerDecade != null)
              StatTile(
                label: '95% CI / decade',
                value:
                    '${trend.ci95LowPerDecade!.toStringAsFixed(4)} to ${trend.ci95HighPerDecade!.toStringAsFixed(4)}',
              ),
            if (trend.pValueHamedRao != null)
              StatTile(
                label: 'p (Hamed-Rao)',
                value: trend.pValueHamedRao!.toStringAsFixed(4),
              ),
            if (trend.pValueOriginal != null)
              StatTile(
                label: 'p (original MK)',
                value: trend.pValueOriginal!.toStringAsFixed(4),
              ),
            if (trend.kendallTau != null)
              StatTile(
                label: 'Kendall τ-b',
                value: trend.kendallTau!.toStringAsFixed(4),
              ),
            StatTile(label: 'Observations', value: '${trend.nObservations}'),
            const SizedBox(height: 10),
            Text(
              trend.interpretation,
              style: tt.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (trend.ci95Note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                trend.ci95Note,
                style: tt.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shell(BuildContext context, {required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _titleRow(TextTheme tt) => Text(
    title,
    style: tt.titleMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimary,
    ),
  );

  Color _dirColor(String? dir) {
    if (dir == 'increasing') return AppColors.cyan;
    if (dir == 'decreasing') return AppColors.orange;
    return AppColors.textSecondary;
  }

  Widget _directionChip(String? dir) {
    final label = dir == null
        ? 'No direction'
        : dir[0].toUpperCase() + dir.substring(1);
    final color = _dirColor(dir);
    return _Chip(label: label, color: color);
  }

  Widget _significanceChip(bool sig) => _Chip(
    label: sig ? 'Significant' : 'Not significant',
    color: sig ? AppColors.cyan : AppColors.orange,
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
