import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/climate_trend_card.dart';
import 'package:mobile/widgets/seasonal_trend_card.dart';
import 'package:mobile/widgets/temperature_explorer.dart';

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
  String interpretation = 'Backend interpretation preserved.',
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
  interpretation: interpretation,
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
  SeasonalTrend seasonal = _seasonal,
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
    method: units == '°C'
        ? 'Day-weighted mean of 12 monthly mean temperatures (leap years respected); years with fewer than 12 valid months are excluded.'
        : 'Monthly total (mm) = mean daily rate (mm/day) x days in month; annual total is the sum of 12 monthly totals.',
    excludedYears: excluded,
    trend: t,
    seasonal: seasonal,
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
      interpretation: "Statistically significant increasing monotonic trend at alpha=0.05 (Hamed-Rao corrected p=0.012); Sen’s slope +0.2 °C/decade.",
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
  await tester.tap(find.byIcon(Icons.thermostat_outlined).first);
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
    // Native inputs retain hidden hints and transform their floating labels.
    // Check their bounds below; check actual validation separately. Apply the
    // paragraph clipping assertion to the page's scientific content and controls.
    var nativeInput = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is InputDecorator) {
        nativeInput = true;
        return false;
      }
      return true;
    });
    if (!nativeInput) {
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: paragraph.text.toPlainText(),
      );
    }
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
        testWidgets('Temperature fits $width x $height scale $scale', (
          tester,
        ) async {
          await _pumpDashboard(
            tester,
            width,
            scale: scale,
            height: height,
            data: _analysis(
              temp: _trend(
                interpretation: List.filled(
                  12,
                  'Backend interpretation with long scientific context.',
                ).join(' '),
              ),
              reqLat: -89.123456789,
              reqLon: 179.987654321,
              tempSeries: const [
                AnnualPoint(1981, -123.123456),
                AnnualPoint(2025, 123.987654),
              ],
              excluded: const [ExcludedYear(year: 2000, validMonths: 11)],
            ),
          );
          expect(find.byType(TemperatureExplorer), findsOneWidget);
          final chart = tester.widget<AnnualChart>(find.byType(AnnualChart));
          expect(chart.framed, isFalse);
          expect(
            tester.getSize(find.byType(LineChart)).height,
            greaterThanOrEqualTo(250),
          );
          expect(
            tester.getRect(find.byType(AnnualChart)).top,
            lessThan(tester.getRect(find.byType(ClimateTrendCard)).top),
          );
          expect(find.text('2000 · 11/12 valid months'), findsOneWidget);
          final toggle = find.byKey(
            const ValueKey('climate_trend_details_toggle'),
          );
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text('95% CI / decade'), findsOneWidget);
          expect(find.text('Seasonal Temperature Trend'), findsOneWidget);
          _readable(tester, width);
        });
      }
    }
  }

  for (final significant in <bool?>[true, false, null]) {
    testWidgets(
      'Temperature retains API interpretation and significance $significant',
      (tester) async {
        const interpretation =
            'Backend describes stable or no change; preserved verbatim.';
        final data = _analysis(
          temp: _trend(
            significant: significant,
            p: significant == true ? .01 : .45,
            interpretation: interpretation,
          ),
        );
        await _pumpDashboard(tester, 1280, data: data);
        final annual = find.byType(ClimateTrendCard);
        expect(
          find.descendant(of: annual, matching: find.text(interpretation)),
          findsOneWidget,
        );
        expect(
          tester.widget<ClimateTrendCard>(annual).trend,
          same(data.temperature.trend),
        );
        expect(
          tester
              .widget<SeasonalTrendCard>(find.byType(SeasonalTrendCard))
              .trend,
          same(data.temperature.seasonal),
        );
        if (significant == false) {
          expect(
            find.descendant(
              of: annual,
              matching: find.textContaining(
                'A non-significant result is inconclusive',
              ),
            ),
            findsOneWidget,
          );
        } else if (significant == null) {
          expect(
            find.descendant(of: annual, matching: find.text('Not significant')),
            findsNothing,
          );
          expect(
            find.descendant(
              of: annual,
              matching: find.text('Significance unavailable'),
            ),
            findsOneWidget,
          );
        } else {
          expect(
            find.descendant(of: annual, matching: find.text('Significant')),
            findsOneWidget,
          );
        }
        for (final text in [
          data.temperature.method,
          data.methodology.seasonal,
          data.methodology.significanceBasis,
          data.methodology.confidenceInterval,
          data.methodology.annualCompleteness,
          ...data.methodology.limitations,
        ]) {
          expect(find.text(text), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'drawing gaps, endpoints, tooltip values and accessibility are preserved',
    (tester) async {
      final data = _representative();
      await _pumpDashboard(tester, 390, data: data);
      final line = tester.widget<LineChart>(find.byType(LineChart)).data;
      final observed = line.lineBarsData.first;
      expect(observed.spots.where((s) => s.isNull()), hasLength(3));
      expect(
        observed.spots.where((s) => !s.isNull()).map((s) => (s.x.toInt(), s.y)),
        data.temperature.series.map((p) => (p.year, p.value)),
      );
      expect(
        line.lineBarsData.last.spots,
        computeSenTrendSpots(
          years: data.temperature.series.map((p) => p.year).toList(),
          values: data.temperature.series.map((p) => p.value).toList(),
          senSlopePerDecade: data.temperature.trend.senSlopePerDecade!,
        ),
      );
      expect(line.lineBarsData.last.dashArray, [6, 4]);
      final tooltip = line.lineTouchData.touchTooltipData;
      expect(tooltip.fitInsideHorizontally, isTrue);
      expect(tooltip.fitInsideVertically, isTrue);
      final last = observed.spots.last;
      expect(
        tooltip.getTooltipItems([LineBarSpot(observed, 0, last)]).single!.text,
        '2025\n${last.y.toStringAsFixed(2)} °C',
      );
      final trend = line.lineBarsData.last;
      expect(
        tooltip.getTooltipItems([LineBarSpot(trend, 1, trend.spots.last)]),
        [null],
      );
      expect(
        find.bySemanticsLabel(
          RegExp('42 annual observations from 1981 to 2025'),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(LineChart));
      await tester.pumpAndSettle();
      // Exercise the actual fl_chart gesture path, as well as its tooltip callback.
      await tester.tapAt(tester.getCenter(find.byType(LineChart)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final empty in [false, true]) {
    testWidgets(
      'insufficient annual result preserves observations and seasonal result empty=$empty',
      (tester) async {
        await _pumpDashboard(
          tester,
          390,
          data: _analysis(
            temp: _insufficient(n: empty ? 0 : 4),
            tempSeries: empty
                ? []
                : const [AnnualPoint(2000, 27), AnnualPoint(2001, 28)],
            excluded: const [ExcludedYear(year: 2002, validMonths: 4)],
          ),
        );
        expect(find.byType(LineChart), empty ? findsNothing : findsOneWidget);
        if (empty) {
          expect(find.text('0 annual observations available.'), findsOneWidget);
        }
        final annual = find.byType(ClimateTrendCard);
        expect(
          find.descendant(of: annual, matching: find.text("SEN'S SLOPE")),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('climate_trend_details_toggle')),
          findsNothing,
        );
        expect(find.text('2002 · 4/12 valid months'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SeasonalTrendCard),
            matching: find.text('p-value'),
          ),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
      },
    );
  }

  testWidgets(
    'Temperature editor and details survive breakpoint changes without losing drafts',
    (tester) async {
      final service = await _pumpDashboard(
        tester,
        390,
        data: _representative(),
      );
      final toggle = find.byKey(const ValueKey('climate_trend_details_toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Edit location'));
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
      for (final width in [599.0, 600.0, 768.0, 999.0, 1000.0, 1280.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(
          tester.widgetList<TextFormField>(fields).map((f) => f.controller),
          controllers,
        );
        expect(
          tester
              .widgetList<TextFormField>(fields)
              .map((f) => f.controller!.text),
          values,
        );
        expect(find.text('95% CI / decade'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Collapse'));
      await tester.tap(find.text('Collapse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit location'));
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<TextFormField>(fields).map((f) => f.controller!.text),
        values,
      );
      await tester.ensureVisible(find.text('Analyze'));
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      expect(service.requests.last, (
        lat: -8.123456,
        lon: 80.987654,
        start: 1990,
        end: 2020,
      ));
      expect(find.byType(AnnualChart), findsNothing);
      expect(find.byKey(const ValueKey('temperature_findings')), findsNothing);
      service.responses.last.complete(_representative());
      await tester.pumpAndSettle();
      expect(find.byType(AnnualChart), findsOneWidget);
    },
  );

  testWidgets(
    'Temperature retains hero, retry and submitted parameters during failure',
    (tester) async {
      final service = await _pumpDashboard(tester, 390);
      expect(find.text('TEMPERATURE EXPLORATION'), findsOneWidget);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      expect(find.byType(AnnualChart), findsNothing);
      service.responses.first.completeError(
        const ApiException(ApiErrorKind.timeout, 'Service timed out.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Request timed out'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(service.requests.last, service.requests.first);
      expect(find.byType(AnnualChart), findsNothing);
      service.responses.last.complete(_representative());
      await tester.pumpAndSettle();
      expect(find.byType(AnnualChart), findsOneWidget);
    },
  );

  testWidgets(
    'open annual details retain keyboard activation and expanded semantics',
    (tester) async {
      await _pumpDashboard(tester, 390, data: _representative());
      final toggle = find.byKey(const ValueKey('climate_trend_details_toggle'));
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        ui.Tristate.isFalse,
      );
      Focus.of(tester.element(find.text('Statistical details'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        ui.Tristate.isTrue,
      );
      expect(find.text('95% CI / decade'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggle).flagsCollection.isExpanded,
        ui.Tristate.isFalse,
      );
      expect(find.text('95% CI / decade'), findsNothing);
    },
  );

  testWidgets(
    'Temperature editor validates all fields in short 320px landscape at 2x text',
    (tester) async {
      final service = await _pumpDashboard(
        tester,
        320,
        height: 320,
        scale: 2,
        data: _representative(),
      );
      await tester.ensureVisible(find.text('Edit location'));
      await tester.tap(find.text('Edit location'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final (i, value) in ['100', '181', '1980', '2030'].indexed) {
        await tester.enterText(fields.at(i), value);
      }
      await tester.ensureVisible(find.text('Analyze'));
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();
      for (final (i, error) in [
        '−90 to 90',
        '−180 to 180',
        '≥ 1981',
        '≤ 2025',
      ].indexed) {
        expect(
          tester.state<FormFieldState<String>>(fields.at(i)).errorText,
          error,
        );
        await tester.ensureVisible(fields.at(i));
        await tester.pumpAndSettle();
        expect(fields.at(i).hitTestable(), findsOneWidget);
      }
      expect(service.requests, hasLength(1));
      _readable(tester, 320);
    },
  );

  if (const bool.fromEnvironment('P37_TEMPERATURE_CAPTURE')) {
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
      (390.0, 2000.0),
      (768.0, 1700.0),
      (1280.0, 1700.0),
    ]) {
      testWidgets('capture actual Temperature $width', (tester) async {
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
          await File('/tmp/p37-temperature-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
