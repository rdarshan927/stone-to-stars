import 'dart:async';
import 'dart:convert';
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
import 'package:mobile/widgets/app_shell.dart';
import 'package:mobile/widgets/methodology_guide.dart';
import 'package:mobile/widgets/observatory_artwork.dart';
import 'package:mobile/widgets/observatory_layout.dart';
import 'package:mobile/widgets/overview_card.dart';
import 'package:mobile/widgets/precipitation_explorer.dart';
import 'package:mobile/widgets/temperature_explorer.dart';

// Synthetic observations and their results computed once using the repository's
// existing backend functions. No NASA requests or runtime calculations are used.
ClimateAnalysis _fixture() => ClimateAnalysis.fromJson(
  jsonDecode(File('test/fixtures/p37_imagery_analysis.json').readAsStringSync())
      as Map<String, dynamic>,
);

class _Service extends ClimateApiService {
  final pending = <Completer<ClimateAnalysis>>[];
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
    final response = Completer<ClimateAnalysis>();
    pending.add(response);
    return response.future;
  }
}

const _icons = [
  Icons.dashboard_outlined,
  Icons.thermostat_outlined,
  Icons.water_drop_outlined,
  Icons.science_outlined,
];
const _destinations = [
  'overview',
  'temperature',
  'precipitation',
  'methodology',
];
final _captureKey = GlobalKey();

Future<_Service> _pump(
  WidgetTester tester,
  double width, {
  double scale = 1,
  double height = 900,
  bool complete = true,
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
  if (complete) service.pending.first.complete(_fixture());
  await tester.pump();
  if (complete) await tester.pumpAndSettle();
  return service;
}

Future<void> _select(WidgetTester tester, int index) async {
  final inactive = find.byIcon(_icons[index]);
  final destination = inactive.evaluate().isNotEmpty
      ? inactive.first
      : find.byIcon(kShellDestinations[index].selectedIcon).first;
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

void _bounds(WidgetTester tester, double width) {
  final hero = tester.getRect(find.byType(ObservatoryHero));
  final art = find.byType(ObservatoryArtwork);
  for (final element in art.evaluate()) {
    final rect = tester.getRect(find.byWidget(element.widget));
    expect(rect.left, greaterThanOrEqualTo(hero.left - .01));
    expect(rect.right, lessThanOrEqualTo(hero.right + .01));
    expect(rect.top, greaterThanOrEqualTo(hero.top - .01));
    expect(rect.bottom, lessThanOrEqualTo(hero.bottom + .01));
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    final ignore = find.descendant(
      of: find.byWidget(element.widget),
      matching: find.byType(IgnorePointer),
    );
    expect(tester.widget<IgnorePointer>(ignore).ignoring, isTrue);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(Image),
      ),
    );
    expect(image.excludeFromSemantics, isTrue);
    final shape = tester.getSize(find.byWidget(element.widget));
    final globe =
        tester.widget<ObservatoryArtwork>(find.byWidget(element.widget)).kind ==
        ObservatoryArtworkKind.globe;
    expect(
      image.fit,
      globe && shape.width / shape.height > 960 / 720
          ? BoxFit.contain
          : BoxFit.cover,
    );
    expect(image.image, isA<ResizeImage>());
  }
  final fields = find.byType(TextFormField);
  if (art.evaluate().isNotEmpty) {
    final rect = tester.getRect(art);
    for (final field in fields.evaluate()) {
      expect(
        rect.overlaps(tester.getRect(find.byWidget(field.widget))),
        isFalse,
      );
    }
    if (find.byType(AnnualChart).evaluate().isNotEmpty) {
      expect(
        rect.bottom,
        lessThan(tester.getRect(find.byType(AnnualChart)).top),
      );
    }
  }
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final rect = MatrixUtils.transformRect(
      paragraph.getTransformTo(null),
      Offset.zero & paragraph.size,
    );
    expect(
      rect.left,
      greaterThanOrEqualTo(-.01),
      reason: paragraph.text.toPlainText(),
    );
    expect(
      rect.right,
      lessThanOrEqualTo(width + .01),
      reason: paragraph.text.toPlainText(),
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('bundled illustrations decode with optimized dimensions', (
    tester,
  ) async {
    for (final (asset, expected) in [
      (ObservatoryArtwork.globeAsset, const Size(960, 720)),
      (ObservatoryArtwork.horizonAsset, const Size(1440, 810)),
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, lessThan(120000));
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(
          Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
          expected,
        );
        frame.image.dispose();
        codec.dispose();
      });
    }
  });

  testWidgets(
    'atmospheric headers retain readable text over the brightest possible artwork',
    (tester) async {
      await _pump(tester, 390);
      final brightestBackground = Color.alphaBlend(
        Colors.white.withAlpha(ObservatoryArtwork.maxHorizonAlpha),
        AppColors.atmosphere,
      );
      for (final (index, description) in [
        (1, 'Explore annual observations and seasonal evidence.'),
        (
          2,
          'Explore year-to-year rainfall variability and long-term evidence.',
        ),
      ]) {
        await _select(tester, index);
        final text = tester.widget<Text>(find.text(description));
        final contrast =
            (text.style!.color!.computeLuminance() + .05) /
            (brightestBackground.computeLuminance() + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
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
      for (final height in [900.0, 320.0]) {
        testWidgets(
          'bounded imagery and four destinations $width x $height scale $scale',
          (tester) async {
            await _pump(tester, width, scale: scale, height: height);
            for (var index = 0; index < 4; index++) {
              await _select(tester, index);
              final art = find.byType(ObservatoryArtwork);
              expect(art, index == 3 ? findsNothing : findsOneWidget);
              if (index < 3) {
                expect(
                  tester.widget<ObservatoryArtwork>(art).kind,
                  ObservatoryArtworkKind.values[index],
                );
                expect(
                  find.descendant(of: art, matching: find.byType(Semantics)),
                  findsNothing,
                );
              }
              _bounds(tester, width);
              if (index == 0) {
                expect(find.text('CLIMATE INSIGHT'), findsOneWidget);
                final hero = tester.getRect(find.byType(ObservatoryHero));
                final artwork = tester.getRect(art);
                if (width >= 1000 && hero.width >= 900 * scale) {
                  expect(
                    artwork.left,
                    greaterThan(
                      tester
                          .getRect(
                            find.text('How is the climate changing here?'),
                          )
                          .right,
                    ),
                  );
                } else {
                  expect(
                    artwork.overlaps(
                      tester.getRect(
                        find.text('How is the climate changing here?'),
                      ),
                    ),
                    isFalse,
                  );
                }
                for (final text in [
                  'Explore temperature',
                  'Explore precipitation',
                ]) {
                  await tester.ensureVisible(find.text(text));
                  await tester.pumpAndSettle();
                  expect(find.text(text).hitTestable(), findsOneWidget);
                }
              }
            }
          },
        );
      }
    }
  }

  testWidgets(
    'decoration leaves keyboard editing, drafts and submitted parameters intact',
    (tester) async {
      final service = await _pump(tester, 390);
      final edit = find.text('Edit location');
      Focus.of(tester.element(edit)).requestFocus();
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
      for (final width in [599.0, 600.0, 768.0, 999.0, 1000.0, 1280.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        for (var index = 0; index < 4; index++) {
          await _select(tester, index);
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
          _bounds(tester, width);
        }
      }
      await tester.ensureVisible(find.text('Analyze'));
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      expect(service.requests.last, (
        lat: -89.123456789,
        lon: 179.987654321,
        start: 1990,
        end: 2020,
      ));
      service.pending.last.complete(_fixture());
      await tester.pumpAndSettle();
      expect(find.byType(MethodologyGuide), findsOneWidget);
    },
  );

  testWidgets(
    'imagery retains readable loading and error controls without stale findings',
    (tester) async {
      final service = await _pump(tester, 320, scale: 2, complete: false);
      expect(
        find.text('Fetching climate data from NASA POWER…'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('overview_findings')), findsNothing);
      service.pending.first.completeError(
        const ApiException(
          ApiErrorKind.connection,
          'Service connection failed.',
        ),
      );
      await tester.pumpAndSettle();
      _bounds(tester, 320);
      await tester.ensureVisible(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(service.requests.last, service.requests.first);
      service.pending.last.complete(_fixture());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('overview_findings')), findsOneWidget);
    },
  );

  if (const bool.fromEnvironment('P37_IMAGERY_CAPTURE')) {
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
      testWidgets('capture imagery all destinations $width', (tester) async {
        await _pump(tester, width);
        // Wait for actual codecs, which can finish after pumpAndSettle in tests.
        await tester.runAsync(() async {
          for (final asset in [
            ObservatoryArtwork.globeAsset,
            ObservatoryArtwork.horizonAsset,
          ]) {
            await precacheImage(
              AssetImage(asset),
              tester.element(find.byType(DashboardScreen)),
            );
          }
        });
        for (var index = 0; index < 4; index++) {
          tester.view.physicalSize = Size(width, 900);
          await tester.pumpAndSettle();
          await _select(tester, index);
          final page = [
            find.byType(OverviewCard),
            find.byType(TemperatureExplorer),
            find.byType(PrecipitationExplorer),
            find.byType(MethodologyGuide),
          ][index];
          final scroll = find
              .ancestor(of: page, matching: find.byType(SingleChildScrollView))
              .first;
          final padding = tester
              .widget<SingleChildScrollView>(scroll)
              .padding!
              .resolve(TextDirection.ltr)
              .vertical;
          final chrome = 900 - tester.getSize(scroll).height;
          tester.view.physicalSize = Size(
            width,
            (tester.getSize(page).height + padding + chrome).ceilToDouble(),
          );
          await tester.pumpAndSettle();
          final artworkImages = find.descendant(
            of: find.byType(ObservatoryArtwork),
            matching: find.byType(Image),
          );
          await tester.runAsync(() async {
            for (final widget in tester.widgetList<Image>(artworkImages)) {
              await precacheImage(widget.image, tester.element(page));
            }
          });
          await tester.pumpAndSettle();
          final boundary =
              _captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/p37-imagery-${_destinations[index]}-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
