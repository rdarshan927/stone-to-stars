import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/app/map_config.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/controllers/location_draft_controller.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/annual_chart.dart';
import 'package:mobile/widgets/excluded_years_panel.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/methodology_guide.dart';
import 'package:mobile/widgets/overview_card.dart';
import 'package:mobile/widgets/precipitation_explorer.dart';
import 'package:mobile/widgets/temperature_explorer.dart';

import 'fixtures/scientific_fixture.dart';

const _provider = MapTileConfiguration(
  apiKey: 'fake',
  style: 'fake',
  termsConfirmed: true,
);

class _Tiles extends TileProvider {
  _Tiles({this.fail = false});
  final bool fail;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        fail
            ? File('test/fixtures/p37_imagery_analysis.json').readAsBytesSync()
            : File('assets/maps/maptiler-logo.png').readAsBytesSync(),
      );
}

class _Pending {
  _Pending(this.request);
  final http.Request request;
  final response = Completer<http.Response>();
}

/// Uses the actual API client and JSON parser, replacing only HTTP transport.
class _Backend {
  final pending = <_Pending>[];
  late final client = MockClient((request) {
    final next = _Pending(request);
    pending.add(next);
    return next.response.future;
  });
  late final service = ClimateApiService(
    client: client,
    baseUrl: 'https://climate.example.test',
  );

  void success(int index, {bool empty = false, bool mixed = false}) {
    final request = pending[index].request;
    final query = request.url.queryParameters;
    final start = int.parse(query['start_year']!);
    final end = int.parse(query['end_year']!);
    // Synthetic observations with precomputed statistics, never live data.
    final json = jsonDecode(
      File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    json['location'] = {
      'latitude': double.parse(query['latitude']!),
      'longitude': double.parse(query['longitude']!),
      'requested_latitude': double.parse(query['latitude']!),
      'requested_longitude': double.parse(query['longitude']!),
      'elevation_m': null,
    };
    json['period'] = {'start_year': start, 'end_year': end};
    for (final name in ['temperature', 'precipitation']) {
      final variable = json[name] as Map<String, dynamic>;
      final annual = variable['annual'] as Map<String, dynamic>;
      final sparse = empty || (mixed && name == 'temperature');
      annual['series'] = (annual['series'] as List)
          .where((p) => p['year'] >= start && p['year'] <= end && !sparse)
          .toList();
      annual['excluded_years'] = sparse
          ? [
              for (var year = start; year <= end; year++)
                {'year': year, 'valid_months': 0},
            ]
          : (annual['excluded_years'] as List)
                .where((p) => p['year'] >= start && p['year'] <= end)
                .toList();
      final count = (annual['series'] as List).length;
      if (count < 10) {
        final key = name == 'temperature'
            ? 'annual_trend'
            : 'annual_total_trend';
        final original = variable[key] as Map<String, dynamic>;
        variable[key] = {
          'status': 'insufficient_data',
          'n_observations': count,
          'min_observations_required': 10,
          'alpha': 0.05,
          'hamed_rao_lag': original['hamed_rao_lag'],
          'value_units': original['value_units'],
          'slope_units_per_decade': original['slope_units_per_decade'],
          'ci95_note': original['ci95_note'],
          'interpretation':
              'Insufficient observations in this synthetic response.',
        };
        variable['seasonal_trend'] = scientificCase(
          'empty',
        )[name]['seasonal_trend'];
      }
    }
    respond(index, 200, jsonEncode(json));
  }

  void respond(int index, int code, String body) =>
      pending[index].response.complete(
        http.Response(
          body,
          code,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
}

Future<void> _flush(WidgetTester tester) async {
  // No pumpAndSettle: pending requests deliberately leave a spinner animating.
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  await tester.pump();
  await tester.pump();
}

LocationForm _form(WidgetTester tester) =>
    tester.widget<LocationForm>(find.byType(LocationForm));
LocationDraftController _draft(WidgetTester tester) =>
    _form(tester).draftController!;
ClimateAnalysis? _shown(WidgetTester tester) {
  if (find.byType(OverviewCard).evaluate().isNotEmpty) {
    return tester.widget<OverviewCard>(find.byType(OverviewCard)).analysis;
  }
  if (find.byType(TemperatureExplorer).evaluate().isNotEmpty) {
    return tester
        .widget<TemperatureExplorer>(find.byType(TemperatureExplorer))
        .analysis;
  }
  if (find.byType(PrecipitationExplorer).evaluate().isNotEmpty) {
    return tester
        .widget<PrecipitationExplorer>(find.byType(PrecipitationExplorer))
        .analysis;
  }
  return tester
      .widget<MethodologyGuide>(find.byType(MethodologyGuide))
      .analysis;
}

Future<_Backend> _pump(
  WidgetTester tester, {
  double width = 1280,
  double scale = 1,
  bool configured = true,
  bool tileFailure = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = _Backend();
  addTearDown(backend.service.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DashboardScreen(
        service: backend.service,
        mapConfiguration: configured ? _provider : const MapTileConfiguration(),
        mapTileProviderFactory: () => _Tiles(fail: tileFailure),
      ),
    ),
  );
  await _flush(tester);
  expect(backend.pending, hasLength(1)); // Existing startup analysis.
  backend.success(0);
  await _flush(tester);
  return backend;
}

Future<void> _openMap(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('map_explorer_toggle'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await _flush(tester);
}

Future<void> _select(
  WidgetTester tester, {
  Offset offset = const Offset(40, -20),
}) async {
  final canvas = find.byKey(const ValueKey('map_canvas'));
  await tester.ensureVisible(canvas);
  await tester.tapAt(tester.getCenter(canvas) + offset);
  await tester.pump(const Duration(milliseconds: 350));
  await _flush(tester);
}

Future<void> _submit(WidgetTester tester) async {
  if (find.text('Edit location').evaluate().isNotEmpty) {
    await tester.ensureVisible(find.text('Edit location'));
    await tester.tap(find.text('Edit location'));
    await _flush(tester);
  }
  final analyze = find.text('Analyze').first;
  await tester.ensureVisible(analyze);
  await tester.tap(analyze);
  await _flush(tester);
}

void main() {
  testWidgets(
    'malformed nested annual records are response errors and can recover',
    (tester) async {
      final backend = await _pump(tester);
      await _openMap(tester);
      await _select(tester);
      await _submit(tester);
      final malformed = jsonDecode(
        File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      malformed['temperature']['annual']['series'] = ['not an annual record'];
      backend.respond(1, 200, jsonEncode(malformed));
      await _flush(tester);
      expect(find.text('Unexpected response'), findsOneWidget);
      expect(find.text('Connection unavailable'), findsNothing);
      expect(_shown(tester), isNull);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await _flush(tester);
      backend.success(2);
      await _flush(tester);
      expect(_shown(tester), isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Enter while busy retains the phone editor and unsent edits', (
    tester,
  ) async {
    final backend = await _pump(tester, width: 390);
    await _openMap(tester);
    await _select(tester);
    await _submit(tester);
    expect(backend.pending, hasLength(2));
    await tester.ensureVisible(find.text('Edit location'));
    await tester.tap(find.text('Edit location'));
    await _flush(tester);
    final fields = find.descendant(
      of: find.byType(LocationForm),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(fields.first);
    await tester.enterText(fields.first, '-12.345');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _flush(tester);
    expect(fields, findsNWidgets(4));
    expect(_draft(tester).latitude.text, '-12.345');
    expect(backend.pending, hasLength(2));
    backend.success(1);
    await _flush(tester);
    expect(_draft(tester).latitude.text, '-12.345');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'latest draft and years use the real request; delayed result retains submitted context',
    (tester) async {
      final backend = await _pump(tester);
      final original = _shown(tester);
      await _openMap(tester);
      await _select(tester);
      final draft = _draft(tester);
      final selected = draft.coordinates!;
      draft.startYear.text = '2001';
      draft.endYear.text = '2008';
      expect(_shown(tester), same(original));
      expect(backend.pending, hasLength(1));
      await _submit(tester);
      final submitted = backend.pending[1].request.url;
      expect(submitted.path, '/api/v1/analysis/climate');
      expect(submitted.queryParameters, {
        'latitude': '${selected.latitude}',
        'longitude': '${selected.longitude}',
        'start_year': '2001',
        'end_year': '2008',
      });
      expect(_shown(tester), isNull);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      await _select(tester, offset: const Offset(-45, 25));
      final nextDraft = draft.coordinates!;
      expect(nextDraft, isNot(selected));
      // Even a previously obtained callback cannot bypass the single-flight guard.
      _form(tester)
          .onAnalyze(nextDraft.latitude, nextDraft.longitude, 2002, 2007);
      await _flush(tester);
      expect(backend.pending, hasLength(2));
      for (final icon in [
        Icons.thermostat_outlined,
        Icons.water_drop_outlined,
        Icons.science_outlined,
        Icons.dashboard_outlined,
      ]) {
        await tester.tap(find.byIcon(icon).first);
        await _flush(tester);
        expect(_draft(tester), same(draft));
        expect(_form(tester).initialLat, selected.latitude);
        expect(_form(tester).initialStartYear, 2001);
        expect(draft.coordinates, nextDraft);
        expect(_shown(tester), isNull);
      }
      backend.success(1);
      await _flush(tester);
      expect(_shown(tester)!.location.requestedLatitude, selected.latitude);
      expect(_shown(tester)!.period.startYear, 2001);
      expect(draft.coordinates, nextDraft);
      expect(
        find.byKey(const ValueKey('submitted_location_context')),
        findsOneWidget,
      );
      await _submit(tester);
      expect(backend.pending, hasLength(3));
      expect(
        backend.pending[2].request.url.queryParameters['latitude'],
        '${nextDraft.latitude}',
      );
      backend.success(2);
      await _flush(tester);
      expect(_shown(tester)!.location.requestedLatitude, nextDraft.latitude);
      expect(
        find.byKey(const ValueKey('submitted_location_context')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ApiErrorKind.values) {
    testWidgets(
      '$kind is recoverable; retry retains submitted query rather than newer draft',
      (tester) async {
        final backend = await _pump(tester);
        await _openMap(tester);
        await _select(tester);
        await _submit(tester);
        final submitted = backend.pending[1].request.url;
        switch (kind) {
          case ApiErrorKind.connection:
            backend.pending[1].response.completeError(
              http.ClientException('Synthetic connection failure'),
            );
          case ApiErrorKind.timeout:
            backend.pending[1].response.completeError(
              TimeoutException('Synthetic transport timeout'),
            );
          case ApiErrorKind.http:
            backend.respond(
              1,
              503,
              jsonEncode({'detail': 'Synthetic backend unavailable'}),
            );
          case ApiErrorKind.invalidResponse:
            backend.respond(1, 200, '{not JSON');
        }
        await _flush(tester);
        expect(_shown(tester), isNull);
        expect(
          find.text(switch (kind) {
            ApiErrorKind.connection => 'Connection unavailable',
            ApiErrorKind.timeout => 'Request timed out',
            ApiErrorKind.http => 'Service error',
            ApiErrorKind.invalidResponse => 'Unexpected response',
          }),
          findsOneWidget,
        );
        await _select(tester, offset: const Offset(-45, 25));
        final draft = _draft(tester).coordinates;
        final retry = find.text('Retry');
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await _flush(tester);
        expect(backend.pending, hasLength(3));
        expect(backend.pending[2].request.url, submitted);
        expect(_draft(tester).coordinates, draft);
        expect(_shown(tester), isNull);
        backend.success(2);
        await _flush(tester);
        expect(
          _shown(tester)!.location.requestedLatitude,
          double.parse(submitted.queryParameters['latitude']!),
        );
        expect(_draft(tester).coordinates, draft);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'actual 45-second timeout ignores a late response after a newer query succeeds',
    (tester) async {
      final backend = await _pump(tester);
      expect(backend.service.timeout, const Duration(seconds: 45));
      await _openMap(tester);
      await _select(tester);
      await _submit(tester);
      await tester.pump(const Duration(seconds: 44));
      expect(find.text('Request timed out'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await _flush(tester);
      expect(find.text('Request timed out'), findsOneWidget);
      await _select(tester, offset: const Offset(-45, 25));
      final latest = _draft(tester).coordinates!;
      await _submit(tester);
      expect(backend.pending, hasLength(3));
      backend.success(2);
      await _flush(tester);
      final result = _shown(tester);
      backend.success(1);
      await _flush(tester);
      expect(_shown(tester), same(result));
      expect(_shown(tester)!.location.requestedLatitude, latest.latitude);
      expect(backend.pending, hasLength(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rapid repeated callbacks serialize queries instead of replacing submitted parameters',
    (tester) async {
      final backend = await _pump(tester);
      final callback = _form(tester).onAnalyze;
      callback(10, 20, 1981, 2025);
      callback(30, 40, 2001, 2008);
      callback(50, 60, 2002, 2007);
      await _flush(tester);
      expect(backend.pending, hasLength(2));
      expect(
        backend.pending[1].request.url.queryParameters['latitude'],
        '10.0',
      );
      expect(_form(tester).initialLat, 10);
      backend.success(1);
      await _flush(tester);
      expect(_shown(tester)!.location.requestedLatitude, 10);
      expect(tester.takeException(), isNull);
    },
  );

  for (final empty in [true, false]) {
    testWidgets(
      'valid ${empty ? 'empty' : 'mixed sufficient/insufficient'} response is not a backend failure',
      (tester) async {
        final backend = await _pump(tester);
        await _openMap(tester);
        await _select(tester);
        await _submit(tester);
        backend.success(1, empty: empty, mixed: !empty);
        await _flush(tester);
        final result = _shown(tester)!;
        expect(result.temperature.series, isEmpty);
        expect(result.temperature.trend.senSlopePerDecade, isNull);
        expect(result.temperature.trend.pValueHamedRao, isNull);
        expect(result.precipitation.series.isEmpty, empty);
        expect(find.text('Failed to load data'), findsNothing);
        expect(find.text('Retry'), findsNothing);
        await tester.tap(find.byIcon(Icons.thermostat_outlined).first);
        await _flush(tester);
        final chart = tester.widget<AnnualChart>(find.byType(AnnualChart));
        expect(chart.series, isEmpty);
        expect(chart.title, 'Annual Mean Temperature');
        expect(chart.seriesUnits, '°C');
        expect(find.byType(ExcludedYearsPanel), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final configured in [false, true]) {
    testWidgets(
      'manual input works with ${configured ? 'tile failures' : 'no provider'} and rejects invalid input',
      (tester) async {
        final backend = await _pump(
          tester,
          configured: configured,
          tileFailure: configured,
        );
        await _openMap(tester);
        expect(
          find.textContaining(
            configured ? 'Some map tiles could not load' : 'Map unavailable:',
          ),
          findsOneWidget,
        );
        final draft = _draft(tester);
        for (final text in ['', '-', 'NaN', 'Infinity', '91']) {
          draft.latitude.text = text;
          await _submit(tester);
          expect(backend.pending, hasLength(1));
          expect(draft.latitude.text, text);
        }
        draft.latitude.text = '90';
        draft.longitude.text = '181';
        await _submit(tester);
        expect(backend.pending, hasLength(1));
        draft.longitude.text = '-180';
        await _submit(tester);
        expect(backend.pending, hasLength(2));
        expect(
          backend.pending[1].request.url.queryParameters['latitude'],
          '90.0',
        );
        expect(
          backend.pending[1].request.url.queryParameters['longitude'],
          '-180.0',
        );
        backend.success(1);
        await _flush(tester);
        expect(_shown(tester)!.location.requestedLatitude, 90);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('a pending response after disposal cannot update the screen', (
    tester,
  ) async {
    final backend = await _pump(tester);
    await _submit(tester);
    await tester.pumpWidget(const SizedBox());
    backend.success(1);
    await _flush(tester);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
