import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/recent_locations.dart';
import 'package:mobile/widgets/seasonal_trend_card.dart';
import 'package:mobile/widgets/temperature_anomaly_explorer.dart';

import 'fixtures/scientific_fixture.dart';

ClimateAnalysis _analysis({
  String? scientific,
  double lat = 7.3,
  double lon = 81.8,
}) {
  final json = jsonDecode(
    File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  if (scientific != null) {
    final variables = scientificCase(scientific);
    json['temperature'] = variables['temperature'];
    json['precipitation'] = variables['precipitation'];
    json['period'] = {'start_year': 1981, 'end_year': 1992};
  }
  json['location'].addAll({
    'latitude': lat,
    'longitude': lon,
    'requested_latitude': lat,
    'requested_longitude': lon,
  });
  return ClimateAnalysis.fromJson(json);
}

Future<void> _pump(
  WidgetTester t,
  AnomalyResult? result, {
  double width = 390,
  double scale = 1,
  double height = 900,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TemperatureAnomalyExplorer(result: result),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

BarChartData _chart(WidgetTester t) =>
    t.widget<BarChart>(find.byType(BarChart)).data;

Future<void> _year(WidgetTester t, int year) async {
  final dropdown = find.byKey(const ValueKey('temperature_anomaly_year'));
  await t.ensureVisible(dropdown);
  await t.pumpAndSettle();
  await t.tap(dropdown);
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.text('$year'),
    -160,
    scrollable: find.byType(Scrollable).last,
  );
  await t.tap(find.text('$year').last);
  await t.pumpAndSettle();
}

Future<void> _values(WidgetTester t, int year) async {
  final heading = find.text('Monthly values for $year');
  await t.ensureVisible(heading);
  await t.tap(heading);
  await t.pumpAndSettle();
}

class _Service extends ClimateApiService {
  final responses = <Completer<ClimateAnalysis>>[];
  final requests = <({double lat, double lon, int start, int end})>[];
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
    final completer = Completer<ClimateAnalysis>();
    responses.add(completer);
    return completer.future;
  }
}

void main() {
  testWidgets(
    'plots backend values without recalculation; negative and positive years',
    (t) async {
      final result = _analysis(scientific: 'custom').temperature.anomalies!;
      await _pump(t, result);
      expect(find.text('Custom reference period · 1981–1992'), findsOneWidget);
      expect(find.text('Baseline sufficient'), findsOneWidget);
      expect(_chart(t).extraLinesData.horizontalLines.single.y, 0);
      expect(_chart(t).barGroups.map((g) => g.x), List.generate(12, (i) => i));
      for (final group in _chart(t).barGroups) {
        final source = result.anomalies.singleWhere(
          (r) => r.year == 1992 && r.month == group.x + 1,
        );
        expect(group.barRods.single.toY, source.anomaly);
        expect(group.barRods.single.toY, greaterThan(0));
        expect(group.barRods.single.color, AppColors.cyan);
      }
      await _year(t, 1981);
      final chart = _chart(t);
      for (final group in chart.barGroups) {
        expect(
          group.barRods.single.toY,
          result.anomalies
              .singleWhere((r) => r.year == 1981 && r.month == group.x + 1)
              .anomaly,
        );
        expect(group.barRods.single.toY, lessThan(0));
        expect(group.barRods.single.color, AppColors.blue);
      }
      final group = chart.barGroups.first;
      final tooltip = chart.barTouchData.touchTooltipData;
      expect(tooltip.fitInsideHorizontally, isTrue);
      expect(tooltip.fitInsideVertically, isTrue);
      expect(
        tooltip.getTooltipItem(group, 0, group.barRods.single, 0)!.text,
        'Jan 1981\n−0.165 °C\ncooler than reference',
      );
      await _values(t, 1981);
      expect(
        find.text('Jan 1981: −0.165 °C · cooler than reference'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not themselves a significance test'),
        findsOneWidget,
      );
      expect(
        find.textContaining('not local weather-station measurements'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'true zeros have a visible marker, missing months have no plotted value',
    (t) async {
      await _pump(
        t,
        _analysis(scientific: 'zero_missing').temperature.anomalies,
      );
      await _year(t, 1981);
      final groups = _chart(t).barGroups;
      expect(groups[1].barRods, isEmpty);
      expect(groups.expand((g) => g.barRods), hasLength(11));
      for (final rod in groups.expand((g) => g.barRods)) {
        expect(rod.toY, 0);
        expect(rod.label.show, isTrue);
        expect(rod.label.text, '●');
        expect(rod.color, AppColors.textPrimary);
      }
      await _values(t, 1981);
      expect(find.text('Jan 1981: 0.000 °C · at reference'), findsOneWidget);
      expect(find.text('Feb 1981: no returned observation'), findsOneWidget);
      expect(find.textContaining('11/12 monthly observations'), findsOneWidget);
    },
  );

  testWidgets(
    'orders copied records by year and month without mutating the response',
    (t) async {
      final raw =
          scientificCase('custom')['temperature']['anomalies']
              as Map<String, dynamic>;
      raw['anomalies'] = (raw['anomalies'] as List).reversed.toList();
      final result = AnomalyResult.fromJson(raw);
      final original = [...result.anomalies];
      await _pump(t, result);
      final dropdown = t.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(
        dropdown.items!.map((i) => i.value),
        List.generate(12, (i) => 1981 + i),
      );
      expect(dropdown.value, 1992);
      await _values(t, 1992);
      expect(
        t
            .getTopLeft(
              find.text('Jan 1992: +0.165 °C · warmer than reference'),
            )
            .dy,
        lessThan(
          t
              .getTopLeft(
                find.text('Dec 1992: +0.165 °C · warmer than reference'),
              )
              .dy,
        ),
      );
      expect(result.anomalies, orderedEquals(original));
    },
  );

  testWidgets('zero markers do not collide at 320px and 2x text', (t) async {
    await _pump(
      t,
      _analysis(scientific: 'zero_missing').temperature.anomalies,
      width: 320,
      scale: 2,
    );
    final chart = _chart(t);
    final cellWidth =
        (t.getSize(find.byType(BarChart)).width -
            chart.titlesData.leftTitles.sideTitles.reservedSize) /
        12;
    for (final group in chart.barGroups) {
      final label = group.barRods.single.label;
      final painter = TextPainter(
        text: TextSpan(text: label.text, style: label.style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(2),
      )..layout();
      expect(painter.width, lessThanOrEqualTo(cellWidth));
      painter.dispose();
    }
  });

  testWidgets(
    'standard baseline uses actual years and preserves backend notes',
    (t) async {
      final result = _analysis().temperature.anomalies!;
      await _pump(t, result);
      expect(
        find.text('Standard reference period · 1991–2020'),
        findsOneWidget,
      );
      expect(find.text(result.baseline!.note), findsOneWidget);
      expect(find.text(result.note), findsOneWidget);
      expect(
        find.textContaining('at least 24 valid observations'),
        findsOneWidget,
      );
      expect(find.byType(BarChart), findsOneWidget);
    },
  );

  for (final name in ['insufficient', 'missing', 'empty']) {
    testWidgets(
      'insufficient baseline $name has no fabricated chart or zeros',
      (t) async {
        final result = AnomalyResult.fromJson(
          scientificCase(name)['temperature']['anomalies'],
        );
        await _pump(t, result);
        expect(find.byType(BarChart), findsNothing);
        expect(find.byType(DropdownButton<int>), findsNothing);
        expect(find.text('Insufficient baseline observations'), findsOneWidget);
        expect(find.text(result.note), findsOneWidget);
        expect(
          find.textContaining('not themselves a significance test'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'absent baseline or absent anomaly result does not invent a reference',
    (t) async {
      final raw =
          scientificCase('custom')['temperature']['anomalies']
              as Map<String, dynamic>;
      raw['baseline'] = null;
      await _pump(t, AnomalyResult.fromJson(raw));
      expect(find.byType(BarChart), findsNothing);
      expect(find.text('Baseline unavailable'), findsOneWidget);
      await _pump(t, null);
      expect(find.byType(BarChart), findsNothing);
      expect(find.text('Baseline unavailable'), findsOneWidget);
    },
  );

  testWidgets(
    'sufficient baseline with empty records does not manufacture observations',
    (t) async {
      final raw =
          scientificCase('custom')['temperature']['anomalies']
              as Map<String, dynamic>;
      raw['anomalies'] = [];
      await _pump(t, AnomalyResult.fromJson(raw));
      expect(find.text('Baseline sufficient'), findsOneWidget);
      expect(
        find.text('No monthly anomaly observations were returned.'),
        findsOneWidget,
      );
      expect(find.byType(BarChart), findsNothing);
    },
  );

  testWidgets(
    'year control and monthly values are keyboard accessible with semantics',
    (t) async {
      final semantics = t.ensureSemantics();
      await _pump(t, _analysis(scientific: 'custom').temperature.anomalies);
      final control = find.byKey(const ValueKey('temperature_anomaly_year'));
      await t.ensureVisible(control);
      expect(t.getSize(control).height, greaterThanOrEqualTo(48));
      // Focus the native dropdown and activate its existing keyboard action.
      t
          .widget<Focus>(
            find.descendant(of: control, matching: find.byType(Focus)).first,
          )
          .focusNode!
          .requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(t.widget<DropdownButton<int>>(control).value, 1991);
      final tile = find.byType(ExpansionTile);
      await t.ensureVisible(tile);
      final focus = find
          .descendant(of: tile, matching: find.byType(Focus))
          .first;
      Focus.of(t.element(find.byWidget(t.widget<Focus>(focus).child)))
          .requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Jan 1991:')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Temperature anomalies for 1991')),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );

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
      testWidgets(
        'anomalies fit $width at $scale text scale and short landscape',
        (t) async {
          await _pump(
            t,
            _analysis().temperature.anomalies,
            width: width,
            scale: scale,
            height: 320,
          );
          await _values(t, 2025);
          for (final element in find.byType(RichText).evaluate()) {
            final render = element.renderObject! as RenderParagraph;
            expect(
              render.didExceedMaxLines,
              isFalse,
              reason: render.text.toPlainText(),
            );
            final rect = MatrixUtils.transformRect(
              render.getTransformTo(null),
              Offset.zero & render.size,
            );
            expect(rect.left, greaterThanOrEqualTo(-.01));
            expect(
              rect.right,
              lessThanOrEqualTo(width + .01),
              reason: render.text.toPlainText(),
            );
          }
          final tooltip = _chart(t).barTouchData.touchTooltipData;
          expect(tooltip.fitInsideHorizontally, isTrue);
          expect(tooltip.fitInsideVertically, isTrue);
          expect(t.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'submitted anomaly results survive map drafts/history; Analyze owns updates and retry',
    (t) async {
      t.view.physicalSize = const Size(1280, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final service = _Service();
      addTearDown(service.close);
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: DashboardScreen(service: service),
        ),
      );
      final original = _analysis();
      service.responses.first.complete(original);
      await t.pumpAndSettle();
      Future<void> navigate(IconData icon) async {
        await t.tap(find.byIcon(icon).first);
        await t.pumpAndSettle();
      }

      AnomalyResult? shown() => t
          .widget<TemperatureAnomalyExplorer>(
            find.byType(TemperatureAnomalyExplorer),
          )
          .result;
      final form = t.widget<LocationForm>(find.byType(LocationForm));
      final draft = form.draftController!;
      await navigate(Icons.thermostat_outlined);
      expect(shown(), same(original.temperature.anomalies));
      expect(find.byType(AnnualChart), findsOneWidget);
      expect(
        t.widget<AnnualChart>(find.byType(AnnualChart)).series,
        same(original.temperature.series),
      );
      expect(
        t.widget<ClimateTrendCard>(find.byType(ClimateTrendCard)).trend,
        same(original.temperature.trend),
      );
      expect(
        t.widget<SeasonalTrendCard>(find.byType(SeasonalTrendCard)).trend,
        same(original.temperature.seasonal),
      );
      draft.selectMapPoint(-89.123456789, 179.999);
      expect(service.requests, hasLength(1));
      expect(shown(), same(original.temperature.anomalies));
      await navigate(Icons.dashboard_outlined);
      final recent = find.descendant(
        of: find.byType(RecentLocations),
        matching: find.byType(TextButton),
      );
      await t.ensureVisible(recent);
      await t.tap(recent);
      await t.pumpAndSettle();
      expect(service.requests, hasLength(1));
      await navigate(Icons.thermostat_outlined);
      expect(shown(), same(original.temperature.anomalies));
      draft.restoreAnalyzedLocation(
        latitude: 10,
        longitude: 20,
        startYear: 1981,
        endYear: 1992,
      );
      final edit = find.text('Edit location');
      if (edit.evaluate().isNotEmpty) {
        await t.ensureVisible(edit);
        await t.tap(edit);
        await t.pumpAndSettle();
      }
      final analyze = find.text('Analyze');
      await t.ensureVisible(analyze);
      await t.tap(analyze);
      await t.pump();
      expect(service.requests.last, (
        lat: 10.0,
        lon: 20.0,
        start: 1981,
        end: 1992,
      ));
      expect(find.byType(TemperatureAnomalyExplorer), findsNothing);
      expect(find.byType(AnnualChart), findsNothing);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      draft.selectMapPoint(-30, 40);
      service.responses.last.completeError(
        const ApiException(ApiErrorKind.timeout, 'test timeout'),
      );
      await t.pumpAndSettle();
      expect(find.text('Request timed out'), findsOneWidget);
      expect(find.byType(TemperatureAnomalyExplorer), findsNothing);
      final retry = find.text('Retry');
      await t.ensureVisible(retry);
      await t.tap(retry);
      await t.pump();
      expect(service.requests, hasLength(3));
      expect(service.requests.last, (
        lat: 10.0,
        lon: 20.0,
        start: 1981,
        end: 1992,
      ));
      expect(find.byType(TemperatureAnomalyExplorer), findsNothing);
      final next = _analysis(scientific: 'custom', lat: 10, lon: 20);
      service.responses.last.complete(next);
      await t.pumpAndSettle();
      expect(shown(), same(next.temperature.anomalies));
      expect(draft.coordinates, (latitude: -30.0, longitude: 40.0));
      expect(find.text('Custom reference period · 1981–1992'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
