// P3.4 Climate Visualization tests.
//
// Batch 1: AnnualChart upgrades and climate_format.dart helpers.
//   - Significance-aware Sen's slope overlay colour and width.
//   - Significance-aware area fill opacity.
//   - Latest-point highlight (larger dot on the most recent year).
//   - Shell uses AppRadii.lgAll / AppBorders.subtle.
//   - Title uses AppText.subtitle; unit overline uses AppText.overline.
//   - formatSlope and formatP from climate_format.dart.
//   - All existing P0/P1 guards preserved (computeSenTrendSpots, single-point
//     guard, tooltip suppression tested in p0_verification_test.dart).
//
// Batches 2–4 tests are added in groups below.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/utils/climate_format.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/climate_trend_card.dart';
import 'package:mobile/widgets/status_pill.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

/// A three-year ascending series with no gaps.
const List<AnnualPoint> _series3 = [
  AnnualPoint(2020, 26.0),
  AnnualPoint(2021, 27.0),
  AnnualPoint(2022, 28.0),
];

/// A longer series so that the latest-point (2025) is clearly distinguishable.
const List<AnnualPoint> _series5 = [
  AnnualPoint(2021, 26.0),
  AnnualPoint(2022, 26.4),
  AnnualPoint(2023, 26.8),
  AnnualPoint(2024, 27.2),
  AnnualPoint(2025, 27.6),
];

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

/// Collect all [LineChartBarData] from the first [LineChart] in the tree.
List<LineChartBarData> _chartBars(WidgetTester tester) {
  final chart = tester.widget<LineChart>(find.byType(LineChart).first);
  return chart.data.lineBarsData;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── formatSlope ────────────────────────────────────────────────────────────

  group('formatSlope', () {
    test('returns unsigned zero without sign prefix', () {
      // formatSlope returns the raw toStringAsFixed string for values that
      // round to zero — no sign prefix, with the precision for the magnitude.
      // For 0.0 the magnitude is < 1, so digits = 3 → '0.000'.
      expect(formatSlope(0.0), '0.000');
      expect(formatSlope(-0.0), '0.000');
    });

    test('uses typographic minus (U+2212) for negative values', () {
      expect(formatSlope(-0.034), startsWith('−'));
      expect(formatSlope(-12.5), startsWith('−'));
    });

    test('uses plus prefix for positive values', () {
      expect(formatSlope(0.034), startsWith('+'));
      expect(formatSlope(10.0), startsWith('+'));
    });

    test('scales decimal precision to magnitude', () {
      // < 1: 3 decimal places
      expect(formatSlope(0.034), '+0.034');
      // 1–9.9: 2 decimal places
      expect(formatSlope(1.5), '+1.50');
      // 10–99.9: 1 decimal place
      expect(formatSlope(12.5), '+12.5');
      // ≥ 100: 0 decimal places
      expect(formatSlope(120.0), '+120');
    });

    test('negative small value formats correctly', () {
      expect(formatSlope(-0.034), '−0.034');
    });
  });

  // ── formatP ───────────────────────────────────────────────────────────────

  group('formatP', () {
    test('formats normal p-values to 4 decimal places', () {
      expect(formatP(0.0082), '0.0082');
      expect(formatP(0.4200), '0.4200');
    });

    test('floors very small p-values to < 0.0001', () {
      expect(formatP(0.00009), '< 0.0001');
      expect(formatP(0.0), '< 0.0001');
    });

    test('boundary: exactly 0.0001 is not floored', () {
      expect(formatP(0.0001), '0.0001');
    });
  });

  // ── AnnualChart: empty series ──────────────────────────────────────────────

  group('AnnualChart – empty series', () {
    testWidgets('renders placeholder text without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: [],
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'Annual Mean Temperature',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text('0 annual observations available.'), findsOneWidget);
    });
  });

  // ── AnnualChart: significance-aware trend line ─────────────────────────────

  group('AnnualChart – significance-aware Sen\'s slope overlay', () {
    testWidgets('significant trend: overlay uses seriesColor (cyan)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'Annual Mean Temperature',
            trend: _trend(significant: true, slopePerDecade: 0.25),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final bars = _chartBars(tester);
      // bar 0: observed series; bar 1: trend line
      expect(bars.length, 2);
      final trendBar = bars[1];

      // Colour: significant → seriesColor (AppColors.cyan)
      expect(trendBar.color, AppColors.cyan);
      // Width: significant → 1.5
      expect(trendBar.barWidth, 1.5);
      // Always dashed
      expect(trendBar.dashArray, [6, 4]);
      // No dots on trend line
      expect(trendBar.dotData.show, isFalse);
    });

    testWidgets(
      'non-significant trend: overlay uses muted textSecondary colour',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AnnualChart(
              series: _series3,
              seriesUnits: '°C',
              seriesColor: AppColors.cyan,
              title: 'Annual Mean Temperature',
              trend: _trend(significant: false, slopePerDecade: 0.05),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        final bars = _chartBars(tester);
        expect(bars.length, 2);
        final trendBar = bars[1];

        // Not significant → muted, NOT seriesColor
        expect(trendBar.color, isNot(AppColors.cyan));
        // Width: not significant → 1.0
        expect(trendBar.barWidth, 1.0);
        // Still dashed
        expect(trendBar.dashArray, [6, 4]);
      },
    );

    testWidgets('no trend provided: only observed series bar rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'Annual Mean Temperature',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final bars = _chartBars(tester);
      expect(bars.length, 1); // no trend bar
    });

    testWidgets('trend with null senSlopePerDecade: no overlay rendered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'Annual Mean Temperature',
            trend: _trend(status: 'insufficient_data', slopePerDecade: null),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final bars = _chartBars(tester);
      expect(bars.length, 1);
    });
  });

  // ── AnnualChart: area fill opacity ────────────────────────────────────────

  group('AnnualChart – significance-aware area fill opacity', () {
    // BarAreaData in fl_chart 1.3+ uses `.color` (Color?), not `.colors`.
    // Compare the full Color value to avoid the deprecated Color.alpha getter.
    Color fillColor(WidgetTester tester) {
      final bars = _chartBars(tester);
      return bars[0].belowBarData.color!;
    }

    testWidgets('significant trend uses higher fill alpha (35)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'T',
            trend: _trend(significant: true),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(fillColor(tester), AppColors.cyan.withAlpha(35));
    });

    testWidgets('non-significant trend uses lower fill alpha (18)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'T',
            trend: _trend(significant: false),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(fillColor(tester), AppColors.cyan.withAlpha(18));
    });

    testWidgets('no trend uses lower fill alpha (18)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'T',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(fillColor(tester), AppColors.cyan.withAlpha(18));
    });
  });

  // ── AnnualChart: latest-point highlight ───────────────────────────────────

  group('AnnualChart – latest-point dot highlight', () {
    testWidgets('latest year dot is larger than intermediate dots', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: _series5,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'T',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final bars = _chartBars(tester);
      final seriesBar = bars[0];
      final painter = seriesBar.dotData.getDotPainter;

      // Spot for latest year (2025)
      final latestSpot = seriesBar.spots.last; // x == 2025
      final latestPainter = painter(
        latestSpot,
        0,
        seriesBar,
        seriesBar.spots.length - 1,
      ) as FlDotCirclePainter;

      // Spot for an intermediate year (2022)
      final midSpot = seriesBar.spots[1]; // x == 2022
      final midPainter =
          painter(midSpot, 0, seriesBar, 1) as FlDotCirclePainter;

      expect(latestPainter.radius, greaterThan(midPainter.radius));
      // Latest dot has a stroke; intermediate dots do not.
      expect(latestPainter.strokeWidth, greaterThan(0));
      expect(midPainter.strokeWidth, 0);
    });
  });

  // ── AnnualChart: shell decoration ─────────────────────────────────────────

  group('AnnualChart – shell uses AppBorders.subtle / AppRadii.lgAll', () {
    testWidgets('shell decoration matches Observatory tokens', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'Annual Mean Temperature',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      // Find the outermost Container (the shell).
      final containers = tester
          .widgetList<Container>(find.byType(Container))
          .toList();
      final shell = containers.firstWhere(
        (c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).color == AppColors.surface,
      );
      final decoration = shell.decoration as BoxDecoration;

      // Border: AppBorders.subtle
      expect(decoration.border, Border.fromBorderSide(AppBorders.subtle));
      // Radius: AppRadii.lgAll
      expect(decoration.borderRadius, AppRadii.lgAll);
    });
  });

  // ── AnnualChart: title/unit typography ───────────────────────────────────

  group('AnnualChart – title and unit typography', () {
    testWidgets('title is rendered as AppText.subtitle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'Annual Mean Temperature',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final titleWidget = tester.widget<Text>(
        find.text('Annual Mean Temperature'),
      );
      expect(titleWidget.style?.fontSize, AppText.subtitle.fontSize);
      expect(titleWidget.style?.fontWeight, AppText.subtitle.fontWeight);
    });

    testWidgets('unit overline is rendered with AppText.overline style', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'T',
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final unitWidget = tester.widget<Text>(find.text('°C'));
      // AppText.overline uses letterSpacing; just check fontSize matches.
      expect(unitWidget.style?.fontSize, AppText.overline.fontSize);
    });
  });

  // ── AnnualChart: narrow-width regression (P1) ─────────────────────────────

  group('AnnualChart – narrow-width layout regression', () {
    for (final w in [320.0, 360.0, 400.0]) {
      testWidgets('no overflow at ${w.toInt()} px wide', (tester) async {
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(
            AnnualChart(
              series: _series3,
              seriesUnits: '°C',
              seriesColor: AppColors.cyan,
              title: 'Annual Mean Temperature',
              trend: _trend(significant: true),
            ),
            width: w,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ── AnnualChart: P0-3 tooltip suppression regression ─────────────────────

  group('AnnualChart – P0-3 tooltip suppression regression', () {
    testWidgets('getTooltipItems returns null for barIndex != 0 (trend bar)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnnualChart(
            series: _series3,
            seriesUnits: '°C',
            seriesColor: AppColors.cyan,
            title: 'T',
            trend: _trend(significant: true),
          ),
        ),
      );
      expect(tester.takeException(), isNull);

      final chart = tester.widget<LineChart>(find.byType(LineChart).first);
      final getItems =
          chart.data.lineTouchData.touchTooltipData.getTooltipItems;

      // Fabricate two touched spots: index 0 (observed) and index 1 (trend).
      final spotOnSeries = LineBarSpot(
        chart.data.lineBarsData[0],
        0,
        chart.data.lineBarsData[0].spots[0],
      );
      final spotOnTrend = LineBarSpot(
        chart.data.lineBarsData[1],
        1,
        chart.data.lineBarsData[1].spots[0],
      );

      final items = getItems([spotOnSeries, spotOnTrend]);
      expect(items[0], isNotNull); // observed series → has tooltip
      expect(items[1], isNull); // trend line → suppressed
    });
  });

  // ── Batch 2: ClimateTrendCard ─────────────────────────────────────────────

  group('ClimateTrendCard – primary hierarchy & accent colours', () {
    testWidgets(
      'temperature (cyan): significant trend shows primary stats and cyan accent',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual Temperature Trend',
              trend: _trend(
                significant: true,
                slopePerDecade: 0.34,
                direction: 'increasing',
                nObservations: 44,
              ),
              accentColor: AppColors.cyan,
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        // Header and primary stats are visible.
        expect(find.text('ANNUAL TREND'), findsOneWidget);
        expect(find.text('Annual Temperature Trend'), findsOneWidget);
        expect(find.text("SEN'S SLOPE"), findsOneWidget);
        expect(find.text('+0.340'), findsOneWidget);
        expect(find.text('°C/decade'), findsOneWidget);
        expect(find.text('Observations'), findsOneWidget);
        expect(find.text('44'), findsOneWidget);
        expect(find.text('Significant trend.'), findsOneWidget);

        // Headline slope uses cyan for significant temperature trend.
        final slopeText = tester.widget<Text>(find.text('+0.340'));
        expect(slopeText.style?.color, AppColors.cyan);

        // StatusPills: Increasing (cyan) + Significant (cyan).
        final pills = tester
            .widgetList<StatusPill>(find.byType(StatusPill))
            .toList();
        expect(pills, hasLength(2));
        expect(pills[0].label, 'Increasing');
        expect(pills[0].color, AppColors.cyan);
        expect(pills[1].label, 'Significant');
        expect(pills[1].color, AppColors.cyan);
      },
    );

    testWidgets(
      'precipitation (amber): significant decreasing trend uses amber accent',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual Precipitation Trend',
              trend: _trend(
                significant: true,
                slopePerDecade: -45.2,
                direction: 'decreasing',
                units: 'mm/year',
                slopeUnitsPerDecade: 'mm/year per decade',
                nObservations: 38,
              ),
              accentColor: AppColors.amber,
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        expect(find.text('Annual Precipitation Trend'), findsOneWidget);
        expect(find.text('−45.2'), findsOneWidget);
        expect(find.text('mm/year per decade'), findsOneWidget);
        expect(find.text('38'), findsOneWidget);

        // Headline slope and eyebrow use amber for significant precipitation.
        final slopeText = tester.widget<Text>(find.text('−45.2'));
        expect(slopeText.style?.color, AppColors.amber);
        final eyebrowText = tester.widget<Text>(find.text('ANNUAL TREND'));
        expect(eyebrowText.style?.color, AppColors.amber);

        // Direction StatusPill uses amber when significant.
        final pills = tester
            .widgetList<StatusPill>(find.byType(StatusPill))
            .toList();
        expect(pills[0].label, 'Decreasing');
        expect(pills[0].color, AppColors.amber);
        expect(pills[1].label, 'Significant');
      },
    );

    testWidgets(
      'precipitation (amber): significant increasing trend stays neutral amber',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual Precipitation Trend',
              trend: _trend(
                significant: true,
                slopePerDecade: 28.5,
                direction: 'increasing',
                units: 'mm/year',
                slopeUnitsPerDecade: 'mm/year per decade',
              ),
              accentColor: AppColors.amber,
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        final slopeText = tester.widget<Text>(find.text('+28.5'));
        expect(slopeText.style?.color, AppColors.amber);
        final pills = tester
            .widgetList<StatusPill>(find.byType(StatusPill))
            .toList();
        expect(pills[0].label, 'Increasing');
        expect(pills[0].color, AppColors.amber);
      },
    );
  });

  group('ClimateTrendCard – non-significant & inconclusive states', () {
    testWidgets(
      'non-significant trend mutes slope and pills and never implies no change',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual Temperature Trend',
              trend: _trend(
                significant: false,
                slopePerDecade: 0.12,
                direction: 'increasing',
                interpretation: 'No significant trend.',
              ),
              accentColor: AppColors.cyan,
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        // Slope is muted (textSecondary), not cyan.
        final slopeText = tester.widget<Text>(find.text('+0.120'));
        expect(slopeText.style?.color, AppColors.textSecondary);

        // Both StatusPills are muted (textSecondary).
        final pills = tester
            .widgetList<StatusPill>(find.byType(StatusPill))
            .toList();
        expect(pills[0].label, 'Increasing');
        expect(pills[0].color, AppColors.textSecondary);
        expect(pills[1].label, 'Not significant');
        expect(pills[1].color, AppColors.textSecondary);

        // Explicitly warns that non-significance is inconclusive and does not
        // imply no change or a stable climate.
        expect(
          find.textContaining('inconclusive and does not imply no change'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'non-significant trend retains clarification even when backend mentions stability',
      (tester) async {
        const backendNote =
            'No statistically significant monotonic trend detected at alpha=0.05. '
            'This does not show that the climate is stable: the test may lack power.';
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual Temperature Trend',
              trend: _trend(
                significant: false,
                slopePerDecade: 0.05,
                interpretation: backendNote,
              ),
              accentColor: AppColors.cyan,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(backendNote), findsOneWidget);
        expect(
          find.textContaining('inconclusive and does not imply no change'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'direction "none" renders "No clear direction" pill in muted colour',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual Temperature Trend',
              trend: _trend(
                significant: false,
                slopePerDecade: 0.0,
                direction: 'none',
              ),
              accentColor: AppColors.cyan,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('No clear direction'), findsOneWidget);
      },
    );

    testWidgets('insufficient_data status renders informative fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ClimateTrendCard(
            title: 'Annual Temperature Trend',
            trend: _trend(
              status: 'insufficient_data',
              slopePerDecade: null,
              nObservations: 4,
            ),
            accentColor: AppColors.cyan,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Annual Temperature Trend'), findsOneWidget);
      expect(
        find.textContaining('Insufficient data for trend analysis (4 / 10'),
        findsOneWidget,
      );
      expect(find.text("SEN'S SLOPE"), findsNothing);
      expect(
        find.byKey(const ValueKey('climate_trend_details_toggle')),
        findsNothing,
      );
    });
  });

  group('ClimateTrendCard – scientific state clarity', () {
    for (final note in [
      'The climate is stable.',
      'There is no change.',
      'An inconclusive result.',
    ]) {
      testWidgets('backend text cannot suppress clarification: $note', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(
            ClimateTrendCard(
              title: 'Annual trend',
              trend: _trend(significant: false, interpretation: note),
              accentColor: AppColors.amber,
            ),
          ),
        );
        expect(find.text(note), findsOneWidget);
        expect(
          find.textContaining('inconclusive and does not imply no change'),
          findsOneWidget,
        );
        expect(find.text('Not significant'), findsOneWidget);
      });
    }
    for (final significance in <bool?>[null, false, true]) {
      testWidgets(
        'API significance $significance controls presentation, regardless of interpretation or p-value',
        (tester) async {
          const note = 'Backend interpretation preserved verbatim.';
          await tester.pumpWidget(
            _wrap(
              ClimateTrendCard(
                title: 'Annual trend',
                trend: _trend(
                  significant: significance,
                  interpretation: note,
                  pHamedRao: 0.00001,
                ),
                accentColor: AppColors.amber,
              ),
            ),
          );
          expect(find.text(note), findsOneWidget);
          expect(
            find.text('Significance unavailable'),
            significance == null ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Not significant'),
            significance == false ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Significant'),
            significance == true ? findsOneWidget : findsNothing,
          );
          expect(
            find.textContaining('inconclusive and does not imply no change'),
            significance == false ? findsOneWidget : findsNothing,
          );
          expect(
            tester.widget<Text>(find.text('+0.250')).style?.color,
            significance == true ? AppColors.amber : AppColors.textSecondary,
          );
        },
      );
    }
  });

  group('ClimateTrendCard – expandable secondary statistical details', () {
    testWidgets(
      'secondary stats are collapsed by default and revealed on tap',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            SingleChildScrollView(
              child: ClimateTrendCard(
                title: 'Annual Temperature Trend',
                trend: _trend(
                  significant: true,
                  slopePerDecade: 0.25,
                  ciLow: 0.12,
                  ciHigh: 0.38,
                  pHamedRao: 0.0082,
                  pOriginal: 0.00004,
                  hamedRaoLag: 3,
                  kendallTau: 0.3714,
                  ci95Note: 'Theil-Sen 95% confidence interval.',
                ),
                accentColor: AppColors.cyan,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);

        // Collapsed by default: secondary details are not in the widget tree.
        expect(find.text('Statistical details'), findsOneWidget);
        expect(find.text('95% CI / decade'), findsNothing);
        expect(find.text('p (Hamed-Rao)'), findsNothing);
        expect(find.text('p (original MK)'), findsNothing);
        expect(find.text('Kendall τ-b'), findsNothing);
        expect(find.text('Theil-Sen 95% confidence interval.'), findsNothing);

        // Tap toggle to expand.
        await tester.tap(
          find.byKey(const ValueKey('climate_trend_details_toggle')),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        expect(find.text('Hide statistical details'), findsOneWidget);
        expect(find.text('95% CI / decade'), findsOneWidget);
        expect(find.text('+0.120 to +0.380 °C/decade'), findsOneWidget);
        expect(find.text('p (Hamed-Rao)'), findsOneWidget);
        expect(find.text('0.0082 (lag 3)'), findsOneWidget);
        expect(find.text('p (original MK)'), findsOneWidget);
        expect(find.text('< 0.0001'), findsOneWidget);
        expect(find.text('Kendall τ-b'), findsOneWidget);
        expect(find.text('0.3714'), findsOneWidget);
        expect(find.text('Theil-Sen 95% confidence interval.'), findsOneWidget);

        // Tap again to collapse.
        await tester.tap(
          find.byKey(const ValueKey('climate_trend_details_toggle')),
        );
        await tester.pump();
        expect(find.text('95% CI / decade'), findsNothing);
        expect(find.text('Statistical details'), findsOneWidget);
      },
    );

    for (final w in [320.0, 360.0, 400.0]) {
      testWidgets(
        'no overflow at ${w.toInt()} px wide when collapsed and expanded',
        (tester) async {
          tester.view.physicalSize = Size(w, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            _wrap(
              SingleChildScrollView(
                child: ClimateTrendCard(
                  title: 'Annual Precipitation Trend',
                  trend: _trend(
                    significant: false,
                    slopePerDecade: -45.2,
                    direction: 'decreasing',
                    units: 'mm/year',
                    slopeUnitsPerDecade: 'mm/year per decade',
                  ),
                  accentColor: AppColors.amber,
                ),
              ),
              width: w,
            ),
          );
          expect(tester.takeException(), isNull);

          await tester.tap(
            find.byKey(const ValueKey('climate_trend_details_toggle')),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
