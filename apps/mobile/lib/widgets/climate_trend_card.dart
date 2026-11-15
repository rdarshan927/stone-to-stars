import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import '../utils/climate_format.dart';
import 'app_card.dart';
import 'stat_tile.dart';
import 'status_pill.dart';

/// Observatory-styled card presenting an annual [TrendResult] for a single
/// climate variable (Temperature in [AppColors.cyan] or Precipitation in
/// [AppColors.amber]).
///
/// Primary statistics (Sen's slope, trend direction, statistical significance,
/// observation count, and plain-language interpretation) remain visible at all
/// times. Secondary statistical details (95% confidence interval, Hamed-Rao
/// corrected p-value, original Mann-Kendall p-value, and Kendall's τ-b) are
/// placed in an expandable section that is collapsed by default.
class ClimateTrendCard extends StatefulWidget {
  const ClimateTrendCard({
    super.key,
    required this.title,
    required this.trend,
    required this.accentColor,
    this.framed = true,
    this.eyebrow = 'ANNUAL TREND',
  });

  final String title;
  final TrendResult trend;
  final Color accentColor;

  /// Open presentation for a section without an enclosing card.
  final bool framed;
  final String eyebrow;

  @override
  State<ClimateTrendCard> createState() => _ClimateTrendCardState();
}

class _ClimateTrendCardState extends State<ClimateTrendCard> {
  bool _expanded = false;

  TrendResult get _trend => widget.trend;

  bool get _hasSecondaryStats =>
      (_trend.ci95LowPerDecade != null && _trend.ci95HighPerDecade != null) ||
      _trend.pValueHamedRao != null ||
      _trend.pValueOriginal != null ||
      _trend.kendallTau != null ||
      _trend.ci95Note.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_trend.hasResult) {
      return _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md),
            const StatusPill(
              label: 'Insufficient data',
              color: AppColors.textSecondary,
              icon: Icons.info_outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
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
                    'Insufficient data for trend analysis '
                    '(${_trend.nObservations} / ${_trend.minObservationsRequired} '
                    'observations required).',
                    style: AppText.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final dir = _trend.direction;
    final known = dir == 'increasing' || dir == 'decreasing';
    final up = dir == 'increasing';
    final sig = _trend.significant == true;
    final slope = _trend.senSlopePerDecade;

    // Accent colour highlights confirmed (significant) monotonic trends;
    // non-significant or directionless slopes use muted secondary text.
    final valueColor = (sig && known)
        ? widget.accentColor
        : AppColors.textSecondary;

    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: AppSpacing.md),
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
                child: Text(
                  _trend.slopeUnitsPerDecade,
                  style: AppText.bodySmall,
                ),
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
                  color: sig ? widget.accentColor : AppColors.textSecondary,
                  icon: up ? Icons.trending_up : Icons.trending_down,
                )
              else
                const StatusPill(
                  label: 'No clear direction',
                  color: AppColors.textSecondary,
                  icon: Icons.horizontal_rule,
                ),
              if (_trend.significant != null)
                StatusPill.significance(significant: sig)
              else
                const StatusPill(
                  label: 'Significance unavailable',
                  color: AppColors.textSecondary,
                  icon: Icons.info_outline,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_trend.interpretation, style: AppText.bodySmall),
          if (!sig) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _trend.significant == false
                  ? 'A non-significant result is inconclusive and does not imply '
                        'no change or a stable climate.'
                  : 'Statistical significance is unavailable; this result '
                        'does not establish a confirmed annual trend.',
              style: AppText.label.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          StatTile(label: 'Observations', value: '${_trend.nObservations}'),
          if (_hasSecondaryStats) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: MergeSemantics(
                child: Semantics(
                  expanded: _expanded,
                  child: TextButton.icon(
                    key: const ValueKey('climate_trend_details_toggle'),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.accentColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      minimumSize: const Size(
                        kMinInteractiveDimension,
                        kMinInteractiveDimension,
                      ),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: widget.accentColor,
                    ),
                    label: Text(
                      _expanded
                          ? 'Hide statistical details'
                          : 'Statistical details',
                      style: AppText.label.copyWith(
                        color: widget.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: AppSpacing.xs),
              if (_trend.ci95LowPerDecade != null &&
                  _trend.ci95HighPerDecade != null)
                StatTile(
                  label: '95% CI / decade',
                  value:
                      '${formatSlope(_trend.ci95LowPerDecade!)} to '
                      '${formatSlope(_trend.ci95HighPerDecade!)} '
                      '${_trend.slopeUnitsPerDecade}',
                ),
              if (_trend.pValueHamedRao != null)
                StatTile(
                  label: 'p (Hamed-Rao)',
                  value:
                      '${formatP(_trend.pValueHamedRao!)} '
                      '(lag ${_trend.hamedRaoLag})',
                ),
              if (_trend.pValueOriginal != null)
                StatTile(
                  label: 'p (original MK)',
                  value: formatP(_trend.pValueOriginal!),
                ),
              if (_trend.kendallTau != null)
                StatTile(
                  label: 'Kendall τ-b',
                  value: _trend.kendallTau!.toStringAsFixed(4),
                ),
              if (_trend.ci95Note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _trend.ci95Note,
                  style: AppText.label.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.eyebrow.toUpperCase(),
          style: AppText.overline.copyWith(color: widget.accentColor),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Semantics(
          header: true,
          child: Text(widget.title, style: AppText.subtitle),
        ),
      ],
    );
  }

  Widget _surface({required Widget child}) =>
      widget.framed ? AppCard(child: child) : child;
}
