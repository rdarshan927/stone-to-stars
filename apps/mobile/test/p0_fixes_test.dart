// Focused tests for the P0 fixes.
// P0-1: computeSenTrendSpots median correctness.
// P0-4: LocationForm controller synchronisation via didUpdateWidget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/location_form.dart';

// ─── P0-1: computeSenTrendSpots ──────────────────────────────────────────────

void main() {
  group('computeSenTrendSpots (P0-1)', () {
    // ── edge cases ────────────────────────────────────────────────────────────

    test('returns null for empty inputs', () {
      expect(
        computeSenTrendSpots(years: [], values: [], senSlopePerDecade: 1.0),
        isNull,
      );
    });

    test('returns null when lengths mismatch', () {
      expect(
        computeSenTrendSpots(
          years: [2000, 2001],
          values: [1.0],
          senSlopePerDecade: 1.0,
        ),
        isNull,
      );
    });

    test('single-point series: returns two spots at that point', () {
      final spots = computeSenTrendSpots(
        years: [2010],
        values: [25.0],
        senSlopePerDecade: 1.0,
      );
      expect(spots, isNotNull);
      expect(spots!.length, 2);
      expect(spots[0].x, 2010.0);
      expect(spots[0].y, closeTo(25.0, 1e-9));
      expect(spots[1].x, spots[0].x);
      expect(spots[1].y, spots[0].y);
    });

    // ── odd-length monotonic series (median value == middle list element) ──────

    test('monotonic ascending: trend line anchors correctly', () {
      // years: [2000, 2001, 2002], values: [1.0, 2.0, 3.0]
      // slope = 1.0 / 10 = 0.1 / year
      // medianYear = years[1] = 2001.0
      // sorted values = [1.0, 2.0, 3.0] → medianValue = 2.0
      // intercept = 2.0 − 0.1 × 2001 = −198.1
      // first spot: 0.1 × 2000 − 198.1 = 1.9
      // last spot:  0.1 × 2002 − 198.1 = 2.1
      final spots = computeSenTrendSpots(
        years: [2000, 2001, 2002],
        values: [1.0, 2.0, 3.0],
        senSlopePerDecade: 1.0,
      );
      expect(spots, isNotNull);
      expect(spots![0].x, 2000.0);
      expect(spots[1].x, 2002.0);
      expect(spots[0].y, closeTo(1.9, 1e-9));
      expect(spots[1].y, closeTo(2.1, 1e-9));
    });

    test('negative slope: trend line descends left-to-right', () {
      // years: [2000, 2001, 2002], values: [3.0, 2.0, 1.0]
      // slope = -1.0 / 10 = -0.1 / year
      // medianYear = 2001.0, medianValue (sorted [1,2,3]) = 2.0
      // intercept = 2.0 − (−0.1) × 2001 = 202.1
      // first spot: −0.1 × 2000 + 202.1 = 2.1
      // last spot:  −0.1 × 2002 + 202.1 = 1.9
      final spots = computeSenTrendSpots(
        years: [2000, 2001, 2002],
        values: [3.0, 2.0, 1.0],
        senSlopePerDecade: -1.0,
      );
      expect(spots, isNotNull);
      expect(spots![0].y, closeTo(2.1, 1e-9));
      expect(spots[1].y, closeTo(1.9, 1e-9));
      expect(spots[0].y, greaterThan(spots[1].y)); // slope is downward
    });

    // ── non-monotonic series (the key regression test) ─────────────────────

    test('non-monotonic values: median is the statistical median, '
        'NOT the middle list element', () {
      // values: [5.0, 1.0, 10.0]
      //   middle list element = values[1] = 1.0  ← what the OLD buggy code used
      //   sorted = [1.0, 5.0, 10.0] → statistical median = 5.0  ← correct
      //
      // With zero slope the intercept = medianValue.
      // Old code:  intercept = 1.0 → all spots at y = 1.0  ← WRONG
      // New code:  intercept = 5.0 → all spots at y = 5.0  ← CORRECT
      final spots = computeSenTrendSpots(
        years: [2000, 2001, 2002],
        values: [5.0, 1.0, 10.0],
        senSlopePerDecade: 0.0,
      );
      expect(spots, isNotNull);
      expect(
        spots![0].y,
        closeTo(5.0, 1e-9),
        reason:
            'Old buggy code would give 1.0 (middle element), '
            'correct answer is 5.0 (statistical median).',
      );
      expect(spots[1].y, closeTo(5.0, 1e-9));
    });

    test('non-monotonic with positive slope: intercept uses true median', () {
      // years: [2000, 2001, 2002], values: [10.0, 2.0, 5.0]
      // sorted = [2.0, 5.0, 10.0] → medianValue = 5.0
      // slope = 2.0/decade = 0.2/year
      // medianYear = 2001.0
      // intercept = 5.0 − 0.2 × 2001 = 5.0 − 400.2 = −395.2
      // first: 0.2 × 2000 − 395.2 = 400 − 395.2 = 4.8
      // last:  0.2 × 2002 − 395.2 = 400.4 − 395.2 = 5.2
      final spots = computeSenTrendSpots(
        years: [2000, 2001, 2002],
        values: [10.0, 2.0, 5.0],
        senSlopePerDecade: 2.0,
      );
      expect(spots, isNotNull);
      expect(spots![0].y, closeTo(4.8, 1e-9));
      expect(spots[1].y, closeTo(5.2, 1e-9));
    });

    // ── even-length series (median = average of two middle sorted values) ─────

    test('even-length: median year and value are averages of two middles', () {
      // years: [2000, 2001, 2002, 2003], values: [4.0, 1.0, 3.0, 2.0]
      // medianYear = (2001 + 2002) / 2 = 2001.5
      // sorted values = [1.0, 2.0, 3.0, 4.0] → medianValue = (2.0 + 3.0) / 2 = 2.5
      // slope = 2.0 / 10 = 0.2 / year
      // intercept = 2.5 − 0.2 × 2001.5 = 2.5 − 400.3 = −397.8
      // first: 0.2 × 2000 − 397.8 = 400 − 397.8 = 2.2
      // last:  0.2 × 2003 − 397.8 = 400.6 − 397.8 = 2.8
      final spots = computeSenTrendSpots(
        years: [2000, 2001, 2002, 2003],
        values: [4.0, 1.0, 3.0, 2.0],
        senSlopePerDecade: 2.0,
      );
      expect(spots, isNotNull);
      expect(spots![0].x, 2000.0);
      expect(spots[1].x, 2003.0);
      expect(spots[0].y, closeTo(2.2, 1e-9));
      expect(spots[1].y, closeTo(2.8, 1e-9));
    });

    test('zero slope: trend line is horizontal through statistical median', () {
      // values: [1.0, 100.0, 2.0] → sorted [1, 2, 100] → median = 2.0
      final spots = computeSenTrendSpots(
        years: [1990, 2000, 2010],
        values: [1.0, 100.0, 2.0],
        senSlopePerDecade: 0.0,
      );
      expect(spots, isNotNull);
      expect(spots![0].y, closeTo(2.0, 1e-9));
      expect(spots[1].y, closeTo(2.0, 1e-9));
      // Old buggy code would anchor at values[1] = 100.0 ← very wrong.
    });

    test(
      'gaps between years: trend line endpoints respect actual first/last year',
      () {
        // A series with a missing middle year: [2000, 2005, 2010]
        final spots = computeSenTrendSpots(
          years: [2000, 2005, 2010],
          values: [10.0, 12.0, 11.0],
          senSlopePerDecade: 1.0,
        );
        expect(spots, isNotNull);
        expect(spots![0].x, 2000.0); // first year
        expect(spots[1].x, 2010.0); // last year — not 2010+interval
      },
    );
  });

  // ─── P0-4: LocationForm.didUpdateWidget ─────────────────────────────────────

  group('LocationForm didUpdateWidget (P0-4)', () {
    testWidgets(
      'controllers update when parent passes new initial coordinates',
      (tester) async {
        // Track what gets submitted.

        // Wrap in a StatefulWidget that lets us change the initial values.
        await tester.pumpWidget(
          _LocationFormHarness(
            initialLat: 7.3,
            initialLon: 81.8,
            initialStartYear: 1981,
            initialEndYear: 2025,
            onAnalyze: (a, b, c, d) {},
          ),
        );

        // Advance to new coordinates the same way DashboardScreen would after
        // a successful query — by passing different initial values.
        await tester.pumpWidget(
          _LocationFormHarness(
            initialLat: 10.0,
            initialLon: 81.8,
            initialStartYear: 1981,
            initialEndYear: 2025,
            onAnalyze: (a, b, c, d) {},
          ),
        );
        await tester.pump();

        // The latitude field should now show the new value.
        expect(
          tester
              .widget<EditableText>(
                find
                    .descendant(
                      of: find.byType(TextFormField).first,
                      matching: find.byType(EditableText),
                    )
                    .first,
              )
              .controller
              .text,
          '10.0',
          reason:
              'Controller must reflect the updated initialLat; '
              'without didUpdateWidget it would still show 7.3.',
        );
      },
    );

    testWidgets('controller is NOT reset when only loading flag changes', (
      tester,
    ) async {
      // The form updates `loading` frequently (each API call). The controller
      // must not be reset when only loading changes and initial coords stay the same.
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

      // Simulate user typing a new value.
      await tester.enterText(find.byType(TextFormField).first, '55.0');

      // Parent rebuilds with loading=true but same coords.
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

      // User's typed value should NOT have been overwritten.
      expect(
        tester
            .widget<EditableText>(
              find
                  .descendant(
                    of: find.byType(TextFormField).first,
                    matching: find.byType(EditableText),
                  )
                  .first,
            )
            .controller
            .text,
        '55.0',
        reason: 'Changing only the loading flag must not reset the field.',
      );
    });
  });

  // ─── P0-5: AnnualChart renders without overflow on narrow viewports ──────────

  group('AnnualChart narrow screen rendering (P0-5 related)', () {
    Widget buildChart({double width = 320}) {
      final series = [
        const AnnualPoint(2000, 27.5),
        const AnnualPoint(2001, 27.8),
        const AnnualPoint(2002, 27.2),
      ];
      return MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: AnnualChart(
              series: series,
              seriesUnits: '°C',
              seriesColor: const Color(0xFF22D3EE),
              title: 'Annual Mean Temperature',
            ),
          ),
        ),
      );
    }

    for (final width in [320.0, 360.0, 400.0]) {
      testWidgets('renders without overflow at ${width.toInt()} px width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildChart(width: width));
        await tester.pump();

        // If there were an overflow, Flutter test framework would throw an
        // exception during the pump.  Reaching here means no overflow.
        expect(find.byType(AnnualChart), findsOneWidget);
      });
    }
  });
}

/// A minimal harness that lets tests change [LocationForm]'s initial props
/// without rebuilding the widget from scratch.
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
