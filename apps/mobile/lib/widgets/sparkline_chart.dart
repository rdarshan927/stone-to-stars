import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import 'annual_chart.dart';

/// Builds [FlSpot] points from [series] while preserving missing-year gaps.
///
/// Whenever consecutive observations in [series] are separated by more than one
/// calendar year (`series[i].year - series[i - 1].year > 1`), an
/// [FlSpot.nullSpot] is inserted between them so `fl_chart` breaks the line
/// across excluded/incomplete years rather than drawing a synthetic segment
/// across the gap.
List<FlSpot> buildSparklineSpots(List<AnnualPoint> series) {
  if (series.isEmpty) return const [];
  final spots = <FlSpot>[];
  for (var i = 0; i < series.length; i++) {
    if (i > 0 && series[i].year - series[i - 1].year > 1) {
      spots.add(FlSpot.nullSpot);
    }
    spots.add(FlSpot(series[i].year.toDouble(), series[i].value));
  }
  return spots;
}

/// Computes the arithmetic mean of the valid annual observations in [series].
///
/// Returns `null` when [series] is empty.
double? computeSeriesMean(List<AnnualPoint> series) {
  if (series.isEmpty) return null;
  var sum = 0.0;
  for (final point in series) {
    sum += point.value;
  }
  return sum / series.length;
}

/// Formats an annual observation or period mean value with units.
///
/// Temperature (`°C`) uses 2 decimal places; precipitation (`mm/year`) uses
/// 1 decimal place.
String formatObservationValue(double value, String units) {
  final decimals = units == '°C' ? 2 : 1;
  return '${value.toStringAsFixed(decimals)} $units';
}

/// Compact historical annual series chart for the Observatory Overview.
///
/// Plots genuine annual observations from [series], preserves missing-year
/// gaps with [FlSpot.nullSpot], overlays a visually distinct dashed Sen's
/// slope reference line when [trend] has a valid slope, and displays a footer
/// with both the latest annual value and the period mean.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.series,
    required this.seriesUnits,
    required this.accentColor,
    this.trend,
    this.semanticLabel,
    this.chartHeight = 136,
    this.compact = false,
  });

  final List<AnnualPoint> series;
  final String seriesUnits;
  final Color accentColor;
  final TrendResult? trend;
  final String? semanticLabel;
  final double chartHeight;

  /// Overview preview: keep the same observations and semantics, with no axes
  /// or repeated detail legend/footer. Full charts retain their default layout.
  final bool compact;

  bool get _isSignificant =>
      trend != null && trend!.hasResult && (trend!.significant ?? false);

  bool get _hasTrendLine =>
      trend != null &&
      trend!.hasResult &&
      trend!.senSlopePerDecade != null &&
      series.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final latestPoint = series.isEmpty ? null : series.last;
    final meanValue = computeSeriesMean(series);

    final latestLabel = latestPoint == null
        ? 'Latest'
        : 'Latest (${latestPoint.year})';
    final latestValueText = latestPoint == null
        ? '—'
        : formatObservationValue(latestPoint.value, seriesUnits);
    final meanValueText = meanValue == null
        ? '—'
        : formatObservationValue(meanValue, seriesUnits);

    final a11ySummary = _buildSemanticsLabel(
      latestPoint: latestPoint,
      latestValueText: latestValueText,
      meanValueText: meanValueText,
    );

    return Semantics(
      container: true,
      label: a11ySummary,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background.withAlpha(140),
          borderRadius: AppRadii.mdAll,
          border: const Border.fromBorderSide(AppBorders.subtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact) ...[
              _LegendRow(
                accentColor: accentColor,
                isSignificant: _isSignificant,
                showTrendLine: _hasTrendLine,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              height: chartHeight,
              child: series.isEmpty ? _buildEmptyState() : _buildChart(context),
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              _FooterStats(
                latestLabel: latestLabel,
                latestValue: latestValueText,
                meanValue: meanValueText,
                accentColor: _isSignificant
                    ? accentColor
                    : AppColors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildSemanticsLabel({
    required AnnualPoint? latestPoint,
    required String latestValueText,
    required String meanValueText,
  }) {
    final prefix = semanticLabel != null ? '$semanticLabel. ' : '';
    if (series.isEmpty) {
      return '${prefix}No annual observations available.';
    }
    final firstYear = series.first.year;
    final lastYear = series.last.year;
    return '${prefix}Annual series from $firstYear to $lastYear '
        '(${series.length} observations). '
        'Latest (${latestPoint!.year}): $latestValueText. '
        'Period mean: $meanValueText.';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No annual observations available.',
        style: AppText.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final years = series.map((p) => p.year).toList();
    final values = series.map((p) => p.value).toList();

    // Compute Sen's slope endpoints first so vertical bounds include both
    // observed data and the trend reference line.
    List<FlSpot>? trendSpots;
    if (_hasTrendLine) {
      trendSpots = computeSenTrendSpots(
        years: years,
        values: values,
        senSlopePerDecade: trend!.senSlopePerDecade!,
      );
    }

    var minY = values.reduce((a, b) => a < b ? a : b);
    var maxY = values.reduce((a, b) => a > b ? a : b);
    if (trendSpots != null) {
      for (final s in trendSpots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
    }
    final yRange = (maxY - minY).abs();
    final yPad = yRange < 1 ? 0.5 : yRange * 0.14;

    // P0-2 guard: avoid zero-width x-axis when series has a single point.
    final double minX;
    final double maxX;
    if (years.length == 1) {
      minX = years.first.toDouble() - 0.5;
      maxX = years.first.toDouble() + 0.5;
    } else {
      minX = years.first.toDouble();
      maxX = years.last.toDouble();
    }

    final observedColor = _isSignificant
        ? accentColor
        : accentColor.withAlpha(190);
    final lastYearX = years.last.toDouble();

    final spots = buildSparklineSpots(series);

    final lineBarsData = <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        isCurved: false,
        color: observedColor,
        barWidth: 1.8,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isLatest = spot.x == lastYearX;
            return FlDotCirclePainter(
              radius: isLatest ? 3.0 : 1.8,
              color: observedColor,
              strokeWidth: isLatest ? 1.5 : 0,
              strokeColor: AppColors.surface,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: accentColor.withAlpha(_isSignificant ? 26 : 14),
        ),
      ),
    ];

    if (trendSpots != null) {
      final trendLineColor = _isSignificant
          ? AppColors.textPrimary.withAlpha(220)
          : AppColors.textSecondary.withAlpha(155);
      lineBarsData.add(
        LineChartBarData(
          spots: trendSpots,
          isCurved: false,
          color: trendLineColor,
          barWidth: _isSignificant ? 1.6 : 1.3,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs, top: AppSpacing.xs),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY - yPad,
          maxY: maxY + yPad,
          lineBarsData: lineBarsData,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: compact
              ? const FlTitlesData(show: false)
              : FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (val, meta) {
                        if (val == meta.min || val == meta.max) {
                          return const SizedBox.shrink();
                        }
                        final formatted = yRange < 2
                            ? val.toStringAsFixed(2)
                            : (yRange < 20
                                  ? val.toStringAsFixed(1)
                                  : val.toStringAsFixed(0));
                        return Text(
                          formatted,
                          style: AppText.numeric.copyWith(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: _xInterval(years),
                      getTitlesWidget: (val, _) {
                        if ((val - val.roundToDouble()).abs() > 0.01) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${val.toInt()}',
                            style: AppText.numeric.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surfaceHigh,
              // P0-3 guard: return null for the Sen's slope trend-line bar so
              // no blank entry appears in the tooltip.
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                if (s.barIndex != 0) return null;
                return LineTooltipItem(
                  '${s.x.toInt()}\n'
                  '${formatObservationValue(s.y, seriesUnits)}',
                  AppText.numeric.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  double _xInterval(List<int> years) {
    final span = years.last - years.first;
    if (span <= 5) return 1;
    if (span <= 12) return 3;
    if (span <= 25) return 5;
    return 10;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.accentColor,
    required this.isSignificant,
    required this.showTrendLine,
  });

  final Color accentColor;
  final bool isSignificant;
  final bool showTrendLine;

  @override
  Widget build(BuildContext context) {
    final observedColor = isSignificant
        ? accentColor
        : accentColor.withAlpha(190);
    final trendColor = isSignificant
        ? AppColors.textPrimary.withAlpha(220)
        : AppColors.textSecondary.withAlpha(155);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _LegendItem(
          swatch: _SolidLineSwatch(color: observedColor),
          label: 'Observed annual',
        ),
        if (showTrendLine)
          _LegendItem(
            swatch: _DashedLineSwatch(color: trendColor),
            label: "Sen's slope",
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.swatch, required this.label});

  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(label, style: AppText.label.copyWith(fontSize: 11)),
        ),
      ],
    );
  }
}

class _SolidLineSwatch extends StatelessWidget {
  const _SolidLineSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _DashedLineSwatch extends StatelessWidget {
  const _DashedLineSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 6, height: 2, color: color),
          Container(width: 6, height: 2, color: color),
        ],
      ),
    );
  }
}

class _FooterStats extends StatelessWidget {
  const _FooterStats({
    required this.latestLabel,
    required this.latestValue,
    required this.meanValue,
    required this.accentColor,
  });

  final String latestLabel;
  final String latestValue;
  final String meanValue;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.spaceBetween,
      children: [
        _StatPair(
          label: latestLabel,
          value: latestValue,
          valueColor: accentColor,
        ),
        _StatPair(
          label: 'Period mean',
          value: meanValue,
          valueColor: AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _StatPair extends StatelessWidget {
  const _StatPair({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$label: ', style: AppText.label),
        Text(
          value,
          style: AppText.numeric.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
