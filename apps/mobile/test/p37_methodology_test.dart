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
import 'package:mobile/widgets/methodology_guide.dart';
import 'package:mobile/widgets/methodology_panel.dart';

import 'p35_methodology_test.dart' as legacy;
import 'p36_frontend_polish_test.dart' as regression;

// Representative backend methodology descriptions; no scientific computation
// is performed by the guide or these fixtures.
const _methodology = Methodology(
  alpha: .05,
  minObservations: 10,
  hamedRaoLag: 3,
  annualCompleteness: "Annual values require all 12 valid monthly observations; NASA's YYYY13 value is never used.",
  significanceBasis: 'Hamed-Rao corrected p-value (lag limited to 3); the original Mann-Kendall p-value is reported alongside.',
  confidenceInterval: 'Conventional 95% Theil-Sen confidence interval (Sen 1968, as implemented in scipy.stats.theilslopes). It is NOT adjusted for autocorrelation and may be too narrow for serially correlated data.',
  seasonal: 'Hirsch-Slack seasonal Mann-Kendall with period 12; not autocorrelation-adjusted.',
  monthWise: 'Exploratory; Holm-Bonferroni adjusted p-values provided.',
  baseline: '1991-2020 when each calendar month has >= 24 valid observations, otherwise a labelled custom reference period.',
  limitations: [
    'Reanalysis grid-cell data (~50 km), not station observations.',
    'Mann-Kendall detects monotonic trends; non-significance does not prove stability.',
    'Hamed-Rao treats retained values as consecutive; excluded years create gaps.',
    'Confidence intervals are not autocorrelation-adjusted.',
    'Seasonal test ignores correlation between calendar months.',
  ],
);

ClimateAnalysis _analysis({Methodology methodology = _methodology}) {
  final base = regression.fixture();
  VariableAnalysis variable(VariableAnalysis source, String method) =>
      VariableAnalysis(
        series: source.series,
        seriesUnits: source.seriesUnits,
        excludedYears: source.excludedYears,
        trend: source.trend,
        seasonal: source.seasonal,
        method: method,
      );
  return ClimateAnalysis(
    location: base.location,
    dataset: base.dataset,
    period: base.period,
    methodology: methodology,
    temperature: variable(
      base.temperature,
      'Day-weighted mean of 12 monthly mean temperatures (leap years respected); years with fewer than 12 valid months are excluded.',
    ),
    precipitation: variable(
      base.precipitation,
      'Monthly total (mm) = mean daily rate (mm/day) x days in month; annual total (mm/year) = sum of monthly totals; annual mean rate (mm/day) = annual total / days in year. Years with fewer than 12 valid months are excluded.',
    ),
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
    final response = Completer<ClimateAnalysis>();
    responses.add(response);
    return response.future;
  }
}

final _captureKey = GlobalKey();
Future<_Service> _pump(
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
  await tester.tap(find.byIcon(Icons.science_outlined).first);
  await tester.pump();
  if (data != null) await tester.pumpAndSettle();
  return service;
}

const _headings = [
  'Statistical Parameters',
  'Data & completeness',
  "Sen's slope",
  'Mann-Kendall & Hamed-Rao',
  'Confidence intervals',
  'Seasonality',
  'Month-wise Trends',
  'Anomaly Baseline',
  'Interpreting results',
  'Limitations',
];

void _checkText(WidgetTester tester, double width) {
  final panel = tester.getRect(find.byType(MethodologyPanel));
  for (final element
      in find
          .descendant(
            of: find.byType(MethodologyPanel),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: paragraph.text.toPlainText(),
    );
    expect(rect.left, greaterThanOrEqualTo(panel.left - .01));
    expect(rect.right, lessThanOrEqualTo(panel.right + .01));
    expect(rect.right, lessThanOrEqualTo(width + .01));
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
        testWidgets('scientific guide fits $width x $height at $scale text', (
          tester,
        ) async {
          final data = _analysis();
          await _pump(tester, width, scale: scale, height: height, data: data);
          expect(find.byType(MethodologyGuide), findsOneWidget);
          legacy.expectSuppliedContent(data.methodology);
          expect(find.text(data.temperature.method), findsOneWidget);
          expect(find.text(data.precipitation.method), findsOneWidget);
          expect(find.text(data.dataset.sources.join(' · ')), findsOneWidget);
          for (final heading in _headings) {
            expect(find.text(heading), findsOneWidget);
            expect(
              tester.getSemantics(find.text(heading)).flagsCollection.isHeader,
              isTrue,
            );
          }
          final source = tester.getRect(find.text('Data & completeness'));
          final slope = tester.getRect(find.text("Sen's slope"));
          final wide =
              tester.getSize(find.byType(MethodologyPanel)).width >=
              900 * scale;
          if (wide) {
            expect(slope.top, source.top);
            expect(slope.left, greaterThan(source.right));
          } else {
            expect(slope.top, greaterThan(source.bottom));
            expect(slope.left, source.left);
          }
          // All caveats are built and reachable without an expansion action.
          expect(find.byType(ExpansionTile), findsNothing);
          for (final text in [
            'Interpreting results',
            data.methodology.limitations.last,
          ]) {
            // At 2x text in a short viewport a paragraph can be taller
            // than the reading area. Verify both ends can be scrolled into view.
            for (final alignment in [0.0, 1.0]) {
              await Scrollable.ensureVisible(
                tester.element(find.text(text)),
                alignment: alignment,
              );
              await tester.pumpAndSettle();
              expect(
                find
                    .text(text)
                    .hitTestable(at: Alignment(0, alignment == 0 ? -.99 : .99)),
                findsOneWidget,
              );
            }
          }
          _checkText(tester, width);
        });
      }
    }
  }

  testWidgets('backend strings remain verbatim even when unusually long', (
    tester,
  ) async {
    final data = _analysis(methodology: legacy.methodology(longText: true));
    await _pump(tester, 320, scale: 2, data: data);
    legacy.expectSuppliedContent(data.methodology);
    _checkText(tester, 320);
  });

  testWidgets(
    'empty limitations leave no orphaned heading and retain critical guidance',
    (tester) async {
      await _pump(
        tester,
        390,
        data: _analysis(methodology: legacy.methodology(limitations: false)),
      );
      expect(find.text('Limitations'), findsNothing);
      expect(find.text('Interpreting results'), findsOneWidget);
      expect(
        find.textContaining('no significance result is supplied'),
        findsOneWidget,
      );
      expect(
        find.textContaining('A non-significant result is inconclusive'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Insufficient observations means'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'guide editor supports keyboard activation and preserves drafts across destinations and breakpoints',
    (tester) async {
      final service = await _pump(tester, 390, data: _analysis());
      final edit = find.ancestor(
        of: find.text('Edit location'),
        matching: find.byType(TextButton),
      );
      expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
      Focus.of(tester.element(find.text('Edit location'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      final controllers = tester
          .widgetList<TextFormField>(fields)
          .map((f) => f.controller)
          .toList();
      const values = ['-89.123456789', '179.987654321', '1990', '2020'];
      for (final (i, value) in values.indexed) {
        await tester.enterText(fields.at(i), value);
      }
      for (final icon in [
        Icons.dashboard_outlined,
        Icons.thermostat_outlined,
        Icons.water_drop_outlined,
        Icons.science_outlined,
      ]) {
        await tester.tap(find.byIcon(icon).first);
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
        lat: -89.123456789,
        lon: 179.987654321,
        start: 1990,
        end: 2020,
      ));
      expect(find.byType(MethodologyPanel), findsNothing);
      service.responses.last.complete(_analysis());
      await tester.pumpAndSettle();
      expect(find.byType(MethodologyPanel), findsOneWidget);
    },
  );

  testWidgets(
    'guide editor validation stays readable at 320px and 2x text in short landscape',
    (tester) async {
      final service = await _pump(
        tester,
        320,
        height: 320,
        scale: 2,
        data: _analysis(),
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
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ApiErrorKind.values) {
    testWidgets('guide keeps location context and retry through $kind', (
      tester,
    ) async {
      final service = await _pump(tester, 390);
      expect(find.text('SCIENTIFIC FIELD GUIDE'), findsOneWidget);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      expect(find.byType(MethodologyPanel), findsNothing);
      service.responses.first.completeError(
        ApiException(kind, 'Analysis unavailable for this request.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Failed to load data'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(service.requests.last, service.requests.first);
      service.responses.last.complete(_analysis());
      await tester.pumpAndSettle();
      expect(find.byType(MethodologyPanel), findsOneWidget);
    });
  }

  if (const bool.fromEnvironment('P37_METHODOLOGY_CAPTURE')) {
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
    for (final width in [390.0, 768.0, 1280.0]) {
      testWidgets('capture actual Methodology $width', (tester) async {
        await _pump(tester, width, height: 900, data: _analysis());
        // Capture the complete page with measured shell chrome, avoiding
        // an artificially tall blank area below the reading content.
        final guide = find.byType(MethodologyGuide);
        final scroll = find
            .ancestor(of: guide, matching: find.byType(SingleChildScrollView))
            .first;
        final scrollWidget = tester.widget<SingleChildScrollView>(scroll);
        final padding = scrollWidget.padding!
            .resolve(TextDirection.ltr)
            .vertical;
        final chrome = 900 - tester.getSize(scroll).height;
        tester.view.physicalSize = Size(
          width,
          (tester.getSize(guide).height + padding + chrome).ceilToDouble(),
        );
        await tester.pumpAndSettle();
        final boundary =
            _captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/p37-methodology-${width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
