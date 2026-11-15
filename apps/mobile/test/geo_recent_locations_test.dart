import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/map_config.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/overview_card.dart';
import 'package:mobile/widgets/recent_locations.dart';

const _initial = (
  latitude: 7.3,
  longitude: 81.8,
  startYear: 1981,
  endYear: 2025,
);
const _polar = (
  latitude: 90.0,
  longitude: 180.0,
  startYear: 2001,
  endYear: 2008,
);
const _other = (
  latitude: -35.123456789,
  longitude: -179.0,
  startYear: 2002,
  endYear: 2007,
);

class _Service extends ClimateApiService {
  final queries = <AnalyzedLocation>[];
  final pending = <Completer<ClimateAnalysis>>[];
  @override
  Future<ClimateAnalysis> fetchAnalysis({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) {
    queries.add((
      latitude: latitude,
      longitude: longitude,
      startYear: startYear,
      endYear: endYear,
    ));
    final next = Completer<ClimateAnalysis>();
    pending.add(next);
    return next.future;
  }

  void success() {
    final q = queries.last;
    final json = jsonDecode(
      File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    json['location'] = {
      'latitude': 0.0,
      'longitude': 0.0,
      'requested_latitude': q.latitude,
      'requested_longitude': q.longitude,
      'elevation_m': null,
    };
    json['period'] = {'start_year': q.startYear, 'end_year': q.endYear};
    // A successful response with insufficient observations still belongs in history.
    // No statistical estimates are fabricated for these synthetic empty series.
    for (final name in ['temperature', 'precipitation']) {
      final v = json[name];
      final key = name == 'temperature' ? 'annual_trend' : 'annual_total_trend';
      v['annual']['series'] = [];
      v['annual']['excluded_years'] = [
        for (var year = q.startYear; year <= q.endYear; year++)
          {'year': year, 'valid_months': 0},
      ];
      final old = v[key];
      v[key] = {
        'status': 'insufficient_data',
        'n_observations': 0,
        'min_observations_required': 10,
        'alpha': 0.05,
        'hamed_rao_lag': 3,
        'value_units': old['value_units'],
        'slope_units_per_decade': old['slope_units_per_decade'],
        'ci95_note': old['ci95_note'],
        'interpretation': 'Insufficient observations in synthetic response.',
      };
      v['seasonal_trend'] = {
        'status': 'insufficient_data',
        'slope_units_per_decade': v['seasonal_trend']['slope_units_per_decade'],
      };
    }
    pending.last.complete(ClimateAnalysis.fromJson(json));
  }
}

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(File('assets/maps/maptiler-logo.png').readAsBytesSync());
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 25)),
  );
  await tester.pump();
  await tester.pump();
}

LocationForm _form(WidgetTester t) =>
    t.widget<LocationForm>(find.byType(LocationForm));
List<AnalyzedLocation> _entries(WidgetTester t) =>
    t.widget<RecentLocations>(find.byType(RecentLocations)).entries;
Future<_Service> _pump(
  WidgetTester t, {
  double width = 1280,
  double scale = 1,
  bool complete = true,
}) async {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final service = _Service();
  addTearDown(service.close);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DashboardScreen(
        service: service,
        mapConfiguration: const MapTileConfiguration(
          apiKey: 'fake',
          style: 'fake',
          termsConfirmed: true,
        ),
        mapTileProviderFactory: _Tiles.new,
      ),
    ),
  );
  await _flush(t);
  if (complete) {
    service.success();
    await _flush(t);
  }
  return service;
}

Future<void> _analyze(
  WidgetTester t,
  _Service service,
  AnalyzedLocation query,
) async {
  _form(
    t,
  ).onAnalyze(query.latitude, query.longitude, query.startYear, query.endYear);
  await _flush(t);
  service.success();
  await _flush(t);
}

Finder _button(AnalyzedLocation q) => find.descendant(
  of: find.byType(RecentLocations),
  matching: find.widgetWithText(
    TextButton,
    '${q.latitude.toStringAsFixed(5)}°, ${q.longitude.toStringAsFixed(5)}° · ${q.startYear}–${q.endYear}',
  ),
);

void main() {
  testWidgets(
    'history starts empty, records successful submitted query only, and resets with a new session',
    (t) async {
      final service = await _pump(t, complete: false);
      expect(_entries(t), isEmpty);
      expect(find.text('Recent Locations'), findsNothing);
      final draft = _form(t).draftController!;
      draft.selectMapPoint(40, 60);
      service.success();
      await _flush(t);
      expect(_entries(t), [_initial]);
      expect(draft.coordinates, (latitude: 40.0, longitude: 60.0));
      expect(
        _entries(t).single.latitude,
        isNot(0),
      ); // Never use returned grid geometry.
      await t.pumpWidget(const SizedBox());
      await _flush(t);
      final next = await _pump(t, complete: false);
      expect(_entries(t), isEmpty);
      next.success();
      await _flush(t);
      expect(_entries(t), [_initial]);
    },
  );

  testWidgets(
    'history is newest first, capped at five, deduplicated and period-sensitive',
    (t) async {
      final service = await _pump(t);
      final queries = [
        for (var i = 1; i <= 6; i++)
          (
            latitude: i.toDouble(),
            longitude: 20.0,
            startYear: 1981,
            endYear: 2025,
          ),
      ];
      for (final q in queries) {
        await _analyze(t, service, q);
      }
      expect(_entries(t), queries.reversed.take(5).toList());
      await _analyze(t, service, queries[2]);
      expect(_entries(t).first, queries[2]);
      expect(_entries(t).length, 5);
      expect(_entries(t).where((q) => q == queries[2]).length, 1);
      final period = (
        latitude: queries[2].latitude,
        longitude: 20.0,
        startYear: 2001,
        endYear: 2008,
      );
      await _analyze(t, service, period);
      expect(_entries(t).first, period);
      expect(_entries(t).contains(queries[2]), isTrue);
    },
  );

  for (final kind in ApiErrorKind.values) {
    testWidgets('$kind does not add history; recovery adds it once', (t) async {
      final service = await _pump(t);
      final submit = _form(t).onAnalyze;
      submit(
        _other.latitude,
        _other.longitude,
        _other.startYear,
        _other.endYear,
      );
      submit(
        _polar.latitude,
        _polar.longitude,
        _polar.startYear,
        _polar.endYear,
      );
      await _flush(t);
      expect(service.queries, hasLength(2));
      service.pending.last.completeError(
        ApiException(kind, 'Synthetic failure'),
      );
      await _flush(t);
      expect(_entries(t), [_initial]);
      await t.ensureVisible(find.text('Retry'));
      await t.tap(find.text('Retry'));
      await _flush(t);
      service.success();
      await _flush(t);
      expect(_entries(t), [_other, _initial]);
    });
  }

  testWidgets(
    'selecting history restores all drafts and marker without replacing results or analyzing',
    (t) async {
      final service = await _pump(t);
      await _analyze(t, service, _other);
      await _analyze(t, service, _polar);
      final shown = t.widget<OverviewCard>(find.byType(OverviewCard)).analysis;
      final toggle = find.byKey(const ValueKey('map_explorer_toggle'));
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await _flush(t);
      await t.ensureVisible(_button(_other));
      await t.tap(_button(_other));
      await _flush(t);
      final draft = _form(t).draftController!;
      expect(draft.coordinates, (
        latitude: _other.latitude,
        longitude: _other.longitude,
      ));
      expect(draft.startYear.text, '2002');
      expect(draft.endYear.text, '2007');
      expect(
        t
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point
            .latitude,
        _other.latitude,
      );
      expect(
        t.widget<OverviewCard>(find.byType(OverviewCard)).analysis,
        same(shown),
      );
      expect(service.queries, hasLength(3));
      expect(_entries(t), [_polar, _other, _initial]);
      expect(
        find.byKey(const ValueKey('submitted_location_context')),
        findsOneWidget,
      );
      // Repeated selections do not reorder history or submit requests.
      final pick = t
          .widget<RecentLocations>(find.byType(RecentLocations))
          .onSelected;
      pick(_initial);
      pick(_other);
      pick(_polar);
      await _flush(t);
      expect(find.byType(MarkerLayer), findsNothing);
      expect(draft.latitude.text, '90.0');
      expect(draft.longitude.text, '180.0');
      expect(
        find.textContaining('outside the map’s visible range'),
        findsOneWidget,
      );
      pick(_other);
      await _flush(t);
      for (final icon in [
        Icons.thermostat_outlined,
        Icons.water_drop_outlined,
        Icons.science_outlined,
        Icons.dashboard_outlined,
      ]) {
        await t.tap(find.byIcon(icon).first);
        await _flush(t);
        expect(_form(t).draftController, same(draft));
      }
      expect(_entries(t), [_polar, _other, _initial]);
      expect(service.queries, hasLength(3));
      await t.ensureVisible(find.text('Analyze').first);
      await t.tap(find.text('Analyze').first);
      await _flush(t);
      expect(service.queries.last, _other);
      expect(_entries(t), [_polar, _other, _initial]);
      service.success();
      await _flush(t);
      expect(_entries(t), [_other, _polar, _initial]);
    },
  );

  testWidgets(
    'map-wrapped longitude deduplicates; polar and antimeridian values restore verbatim',
    (t) async {
      final service = await _pump(t);
      final d = _form(t).draftController!;
      d.selectMapPoint(10, 181);
      final point = d.coordinates!;
      final query = (
        latitude: point.latitude,
        longitude: point.longitude,
        startYear: 1981,
        endYear: 2025,
      );
      await _analyze(t, service, query);
      await _analyze(t, service, query);
      expect(_entries(t).where((e) => e.longitude == -179).length, 1);
      await _analyze(t, service, _polar);
      final west = (
        latitude: 90.0,
        longitude: -180.0,
        startYear: 2001,
        endYear: 2008,
      );
      await _analyze(t, service, west);
      expect(_entries(t).where((e) => e.latitude == 90).length, 1);
      final pick = t
          .widget<RecentLocations>(find.byType(RecentLocations))
          .onSelected;
      pick(west);
      expect(d.latitude.text, '90.0');
      expect(d.longitude.text, '-180.0');
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
    testWidgets(
      'five recent locations fit $width at 2x and support keyboard selection',
      (t) async {
        final service = await _pump(t, width: width, scale: 2);
        await _analyze(t, service, _other);
        await _analyze(t, service, _polar);
        await _analyze(t, service, (
          latitude: -89.999999999,
          longitude: 179.999999999,
          startYear: 1981,
          endYear: 2025,
        ));
        await _analyze(t, service, (
          latitude: 45.0,
          longitude: 90.0,
          startYear: 1991,
          endYear: 2020,
        ));
        final semantics = t.ensureSemantics();
        for (final entry in _entries(t)) {
          final b = _button(entry);
          await t.ensureVisible(b);
          final rect = t.getRect(b);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(
            t
                .getSemantics(b)
                .getSemanticsData()
                .hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
        }
        await t.ensureVisible(_button(_other));
        Focus.of(
          t.element(
            find
                .descendant(of: _button(_other), matching: find.byType(Text))
                .first,
          ),
        ).requestFocus();
        await t.pump();
        final count = service.queries.length;
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await _flush(t);
        expect(_form(t).draftController!.coordinates, (
          latitude: _other.latitude,
          longitude: _other.longitude,
        ));
        expect(service.queries, hasLength(count));
        expect(t.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
