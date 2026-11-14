import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';

/// Computes the two [FlSpot] endpoints of a Sen's slope trend line.
///
/// The intercept is anchored at the **statistical median** of [values] and the
/// **median year** — consistent with the Theil-Sen estimator definition used by
/// the backend:
///
///   intercept = median(y) − (senSlopePerDecade / 10) × median(x)
///
/// [years] must be in ascending order (guaranteed by the backend).
/// [values] corresponds positionally to [years] but need not be sorted.
///
/// Returns `null` when inputs are empty or mismatched in length.
///
/// This function is package-visible so that unit tests can verify the
/// intercept calculation without rendering a widget.
List<FlSpot>? computeSenTrendSpots({
  required List<int> years,
  required List<double> values,
  required double senSlopePerDecade,
}) {
  if (years.isEmpty || values.isEmpty || years.length != values.length) {
    return null;
  }

  final slopePerYear = senSlopePerDecade / 10.0;

  final n = years.length;

  // Median year: years are already sorted ascending, so index-based is correct.
  final medianYear = n.isOdd
      ? years[n ~/ 2].toDouble()
      : (years[n ~/ 2 - 1] + years[n ~/ 2]) / 2.0;

  // Statistical median of values: sort a copy first.
  final sortedValues = [...values]..sort();
  final medianValue = n.isOdd
      ? sortedValues[n ~/ 2]
      : (sortedValues[n ~/ 2 - 1] + sortedValues[n ~/ 2]) / 2.0;

  final intercept = medianValue - slopePerYear * medianYear;

  return [
    FlSpot(years.first.toDouble(), slopePerYear * years.first + intercept),
    FlSpot(years.last.toDouble(), slopePerYear * years.last + intercept),
  ];
}

/// Line chart of an annual climate series with an optional Sen's slope overlay.
class AnnualChart extends StatelessWidget {
  const AnnualChart({
    super.key,
    required this.series,
    required this.seriesUnits,
    required this.seriesColor,
    required this.title,
    this.trend,
  });

  final List<AnnualPoint> series;
  final String seriesUnits;
  final Color seriesColor;
  final String title;

  /// When provided, a trend line is drawn based on Sen's slope.
  final TrendResult? trend;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return _shell(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No data available.',
              style: AppText.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final years = series.map((p) => p.year).toList();
    final values = series.map((p) => p.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY).abs();
    final yPad = yRange < 1 ? 0.5 : yRange * 0.12;

    // P0-2: Explicitly constrain the x-axis to prevent fl_chart from generating
    // ticks outside the data range.
    //
    // Guard: when there is exactly one data point minX would equal maxX, which
    // would give fl_chart a zero-width axis and can cause assertion failures or
    // visual artefacts.  Use a small symmetric ±0.5 year range instead.
    final double minX;
    final double maxX;
    if (years.length == 1) {
      minX = years.first.toDouble() - 0.5;
      maxX = years.first.toDouble() + 0.5;
    } else {
      minX = years.first.toDouble();
      maxX = years.last.toDouble();
    }

    // Significance-aware fill opacity: brighter when trend is confirmed.
    final bool isTrendSignificant = trend?.significant == true;
    final int fillAlpha = isTrendSignificant ? 35 : 18;

    // Latest-point highlight: the last year in the ascending series.
    final int latestYear = years.last;

    final spots = [
      for (var i = 0; i < series.length; i++)
        FlSpot(years[i].toDouble(), values[i]),
    ];

    final lineBarsData = <LineChartBarData>[
      LineChartBarData(
        spots: spots,
        isCurved: false,
        color: seriesColor,
        barWidth: 1.8,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isLatest = spot.x.toInt() == latestYear;
            return FlDotCirclePainter(
              radius: isLatest ? 4.5 : 2.5,
              color: isLatest ? seriesColor : seriesColor.withAlpha(200),
              strokeWidth: isLatest ? 1.5 : 0,
              strokeColor: isLatest ? AppColors.background : Colors.transparent,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: seriesColor.withAlpha(fillAlpha),
        ),
      ),
    ];

    // P0-1: Add Sen's slope trend line using the correct statistical median
    // for the intercept, not the arbitrary middle list element.
    //
    // Significance-aware styling:
    //   significant   → seriesColor, full line weight, dashed — clearly visible.
    //   not significant → textSecondary muted, thinner — present but subordinate.
    // This matches the visual convention established in SparklineChart.
    if (trend != null && trend!.hasResult && trend!.senSlopePerDecade != null) {
      final trendSpots = computeSenTrendSpots(
        years: years,
        values: values,
        senSlopePerDecade: trend!.senSlopePerDecade!,
      );
      if (trendSpots != null) {
        final Color trendLineColor = isTrendSignificant
            ? seriesColor
            : AppColors.textSecondary.withAlpha(140);
        final double trendLineWidth = isTrendSignificant ? 1.5 : 1.0;
        lineBarsData.add(
          LineChartBarData(
            spots: trendSpots,
            isCurved: false,
            color: trendLineColor,
            barWidth: trendLineWidth,
            dashArray: [6, 4],
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }

    final leftLabels = (yRange < 2) ? '%.2f' : (yRange < 20 ? '%.1f' : '%.0f');

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(title, style: AppText.subtitle),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              seriesUnits,
              style: AppText.overline.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: LineChart(
                LineChartData(
                  // P0-2: Explicit x-range so ticks stay within the data.
                  minX: minX,
                  maxX: maxX,
                  minY: minY - yPad,
                  maxY: maxY + yPad,
                  lineBarsData: lineBarsData,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppColors.border, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (val, _) => Text(
                          leftLabels == '%.0f'
                              ? val.toStringAsFixed(0)
                              : leftLabels == '%.1f'
                              ? val.toStringAsFixed(1)
                              : val.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: _xInterval(years),
                        // P0-2: Removed the years.contains() membership guard
                        // that silently dropped labels for excluded years.
                        // With explicit minX/maxX the chart never generates
                        // ticks outside the data range.
                        getTitlesWidget: (val, _) {
                          // Guard against floating-point ticks that differ
                          // from an exact integer (defensive; shouldn't occur
                          // with integer intervals and integer minX/maxX).
                          if ((val - val.roundToDouble()).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${val.toInt()}',
                              style: const TextStyle(
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
                      // P0-3: Return null (not an empty LineTooltipItem) for
                      // the trend-line bar so fl_chart suppresses the entry
                      // entirely and no blank line appears in the tooltip.
                      getTooltipItems: (spots) => spots.map((s) {
                        if (s.barIndex != 0) return null;
                        return LineTooltipItem(
                          '${s.x.toInt()}\n'
                          '${s.y.toStringAsFixed(2)} $seriesUnits',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _xInterval(List<int> years) {
    final span = years.last - years.first;
    if (span <= 5) return 1; // ≤5 year query: label every year
    if (span <= 10) return 2;
    if (span <= 25) return 5;
    return 10;
  }

  Widget _shell({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadii.lgAll,
      border: Border.fromBorderSide(AppBorders.subtle),
    ),
    child: child,
  );
}
