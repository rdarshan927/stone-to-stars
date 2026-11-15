import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/app/map_config.dart';
import 'package:mobile/app/theme.dart';
import 'package:mobile/models/climate_analysis.dart';
import 'package:mobile/screens/dashboard_screen.dart';
import 'package:mobile/services/climate_api_service.dart';
import 'package:mobile/widgets/geographical_explorer.dart';
import 'package:mobile/widgets/location_form.dart';
import 'package:mobile/widgets/location_map.dart';
import 'package:mobile/widgets/observatory_artwork.dart';

const _configured = MapTileConfiguration(
  apiKey: 'fake-test-token',
  style: 'fake-test-style',
  termsConfirmed: true,
);

class _Tiles {
  int requests = 0;
  int disposed = 0;
  bool fail = false;
  bool pending = false;
  final Uint8List bytes = File('assets/maps/maptiler-logo.png')
      .readAsBytesSync();

  TileProvider create() => _Provider(this);
}

class _Provider extends TileProvider {
  _Provider(this.owner);
  final _Tiles owner;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    owner.requests++;
    if (owner.pending) return _PendingImage();
    return MemoryImage(owner.fail ? Uint8List(0) : owner.bytes);
  }

  @override
  void dispose() => owner.disposed++;
}

class _PendingImage extends ImageProvider<_PendingImage> {
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
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
    return ClimateAnalysis.fromJson(
      jsonDecode(
        File('test/fixtures/p37_imagery_analysis.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required _Tiles tiles,
  required MapExplorerSession session,
  double width = 768,
  double height = 900,
  double scale = 1,
  MapTileConfiguration configuration = _configured,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GeographicalExplorer(
                session: session,
                configuration: configuration,
                tileProviderFactory: tiles.create,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _open(WidgetTester tester) async {
  final toggle = find.byKey(const ValueKey('map_explorer_toggle'));
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await _settle(tester);
}

void main() {
  testWidgets('toggle exposes expansion; keyboard pan and touch zoom work', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final session = MapExplorerSession();
    await _pump(tester, tiles: _Tiles(), session: session);
    final toggle = find.byKey(const ValueKey('map_explorer_toggle'));
    expect(
      tester.getSemantics(toggle).flagsCollection.isExpanded,
      ui.Tristate.isFalse,
    );
    await _open(tester);
    expect(
      tester.getSemantics(toggle).flagsCollection.isExpanded,
      ui.Tristate.isTrue,
    );
    final keyboard = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .options
        .interactionOptions
        .keyboardOptions;
    expect(keyboard.autofocus, isFalse);
    final mapFocus = tester
        .widget<Focus>(
          find.byWidgetPredicate(
            (w) => w is Focus && w.debugLabel == 'FlutterMap',
          ),
        )
        .focusNode!;
    mapFocus.requestFocus();
    await tester.pump();
    final before = session.center;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await _settle(tester);
    expect(session.center, isNot(before));
    final canvas = find.byKey(const ValueKey('map_canvas'));
    final center = tester.getCenter(canvas);
    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(center - const Offset(70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await _settle(tester);
    expect(session.zoom, greaterThan(2));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

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
    testWidgets('open explorer fits the actual shell at $width and 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _Service();
      addTearDown(service.close);
      final tiles = _Tiles();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: DashboardScreen(
            service: service,
            mapConfiguration: _configured,
            mapTileProviderFactory: tiles.create,
          ),
        ),
      );
      await _settle(tester);
      await _open(tester);
      final canvas = find.byKey(const ValueKey('map_canvas'));
      await tester.ensureVisible(canvas);
      final rect = tester.getRect(canvas);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
      final nav = tester.getRect(find.byIcon(Icons.science_outlined).first);
      expect(rect.overlaps(nav), isFalse);
      await tester.ensureVisible(find.text('© OpenStreetMap contributors'));
      expect(service.requests, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('manual analysis works without provider configuration', (
    tester,
  ) async {
    final service = _Service();
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: DashboardScreen(service: service),
      ),
    );
    await _settle(tester);
    await _open(tester);
    expect(find.byKey(const ValueKey('map_unconfigured')), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(LocationForm),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(fields.first);
    await tester.enterText(fields.first, '91');
    await tester.ensureVisible(find.text('Analyze').first);
    await tester.tap(find.text('Analyze').first);
    await _settle(tester);
    expect(find.text('−90 to 90'), findsNWidgets(2));
    expect(service.requests, hasLength(1));
    await tester.enterText(fields.first, '-45.25');
    await tester.tap(find.text('Analyze').first);
    await _settle(tester);
    expect(service.requests, hasLength(2));
    expect(service.requests.last.lat, -45.25);
    expect(tester.takeException(), isNull);
  });

  test('provider configuration is explicit and rejects public OSM tiles', () {
    expect(const MapTileConfiguration().isConfigured, isFalse);
    expect(
      const MapTileConfiguration(apiKey: 'key', style: 'style').isConfigured,
      isFalse,
    );
    expect(_configured.isConfigured, isTrue);
    expect(
      _configured.urlTemplate,
      contains('/fake-test-style/256/{z}/{x}/{y}.png'),
    );
    const osm = MapTileConfiguration(
      customUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      providerLabel: '© OSM',
      providerUrl: 'https://www.openstreetmap.org/copyright',
      termsConfirmed: true,
    );
    expect(osm.isConfigured, isFalse);
    const custom = MapTileConfiguration(
      customUrl: 'https://tiles.example.test/{z}/{x}/{y}.png',
      providerLabel: '© Test provider',
      providerUrl: 'https://example.test/license',
      termsConfirmed: true,
    );
    expect(custom.isConfigured, isTrue);
    const maptilerUrl = MapTileConfiguration(
      customUrl:
          'https://api.maptiler.com/maps/test/256/{z}/{x}/{y}.png?key=fake',
      termsConfirmed: true,
    );
    expect(maptilerUrl.isConfigured, isTrue);
    expect(maptilerUrl.isMapTiler, isTrue);
  });

  testWidgets(
    'closed explorer makes no tile requests; close disposes the map',
    (tester) async {
      final tiles = _Tiles();
      final session = MapExplorerSession();
      await _pump(tester, tiles: tiles, session: session);
      expect(find.byType(FlutterMap), findsNothing);
      expect(tiles.requests, 0);
      await _open(tester);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(tiles.requests, greaterThan(0));
      expect(
        find.text(
          'Basemap for geographical context; not NASA POWER observations.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Zoom in map'));
      await _settle(tester);
      expect(session.zoom, 3);
      await tester.tap(find.text('Close map'));
      await _settle(tester);
      final stoppedAt = tiles.requests;
      expect(tiles.disposed, 1);
      expect(find.byType(FlutterMap), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(tiles.requests, stoppedAt);
      await _open(tester);
      expect(
        MapController.of(tester.element(find.byType(TileLayer))).camera.zoom,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unconfigured provider has no map and clear independent guidance',
    (tester) async {
      final tiles = _Tiles();
      await _pump(
        tester,
        tiles: tiles,
        session: MapExplorerSession(),
        configuration: const MapTileConfiguration(),
      );
      await _open(tester);
      expect(find.byKey(const ValueKey('map_unconfigured')), findsOneWidget);
      expect(
        find.textContaining(
          'Manual location entry and climate analysis remain available',
        ),
        findsOneWidget,
      );
      expect(find.byType(FlutterMap), findsNothing);
      expect(tiles.requests, 0);
    },
  );

  testWidgets(
    'pending tiles show loading; failures offer explicit recoverable retry',
    (tester) async {
      final tiles = _Tiles()..pending = true;
      final session = MapExplorerSession()..expanded = true;
      await _pump(tester, tiles: tiles, session: session);
      expect(find.text('Loading map tiles…'), findsOneWidget);
      // Remount with a failing provider; no real network is involved.
      await tester.pumpWidget(const SizedBox());
      tiles.pending = false;
      tiles.fail = true;
      await _pump(tester, tiles: tiles, session: session);
      expect(
        find.textContaining('Some map tiles could not load'),
        findsOneWidget,
      );
      expect(find.text('Retry map tiles'), findsOneWidget);
      final failedRequests = tiles.requests;
      await tester.pump(const Duration(seconds: 2));
      expect(tiles.requests, failedRequests);
      tiles.fail = false;
      await tester.ensureVisible(find.text('Retry map tiles'));
      await tester.tap(find.text('Retry map tiles'));
      await _settle(tester);
      expect(tiles.requests, greaterThan(failedRequests));
      expect(
        find.textContaining('Some map tiles could not load'),
        findsNothing,
      );
      expect(
        find.textContaining('Basemap for geographical context'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zoom, pan, keyboard activation, recenter and page wheel scrolling',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final session = MapExplorerSession()..expanded = true;
      await _pump(tester, tiles: _Tiles(), session: session);
      final plus = find.byTooltip('Zoom in map');
      final minus = find.byTooltip('Zoom out map');
      for (final control in [
        plus,
        minus,
        find.widgetWithText(TextButton, 'Recenter view'),
      ]) {
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      }
      expect(
        tester
            .getSemantics(plus)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(plus);
      await _settle(tester);
      expect(session.zoom, 3);
      await tester.tap(minus);
      await _settle(tester);
      expect(session.zoom, 2);
      final canvas = find.byKey(const ValueKey('map_canvas'));
      final beforePan = session.center;
      await tester.drag(canvas, const Offset(80, 30));
      await _settle(tester);
      expect(session.center, isNot(beforePan));
      // Traverse to an actual map control and activate it with the keyboard.
      final focus = Focus.of(
        tester.element(
          find.descendant(of: plus, matching: find.byIcon(Icons.add)),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(session.zoom, 3);
      await tester.tap(find.text('Recenter view'));
      await _settle(tester);
      expect(session.center, const LatLng(20, 0));
      expect(session.zoom, 2);
      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(
        options.interactionOptions.flags & InteractiveFlag.scrollWheelZoom,
        0,
      );
      expect(options.onTap, isNull);
      expect(find.byType(MarkerLayer), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'attribution links are visible outside the canvas and launch correct URLs',
    (tester) async {
      final opened = <Uri>[];
      final tiles = _Tiles();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LocationMap(
                configuration: _configured,
                initialCenter: const LatLng(20, 0),
                initialZoom: 2,
                onCameraChanged: (_, _) {},
                tileProviderFactory: tiles.create,
                openLink: (url) async {
                  opened.add(url);
                  return true;
                },
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final canvas = tester.getRect(find.byKey(const ValueKey('map_canvas')));
      for (final label in ['© MapTiler', '© OpenStreetMap contributors']) {
        final link = find.text(label);
        await tester.ensureVisible(link);
        expect(tester.getRect(link).top, greaterThanOrEqualTo(canvas.bottom));
        await tester.tap(link);
        await tester.pump();
      }
      expect(opened.map((u) => u.toString()), [
        'https://www.maptiler.com/copyright/',
        'https://www.openstreetmap.org/copyright',
      ]);
      expect(find.bySemanticsLabel('MapTiler website'), findsWidgets);
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
    for (final scale in [1.0, 2.0]) {
      testWidgets('map controls and attribution fit $width at scale $scale', (
        tester,
      ) async {
        final tiles = _Tiles();
        await _pump(
          tester,
          tiles: tiles,
          session: MapExplorerSession()..expanded = true,
          width: width,
          scale: scale,
        );
        for (final item in [
          find.byKey(const ValueKey('map_canvas')),
          find.byTooltip('Zoom in map'),
          find.byTooltip('Zoom out map'),
          find.text('Recenter view'),
          find.text('© MapTiler'),
          find.text('© OpenStreetMap contributors'),
        ]) {
          await tester.ensureVisible(item);
          final rect = tester.getRect(item);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('short landscape leaves page scrolling available over the map', (
    tester,
  ) async {
    await _pump(
      tester,
      tiles: _Tiles(),
      session: MapExplorerSession()..expanded = true,
      width: 768,
      height: 320,
      scale: 2,
    );
    final canvas = find.byKey(const ValueKey('map_canvas'));
    await tester.ensureVisible(canvas);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final previous = scroll.pixels;
    final zoom = MapController.of(tester.element(find.byType(TileLayer)))
        .camera
        .zoom;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(canvas),
        scrollDelta: const Offset(0, 100),
      ),
    );
    await _settle(tester);
    expect(scroll.pixels, greaterThan(previous));
    expect(
      MapController.of(tester.element(find.byType(TileLayer))).camera.zoom,
      zoom,
    );
    await tester.ensureVisible(find.text('© OpenStreetMap contributors'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Overview map gestures preserve drafts and never analyze; manual submission still works',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _Service();
      addTearDown(service.close);
      final tiles = _Tiles();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: DashboardScreen(
            service: service,
            mapConfiguration: _configured,
            mapTileProviderFactory: tiles.create,
          ),
        ),
      );
      await _settle(tester);
      expect(service.requests, hasLength(1));
      expect(tiles.requests, 0);
      expect(find.text('How is the climate changing here?'), findsOneWidget);
      expect(find.byType(ObservatoryArtwork), findsWidgets);
      final fields = find.descendant(
        of: find.byType(LocationForm),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(0), '12.3456');
      await tester.enterText(fields.at(2), '1990');
      await _open(tester);
      await tester.ensureVisible(find.byTooltip('Zoom in map'));
      await tester.tap(find.byTooltip('Zoom in map'));
      await tester.drag(
        find.byKey(const ValueKey('map_canvas')),
        const Offset(50, 15),
      );
      await _settle(tester);
      final zoom = MapController.of(tester.element(find.byType(TileLayer)))
          .camera
          .zoom;
      expect(service.requests, hasLength(1));
      final temp = find.byIcon(Icons.thermostat_outlined).first;
      await tester.ensureVisible(temp);
      await tester.tap(temp);
      await _settle(tester);
      expect(find.byType(FlutterMap), findsNothing);
      final stopped = tiles.requests;
      await tester.pump(const Duration(seconds: 1));
      expect(tiles.requests, stopped);
      await tester.tap(find.byIcon(Icons.dashboard_outlined).first);
      await _settle(tester);
      expect(find.text('Close map'), findsOneWidget);
      expect(
        MapController.of(tester.element(find.byType(TileLayer))).camera.zoom,
        zoom,
      );
      expect(find.text('12.3456'), findsOneWidget);
      expect(find.text('1990'), findsOneWidget);
      expect(service.requests, hasLength(1));
      await tester.ensureVisible(find.text('Analyze').first);
      await tester.tap(find.text('Analyze').first);
      await _settle(tester);
      expect(service.requests, hasLength(2));
      expect(service.requests.last.lat, 12.3456);
      expect(service.requests.last.start, 1990);
      expect(tester.takeException(), isNull);
    },
  );
}
