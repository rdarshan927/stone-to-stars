import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/annual_chart.dart';

TrendResult _trend({
  bool? significant = true,
  double? slopePerDecade = 0.25,
  String status = 'ok',
  String direction = 'increasing',
  String units = '°C',
  String? slopeUnitsPerDecade,
  int nObservations = 10,
  double? pOriginal,
  double? pHamedRao,
  int hamedRaoLag = 1,
  double? kendallTau = 0.45,
  double? ciLow,
  double? ciHigh,
  String ci95Note = '95% CI',
  String? interpretation,
}) => TrendResult(
  status: status,
  nObservations: nObservations,
  minObservationsRequired: 10,
  valueUnits: units,
  alpha: 0.05,
  direction: direction,
  significant: status == 'ok' ? significant : null,
  pValueOriginal: status == 'ok'
      ? (pOriginal ?? (significant == true ? 0.004 : 0.42))
      : null,
  pValueHamedRao: status == 'ok'
      ? (pHamedRao ?? (significant == true ? 0.008 : 0.48))
      : null,
  hamedRaoLag: hamedRaoLag,
  kendallTau: status == 'ok' ? kendallTau : null,
  senSlopePerDecade: status == 'ok' ? slopePerDecade : null,
  slopeUnitsPerDecade: slopeUnitsPerDecade ?? '$units/decade',
  ci95LowPerDecade: status == 'ok' && slopePerDecade != null
      ? (ciLow ?? slopePerDecade - 0.1)
      : null,
  ci95HighPerDecade: status == 'ok' && slopePerDecade != null
      ? (ciHigh ?? slopePerDecade + 0.1)
      : null,
  ci95Note: ci95Note,
  interpretation:
      interpretation ??
      (significant == true ? 'Significant trend.' : 'No significant trend.'),
);

const series = [
  AnnualPoint(2000, 27),
  AnnualPoint(2001, 25),
  AnnualPoint(2005, 26),
  AnnualPoint(2010, 28),
];

Future<void> pumpChart(
  WidgetTester tester, {
  List<AnnualPoint> points = series,
  TrendResult? trend,
  double width = 360,
  double scale = 1,
  String units = '°C',
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AnnualChart(
              series: points,
              seriesUnits: units,
              seriesColor: AppColors.amber,
              title: 'Annual climate observations',
              trend: trend,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'gaps change only observed drawing; trend endpoints and values are preserved',
    (tester) async {
      final trend = _trend(slopePerDecade: 0.5);
      await pumpChart(tester, trend: trend);
      final bars = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData;
      expect(bars.first.spots.where((s) => s.isNull()).length, 2);
      expect(bars.first.spots.where((s) => !s.isNull()).toList(), [
        const FlSpot(2000, 27),
        const FlSpot(2001, 25),
        const FlSpot(2005, 26),
        const FlSpot(2010, 28),
      ]);
      expect(
        bars.last.spots,
        computeSenTrendSpots(
          years: [2000, 2001, 2005, 2010],
          values: [27, 25, 26, 28],
          senSlopePerDecade: 0.5,
        ),
      );
      expect(bars.last.spots.any((s) => s.isNull()), isFalse);
      final latest = bars.first.dotData.getDotPainter(
        bars.first.spots.last,
        0,
        bars.first,
        bars.first.spots.length - 1,
      ) as FlDotCirclePainter;
      expect(latest.radius, 4.5);
    },
  );

  for (final state in [
    'absent',
    'insufficient',
    'no slope',
    'significant',
    'non-significant',
    'unavailable',
  ]) {
    testWidgets('legend and summary reflect actual $state chart', (
      tester,
    ) async {
      final trend = switch (state) {
        'absent' => null,
        'insufficient' => _trend(status: 'insufficient_data'),
        'no slope' => _trend(slopePerDecade: null),
        'significant' => _trend(),
        'non-significant' => _trend(significant: false),
        _ => _trend(significant: null),
      };
      await pumpChart(tester, trend: trend);
      final hasLine = [
        'significant',
        'non-significant',
        'unavailable',
      ].contains(state);
      expect(find.text('Observed annual'), findsOneWidget);
      expect(find.text("Sen's slope"), hasLine ? findsOneWidget : findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp(
            r'4 annual observations from 2000 to 2010.*Latest \(2010\): 28.00 °C',
          ),
        ),
        findsOneWidget,
      );
      if (state == 'non-significant') {
        expect(
          find.bySemanticsLabel(RegExp('Non-significant result; inconclusive')),
          findsOneWidget,
        );
      }
      if (state == 'unavailable') {
        expect(
          find.bySemanticsLabel(RegExp('Statistical significance unavailable')),
          findsOneWidget,
        );
      }
      final heading = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Annual climate observations'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(heading.properties.header, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'empty chart preserves identity and count without repeated empty messages',
    (tester) async {
      await pumpChart(tester, points: []);
      expect(find.text('Annual climate observations'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
      expect(find.text('0 annual observations available.'), findsOneWidget);
      expect(find.text('No data available.'), findsNothing);
      expect(find.text('No annual observations'), findsNothing);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('Observed annual'), findsNothing);
    },
  );

  for (final width in [320.0, 360.0, 600.0, 768.0, 1024.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('labels and legend fit $width px at text scale $scale', (
        tester,
      ) async {
        await pumpChart(
          tester,
          points: List.generate(
            6,
            (i) => AnnualPoint(2020 + i, 1800 + i * 10.0),
          ),
          trend: _trend(significant: false),
          width: width,
          scale: scale,
          units: 'mm/year',
        );
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final chartRect = tester.getRect(find.byType(LineChart));
        expect(chartRect.height, greaterThanOrEqualTo(200));
        for (final element
            in find
                .descendant(
                  of: find.byType(AnnualChart),
                  matching: find.byType(RichText),
                )
                .evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        // Tick separation leaves room for a scaled four-digit year.
        final data = chart.data;
        final available =
            chartRect.width -
            data.titlesData.leftTitles.sideTitles.reservedSize;
        final spacing =
            available *
            data.titlesData.bottomTitles.sideTitles.interval! /
            (data.maxX - data.minX);
        final painter = TextPainter(
          text: TextSpan(text: '2025', style: const TextStyle(fontSize: 10)),
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout();
        expect(spacing, greaterThan(painter.width));
        painter.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'single observation and endpoint tooltips preserve year and units',
    (tester) async {
      await pumpChart(
        tester,
        points: [const AnnualPoint(2025, 1750.25)],
        units: 'mm/year',
      );
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.minX, 2024.5);
      expect(data.maxX, 2025.5);
      final tooltip = data.lineTouchData.touchTooltipData;
      expect(tooltip.fitInsideHorizontally, isTrue);
      expect(tooltip.fitInsideVertically, isTrue);
      final bar = data.lineBarsData.first;
      expect(
        tooltip
            .getTooltipItems([LineBarSpot(bar, 0, bar.spots.first)])
            .single!
            .text,
        '2025\n1750.25 mm/year',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'both endpoint tooltip values survive gaps and trend entry remains suppressed',
    (tester) async {
      await pumpChart(tester, trend: _trend());
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final observed = data.lineBarsData.first;
      final trend = data.lineBarsData.last;
      final items = data.lineTouchData.touchTooltipData.getTooltipItems([
        LineBarSpot(observed, 0, observed.spots.first),
        LineBarSpot(observed, 0, observed.spots.last),
        LineBarSpot(trend, 1, trend.spots.first),
      ]);
      expect(items[0]!.text, '2000\n27.00 °C');
      expect(items[1]!.text, '2010\n28.00 °C');
      expect(items[2], isNull);
    },
  );
}
