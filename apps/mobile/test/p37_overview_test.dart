import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/observatory_layout.dart';

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
  valueUnits: units.startsWith('°C') ? '°C' : 'mm/year',
  alpha: 0.05,
  direction: direction,
  significant: significant,
  pValueOriginal: p,
  pValueHamedRao: p,
  hamedRaoLag: 1,
  kendallTau: direction == 'decreasing' ? -0.4 : 0.4,
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
      annualCompleteness: 'Annual values require 12 valid monthly observations',
      significanceBasis: 'Hamed-Rao corrected p-value',
      confidenceInterval: '95% confidence interval',
      seasonal: 'Seasonal Mann-Kendall across monthly sub-series',
      monthWise: 'Exploratory monthly tests',
      baseline: '1991–2020 anomaly baseline',
      limitations: ['NASA POWER is gridded, not station-observed data.'],
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

ClimateAnalysis _representative() {
  const gaps = [1983, 2009, 2024];
  final years = [
    for (var year = 1981; year <= 2025; year++)
      if (!gaps.contains(year)) year,
  ];
  return _analysis(
    lat: 7.3,
    lon: 81.8,
    reqLat: 7.3,
    reqLon: 81.8,
    temp: _trend(
      slope: 0.2,
      p: 0.012,
      n: years.length,
      ciLow: 0.08,
      ciHigh: 0.32,
    ),
    precip: _trend(
      direction: 'decreasing',
      significant: false,
      slope: -40,
      p: 0.45,
      n: years.length,
      units: 'mm/year per decade',
      ciLow: -100,
      ciHigh: 20,
    ),
    tempSeries: [
      for (final year in years)
        AnnualPoint(year, 26 + (year - 1981) * 0.02 + (year % 5) * 0.08),
    ],
    precipSeries: [
      for (final year in years)
        AnnualPoint(year, 2100 - (year - 1981) * 4 + (year % 7) * 35),
    ],
    excluded: [
      for (final year in gaps) ExcludedYear(year: year, validMonths: 11),
    ],
  );
}

class _Service extends ClimateApiService {
  final requests = <({double lat, double lon, int start, int end})>[];
  final responses = <Completer<ClimateAnalysis>>[];
  @override
  Future<ClimateAnalysis> fetchAnalysis({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) {
    requests.add((
      lat: latitude,
      lon: longitude,
      start: startYear,
      end: endYear,
    ));
    final pending = Completer<ClimateAnalysis>();
    responses.add(pending);
    return pending.future;
  }
}

final _captureKey = GlobalKey();
Future<_Service> _pumpDashboard(
  WidgetTester tester,
  double width, {
  double scale = 1,
  double height = 900,
  ClimateAnalysis? data,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final service = _Service();
  addTearDown(service.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: _captureKey,
        child: DashboardScreen(service: service),
      ),
    ),
  );
  if (data != null) service.responses.first.complete(data);
  await tester.pump();
  if (data != null) await tester.pumpAndSettle();
  return service;
}

void _readable(WidgetTester tester, double width) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final bounds = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & paragraph.size,
    );
    expect(
      bounds.left,
      greaterThanOrEqualTo(-0.01),
      reason: paragraph.text.toPlainText(),
    );
    expect(
      bounds.right,
      lessThanOrEqualTo(width + 0.01),
      reason: paragraph.text.toPlainText(),
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  for (final (p, expected) in <(double?, String?)>[
    (0, 'p < 0.0001'),
    (.000099, 'p < 0.0001'),
    (.0001, 'p = 0.0001'),
    (.012, 'p = 0.0120'),
    (null, null),
  ]) {
    testWidgets('Overview p-value comparison is unambiguous for $p', (
      tester,
    ) async {
      await _pumpDashboard(
        tester,
        1280,
        data: _analysis(
          temp: _trend(p: p),
          precip: _insufficient(),
        ),
      );
      expect(find.textContaining('p = <'), findsNothing);
      if (expected != null) {
        expect(find.textContaining(expected), findsOneWidget);
      } else {
        expect(find.textContaining('p ='), findsNothing);
        expect(find.textContaining('p <'), findsNothing);
      }
      expect(
        find.textContaining('A statistically significant increase'),
        findsOneWidget,
      );
    });
  }

  for (final significant in <bool?>[true, false, null]) {
    for (final direction in ['increasing', 'decreasing']) {
      testWidgets(
        'narrative follows API significance $significant and direction $direction',
        (tester) async {
          await _pumpDashboard(
            tester,
            1280,
            data: _analysis(
              temp: _trend(
                significant: significant,
                direction: direction,
                slope: direction == 'decreasing' ? -0.32 : 0.32,
                p: significant == true ? 0.01 : 0.45,
              ),
              precip: _insufficient(),
            ),
          );
          expect(find.text('Insufficient data'), findsOneWidget);
          if (significant == true) {
            expect(
              find.textContaining(
                'statistically significant ${direction == 'increasing' ? 'increase' : 'decrease'}',
              ),
              findsOneWidget,
            );
          } else if (significant == false) {
            expect(
              find.textContaining('not statistically significant'),
              findsOneWidget,
            );
            expect(
              find.textContaining('inconclusive, not evidence of stability'),
              findsOneWidget,
            );
            expect(find.text('Not significant'), findsOneWidget);
          } else {
            expect(find.text('Significance unavailable'), findsOneWidget);
            expect(find.text('Not significant'), findsNothing);
            expect(
              find.textContaining(
                'does not establish a confirmed annual trend',
              ),
              findsOneWidget,
            );
          }
        },
      );
    }
  }

  for (final width in [
    320.0,
    390.0,
    599.0,
    600.0,
    768.0,
    999.0,
    1000.0,
    1280.0,
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final height in [900.0, 320.0]) {
        testWidgets(
          'Overview explorer, findings and controls fit $width x $height scale $scale',
          (tester) async {
            await _pumpDashboard(
              tester,
              width,
              scale: scale,
              height: height,
              data: _representative(),
            );
            final hero = find.byType(ObservatoryHero);
            expect(
              find.descendant(of: hero, matching: find.byType(LocationForm)),
              findsOneWidget,
            );
            expect(find.text('CLIMATE INSIGHT'), findsOneWidget);
            expect(find.text('95% confidence range'), findsNothing);
            for (final label in [
              'Explore temperature',
              'Explore precipitation',
            ]) {
              final button = find.ancestor(
                of: find.text(label),
                matching: find.byType(TextButton),
              );
              expect(
                tester.getSize(button).height,
                greaterThanOrEqualTo(kMinInteractiveDimension),
              );
              await tester.ensureVisible(button);
              await tester.pumpAndSettle();
              expect(button.hitTestable(), findsOneWidget);
            }
            _readable(tester, width);
          },
        );
      }
    }
  }

  testWidgets('integrated explorer validates all four fields before analysis', (
    tester,
  ) async {
    final service = await _pumpDashboard(tester, 390, data: _representative());
    await tester.tap(find.text('Edit location'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (final (i, value) in ['100', '181', '1980', '2030'].indexed) {
      await tester.enterText(fields.at(i), value);
    }
    await tester.ensureVisible(find.text('Analyze'));
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    expect(
      tester.state<FormFieldState<String>>(fields.at(0)).errorText,
      '−90 to 90',
    );
    expect(
      tester.state<FormFieldState<String>>(fields.at(1)).errorText,
      '−180 to 180',
    );
    expect(
      tester.state<FormFieldState<String>>(fields.at(2)).errorText,
      '≥ 1981',
    );
    expect(
      tester.state<FormFieldState<String>>(fields.at(3)).errorText,
      '≤ 2025',
    );
    expect(service.requests, hasLength(1));
  });

  testWidgets(
    'highlight actions open the corresponding unchanged detail analysis',
    (tester) async {
      await _pumpDashboard(tester, 390, data: _representative());
      for (final (label, title) in [
        ('Explore temperature', 'Annual Mean Temperature'),
        ('Explore precipitation', 'Annual Precipitation Total'),
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(
          tester.widget<AnnualChart>(find.byType(AnnualChart)).title,
          title,
        );
        await tester.tap(find.byIcon(Icons.dashboard_outlined).first);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'editor drafts survive collapse, destination changes, breakpoints, and submission',
    (tester) async {
      final service = await _pumpDashboard(
        tester,
        390,
        data: _representative(),
      );
      await tester.tap(find.text('Edit location'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      final controllers = tester
          .widgetList<TextFormField>(fields)
          .map((f) => f.controller)
          .toList();
      const values = ['-8.123456', '80.987654', '1990', '2020'];
      for (final (i, value) in values.indexed) {
        await tester.enterText(fields.at(i), value);
      }
      await tester.ensureVisible(find.text('Collapse'));
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit location'));
      await tester.pumpAndSettle();
      for (final index in [1, 2, 3, 0]) {
        final icon = [
          Icons.dashboard_outlined,
          Icons.thermostat_outlined,
          Icons.water_drop_outlined,
          Icons.science_outlined,
        ][index];
        await tester.tap(find.byIcon(icon).first);
        await tester.pumpAndSettle();
        if (find.text('Edit location').evaluate().isNotEmpty) {
          await tester.ensureVisible(find.text('Edit location'));
          await tester.tap(find.text('Edit location'));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller)
              .toList(),
          controllers,
        );
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller!.text)
              .toList(),
          values,
        );
      }
      for (final width in [599.0, 600.0, 999.0, 1000.0, 1280.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller)
              .toList(),
          controllers,
        );
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller!.text)
              .toList(),
          values,
        );
      }
      await tester.ensureVisible(find.text('Analyze'));
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      expect(service.requests.last, (
        lat: -8.123456,
        lon: 80.987654,
        start: 1990,
        end: 2020,
      ));
      expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
      service.responses.last.completeError(
        const ApiException(ApiErrorKind.connection, 'Connection interrupted.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
    },
  );

  testWidgets(
    'loading and failures stay in hero context without stale scientific findings',
    (tester) async {
      final service = await _pumpDashboard(tester, 390);
      expect(find.text('EARTH OBSERVATORY'), findsOneWidget);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
      service.responses.first.completeError(
        const ApiException(ApiErrorKind.timeout, 'Request timed out.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Request timed out'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
    },
  );

  testWidgets(
    'empty insufficient response preserves factual coverage and exclusions',
    (tester) async {
      await _pumpDashboard(
        tester,
        390,
        data: _analysis(
          temp: _insufficient(n: 0),
          precip: _insufficient(n: 0),
          tempSeries: [],
          precipSeries: [],
          excluded: const [ExcludedYear(year: 1981, validMonths: 0)],
        ),
      );
      expect(find.text('Insufficient data'), findsNWidgets(2));
      expect(find.textContaining('0 of 10 years'), findsNWidgets(2));
      expect(find.text('No annual observations available.'), findsNWidgets(2));
      expect(find.text('Years excluded (incomplete)'), findsNWidgets(2));
      expect(find.text('Significant'), findsNothing);
    },
  );

  if (const bool.fromEnvironment('P37_OVERVIEW_CAPTURE')) {
    setUpAll(() async {
      final root = Platform.environment['P37_FONT_ROOT']!;
      for (final (family, names) in [
        (
          'Roboto',
          ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
        ),
        ('MaterialIcons', ['MaterialIcons-Regular.otf']),
      ]) {
        final loader = FontLoader(family);
        for (final name in names) {
          loader.addFont(
            File('$root/$name').readAsBytes().then(ByteData.sublistView),
          );
        }
        await loader.load();
      }
    });
    for (final (width, height) in [
      (390.0, 1800.0),
      (768.0, 1600.0),
      (1280.0, 1250.0),
    ]) {
      testWidgets('capture actual Overview $width', (tester) async {
        await _pumpDashboard(
          tester,
          width,
          height: height,
          data: _representative(),
        );
        final boundary =
            _captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/p37-overview-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
