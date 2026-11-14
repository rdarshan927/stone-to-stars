import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/widgets/app_card.dart';
import 'package:mobile/widgets/overview_card.dart';
import 'package:mobile/widgets/sparkline_chart.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

TrendResult _trend({
  String status = 'ok',
  String? direction = 'increasing',
  bool? significant = true,
  double? slope = 0.32,
  String units = '°C/decade',
  double? p = 0.012,
  double? ciLow = 0.1,
  double? ciHigh = 0.5,
  int n = 45,
}) => TrendResult(
  status: status,
  nObservations: n,
  minObservationsRequired: 10,
  valueUnits: units,
  alpha: 0.05,
  direction: direction,
  significant: significant,
  pValueOriginal: p,
  pValueHamedRao: p,
  hamedRaoLag: 1,
  kendallTau: 0.4,
  senSlopePerDecade: slope,
  slopeUnitsPerDecade: units,
  ci95LowPerDecade: ciLow,
  ci95HighPerDecade: ciHigh,
  ci95Note: 'note',
  interpretation: 'interp',
);

TrendResult _insufficient({int n = 4}) => _trend(
  status: 'insufficient_data',
  direction: null,
  significant: null,
  slope: null,
  p: null,
  ciLow: null,
  ciHigh: null,
  n: n,
);

const _seasonal = SeasonalTrend(
  status: 'ok',
  significant: false,
  pValue: 0.5,
  senSlopePerDecade: 0.1,
  slopeUnitsPerDecade: '°C/decade',
  direction: 'increasing',
);

ClimateAnalysis _analysis({
  TrendResult? temp,
  TrendResult? precip,
  List<AnnualPoint>? tempSeries,
  List<AnnualPoint>? precipSeries,
  double? elevation = 50,
  String provider = 'NASA POWER',
  List<String> sources = const ['MERRA2'],
  double lat = 7.3,
  double lon = 81.8,
  double reqLat = 7.3,
  double reqLon = 81.8,
  int start = 1981,
  int end = 2025,
  List<ExcludedYear> excluded = const [],
}) {
  VariableAnalysis variable(
    TrendResult t,
    String units,
    List<AnnualPoint> series,
  ) => VariableAnalysis(
    series: series,
    seriesUnits: units,
    method: 'method',
    excludedYears: excluded,
    trend: t,
    seasonal: _seasonal,
  );
  return ClimateAnalysis(
    location: Location(
      latitude: lat,
      longitude: lon,
      elevationM: elevation,
      requestedLatitude: reqLat,
      requestedLongitude: reqLon,
    ),
    dataset: Dataset(
      provider: provider,
      title: null,
      sources: sources,
      timeStandard: null,
      community: 'AG',
    ),
    period: Period(startYear: start, endYear: end),
    methodology: const Methodology(
      alpha: 0.05,
      minObservations: 10,
      hamedRaoLag: 1,
      annualCompleteness: '12 months',
      significanceBasis: 'basis',
      confidenceInterval: 'ci',
      seasonal: 's',
      monthWise: 'm',
      baseline: 'b',
      limitations: ['l'],
    ),
    temperature: variable(
      temp ?? _trend(),
      '°C',
      tempSeries ?? const [AnnualPoint(2000, 27.2), AnnualPoint(2001, 27.6)],
    ),
    precipitation: variable(
      precip ??
          _trend(
            direction: 'decreasing',
            slope: -45.2,
            units: 'mm/year per decade',
            p: 0.03,
            ciLow: -80,
            ciHigh: -10,
          ),
      'mm/year',
      precipSeries ??
          const [AnnualPoint(2000, 1400.0), AnnualPoint(2001, 1500.0)],
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  ClimateAnalysis a, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: OverviewCard(analysis: a),
        ),
      ),
    ),
  );
  await tester.pump();
}

Color? _colorOf(WidgetTester t, Finder f) => t.widget<Text>(f).style?.color;

void main() {
  group('formatSlope / formatP', () {
    test('signs, typographic minus and magnitude-scaled precision', () {
      expect(formatSlope(0.32), '+0.320');
      expect(formatSlope(-0.32), '−0.320');
      expect(formatSlope(1.234), '+1.23');
      expect(formatSlope(-45.2), '−45.2');
      expect(formatSlope(123.456), '+123');
      expect(formatSlope(-987.654), '−988');
    });

    test('values that round to zero carry no sign', () {
      expect(formatSlope(0), '0.000');
      expect(formatSlope(0.0004), '0.000');
      expect(formatSlope(-0.0004), '0.000');
    });

    test('p-value formatting', () {
      expect(formatP(0.0123456), '0.0123');
      expect(formatP(0.00001), '< 0.0001');
    });
  });

  group('Overview – significant trends & SparklineChart integration', () {
    testWidgets('shows magnitude, units, direction, significance', (t) async {
      await _pump(t, _analysis());
      expect(find.text('Annual temperature'), findsOneWidget);
      expect(find.text('Annual precipitation'), findsOneWidget);
      // Temperature: increasing & significant.
      expect(find.text('+0.320'), findsOneWidget);
      expect(find.text('°C/decade'), findsWidgets);
      expect(find.text('Increasing'), findsOneWidget);
      // Precipitation: decreasing & significant, distinct units.
      expect(find.text('−45.2'), findsOneWidget);
      expect(find.text('mm/year per decade'), findsWidgets);
      expect(find.text('Decreasing'), findsOneWidget);
      expect(find.text('Significant'), findsNWidgets(2));
      expect(
        find.textContaining('statistically significant increase'),
        findsOneWidget,
      );
      expect(
        find.textContaining('statistically significant decrease'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets(
      'embeds SparklineChart with cyan for temperature and amber for precipitation',
      (t) async {
        await _pump(
          t,
          _analysis(
            precip: _trend(
              direction: 'increasing',
              significant: true,
              slope: 38.4,
              units: 'mm/year per decade',
            ),
          ),
        );

        final sparklines = t
            .widgetList<SparklineChart>(find.byType(SparklineChart))
            .toList();
        expect(sparklines, hasLength(2));
        expect(sparklines[0].accentColor, AppColors.cyan);
        expect(sparklines[1].accentColor, AppColors.amber);

        // Both headline slopes use their variable's identity accent when significant.
        expect(_colorOf(t, find.text('+0.320')), AppColors.cyan);
        expect(_colorOf(t, find.text('+38.4')), AppColors.amber);
      },
    );

    testWidgets(
      'displays latest annual value and period mean in SparklineChart footers',
      (t) async {
        await _pump(t, _analysis());
        // Temp series: (2000, 27.2), (2001, 27.6) -> Latest (2001): 27.60 °C, Period mean: 27.40 °C
        expect(find.text('Latest (2001): '), findsNWidgets(2));
        expect(find.text('27.60 °C'), findsOneWidget);
        expect(find.text('27.40 °C'), findsOneWidget);
        // Precip series: (2000, 1400.0), (2001, 1500.0) -> Latest (2001): 1500.0 mm/year, Period mean: 1450.0 mm/year
        expect(find.text('1500.0 mm/year'), findsOneWidget);
        expect(find.text('1450.0 mm/year'), findsOneWidget);
      },
    );

    testWidgets('supporting statistics are shown with plain labels', (t) async {
      await _pump(t, _analysis());
      expect(find.text('95% confidence range'), findsNWidgets(2));
      expect(find.text('Years analysed'), findsNWidgets(2));
      expect(find.textContaining('p = 0.0120'), findsOneWidget);
      expect(find.text('Years excluded (incomplete)'), findsNothing);
    });

    testWidgets('precipitation direction is not framed as good or bad', (
      t,
    ) async {
      await _pump(t, _analysis());
      for (final w in ['good', 'bad', 'worse', 'better', 'danger', 'drought']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });
  });

  group('Overview – non-significant trends', () {
    testWidgets('are muted and worded as inconclusive', (t) async {
      await _pump(
        t,
        _analysis(
          temp: _trend(significant: false, p: 0.45),
          precip: _trend(
            direction: 'decreasing',
            significant: false,
            slope: -12.3,
            units: 'mm/year per decade',
            p: 0.6,
          ),
        ),
      );
      expect(find.text('Not significant'), findsNWidgets(2));
      expect(find.text('Significant'), findsNothing);
      expect(
        find.textContaining('not statistically significant'),
        findsNWidgets(2),
      );
      expect(
        find.textContaining('not evidence of stability'),
        findsNWidgets(2),
      );
      // Direction pills and values must not use the confirmed-trend colours.
      expect(_colorOf(t, find.text('Increasing')), AppColors.textSecondary);
      expect(_colorOf(t, find.text('Decreasing')), AppColors.textSecondary);
      expect(_colorOf(t, find.text('+0.320')), AppColors.textSecondary);
      expect(_colorOf(t, find.text('−12.3')), AppColors.textSecondary);
    });

    testWidgets('direction "none" shows a neutral pill, never "None"', (
      t,
    ) async {
      await _pump(
        t,
        _analysis(
          temp: _trend(direction: 'none', significant: false, slope: 0),
        ),
      );
      expect(find.text('None'), findsNothing);
      expect(find.text('No clear direction'), findsOneWidget);
      expect(find.textContaining('No clear trend direction'), findsOneWidget);
    });

    testWidgets('null direction on an ok result is handled', (t) async {
      await _pump(
        t,
        _analysis(temp: _trend(direction: null, significant: null)),
      );
      expect(find.text('No clear direction'), findsOneWidget);
      expect(find.text('Not significant'), findsNothing);
      expect(find.text('Significance unavailable'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Overview – scientific state clarity', () {
    for (final direction in <String?>[
      'increasing',
      'decreasing',
      'none',
      null,
    ]) {
      testWidgets(
        'null significance stays unavailable with direction $direction',
        (t) async {
          await _pump(
            t,
            _analysis(
              temp: _trend(direction: direction, significant: null, p: 0.00001),
              precip: _insufficient(),
            ),
          );
          expect(find.text('Significance unavailable'), findsOneWidget);
          expect(find.text('Not significant'), findsNothing);
          expect(find.text('Significant'), findsNothing);
          expect(find.text('Insufficient data'), findsOneWidget);
          expect(
            find.textContaining('does not establish a confirmed annual trend'),
            findsOneWidget,
          );
          expect(_colorOf(t, find.text('+0.320')), AppColors.textSecondary);
        },
      );
    }
    testWidgets('non-significant directionless results remain inconclusive', (
      t,
    ) async {
      await _pump(
        t,
        _analysis(temp: _trend(direction: 'none', significant: false)),
      );
      expect(find.textContaining('No clear trend direction'), findsOneWidget);
      expect(find.textContaining('not evidence of stability'), findsOneWidget);
      expect(find.text('Not significant'), findsOneWidget);
    });
  });

  group('Overview – insufficient data', () {
    testWidgets('both variables insufficient', (t) async {
      await _pump(
        t,
        _analysis(temp: _insufficient(), precip: _insufficient(n: 7)),
      );
      expect(
        find.textContaining('Insufficient data for a trend'),
        findsNWidgets(2),
      );
      expect(find.textContaining('4 of 10 years'), findsOneWidget);
      expect(find.textContaining('7 of 10 years'), findsOneWidget);
      expect(find.text('Significant'), findsNothing);
      expect(find.text('Not significant'), findsNothing);
      expect(find.text('Years analysed'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('only one variable insufficient', (t) async {
      await _pump(t, _analysis(temp: _insufficient()));
      expect(
        find.textContaining('Insufficient data for a trend'),
        findsOneWidget,
      );
      expect(find.text('−45.2'), findsOneWidget);
    });
  });

  group('Overview – missing optional values', () {
    testWidgets('no elevation, no CI, no p-value, no slope', (t) async {
      await _pump(
        t,
        _analysis(
          elevation: null,
          temp: _trend(ciLow: null, ciHigh: null, p: null, slope: null),
          sources: const [],
        ),
      );
      expect(find.textContaining('Elevation'), findsNothing);
      expect(find.text('—'), findsOneWidget);
      // CI row is absent for temperature, still present for precipitation.
      expect(find.text('95% confidence range'), findsOneWidget);
      expect(find.textContaining('p = '), findsOneWidget); // precip only
      expect(find.textContaining('α = 0.05'), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });

    testWidgets('excluded years are summarised when present', (t) async {
      await _pump(
        t,
        _analysis(
          excluded: const [
            ExcludedYear(year: 1981, validMonths: 5),
            ExcludedYear(year: 1982, validMonths: 9),
          ],
        ),
      );
      expect(find.text('Years excluded (incomplete)'), findsNWidgets(2));
      expect(find.text('2'), findsNWidgets(2));
    });
  });

  group('Overview – editorial header and quiet data note', () {
    testWidgets('describes grid cell location and period from the data', (
      t,
    ) async {
      await _pump(
        t,
        _analysis(
          lat: -33.75,
          lon: -70.62,
          reqLat: -33.8,
          reqLon: -70.6,
          start: 1990,
          end: 2020,
        ),
      );
      expect(find.text('33.75°S, 70.62°W'), findsOneWidget);
      expect(find.textContaining('1990–2020'), findsWidgets);
      expect(find.textContaining('-33.8000°, -70.6000°'), findsOneWidget);
      expect(find.textContaining('Elevation'), findsOneWidget);
      expect(find.text('DATASET PROVENANCE'), findsOneWidget);
      // Editorial header and quiet disclaimer avoid wrapping in AppCard.
      expect(find.byType(AppCard), findsNothing);
    });

    testWidgets('project identity is present but not the bare shell wordmark', (
      t,
    ) async {
      await _pump(t, _analysis());
      expect(find.textContaining('STONE TO STARS'), findsOneWidget);
      expect(find.text('Stone to Stars'), findsNothing);
    });

    testWidgets('NASA POWER disclaimer is preserved and visually quiet', (
      t,
    ) async {
      await _pump(t, _analysis());
      final disclaimerFinder = find.textContaining(
        '0.5° latitude × 0.625° longitude',
      );
      expect(disclaimerFinder, findsOneWidget);
      expect(find.textContaining('not weather-station data'), findsOneWidget);
      expect(
        find.textContaining('does not mean climate is stable'),
        findsOneWidget,
      );
      expect(find.textContaining('km'), findsNothing);
      expect(_colorOf(t, disclaimerFinder), AppColors.textSecondary);
    });
  });

  group('Overview – long content and responsive layout', () {
    final longAnalysis = _analysis(
      provider: 'NASA POWER Prediction of Worldwide Energy Resources Community Edition',
      sources: List.generate(8, (i) => 'REANALYSIS-PRODUCT-NUMBER-$i-EXTENDED'),
      lat: -89.99,
      lon: -179.99,
      reqLat: -89.987654,
      reqLon: -179.987654,
      start: 1981,
      end: 2025,
      temp: _trend(
        slope: 123.456,
        units: '°C per decade over the whole analysed period',
      ),
      precip: _trend(
        direction: 'decreasing',
        slope: -987.654,
        units: 'mm/year per decade (annual total precipitation)',
        ciLow: -1234.5,
        ciHigh: -100.25,
      ),
      excluded: List.generate(
        12,
        (i) => ExcludedYear(year: 1981 + i, validMonths: 3),
      ),
    );

    for (final w in [
      320.0,
      360.0,
      400.0,
      600.0,
      768.0,
      1024.0,
      1280.0,
      1920.0,
    ]) {
      testWidgets('long values at ${w.toInt()} px: no overflow', (t) async {
        await _pump(t, longAnalysis, width: w);
        expect(t.takeException(), isNull);
        expect(find.byType(OverviewCard), findsOneWidget);
      });

      testWidgets('normal values at ${w.toInt()} px: no overflow', (t) async {
        await _pump(t, _analysis(), width: w);
        expect(t.takeException(), isNull);
      });

      testWidgets('insufficient data at ${w.toInt()} px: no overflow', (
        t,
      ) async {
        await _pump(
          t,
          _analysis(temp: _insufficient(), precip: _insufficient()),
          width: w,
        );
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('narrow: panels are stacked', (t) async {
      await _pump(t, _analysis(), width: 400);
      final temp = t.getTopLeft(find.text('Annual temperature'));
      final precip = t.getTopLeft(find.text('Annual precipitation'));
      expect(precip.dy, greaterThan(temp.dy));
      expect(precip.dx, temp.dx);
    });

    testWidgets('wide: panels sit side by side with equal top', (t) async {
      await _pump(t, _analysis(), width: 1280);
      final temp = t.getTopLeft(find.text('Annual temperature'));
      final precip = t.getTopLeft(find.text('Annual precipitation'));
      expect(precip.dy, temp.dy);
      expect(precip.dx, greaterThan(temp.dx));
    });

    testWidgets('breakpoint: 719 stacked, 720+ side by side', (t) async {
      // Viewport includes 16 px scroll padding on each side.
      await _pump(t, _analysis(), width: 719 + 32);
      var temp = t.getTopLeft(find.text('Annual temperature'));
      var precip = t.getTopLeft(find.text('Annual precipitation'));
      expect(precip.dy, greaterThan(temp.dy));

      await _pump(t, _analysis(), width: 720 + 32);
      temp = t.getTopLeft(find.text('Annual temperature'));
      precip = t.getTopLeft(find.text('Annual precipitation'));
      expect(precip.dy, temp.dy);
    });
  });
}
