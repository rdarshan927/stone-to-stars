import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/app/map_config.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/controllers/location_draft_controller.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/location_map.dart';

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(File('assets/maps/maptiler-logo.png').readAsBytesSync());
}

class _Service extends ClimateApiService {
  final requests = <({double lat, double lon, int start, int end})>[];
  @override
  Future<ClimateAnalysis> fetchAnalysis({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) async {
    requests.add((
      lat: latitude,
      lon: longitude,
      start: startYear,
      end: endYear,
    ));
    final json = jsonDecode(
      File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    json['location']['requested_latitude'] = latitude;
    json['location']['requested_longitude'] = longitude;
    return ClimateAnalysis.fromJson(json);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

LocationDraftController _draft(WidgetTester tester) =>
    tester.widget<LocationForm>(find.byType(LocationForm)).draftController!;

MapController _camera(WidgetTester tester) =>
    MapController.of(tester.element(find.byType(TileLayer)));

Future<_Service> _pump(
  WidgetTester tester, {
  double width = 1280,
  double height = 900,
  double scale = 1,
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
  await _settle(tester);
  final open = find.byKey(const ValueKey('map_explorer_toggle'));
  await tester.ensureVisible(open);
  await tester.tap(open);
  await _settle(tester);
  return service;
}

Future<void> _tapPoint(
  WidgetTester tester, {
  PointerDeviceKind kind = PointerDeviceKind.touch,
}) async {
  final canvas = find.byKey(const ValueKey('map_canvas'));
  await tester.ensureVisible(canvas);
  await tester.tapAt(
    tester.getCenter(canvas) + const Offset(35, -20),
    kind: kind,
  );
  // flutter_map defers a single tap while recognizing a possible double tap.
  await tester.pump(const Duration(milliseconds: 350));
  await _settle(tester);
}

void main() {
  testWidgets(
    'selection across the antimeridian is normalized and marker remains visible',
    (tester) async {
      final service = await _pump(tester);
      final canvas = find.byKey(const ValueKey('map_canvas'));
      await tester.ensureVisible(canvas);
      _camera(tester).move(const LatLng(10, 179), 4);
      await _settle(tester);
      await _tapPoint(tester);
      final point = _draft(tester).coordinates!;
      expect(point.longitude, greaterThanOrEqualTo(-180));
      expect(point.longitude, lessThan(-170));
      final marker = find.byKey(const ValueKey('draft_location_marker'));
      expect(marker, findsOneWidget);
      expect(tester.getRect(marker).overlaps(tester.getRect(canvas)), isTrue);
      expect(service.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'draft validation preserves raw input and normalizes map longitude only',
    () {
      final draft = LocationDraftController();
      addTearDown(draft.dispose);
      draft.startYear.text = '1990';
      draft.endYear.text = '2020';
      for (final input in ['', '-', '.', '1e', 'NaN', 'Infinity', '91']) {
        draft.latitude.text = input;
        expect(draft.coordinates, isNull);
        expect(draft.latitude.text, input);
      }
      draft.latitude.text = ' 12.3400 ';
      draft.longitude.text = '181';
      expect(draft.coordinates, isNull);
      expect(draft.longitude.text, '181');
      for (final pair in [
        (181.0, -179.0),
        (-181.0, 179.0),
        (540.0, -180.0),
        (-540.0, -180.0),
        (180.0, -180.0),
      ]) {
        expect(draft.selectMapPoint(10, pair.$1), isTrue);
        expect(draft.coordinates!.longitude, pair.$2);
      }
      expect(draft.selectMapPoint(double.nan, 0), isFalse);
      expect(draft.selectMapPoint(91, 0), isFalse);
      expect(draft.selectMapPoint(0, double.infinity), isFalse);
      expect(draft.startYear.text, '1990');
      expect(draft.endYear.text, '2020');
      draft.latitude.text = '90';
      draft.longitude.text = '180';
      expect(draft.coordinates, (latitude: 90.0, longitude: 180.0));
    },
  );

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
      '$kind map tap updates actual fields and marker; Analyze alone submits',
      (tester) async {
        final service = await _pump(tester);
        final draft = _draft(tester);
        draft.startYear.text = '1990';
        draft.endYear.text = '2020';
        final before = draft.coordinates;
        await _tapPoint(tester, kind: kind);
        final point = draft.coordinates!;
        expect(point, isNot(before));
        final fields = find.descendant(
          of: find.byType(LocationForm),
          matching: find.byType(TextFormField),
        );
        expect(
          tester.widget<TextFormField>(fields.at(0)).controller!.text,
          '${point.latitude}',
        );
        expect(
          tester.widget<TextFormField>(fields.at(1)).controller!.text,
          '${point.longitude}',
        );
        expect(
          tester
              .widget<MarkerLayer>(find.byType(MarkerLayer))
              .markers
              .single
              .point,
          LatLng(point.latitude, point.longitude),
        );
        expect(
          find.byKey(const ValueKey('draft_location_marker')),
          findsOneWidget,
        );
        expect(service.requests, hasLength(1));
        expect(service.requests.first.lat, 7.3);
        expect(
          find.textContaining('Last submitted query: 7.30°N, 81.80°E'),
          findsOneWidget,
        );
        expect(draft.startYear.text, '1990');
        expect(draft.endYear.text, '2020');
        await tester.ensureVisible(find.text('Analyze').first);
        await tester.tap(find.text('Analyze').first);
        await _settle(tester);
        expect(service.requests, hasLength(2));
        expect(
          find.byKey(const ValueKey('submitted_location_context')),
          findsNothing,
        );
        expect(service.requests.last, (
          lat: point.latitude,
          lon: point.longitude,
          start: 1990,
          end: 2020,
        ));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'manual edits move marker; incomplete text is preserved and removes stale marker',
    (tester) async {
      final service = await _pump(tester);
      final fields = find.descendant(
        of: find.byType(LocationForm),
        matching: find.byType(TextFormField),
      );
      await tester.ensureVisible(fields.first);
      await tester.enterText(fields.first, '-45.2500');
      await tester.enterText(fields.at(1), '179.7500');
      await _settle(tester);
      expect(
        tester
            .widget<MarkerLayer>(find.byType(MarkerLayer))
            .markers
            .single
            .point,
        const LatLng(-45.25, 179.75),
      );
      expect(_draft(tester).latitude.text, '-45.2500');
      expect(_draft(tester).longitude.text, '179.7500');
      await tester.enterText(fields.first, '-');
      await _settle(tester);
      expect(_draft(tester).latitude.text, '-');
      expect(find.byType(MarkerLayer), findsNothing);
      await tester.ensureVisible(find.byTooltip('Zoom in map'));
      await tester.tap(find.byTooltip('Zoom in map'));
      await _settle(tester);
      expect(_draft(tester).latitude.text, '-');
      expect(
        find.textContaining('Draft coordinates are incomplete or invalid'),
        findsOneWidget,
      );
      await tester.enterText(fields.first, '90');
      await _settle(tester);
      expect(_draft(tester).latitude.text, '90');
      expect(find.byType(MarkerLayer), findsNothing);
      expect(
        find.textContaining('outside the map’s visible range'),
        findsOneWidget,
      );
      expect(service.requests, hasLength(1));
      await tester.ensureVisible(find.text('Analyze').first);
      await tester.tap(find.text('Analyze').first);
      await _settle(tester);
      expect(service.requests.last.lat, 90);
      expect(service.requests.last.lon, 179.75);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('drag, zoom, pinch and double tap never change coordinates', (
    tester,
  ) async {
    final service = await _pump(tester);
    final draft = _draft(tester);
    final original = draft.coordinates;
    final canvas = find.byKey(const ValueKey('map_canvas'));
    await tester.ensureVisible(canvas);
    await tester.drag(canvas, const Offset(80, 20));
    await _settle(tester);
    await tester.ensureVisible(find.byTooltip('Zoom in map'));
    await tester.tap(find.byTooltip('Zoom in map'));
    await _settle(tester);
    await tester.ensureVisible(canvas);
    await tester.tap(canvas);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(canvas);
    await _settle(tester);
    final center = tester.getCenter(canvas);
    final a = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final b = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await a.moveTo(center - const Offset(70, 0));
    await b.moveTo(center + const Offset(70, 0));
    await a.up();
    await b.up();
    await _settle(tester);
    expect(draft.coordinates, original);
    expect(service.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'draft controller and marker survive tabs, collapse and breakpoint transitions',
    (tester) async {
      final service = await _pump(tester);
      await _tapPoint(tester);
      final draft = _draft(tester);
      final selected = draft.coordinates;
      draft.startYear.text = '1991';
      await tester.tap(find.byIcon(Icons.thermostat_outlined).first);
      await _settle(tester);
      expect(_draft(tester), same(draft));
      expect(find.byType(LocationMap), findsNothing);
      await tester.tap(find.byIcon(Icons.dashboard_outlined).first);
      await _settle(tester);
      expect(draft.coordinates, selected);
      for (final width in [999.0, 1000.0, 599.0, 600.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        await _settle(tester);
        expect(_draft(tester), same(draft));
        expect(draft.coordinates, selected);
        expect(draft.startYear.text, '1991');
        expect(
          tester
              .widget<MarkerLayer>(find.byType(MarkerLayer))
              .markers
              .single
              .point,
          LatLng(selected!.latitude, selected.longitude),
        );
      }
      expect(find.textContaining('Draft, not analyzed'), findsOneWidget);
      await tester.ensureVisible(find.text('Close map'));
      await tester.tap(find.text('Close map'));
      await _settle(tester);
      await tester.tap(find.text('Explore on map'));
      await _settle(tester);
      expect(draft.coordinates, selected);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(service.requests, hasLength(1));
      expect(tester.takeException(), isNull);
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
      'selection is accessible at $width, 2x text and short landscape',
      (tester) async {
        final service = await _pump(
          tester,
          width: width,
          height: width == 768 ? 320 : 900,
          scale: 2,
        );
        final semantics = tester.ensureSemantics();
        final useCentre = find.widgetWithText(TextButton, 'Use map centre');
        await tester.ensureVisible(useCentre);
        final rect = tester.getRect(useCentre);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(
          tester
              .getSemantics(useCentre)
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        Focus.of(tester.element(find.text('Use map centre'))).requestFocus();
        await tester.pump();
        final center = _camera(tester).camera.center;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await _settle(tester);
        expect(_draft(tester).coordinates!.latitude, center.latitude);
        expect(_draft(tester).coordinates!.longitude, center.longitude);
        final readout = find.byKey(const ValueKey('map_draft_location'));
        await tester.ensureVisible(readout);
        expect(tester.getRect(readout).right, lessThanOrEqualTo(width));
        final guidance = find.byKey(const ValueKey('map_scientific_guidance'));
        await tester.ensureVisible(guidance);
        expect(
          tester.widget<Text>(guidance).data,
          'The marker selects a requested geographic coordinate. '
          'NASA POWER provides gridded meteorological estimates, not a '
          'weather-station measurement at that point. Zooming the map '
          'does not increase climate-data resolution.',
        );
        final guidanceRect = tester.getRect(guidance);
        expect(guidanceRect.left, greaterThanOrEqualTo(0));
        expect(guidanceRect.right, lessThanOrEqualTo(width));
        expect(
          tester.getSemantics(guidance).label,
          contains(
            'Zooming the map does not increase climate-data resolution.',
          ),
        );
        await tester.ensureVisible(find.text('© OpenStreetMap contributors'));
        expect(find.text('© MapTiler'), findsOneWidget);
        expect(service.requests, hasLength(1));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
