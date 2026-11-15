import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/sparkline_chart.dart';

TrendResult _trend({
  bool significant = true,
  double? slopePerDecade = 0.25,
  String status = 'ok',
  String units = '°C',
}) => TrendResult(
  status: status,
  nObservations: 10,
  minObservationsRequired: 10,
  valueUnits: units,
  alpha: 0.05,
  direction: (slopePerDecade ?? 0) >= 0 ? 'increasing' : 'decreasing',
  significant: status == 'ok' ? significant : null,
  pValueOriginal: status == 'ok' ? (significant ? 0.004 : 0.42) : null,
  pValueHamedRao: status == 'ok' ? (significant ? 0.008 : 0.48) : null,
  hamedRaoLag: 1,
  kendallTau: status == 'ok' ? 0.45 : null,
  senSlopePerDecade: status == 'ok' ? slopePerDecade : null,
  slopeUnitsPerDecade: '$units/decade',
  ci95LowPerDecade: status == 'ok' && slopePerDecade != null
      ? slopePerDecade - 0.1
      : null,
  ci95HighPerDecade: status == 'ok' && slopePerDecade != null
      ? slopePerDecade + 0.1
      : null,
  ci95Note: '95% CI',
  interpretation: significant ? 'Significant trend.' : 'No significant trend.',
);

Widget _wrap(Widget child, {double width = 400}) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  group('buildSparklineSpots – missing-year gap preservation', () {
    test('returns empty list when series is empty', () {
      expect(buildSparklineSpots(const []), isEmpty);
    });

    test('produces contiguous FlSpots when years are consecutive', () {
      const series = [
        AnnualPoint(2020, 27.1),
        AnnualPoint(2021, 27.3),
        AnnualPoint(2022, 27.6),
      ];
      final spots = buildSparklineSpots(series);
      expect(spots, hasLength(3));
      expect(spots.any((s) => s == FlSpot.nullSpot), isFalse);
      expect(spots[0], const FlSpot(2020, 27.1));
      expect(spots[1], const FlSpot(2021, 27.3));
      expect(spots[2], const FlSpot(2022, 27.6));
    });

    test('inserts FlSpot.nullSpot across every missing-year gap', () {
      const series = [
        AnnualPoint(2018, 26.8),
        AnnualPoint(2020, 27.0), // gap: 2019 missing
        AnnualPoint(2021, 27.2), // consecutive
        AnnualPoint(2024, 27.5), // gap: 2022-2023 missing
      ];
      final spots = buildSparklineSpots(series);
      expect(spots, hasLength(6));
      expect(spots[0], const FlSpot(2018, 26.8));
      expect(spots[1], FlSpot.nullSpot);
      expect(spots[2], const FlSpot(2020, 27.0));
      expect(spots[3], const FlSpot(2021, 27.2));
      expect(spots[4], FlSpot.nullSpot);
      expect(spots[5], const FlSpot(2024, 27.5));
    });
  });

  group('computeSeriesMean & formatObservationValue', () {
    test('computeSeriesMean returns null for empty series and exact mean otherwise', () {
      expect(computeSeriesMean(const []), isNull);
      const series = [
        AnnualPoint(2020, 26.0),
        AnnualPoint(2021, 27.5),
        AnnualPoint(2022, 29.0),
      ];
      expect(computeSeriesMean(series), closeTo(27.5, 1e-9));
    });

    test('formatObservationValue formats °C with 2 decimals and mm/year with 1 decimal', () {
      expect(formatObservationValue(27.456, '°C'), '27.46 °C');
      expect(formatObservationValue(1420.34, 'mm/year'), '1420.3 mm/year');
    });
  });

  group('SparklineChart widget behavior', () {
    testWidgets('handles empty series safely with placeholder and em-dashes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SparklineChart(
            series: [],
            seriesUnits: '°C',
            accentColor: AppColors.cyan,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('No annual observations available.'), findsOneWidget);
      expect(find.text('Latest: '), findsOneWidget);
      expect(find.text('Period mean: '), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets(
      'single-point series uses symmetric ±0.5 year axis range (P0-2)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SparklineChart(
              series: const [AnnualPoint(2015, 27.4)],
              seriesUnits: '°C',
              accentColor: AppColors.cyan,
              trend: _trend(significant: true, slopePerDecade: 0.2),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.minX, closeTo(2014.5, 1e-9));
        expect(chart.data.maxX, closeTo(2015.5, 1e-9));
        expect(find.text('Latest (2015): '), findsOneWidget);
        expect(find.text('27.40 °C'), findsNWidgets(2));
      },
    );

    testWidgets('preserves missing-year gaps in rendered LineChart spots', (
      tester,
    ) async {
      const gapSeries = [
        AnnualPoint(2010, 26.5),
        AnnualPoint(2012, 27.0),
        AnnualPoint(2013, 27.5),
      ];

      await tester.pumpWidget(
        _wrap(
          const SparklineChart(
            series: gapSeries,
            seriesUnits: '°C',
            accentColor: AppColors.cyan,
          ),
        ),
      );

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final observedBar = chart.data.lineBarsData.first;
      expect(observedBar.spots, hasLength(4));
      expect(observedBar.spots[1], FlSpot.nullSpot);
    });

    testWidgets(
      "renders visually distinct dashed Sen's slope overlay and suppresses its tooltip",
      (tester) async {
        const series = [
          AnnualPoint(2000, 26.0),
          AnnualPoint(2001, 28.0),
          AnnualPoint(2002, 27.0),
        ];
        final trend = _trend(significant: true, slopePerDecade: 1.5);

        await tester.pumpWidget(
          _wrap(
            SparklineChart(
              series: series,
              seriesUnits: '°C',
              accentColor: AppColors.cyan,
              trend: trend,
            ),
          ),
        );

        expect(find.text('Observed annual'), findsOneWidget);
        expect(find.text("Sen's slope"), findsOneWidget);

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.lineBarsData, hasLength(2));

        final observedBar = chart.data.lineBarsData[0];
        final trendBar = chart.data.lineBarsData[1];

        // Observed bar is solid with dots; trend bar is dashed without dots.
        expect(observedBar.dashArray, isNull);
        expect(observedBar.dotData.show, isTrue);
        expect(trendBar.dashArray, [6, 4]);
        expect(trendBar.dotData.show, isFalse);
        expect(trendBar.color, isNot(equals(observedBar.color)));

        // Trend endpoints match statistical median calculation (P0-1).
        final expectedSpots = computeSenTrendSpots(
          years: [2000, 2001, 2002],
          values: [26.0, 28.0, 27.0],
          senSlopePerDecade: 1.5,
        )!;
        expect(trendBar.spots[0].x, closeTo(expectedSpots[0].x, 1e-9));
        expect(trendBar.spots[0].y, closeTo(expectedSpots[0].y, 1e-9));
        expect(trendBar.spots[1].x, closeTo(expectedSpots[1].x, 1e-9));
        expect(trendBar.spots[1].y, closeTo(expectedSpots[1].y, 1e-9));

        // Tooltip callback suppresses barIndex != 0 (P0-3).
        final tooltipFn =
            chart.data.lineTouchData.touchTooltipData.getTooltipItems;
        final items = tooltipFn([
          LineBarSpot(observedBar, 0, observedBar.spots.first),
          LineBarSpot(trendBar, 1, trendBar.spots.first),
        ]);
        expect(items[0], isNotNull);
        expect(items[1], isNull);
      },
    );

    testWidgets(
      'displays latest annual value and period mean in footer for temperature and precipitation',
      (tester) async {
        const precipSeries = [
          AnnualPoint(2020, 1200.0),
          AnnualPoint(2021, 1500.0),
          AnnualPoint(2022, 1350.0),
        ];

        await tester.pumpWidget(
          _wrap(
            SparklineChart(
              series: precipSeries,
              seriesUnits: 'mm/year',
              accentColor: AppColors.amber,
              trend: _trend(
                significant: true,
                slopePerDecade: -35.0,
                units: 'mm/year',
              ),
            ),
          ),
        );

        // Latest is 2022 -> 1350.0 mm/year; mean of (1200, 1500, 1350) is 1350.0 mm/year.
        expect(find.text('Latest (2022): '), findsOneWidget);
        expect(find.text('Period mean: '), findsOneWidget);
        expect(find.text('1350.0 mm/year'), findsNWidgets(2));
      },
    );

    testWidgets(
      'applies significance-aware styling for significant vs non-significant trends',
      (tester) async {
        const series = [
          AnnualPoint(2019, 26.5),
          AnnualPoint(2020, 27.0),
          AnnualPoint(2021, 27.5),
        ];

        // Significant trend
        await tester.pumpWidget(
          _wrap(
            SparklineChart(
              series: series,
              seriesUnits: '°C',
              accentColor: AppColors.cyan,
              trend: _trend(significant: true, slopePerDecade: 0.4),
            ),
          ),
        );
        final sigChart = tester.widget<LineChart>(find.byType(LineChart));
        final sigObservedColor = sigChart.data.lineBarsData[0].color!;
        final sigTrendColor = sigChart.data.lineBarsData[1].color!;
        expect(sigObservedColor, AppColors.cyan);

        // Non-significant trend
        await tester.pumpWidget(
          _wrap(
            SparklineChart(
              series: series,
              seriesUnits: '°C',
              accentColor: AppColors.cyan,
              trend: _trend(significant: false, slopePerDecade: 0.4),
            ),
          ),
        );
        final nonSigChart = tester.widget<LineChart>(find.byType(LineChart));
        final nonSigObservedColor = nonSigChart.data.lineBarsData[0].color!;
        final nonSigTrendColor = nonSigChart.data.lineBarsData[1].color!;

        expect(nonSigObservedColor.a, lessThan(sigObservedColor.a));
        expect(nonSigTrendColor.a, lessThan(sigTrendColor.a));
      },
    );

    for (final width in [320.0, 360.0, 400.0]) {
      testWidgets(
        'renders without overflow at ${width.toInt()} px and exposes Semantics',
        (tester) async {
          tester.view.physicalSize = Size(width, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          const series = [
            AnnualPoint(1981, 1410.2),
            AnnualPoint(2000, 1525.8),
            AnnualPoint(2025, 1680.4),
          ];

          await tester.pumpWidget(
            _wrap(
              SparklineChart(
                series: series,
                seriesUnits: 'mm/year',
                accentColor: AppColors.amber,
                semanticLabel: 'Annual precipitation sparkline',
                trend: _trend(
                  significant: true,
                  slopePerDecade: 45.2,
                  units: 'mm/year',
                ),
              ),
              width: width,
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(
            find.bySemanticsLabel(RegExp(r'Annual precipitation sparkline')),
            findsOneWidget,
          );
        },
      );
    }
  });
}
