import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';

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
          child: Text(
            'No data available.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
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
          getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(
            radius: 2.5,
            color: seriesColor,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(show: true, color: seriesColor.withAlpha(25)),
      ),
    ];

    // Add Sen's slope trend line if available.
    if (trend != null && trend!.hasResult && trend!.senSlopePerDecade != null) {
      final slope = trend!.senSlopePerDecade! / 10.0; // per year
      final n = values.length;
      final medianYear = years[n ~/ 2].toDouble();
      final medianValue = values[n ~/ 2];
      final intercept = medianValue - slope * medianYear;

      final trendSpots = [
        FlSpot(years.first.toDouble(), slope * years.first + intercept),
        FlSpot(years.last.toDouble(), slope * years.last + intercept),
      ];

      lineBarsData.add(
        LineChartBarData(
          spots: trendSpots,
          isCurved: false,
          color: AppColors.textSecondary.withAlpha(180),
          barWidth: 1.5,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
        ),
      );
    }

    final leftLabels = (yRange < 2) ? '%.2f' : (yRange < 20 ? '%.1f' : '%.0f');

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Text(
              seriesUnits,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: LineChart(
                LineChartData(
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
                        getTitlesWidget: (val, _) {
                          final yr = val.toInt();
                          if (!years.contains(yr)) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$yr',
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
                      getTooltipItems: (spots) => spots.map((s) {
                        // Only label the data line (index 0), ignore trend line.
                        if (s.barIndex != 0) {
                          return LineTooltipItem('', const TextStyle());
                        }
                        return LineTooltipItem(
                          '${s.x.toInt()}\n${s.y.toStringAsFixed(2)} $seriesUnits',
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
    if (span <= 10) return 2;
    if (span <= 25) return 5;
    return 10;
  }

  Widget _shell({required Widget child}) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}
