// Targeted verification tests for the five P0 fixes.
//
// Covers cases not already exercised by p0_fixes_test.dart:
//   - AnnualChart with a single data point (minX == maxX).
//   - AnnualChart rendering with missing/gap years.
//   - Sen's slope intercept alignment with scipy.stats.theilslopes (separate).
//   - LocationForm.didUpdateWidget when year fields change, and when only
//     the loading flag changes (not coords).
//   - OverviewCard at 320, 360 and 400 px widths.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/overview_card.dart';

// ─── Shared fixture helpers ───────────────────────────────────────────────────

TrendResult _noSlopeTrend() => const TrendResult(
  status: 'ok',
  nObservations: 2,
  minObservationsRequired: 10,
  valueUnits: '°C',
  alpha: 0.05,
  direction: 'increasing',
  significant: false,
  pValueOriginal: 0.5,
  pValueHamedRao: 0.5,
  hamedRaoLag: 1,
  kendallTau: 0.1,
  senSlopePerDecade: null,
  slopeUnitsPerDecade: '°C/decade',
  ci95LowPerDecade: null,
  ci95HighPerDecade: null,
  ci95Note: '',
  interpretation: 'No significant trend.',
);

TrendResult _slopeTrend(double slopePerDecade) => TrendResult(
  status: 'ok',
  nObservations: 5,
  minObservationsRequired: 10,
  valueUnits: '°C',
  alpha: 0.05,
  direction: slopePerDecade >= 0 ? 'increasing' : 'decreasing',
  significant: true,
  pValueOriginal: 0.01,
  pValueHamedRao: 0.02,
  hamedRaoLag: 1,
  kendallTau: 0.6,
  senSlopePerDecade: slopePerDecade,
  slopeUnitsPerDecade: '°C/decade',
  ci95LowPerDecade: slopePerDecade - 0.5,
  ci95HighPerDecade: slopePerDecade + 0.5,
  ci95Note: 'Bootstrap 95% CI',
  interpretation: 'Significant trend.',
);

TrendResult _insufficientTrend() => const TrendResult(
  status: 'insufficient_data',
  nObservations: 1,
  minObservationsRequired: 10,
  valueUnits: '°C',
  alpha: 0.05,
  direction: null,
  significant: null,
  pValueOriginal: null,
  pValueHamedRao: null,
  hamedRaoLag: 1,
  kendallTau: null,
  senSlopePerDecade: null,
  slopeUnitsPerDecade: '°C/decade',
  ci95LowPerDecade: null,
  ci95HighPerDecade: null,
  ci95Note: '',
  interpretation: 'Insufficient data.',
);

SeasonalTrend _insufficientSeasonal() => const SeasonalTrend(
  status: 'insufficient_data',
  significant: null,
  pValue: null,
  senSlopePerDecade: null,
  slopeUnitsPerDecade: '°C/decade',
  direction: null,
);

ClimateAnalysis _fakeAnalysis({
  List<AnnualPoint> tempSeries = const [],
  TrendResult? tempTrend,
  TrendResult? precipTrend,
}) {
  return ClimateAnalysis(
    location: const Location(
      latitude: 7.3,
      longitude: 81.8,
      elevationM: 50.0,
      requestedLatitude: 7.3,
      requestedLongitude: 81.8,
    ),
    dataset: const Dataset(
      provider: 'NASA POWER',
      title: 'Test',
      sources: ['MERRA2'],
      timeStandard: 'LST',
      community: 'AG',
    ),
    period: const Period(startYear: 2000, endYear: 2001),
    methodology: const Methodology(
      alpha: 0.05,
      minObservations: 10,
      hamedRaoLag: 1,
      annualCompleteness: '12 months required',
      significanceBasis: 'Hamed-Rao',
      confidenceInterval: '95%',
      seasonal: 'Seasonal MK',
      monthWise: 'Per-month MK',
      baseline: '1991–2020',
      limitations: ['Model-derived.'],
    ),
    temperature: VariableAnalysis(
      series: tempSeries.isEmpty
          ? const [AnnualPoint(2000, 27.5), AnnualPoint(2001, 27.8)]
          : tempSeries,
      seriesUnits: '°C',
      method: 'day-weighted mean',
      excludedYears: [],
      trend: tempTrend ?? _noSlopeTrend(),
      seasonal: _insufficientSeasonal(),
    ),
    precipitation: VariableAnalysis(
      series: const [AnnualPoint(2000, 1800.0)],
      seriesUnits: 'mm/year',
      method: 'rate × days',
      excludedYears: [],
      trend: precipTrend ?? _noSlopeTrend(),
      seasonal: _insufficientSeasonal(),
    ),
  );
}

Widget _chartInApp(
  List<AnnualPoint> series, {
  double width = 400,
  TrendResult? trend,
}) {
  return MaterialApp(
    theme: buildTheme(),
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: AnnualChart(
          series: series,
          seriesUnits: '°C',
          seriesColor: const Color(0xFF22D3EE),
          title: 'Test Chart',
          trend: trend,
        ),
      ),
    ),
  );
}

// ─── Harness for LocationForm ─────────────────────────────────────────────────

class _LocationFormHarness extends StatelessWidget {
  const _LocationFormHarness({
    required this.initialLat,
    required this.initialLon,
    required this.initialStartYear,
    required this.initialEndYear,
    required this.onAnalyze,
    this.loading = false,
  });

  final double initialLat;
  final double initialLon;
  final int initialStartYear;
  final int initialEndYear;
  final bool loading;
  final void Function(double, double, int, int) onAnalyze;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: LocationForm(
          initialLat: initialLat,
          initialLon: initialLon,
          initialStartYear: initialStartYear,
          initialEndYear: initialEndYear,
          loading: loading,
          onAnalyze: onAnalyze,
        ),
      ),
    );
  }
}

// ─── Helper: get controller text from the nth TextFormField ──────────────────

String _textAt(WidgetTester tester, int idx) => tester
    .widget<EditableText>(
      find
          .descendant(
            of: find.byType(TextFormField).at(idx),
            matching: find.byType(EditableText),
          )
          .first,
    )
    .controller
    .text;

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── 1. AnnualChart: single data point ──────────────────────────────────────

  group('AnnualChart – single data point (minX == maxX)', () {
    testWidgets('renders without exception and shows the AnnualChart', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_chartInApp([const AnnualPoint(2010, 25.0)]));
      await tester.pump();

      // No layout exception during pump.
      expect(tester.takeException(), isNull);

      // Widget is present; "No data available" must NOT appear.
      expect(find.byType(AnnualChart), findsOneWidget);
      expect(find.text('No data available.'), findsNothing);

      // The rendered LineChart must have a strictly positive x-axis range so
      // fl_chart never receives a zero-width axis for a single data point.
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.minX,
        lessThan(chart.data.maxX),
        reason:
            'Single-point chart must have minX < maxX (expected ±0.5 around '
            'the year). minX=${chart.data.minX}, maxX=${chart.data.maxX}',
      );
      // Confirm the symmetric ±0.5 year range: year 2010 → [2009.5, 2010.5].
      expect(chart.data.minX, closeTo(2009.5, 1e-9));
      expect(chart.data.maxX, closeTo(2010.5, 1e-9));
    });

    test('computeSenTrendSpots: single-point spots have equal x (zero-width segment)', () {
      final spots = computeSenTrendSpots(
        years: [2010],
        values: [25.0],
        senSlopePerDecade: 1.0,
      );
      expect(spots, isNotNull);
      // Both endpoints share the single year — zero-width segment, not a crash.
      expect(spots![0].x, 2010.0);
      expect(spots[1].x, 2010.0);
      // Value is anchored at the statistical median (which is the value itself).
      expect(spots[0].y, closeTo(25.0, 1e-9));
      expect(spots[1].y, closeTo(25.0, 1e-9));
    });

    testWidgets(
      'renders without exception when trend is provided for single point',
      (tester) async {
        tester.view.physicalSize = const Size(400, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _chartInApp([const AnnualPoint(2010, 25.0)], trend: _slopeTrend(1.0)),
        );
        await tester.pump();

        expect(find.byType(AnnualChart), findsOneWidget);
      },
    );
  });

  // ── 2. AnnualChart: missing/gap years ──────────────────────────────────────

  group('AnnualChart – gap years between valid records', () {
    testWidgets('renders without exception when years are non-consecutive', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gapSeries = [
        const AnnualPoint(2000, 25.0),
        const AnnualPoint(2005, 25.5),
        const AnnualPoint(2010, 26.0),
      ];
      await tester.pumpWidget(_chartInApp(gapSeries));
      await tester.pump();

      expect(find.byType(AnnualChart), findsOneWidget);
    });

    testWidgets('renders without exception with trend line and gap years', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final gapSeries = [
        const AnnualPoint(2000, 25.0),
        const AnnualPoint(2005, 25.5),
        const AnnualPoint(2010, 26.0),
      ];
      await tester.pumpWidget(_chartInApp(gapSeries, trend: _slopeTrend(1.0)));
      await tester.pump();

      expect(find.byType(AnnualChart), findsOneWidget);
    });

    test('trend endpoints span first to last year regardless of gaps', () {
      final spots = computeSenTrendSpots(
        years: [2000, 2005, 2010],
        values: [25.0, 25.5, 26.0],
        senSlopePerDecade: 1.0,
      );
      expect(spots, isNotNull);
      expect(spots![0].x, 2000.0, reason: 'Trend must start at first year');
      expect(spots[1].x, 2010.0, reason: 'Trend must end at last year');
    });

    test(
      'intercept uses sorted-value median (not positional) for gap series',
      () {
        // years: [2000, 2005, 2010], values: [26.0, 24.0, 25.0]
        // sorted values = [24.0, 25.0, 26.0] → statistical median = 25.0
        // medianYear = years[1] = 2005 (n=3, odd)
        // slope/year = 2.0/10 = 0.2
        // intercept = 25.0 − 0.2 × 2005 = 25.0 − 401.0 = −376.0
        // first (x=2000): 0.2 × 2000 − 376.0 = 400 − 376 = 24.0
        // last  (x=2010): 0.2 × 2010 − 376.0 = 402 − 376 = 26.0
        final spots = computeSenTrendSpots(
          years: [2000, 2005, 2010],
          values: [26.0, 24.0, 25.0],
          senSlopePerDecade: 2.0,
        );
        expect(spots, isNotNull);
        expect(spots![0].y, closeTo(24.0, 1e-9));
        expect(spots[1].y, closeTo(26.0, 1e-9));
      },
    );
  });

  // ── 3. Sen's slope intercept vs scipy.stats.theilslopes ────────────────────

  group('Sen slope intercept – matches scipy.stats.theilslopes (separate)', () {
    // scipy.stats.theilslopes uses method='separate' by default.
    // Its intercept: intercept = median(y) − slope × median(x)
    //
    // computeSenTrendSpots:
    //   intercept = medianValue − (senSlopePerDecade/10) × medianYear
    //             = median(values) − slope × median(years)
    //
    // The formulas are identical when the slope passed in equals the
    // actual Theil-Sen slope from the backend.
    //
    // Ground-truth computed with:
    //   scipy.stats.theilslopes([5,3,8,1,9], [2000,2001,2002,2003,2004])
    //   → slope = 0.75/year  intercept = -1496.5

    test('5-point non-monotonic series: endpoints match scipy line', () {
      // scipy: slope=0.75/year, intercept=-1496.5
      // Backend sends senSlopePerDecade = 0.75 × 10 = 7.5
      const senSlopePerDecade = 7.5;
      const slopePerYear = senSlopePerDecade / 10; // 0.75
      const expectedIntercept = -1496.5;

      final spots = computeSenTrendSpots(
        years: [2000, 2001, 2002, 2003, 2004],
        values: [5.0, 3.0, 8.0, 1.0, 9.0],
        senSlopePerDecade: senSlopePerDecade,
      );
      expect(spots, isNotNull);
      expect(
        spots![0].y,
        closeTo(slopePerYear * 2000 + expectedIntercept, 1e-6),
        reason: 'First endpoint must lie on the scipy theilslopes line',
      );
      expect(
        spots[1].y,
        closeTo(slopePerYear * 2004 + expectedIntercept, 1e-6),
        reason: 'Last endpoint must lie on the scipy theilslopes line',
      );
    });

    test(
      'even-length 4-point series: intercept = median(y) − slope×median(x)',
      () {
        // years: [2000,2001,2002,2003]
        // values: [10.0, 2.0, 5.0, 8.0]
        // sorted values = [2, 5, 8, 10] → median = (5+8)/2 = 6.5
        // median(x) = (2001+2002)/2 = 2001.5
        // slope = 3.0/decade = 0.3/year (synthetic)
        // intercept = 6.5 − 0.3 × 2001.5 = 6.5 − 600.45 = −593.95
        const slopePerYear = 0.3;
        const expectedIntercept = 6.5 - slopePerYear * 2001.5;

        final spots = computeSenTrendSpots(
          years: [2000, 2001, 2002, 2003],
          values: [10.0, 2.0, 5.0, 8.0],
          senSlopePerDecade: 3.0,
        );
        expect(spots, isNotNull);
        expect(
          spots![0].y,
          closeTo(slopePerYear * 2000 + expectedIntercept, 1e-9),
        );
        expect(
          spots[1].y,
          closeTo(slopePerYear * 2003 + expectedIntercept, 1e-9),
        );
      },
    );

    test(
      'intercept is independent of value order (pure statistical median)',
      () {
        // With zero slope, the entire trend line is at y = median(values).
        // Reordering values must not change the median.
        const years = [2000, 2001, 2002, 2003, 2004];
        const valuesA = [3.0, 1.0, 5.0, 2.0, 4.0]; // sorted [1,2,3,4,5] → 3
        const valuesB = [4.0, 2.0, 5.0, 1.0, 3.0]; // same set, different order

        final spotsA = computeSenTrendSpots(
          years: years,
          values: valuesA,
          senSlopePerDecade: 0.0,
        );
        final spotsB = computeSenTrendSpots(
          years: years,
          values: valuesB,
          senSlopePerDecade: 0.0,
        );

        expect(spotsA, isNotNull);
        expect(spotsB, isNotNull);
        expect(
          spotsA![0].y,
          closeTo(spotsB![0].y, 1e-9),
          reason: 'Intercept must equal 3.0 regardless of ordering.',
        );
        expect(spotsA[0].y, closeTo(3.0, 1e-9));
      },
    );
  });

  // ── 4. LocationForm.didUpdateWidget – extended cases ───────────────────────

  group('LocationForm didUpdateWidget (P0-4) – extended cases', () {
    testWidgets('start year field updates when initialStartYear changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _LocationFormHarness(
          initialLat: 7.3,
          initialLon: 81.8,
          initialStartYear: 1981,
          initialEndYear: 2025,
          onAnalyze: (a, b, c, d) {},
        ),
      );

      await tester.pumpWidget(
        _LocationFormHarness(
          initialLat: 7.3,
          initialLon: 81.8,
          initialStartYear: 1990,
          initialEndYear: 2025,
          onAnalyze: (a, b, c, d) {},
        ),
      );
      await tester.pump();

      expect(
        _textAt(tester, 2),
        '1990',
        reason: 'Start year field must reflect the updated initialStartYear.',
      );
    });

    testWidgets('end year field updates when initialEndYear changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _LocationFormHarness(
          initialLat: 7.3,
          initialLon: 81.8,
          initialStartYear: 1981,
          initialEndYear: 2020,
          onAnalyze: (a, b, c, d) {},
        ),
      );

      await tester.pumpWidget(
        _LocationFormHarness(
          initialLat: 7.3,
          initialLon: 81.8,
          initialStartYear: 1981,
          initialEndYear: 2025,
          onAnalyze: (a, b, c, d) {},
        ),
      );
      await tester.pump();

      expect(
        _textAt(tester, 3),
        '2025',
        reason: 'End year field must reflect the updated initialEndYear.',
      );
    });

    testWidgets(
      'all four fields update when all initial values change simultaneously',
      (tester) async {
        await tester.pumpWidget(
          _LocationFormHarness(
            initialLat: 7.3,
            initialLon: 81.8,
            initialStartYear: 1981,
            initialEndYear: 2020,
            onAnalyze: (a, b, c, d) {},
          ),
        );

        await tester.pumpWidget(
          _LocationFormHarness(
            initialLat: 10.0,
            initialLon: 77.0,
            initialStartYear: 1990,
            initialEndYear: 2024,
            onAnalyze: (a, b, c, d) {},
          ),
        );
        await tester.pump();

        expect(_textAt(tester, 0), '10.0', reason: 'Latitude must update');
        expect(_textAt(tester, 1), '77.0', reason: 'Longitude must update');
        expect(_textAt(tester, 2), '1990', reason: 'Start year must update');
        expect(_textAt(tester, 3), '2024', reason: 'End year must update');
      },
    );

    testWidgets('user-typed lon is NOT reset when only loading flag changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _LocationFormHarness(
          initialLat: 7.3,
          initialLon: 81.8,
          initialStartYear: 1981,
          initialEndYear: 2025,
          loading: false,
          onAnalyze: (a, b, c, d) {},
        ),
      );

      // User edits the longitude field.
      await tester.enterText(find.byType(TextFormField).at(1), '75.0');

      // Parent rebuilds with loading=true, coords unchanged.
      await tester.pumpWidget(
        _LocationFormHarness(
          initialLat: 7.3,
          initialLon: 81.8,
          initialStartYear: 1981,
          initialEndYear: 2025,
          loading: true,
          onAnalyze: (a, b, c, d) {},
        ),
      );
      await tester.pump();

      expect(
        _textAt(tester, 1),
        '75.0',
        reason: 'Longitude typed by user must not be reset when only loading changes.',
      );
    });
  });

  // ── 5. OverviewCard: narrow screen widths ──────────────────────────────────

  group('OverviewCard – narrow screen widths', () {
    Widget buildCard({
      required double width,
      TrendResult? tempTrend,
      TrendResult? precipTrend,
    }) {
      return MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: OverviewCard(
                analysis: _fakeAnalysis(
                  tempSeries: const [
                    AnnualPoint(2000, 27.5),
                    AnnualPoint(2001, 27.8),
                  ],
                  tempTrend: tempTrend,
                  precipTrend: precipTrend,
                ),
              ),
            ),
          ),
        ),
      );
    }

    for (final width in [320.0, 360.0, 400.0]) {
      testWidgets('renders at ${width.toInt()} px with normal trend', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildCard(width: width));
        await tester.pump();

        // No layout overflow or rendering exception must have been thrown.
        expect(
          tester.takeException(),
          isNull,
          reason: 'No layout overflow expected at ${width.toInt()} px',
        );
        expect(find.byType(OverviewCard), findsOneWidget);
      });

      testWidgets(
        'renders at ${width.toInt()} px with long slope label (P0-5 overflow guard)',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          // Large slope values produce long text strings — exercises the
          // Wrap/ellipsis overflow guard from P0-5.
          await tester.pumpWidget(
            buildCard(
              width: width,
              tempTrend: _slopeTrend(123.456),
              precipTrend: _slopeTrend(-987.654),
            ),
          );
          await tester.pump();

          // No layout overflow or rendering exception must have been thrown.
          expect(
            tester.takeException(),
            isNull,
            reason:
                'No layout overflow expected at ${width.toInt()} px '
                'with long slope label',
          );
          expect(find.byType(OverviewCard), findsOneWidget);
        },
      );

      testWidgets(
        'renders at ${width.toInt()} px with insufficient-data trends',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            buildCard(
              width: width,
              tempTrend: _insufficientTrend(),
              precipTrend: _insufficientTrend(),
            ),
          );
          await tester.pump();

          // No layout overflow or rendering exception must have been thrown.
          expect(
            tester.takeException(),
            isNull,
            reason:
                'No layout overflow expected at ${width.toInt()} px '
                'with insufficient-data trends',
          );
          expect(find.byType(OverviewCard), findsOneWidget);
        },
      );
    }
  });
}
