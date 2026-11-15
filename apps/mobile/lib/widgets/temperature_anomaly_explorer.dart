import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/climate_analysis.dart';
import '../utils/climate_format.dart';
import 'observatory_layout.dart';
import 'status_pill.dart';

/// Monthly departures returned by Python, independent of coordinate drafts.
/// Year selection only limits the view; no anomalies or statistics are computed.
class TemperatureAnomalyExplorer extends StatefulWidget {
  const TemperatureAnomalyExplorer({super.key, required this.result});

  final AnomalyResult? result;

  @override
  State<TemperatureAnomalyExplorer> createState() =>
      _TemperatureAnomalyExplorerState();
}

class _TemperatureAnomalyExplorerState
    extends State<TemperatureAnomalyExplorer> {
  int? _selectedYear;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void didUpdateWidget(TemperatureAnomalyExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.result, widget.result)) _selectedYear = null;
  }

  String _value(double value) {
    final formatted = formatSlope(value);
    // Preserve the distinction between a small nonzero value and a true zero.
    if (value != 0 && double.tryParse(formatted) == 0) {
      return '${value < 0 ? '−' : '+'}${value.abs().toStringAsExponential(2)}';
    }
    return formatted;
  }

  String _meaning(double value) => value > 0
      ? 'warmer than reference'
      : value < 0
      ? 'cooler than reference'
      : 'at reference';

  Color _color(double value) => value > 0
      ? AppColors.cyan
      : value < 0
      ? AppColors.blue
      : AppColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final baseline = result?.baseline;
    final hasPeriod = baseline?.startYear != null && baseline?.endYear != null;
    final usable = result?.hasResult == true && hasPeriod;
    final records = usable
        ? ([...result!.anomalies]..sort((a, b) {
            final year = a.year.compareTo(b.year);
            return year != 0 ? year : a.month.compareTo(b.month);
          }))
        : <AnomalyRecord>[];
    final years = records.map((r) => r.year).toSet().toList();
    final year = years.contains(_selectedYear)
        ? _selectedYear
        : years.lastOrNull;
    final monthly = {
      for (final r in records.where((r) => r.year == year)) r.month: r,
    };

    return ObservatorySection(
      title: 'Monthly temperature anomalies',
      description: 'Departures from the reference mean for the same calendar month, in °C.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (baseline != null) ...[
            Text(
              '${baseline.kind == 'standard_1991_2020' ? 'Standard reference period' : 'Custom reference period'}'
              '${hasPeriod ? ' · ${baseline.startYear}–${baseline.endYear}' : ' · years unavailable'}',
              style: AppText.subtitle,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label:
                  result == null ||
                      baseline == null ||
                      (result.hasResult && !hasPeriod)
                  ? 'Baseline unavailable'
                  : result.hasResult
                  ? 'Baseline sufficient'
                  : 'Insufficient baseline observations',
              color: usable ? AppColors.cyan : AppColors.textSecondary,
              icon: Icons.info_outline,
            ),
          ),
          if (baseline != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(baseline.note, style: AppText.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Reference completeness: at least ${baseline.minObservationsPerMonthRequired} valid observations per calendar month.',
              style: AppText.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (result != null && result.note != baseline?.note)
            Text(result.note, style: AppText.bodySmall),
          if (records.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              !usable
                  ? 'Monthly anomalies are unavailable without a sufficient reference period.'
                  : 'No monthly anomaly observations were returned.',
              style: AppText.body,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: math.min(constraints.maxWidth, 180 * scale),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Anomaly year',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          key: const ValueKey('temperature_anomaly_year'),
                          isExpanded: true,
                          value: year,
                          itemHeight: null,
                          menuMaxHeight: 320,
                          items: [
                            for (final y in years)
                              DropdownMenuItem(
                                value: y,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: Text('$y', style: AppText.numeric),
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedYear = value),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                Text(
                  '+ Warmer',
                  style: AppText.label.copyWith(color: AppColors.cyan),
                ),
                Text(
                  '− Cooler',
                  style: AppText.label.copyWith(color: AppColors.blue),
                ),
                Text(
                  '● At reference (zero)',
                  style: AppText.label.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _chart(context, year!, monthly),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${monthly.length}/12 monthly observations in $year. Blank months have no returned observation; they are not zero anomalies.',
              style: AppText.bodySmall,
            ),
            ExpansionTile(
              key: ValueKey('temperature_anomaly_values_$year'),
              tilePadding: EdgeInsets.zero,
              title: Text('Monthly values for $year', style: AppText.subtitle),
              children: [
                for (var month = 1; month <= 12; month++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        monthly[month] == null
                            ? '${_months[month - 1]} $year: no returned observation'
                            : '${_months[month - 1]} $year: ${_value(monthly[month]!.anomaly)} °C · ${_meaning(monthly[month]!.anomaly)}',
                        style: AppText.numeric,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Positive anomalies indicate warmer-than-reference months; negative anomalies indicate cooler-than-reference months. Zero indicates agreement with the reference mean. Monthly anomalies are not themselves a significance test. NASA POWER values are gridded estimates, not local weather-station measurements.',
            style: AppText.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _chart(
    BuildContext context,
    int year,
    Map<int, AnomalyRecord> monthly,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(11) / 11;
      final maxMagnitude = monthly.values.fold<double>(
        0,
        (m, r) => math.max(m, r.anomaly.abs()),
      );
      final bound = math.max(.5, maxMagnitude * 1.2);
      final yWidth = 60 * scale;
      final plotWidth = math.max(1.0, constraints.maxWidth - yWidth);
      final step = (12 / (plotWidth / (36 * scale)).floor().clamp(2, 12))
          .ceil();
      return Semantics(
        container: true,
        label:
            'Temperature anomalies for $year, in degrees Celsius. ${monthly.length} monthly observations. Zero reference line. Open Monthly values for a readable list.',
        child: SizedBox(
          height: 230 + 35 * (scale - 1),
          child: BarChart(
            key: ValueKey('temperature_anomaly_chart_$year'),
            duration: Duration.zero,
            BarChartData(
              minY: -bound,
              maxY: bound,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: bound / 2,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.border, strokeWidth: .5),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: 0,
                    color: AppColors.textSecondary,
                    strokeWidth: 1.5,
                  ),
                ],
              ),
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
                    reservedSize: yWidth,
                    interval: bound / 2,
                    minIncluded: false,
                    maxIncluded: false,
                    getTitlesWidget: (v, _) => Text(
                      v == 0 ? '0' : _value(v),
                      style: AppText.label.copyWith(fontSize: 11),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30 * scale,
                    getTitlesWidget: (v, _) => v.toInt() % step == 0
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              _months[v.toInt()],
                              style: AppText.label.copyWith(fontSize: 11),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              barGroups: [
                for (var month = 1; month <= 12; month++)
                  BarChartGroupData(
                    x: month - 1,
                    barRods: [
                      if (monthly[month] case final record?)
                        BarChartRodData(
                          toY: record.anomaly,
                          color: _color(record.anomaly),
                          width: (plotWidth / 30).clamp(4, 18),
                          borderRadius: BorderRadius.zero,
                          label: BarChartRodLabel(
                            show: record.anomaly == 0,
                            // A data marker, not twelve adjacent text labels.
                            // Keep it 8px and centered on the zero reference
                            // even with enlarged text; values remain in the list.
                            text: '●',
                            style: AppText.label.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 8 / scale,
                              height: 1,
                            ),
                            offset: const Offset(0, -4),
                          ),
                        ),
                    ],
                  ),
              ],
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: math.max(
                    80,
                    math.min(200, plotWidth - AppSpacing.lg),
                  ),
                  getTooltipColor: (_) => AppColors.surfaceHigh,
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${_months[group.x]} $year\n${_value(rod.toY)} °C\n${_meaning(rod.toY)}',
                    AppText.label.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
